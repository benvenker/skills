const { spawnSync } = require("node:child_process");
const { createHash } = require("node:crypto");
const { existsSync, statSync } = require("node:fs");
const { resolve } = require("node:path");

const [, , contractVersion = "", scriptDir = "", ...rawArgs] = process.argv;
const workflowArg = ".smithers/workflows/better-beads-polish-graph.tsx";
const targetNode = "synthesize-polish-plan";

function usage(message) {
  if (message) {
    console.error(message);
  }
  console.error(
    "Use: better-beads smithers review-export [--repo PATH] [--run-id RUN] " +
      "[--human-label pass|fail|defer] [--feedback TEXT] [--reviewer NAME] --json",
  );
  process.exit(2);
}

function parseArgs(args) {
  const parsed = {
    repo: process.cwd(),
    runIds: [],
    emitJson: false,
    humanLabel: null,
    feedback: "",
    reviewer: "operator",
  };

  for (let index = 0; index < args.length; ) {
    const arg = args[index];
    if (arg === "--json") {
      parsed.emitJson = true;
      index += 1;
    } else if (arg === "--repo") {
      const value = args[index + 1];
      if (!value) usage("--repo requires a path");
      parsed.repo = value;
      index += 2;
    } else if (arg === "--run-id") {
      const value = args[index + 1];
      if (!value) usage("--run-id requires a run id");
      parsed.runIds.push(value);
      index += 2;
    } else if (arg === "--human-label") {
      const value = args[index + 1]?.trim().toLowerCase();
      if (value !== "pass" && value !== "fail" && value !== "defer") {
        usage("--human-label requires pass, fail, or defer");
      }
      parsed.humanLabel = value;
      index += 2;
    } else if (arg === "--feedback") {
      const value = args[index + 1];
      if (value === undefined) usage("--feedback requires text");
      parsed.feedback = value;
      index += 2;
    } else if (arg === "--reviewer") {
      const value = args[index + 1];
      if (!value) usage("--reviewer requires a name");
      parsed.reviewer = value;
      index += 2;
    } else {
      usage(`Unknown smithers review-export option: ${arg}`);
    }
  }

  if (!parsed.emitJson) {
    usage("smithers review-export requires --json");
  }

  parsed.repo = resolve(parsed.repo);
  if (!existsSync(parsed.repo) || !statSync(parsed.repo).isDirectory()) {
    usage(`repo path does not exist or is not a directory: ${parsed.repo}`);
  }

  return parsed;
}

function which(binary) {
  const searchPath = process.env.PATH ?? "";
  for (const entry of searchPath.split(":")) {
    if (!entry) continue;
    const candidate = resolve(entry, binary);
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

function stderrSnippet(text, limit = 20) {
  return text
    .trim()
    .split(/\r?\n/)
    .filter((line) => line.trim())
    .slice(0, limit)
    .join("\n");
}

function parseJson(text) {
  if (!text.trim()) return [null, null];
  try {
    return [JSON.parse(text), null];
  } catch (error) {
    return [null, String(error instanceof Error ? error.message : error)];
  }
}

function commandRecord(repo, command, options = {}) {
  const parseStdout = options.parseStdout ?? true;
  const result = spawnSync(command[0], command.slice(1), {
    cwd: repo,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  const stdout = result.stdout ?? "";
  const stderr = result.stderr ?? "";
  const record = {
    command,
    exit_code: result.status,
    stdout_bytes: Buffer.byteLength(stdout),
    stderr: stderrSnippet(stderr),
  };
  if (parseStdout) {
    const [stdoutJson, parseError] = parseJson(stdout);
    record.stdout_json = stdoutJson;
    record.parse_error = parseError;
  }
  if (options.keepStdout) {
    record.stdout = stdout;
  }
  return record;
}

function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function parseEventsNdjson(text) {
  const events = [];
  const errors = [];
  text.split(/\r?\n/).forEach((line, index) => {
    if (!line.trim()) return;
    try {
      const parsed = JSON.parse(line);
      if (isRecord(parsed)) {
        events.push(parsed);
      } else {
        errors.push(`line ${index + 1}: expected object`);
      }
    } catch (error) {
      errors.push(`line ${index + 1}: ${String(error instanceof Error ? error.message : error)}`);
    }
  });
  return [events, errors.length ? errors.join("; ") : null];
}

function jsonCandidatesFromText(text) {
  const candidates = [];
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    if (char !== "{") continue;
    let depth = 0;
    let inString = false;
    let escaped = false;
    for (let cursor = index; cursor < text.length; cursor += 1) {
      const current = text[cursor];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (current === "\\") {
          escaped = true;
        } else if (current === "\"") {
          inString = false;
        }
        continue;
      }
      if (current === "\"") {
        inString = true;
        continue;
      }
      if (current === "{") depth += 1;
      if (current === "}") depth -= 1;
      if (depth !== 0) continue;
      try {
        candidates.push(JSON.parse(text.slice(index, cursor + 1)));
      } catch {
        break;
      }
      break;
    }
  }
  return candidates;
}

function looksLikePolishResult(value) {
  return (
    isRecord(value) &&
    typeof value.verdict === "string" &&
    typeof value.summary === "string" &&
    isRecord(value.judge_scores)
  );
}

function extractPolishResult(value) {
  if (looksLikePolishResult(value)) return [value, null];
  if (isRecord(value)) {
    for (const key of ["output", "value", "data"]) {
      const candidate = value[key];
      if (looksLikePolishResult(candidate)) return [candidate, null];
    }
    if (isRecord(value.row)) {
      const [nested] = extractPolishResult(value.row);
      if (nested) return [nested, null];
    }
  }
  return [null, "could not locate polish result in output row"];
}

function extractNodeValidated(value) {
  if (!isRecord(value)) return [null, "Smithers node output was not an object"];
  const output = value.output;
  if (isRecord(output)) {
    if (looksLikePolishResult(output.validated)) return [output.validated, null];
    if (looksLikePolishResult(output.raw)) return [output.raw, null];
  }
  return [null, "could not locate polish result in node output"];
}

function extractPolishResultFromEvents(events) {
  const chunks = [];
  events.forEach((event, index) => {
    const payload = event.payload;
    if (!isRecord(payload)) return;
    if (payload.nodeId !== targetNode) return;
    if (payload.stream !== undefined && payload.stream !== null && payload.stream !== "stdout") return;
    if (typeof payload.text !== "string" || payload.text.length === 0) return;
    chunks.push([typeof event.seq === "number" ? event.seq : index, payload.text]);
  });
  if (!chunks.length) {
    return [null, `could not locate ${targetNode} stdout chunks in Smithers events`];
  }
  const combined = chunks
    .sort((left, right) => left[0] - right[0])
    .map(([, text]) => text)
    .join("");
  const valid = jsonCandidatesFromText(combined).filter(looksLikePolishResult);
  if (valid.length) return [valid[valid.length - 1], null];
  return [null, "could not parse schema-valid polish result from Smithers output events"];
}

function normalizeDependencyIds(issue, key) {
  return asArray(issue[key]).flatMap((entry) => {
    if (typeof entry === "string") return [entry];
    if (isRecord(entry) && typeof entry.id === "string") return [entry.id];
    return [];
  });
}

function compactIssue(issue) {
  return {
    id: typeof issue.id === "string" ? issue.id : null,
    title: typeof issue.title === "string" ? issue.title : null,
    status: typeof issue.status === "string" ? issue.status : null,
    priority: typeof issue.priority === "number" ? issue.priority : null,
    issue_type:
      typeof issue.issue_type === "string"
        ? issue.issue_type
        : typeof issue.type === "string"
          ? issue.type
          : null,
    labels: asArray(issue.labels).filter((label) => typeof label === "string"),
    parent: typeof issue.parent === "string" ? issue.parent : null,
    dependencies: normalizeDependencyIds(issue, "dependencies"),
    dependents: normalizeDependencyIds(issue, "dependents"),
    description: typeof issue.description === "string" ? issue.description : "",
  };
}

function issueRecords(value) {
  if (Array.isArray(value)) return value.filter(isRecord);
  if (isRecord(value) && Array.isArray(value.issues)) return value.issues.filter(isRecord);
  return [];
}

function collectBeadsSnapshot(repo) {
  const record = commandRecord(repo, ["br", "list", "--json"]);
  const issues = issueRecords(record.stdout_json)
    .map(compactIssue)
    .sort((left, right) => String(left.id ?? "").localeCompare(String(right.id ?? "")));
  return [issues, record];
}

function runIdsFromPs(repo) {
  const record = commandRecord(repo, ["bunx", "smithers-orchestrator", "ps", "--all", "--format", "json"]);
  const payload = record.stdout_json;
  let candidates = [];
  if (Array.isArray(payload)) {
    candidates = payload;
  } else if (isRecord(payload)) {
    for (const key of ["runs", "items", "data"]) {
      if (Array.isArray(payload[key])) {
        candidates = payload[key];
        break;
      }
    }
  }
  const ids = candidates.flatMap((candidate) => {
    if (!isRecord(candidate)) return [];
    const runId = candidate.runId ?? candidate.id;
    return typeof runId === "string" && runId.includes("better-beads-polish-graph") ? [runId] : [];
  });
  return [ids, record];
}

function shellCommand(command) {
  return command
    .map((part) => (/^[A-Za-z0-9_./:=@+-]+$/.test(part) ? part : JSON.stringify(part)))
    .join(" ");
}

function commandsFor(runId) {
  return {
    inspect: ["bunx", "smithers-orchestrator", "inspect", runId, "--format", "json"],
    output: ["bunx", "smithers-orchestrator", "output", runId, targetNode, "--json"],
    node: ["bunx", "smithers-orchestrator", "node", targetNode, "--run-id", runId, "--format", "json", "--filter-output", "output"],
    events: ["bunx", "smithers-orchestrator", "events", runId, "--node", targetNode, "--type", "output", "--json", "--limit", "100000"],
    chat: ["bunx", "smithers-orchestrator", "chat", runId, "--tail", "20"],
    logs: ["bunx", "smithers-orchestrator", "logs", runId, "--tail", "80"],
    scores: ["bunx", "smithers-orchestrator", "scores", runId, "--node", targetNode],
  };
}

function extractResultForRun(repo, runId) {
  const commands = commandsFor(runId);
  const outputRecord = commandRecord(repo, commands.output);
  const inspectRecord = commandRecord(repo, commands.inspect);
  const nodeRecord = commandRecord(repo, commands.node);
  const eventsRecord = commandRecord(repo, commands.events, { parseStdout: false, keepStdout: true });
  const [eventsJson, eventsParseError] = parseEventsNdjson(eventsRecord.stdout ?? "");
  delete eventsRecord.stdout;
  eventsRecord.stdout_json = eventsJson;
  eventsRecord.parse_error = eventsParseError;
  const scoresRecord = commandRecord(repo, commands.scores);

  let [result, resultError] = extractPolishResult(outputRecord.stdout_json);
  let resultSource = result ? "output_row" : "none";
  const extractionErrors = resultError ? [resultError] : [];

  if (!result) {
    const [nodeResult, nodeError] = extractNodeValidated(nodeRecord.stdout_json);
    if (nodeResult) {
      result = nodeResult;
      resultSource = "node_validated";
      resultError = null;
    } else {
      if (nodeError) extractionErrors.push(nodeError);
      const [eventResult, eventError] = extractPolishResultFromEvents(eventsJson);
      if (eventResult) {
        result = eventResult;
        resultSource = "output_events";
        resultError = null;
      } else {
        if (eventError) extractionErrors.push(eventError);
        resultError = extractionErrors.filter(Boolean).join("; ");
      }
    }
  }

  return {
    result,
    resultSource,
    resultError,
    records: {
      output: outputRecord,
      inspect: inspectRecord,
      node: nodeRecord,
      events: eventsRecord,
      scores: scoresRecord,
    },
  };
}

function labelToEvalStatus(label) {
  if (label === "pass") return "Pass";
  if (label === "fail") return "Fail";
  if (label === "defer") return "Defer";
  return null;
}

function makeEvalCase(args, runId, result, beads, reviewedAt) {
  const humanResult = labelToEvalStatus(args.humanLabel);
  if (!humanResult) return null;
  const judge = isRecord(result?.judge_verdict) ? result.judge_verdict : null;
  const judgeResult = typeof judge?.result === "string" ? judge.result : "";
  const disagreement = Boolean(judgeResult && judgeResult.toLowerCase() !== args.humanLabel);
  const beadIds = beads.flatMap((issue) => (typeof issue.id === "string" ? [issue.id] : []));
  const caseId = `human-review-${createHash("sha1").update(`${runId}:${reviewedAt}`).digest("hex").slice(0, 10)}`;
  return {
    id: caseId,
    input: {
      request: "Post-hoc human review of Better Beads Smithers polish output.",
      repo: args.repo,
      apply: false,
      strict: true,
      localInspection: {
        reviewed_run_id: runId,
        reviewed_bead_ids: beadIds,
      },
    },
    expected: {
      outputContains: {
        polishPlan: {
          judge_verdict: {
            result: humanResult,
          },
        },
      },
    },
    annotations: {
      suite: "better-beads-polish-human-review",
      human_label: humanResult,
      reviewer: args.reviewer,
      reviewed_at: reviewedAt,
      judge_result: judgeResult,
      judge_disagreement: disagreement,
    },
    metadata: {
      human_review: {
        label: humanResult,
        feedback: args.feedback,
        reviewed_at: reviewedAt,
        reviewer: args.reviewer,
        source: {
          run_id: runId,
          workflow_path: workflowArg,
          target_node: targetNode,
          bead_ids: beadIds,
        },
        judge,
        judge_disagreement: disagreement,
      },
    },
  };
}

function main() {
  void scriptDir;
  const args = parseArgs(rawArgs);
  const bunxPath = which("bunx");
  const workflowPath = resolve(args.repo, workflowArg);
  const checks = {
    bunx: { available: bunxPath !== null, path: bunxPath, invoked: false },
    smithers_dir: { available: existsSync(resolve(args.repo, ".smithers")), path: resolve(args.repo, ".smithers") },
    workflow: { available: existsSync(workflowPath), path: workflowPath },
  };
  const missing = Object.entries(checks)
    .filter(([, check]) => !check.available)
    .map(([name]) => name);
  const available = missing.length === 0;
  const payload = {
    tool: "better-beads",
    schema: "better-beads-smithers-review-export-v1",
    contract_version: contractVersion,
    available,
    repo: args.repo,
    workflow_path: workflowArg,
    run_ids: args.runIds,
    checks,
    missing,
    items: [],
    ps: null,
    error: null,
  };

  if (!available) {
    payload.error = "Smithers unavailable: bunx missing, .smithers missing, or workflow template not installed.";
    console.log(JSON.stringify(payload, null, 2));
    return;
  }

  let runIds = args.runIds;
  if (!runIds.length) {
    const [discovered, psRecord] = runIdsFromPs(args.repo);
    runIds = discovered;
    payload.run_ids = runIds;
    payload.ps = psRecord;
  }

  const [beads, beadsRecord] = collectBeadsSnapshot(args.repo);
  const reviewedAt = new Date().toISOString();
  payload.items = runIds.map((runId) => {
    const { result, resultSource, resultError, records } = extractResultForRun(args.repo, runId);
    const scoresPayload = records.scores.stdout_json;
    const scores = isRecord(scoresPayload) && Array.isArray(scoresPayload.scores) ? scoresPayload.scores : [];
    const commands = commandsFor(runId);
    return {
      item_id: `smithers-polish:${runId}:${targetNode}`,
      source: "smithers_polish_run",
      run_id: runId,
      workflow_path: workflowArg,
      target_node: targetNode,
      result,
      result_source: resultSource,
      result_error: resultError,
      judge_verdict: isRecord(result?.judge_verdict) ? result.judge_verdict : null,
      judge_scores: isRecord(result?.judge_scores) ? result.judge_scores : null,
      smithers_scores: scores,
      beads,
      beads_record: beadsRecord,
      commands: Object.fromEntries(Object.entries(commands).map(([name, command]) => [name, shellCommand(command)])),
      smithers: records,
      human_review: {
        label: labelToEvalStatus(args.humanLabel),
        feedback: args.feedback,
        reviewer: args.humanLabel ? args.reviewer : null,
        reviewed_at: args.humanLabel ? reviewedAt : null,
      },
      eval_case: makeEvalCase(args, runId, result, beads, reviewedAt),
    };
  });

  console.log(JSON.stringify(payload, null, 2));
}

main();

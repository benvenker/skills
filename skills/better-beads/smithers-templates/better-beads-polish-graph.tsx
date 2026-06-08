/** @jsxImportSource smithers-orchestrator */
import { createSmithers, PiAgent } from "smithers-orchestrator";
import { schemaAdherenceScorer } from "smithers-orchestrator/scorers";
import { z } from "zod/v4";

const inputSchema = z.object({
  request: z
    .string()
    .default("Polish existing Better Beads graph before implementation dispatch."),
  repo: z.string().default("."),
  apply: z.boolean().default(false),
  strict: z.boolean().default(true),
  localInspection: z.unknown().optional(),
});

const reviewerKindSchema = z.enum([
  "behavior-contract",
  "implementation-agent",
  "dependency-reviewability",
]);

const recommendedChangeSchema = z.object({
  kind: z.enum([
    "keep",
    "deepen",
    "split",
    "merge",
    "add_dependency",
    "remove_dependency",
    "add_label",
    "remove_label",
    "close_unnecessary",
    "defer",
  ]),
  beadId: z.string().optional(),
  titleOrScope: z.string().optional(),
  reason: z.string(),
});

const reviewerFindingSchema = z.object({
  reviewer: reviewerKindSchema,
  summary: z.string(),
  blockers: z.array(z.string()).default([]),
  warnings: z.array(z.string()).default([]),
  recommendedChanges: z.array(recommendedChangeSchema).default([]),
});

const recommendedMutationSchema = z.object({
  kind: z.enum([
    "update_description",
    "split",
    "merge",
    "add_dependency",
    "remove_dependency",
    "add_label",
    "remove_label",
    "close_unnecessary",
    "defer",
  ]),
  bead_id: z.string().optional(),
  reason: z.string(),
  command: z.string().nullable().default(null),
});

const polishPlanSchema = z.object({
  verdict: z.enum(["ready", "needs_mutation", "blocked"]),
  summary: z.string(),
  recommended_mutations: z.array(recommendedMutationSchema).default([]),
  ready_frontier: z.array(z.string()).default([]),
  blocked_dispatch_reasons: z.array(z.string()).default([]),
  judge_verdict: z.object({
    result: z.enum(["Pass", "Fail"]),
    critique: z.string(),
    confidence: z.number().min(0).max(1).default(0.5),
  }),
  judge_scores: z.object({
    behavior_contract_quality: z.number().min(0).max(1),
    implementation_fungibility: z.number().min(0).max(1),
    dependency_correctness: z.number().min(0).max(1),
    reviewability: z.number().min(0).max(1),
    dispatch_readiness: z.number().min(0).max(1),
  }),
});

const { Workflow, Sequence, Parallel, Task, smithers, outputs } = createSmithers({
  input: inputSchema,
  reviewerFinding: reviewerFindingSchema,
  polishPlan: polishPlanSchema,
});

const model =
  process.env.BETTER_BEADS_SMITHERS_MODEL ??
  process.env.SMITHERS_MODEL ??
  "anthropic/claude-sonnet-4.6";

const provider =
  process.env.BETTER_BEADS_SMITHERS_PROVIDER ??
  process.env.SMITHERS_PROVIDER ??
  "openrouter";

const reviewer = new PiAgent({
  provider,
  model,
  cwd: process.cwd(),
  noSession: true,
  tools: ["read", "grep"],
  noExtensions: true,
  skill: ["better-beads"],
});

const synthesizer = new PiAgent({
  provider,
  model,
  cwd: process.cwd(),
  noSession: true,
  tools: ["read", "grep"],
  noExtensions: true,
  skill: ["better-beads"],
});

export default smithers((ctx) => {
  const input = ctx.input;
  const inspectionJson = JSON.stringify(input.localInspection ?? null, null, 2);
  const sharedContext = [
    `Request: ${input.request}`,
    `Repository: ${input.repo}`,
    `Strict mode: ${input.strict ? "true" : "false"}`,
    `Apply requested: ${input.apply ? "true" : "false"}`,
    "Local inspection JSON:",
    inspectionJson,
  ].join("\n");

  return (
    <Workflow name="better-beads-polish-graph">
      <Sequence>
        <Parallel id="polish-review" maxConcurrency={3}>
          <Task
            id="behavior-contract-review"
            label="Behavior contract review"
            output={outputs.reviewerFinding}
            agent={reviewer}
          >
            You are reviewing a Better Beads graph as a behavior-contract
            editor.
            {"\n\n"}
            {sharedContext}
            {"\n\n"}
            Check outcome, success criteria, non-goals, failure behavior,
            validation, grounding, and closure evidence. Recommend only graph
            or Bead-contract changes. Do not mutate Beads. Do not produce
            implementation code. If apply is true, treat it as out of scope and
            continue recommendation-only review. Use the Better Beads skill and
            read-only repo inspection where useful. You may read and grep files
            for context, but you must not run shell commands, edit files, mutate
            Beads, close issues, commit, push, or implement any Bead. Treat
            localInspection.context_pack as the authoritative Beads graph pack
            when present. Use full Bead IDs exactly as given. Distinguish
            contract updates to existing Beads from new-Bead suggestions,
            dependency repairs, and label repairs.
            {"\n\n"}
            Return only JSON matching the reviewer finding schema with reviewer
            set to "behavior-contract".
          </Task>

          <Task
            id="implementation-agent-review"
            label="Implementation agent review"
            output={outputs.reviewerFinding}
            agent={reviewer}
          >
            You are reviewing a Better Beads graph as a fresh implementation
            agent who must execute exactly one leaf Bead.
            {"\n\n"}
            {sharedContext}
            {"\n\n"}
            Identify where implementation would require product, architecture,
            data-contract, failure-handling, or verification invention. Prefer
            recommendations that make each Bead executable by a fungible coding
            agent without hidden context. Do not mutate Beads. Do not produce
            implementation code. If apply is true, treat it as out of scope and
            continue recommendation-only review. Use the Better Beads skill and
            read-only repo inspection where useful. You may read and grep files
            for context, but you must not run shell commands, edit files, mutate
            Beads, close issues, commit, push, or implement any Bead. Treat
            localInspection.context_pack as the authoritative Beads graph pack
            when present. Use full Bead IDs exactly as given. Distinguish
            contract updates to existing Beads from new-Bead suggestions,
            dependency repairs, and label repairs.
            {"\n\n"}
            Return only JSON matching the reviewer finding schema with reviewer
            set to "implementation-agent".
          </Task>

          <Task
            id="dependency-reviewability-review"
            label="Dependency and reviewability review"
            output={outputs.reviewerFinding}
            agent={reviewer}
          >
            You are reviewing a Better Beads graph as a dependency and
            reviewability auditor.
            {"\n\n"}
            {sharedContext}
            {"\n\n"}
            Check parent closure contracts, child ordering, dependency
            correctness, ready-for-agent truth, reviewable atomicity, and unsafe
            parallelism. Prefer graph-shape fixes over prose churn. Do not
            mutate Beads. Do not produce implementation code. If apply is true,
            treat it as out of scope and continue recommendation-only review.
            Use the Better Beads skill and read-only repo inspection where
            useful. You may read and grep files for context, but you must not
            run shell commands, edit files, mutate Beads, close issues, commit,
            push, or implement any Bead. Treat localInspection.context_pack as
            the authoritative Beads graph pack when present. Use full Bead IDs
            exactly as given. Distinguish contract updates to existing Beads
            from new-Bead suggestions, dependency repairs, and label repairs.
            {"\n\n"}
            Return only JSON matching the reviewer finding schema with reviewer
            set to "dependency-reviewability".
          </Task>
        </Parallel>

        <Task
          id="synthesize-polish-plan"
          label="Synthesize polish plan"
          output={outputs.polishPlan}
          agent={synthesizer}
          deps={{
            behavior: outputs.reviewerFinding,
            implementation: outputs.reviewerFinding,
            dependency: outputs.reviewerFinding,
          }}
          needs={{
            behavior: "behavior-contract-review",
            implementation: "implementation-agent-review",
            dependency: "dependency-reviewability-review",
          }}
          scorers={{
            schema: { scorer: schemaAdherenceScorer() },
          }}
        >
          {({ behavior, implementation, dependency }) => (
            <>
              Combine the three reviews into one Better Beads polish
              recommendation.
              {"\n\n"}
              Request context:
              {"\n"}
              {sharedContext}
              {"\n\n"}
              Behavior-contract review:
              {"\n"}
              {JSON.stringify(behavior, null, 2)}
              {"\n\n"}
              Implementation-agent review:
              {"\n"}
              {JSON.stringify(implementation, null, 2)}
              {"\n\n"}
              Dependency-reviewability review:
              {"\n"}
              {JSON.stringify(dependency, null, 2)}
              {"\n\n"}
              Prefer graph-shape fixes over prose churn. Classify weak Beads as
              keep, split, merge, deepen, defer, close unnecessary, relabel, or
              dependency repair. Do not mutate Beads. Do not invent repo file
              changes. Do not produce implementation code. If reviewer findings
              disagree, synthesize a verdict of ready, needs_mutation, or
              blocked with concrete reasons.
              {"\n\n"}
              Use the Better Beads skill and read-only repo inspection where
              useful. You may read and grep files for context, but you must not
              run shell commands, edit files, mutate Beads, close issues,
              commit, push, or implement any Bead. Treat
              localInspection.context_pack as the authoritative Beads graph pack
              when present. Use full Bead IDs exactly as given. Distinguish
              contract updates to existing Beads from new-Bead suggestions,
              dependency repairs, and label repairs.
              {"\n\n"}
              Return only JSON matching the polish plan schema. Judge scores
              must be numbers from 0 to 1. The judge_verdict is advisory:
              return Pass only if the graph is ready for operator dispatch or
              the recommended mutations are precise enough for a human to
              review and apply without product invention; return Fail when
              the polish result is blocked, vague, unsafe, missing full Bead
              IDs, or would still require product/architecture invention.
            </>
          )}
        </Task>
      </Sequence>
    </Workflow>
  );
});

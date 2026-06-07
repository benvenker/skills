# Agent Skills

Agent skills I use for planning, reviewing, and shipping software with AI coding agents.

## Skills

### better-beads

Better Beads helps create and polish Beads task graphs as behavioral execution contracts for fungible coding agents. The skill emphasizes outcome-first task design, dependency correctness, parent closure contracts, validation, BV readability, and reviewable PR-sized slices.

Use it when converting plans or PRDs into Beads, reviewing an existing Beads graph, or tightening tasks before multi-agent implementation.

The packaged skill includes an inspection-first routing workflow:

- `scripts/better-beads route --json` delegates to `bead_route.sh` and emits
  `better-beads-route-v1`.
- `scripts/better-beads route --plan PATH --json` reports plan-readiness gates
  and routes weak plans to `improve-plan-first`.
- `scripts/better-beads capabilities --json` and the reference docs publish the
  robot surfaces, schemas, and delegated helper identity expected by agents.

It also includes closeout helpers so implementation swarms do not leave
completed work stuck in `in_progress`. Use
`skills/better-beads/scripts/bead_closeout_guard.sh` from swarm/operator
closeout hooks to fail loudly until each in-progress bead is closed, reopened,
or marked blocked with evidence.

## Install

List available skills:

```bash
npx skills add benvenker/skills --list
```

Install the Beads authoring skill globally:

```bash
npx skills add benvenker/skills --skill better-beads -g -y
```

Install all skills in this repo:

```bash
npx skills add benvenker/skills --all -g -y
```

## Structure

Each skill lives under `skills/<skill-name>/` and follows the Agent Skills format:

- `SKILL.md` — trigger description and operating instructions
- `references/` — examples, rubrics, failure modes, and longer guidance
- `scripts/` — optional validation or helper scripts

## License

MIT

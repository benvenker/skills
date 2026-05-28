# Ben Venker Skills

Agent skills I use for planning, reviewing, and shipping software with AI coding agents.

## Skills

### better-beads

Better Beads helps create and polish Beads task graphs as behavioral execution contracts for fungible coding agents. The skill emphasizes outcome-first task design, dependency correctness, parent closure contracts, validation, BV readability, and reviewable PR-sized slices.

Use it when converting plans or PRDs into Beads, reviewing an existing Beads graph, or tightening tasks before multi-agent implementation.

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

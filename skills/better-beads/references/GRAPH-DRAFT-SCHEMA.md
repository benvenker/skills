# Graph Draft Schema

`better-beads create-graph` turns a reviewed JSON draft into `br` commands.
Always run `--dry-run` first and inspect the preview before `--apply`.

## Command

```bash
skills/better-beads/scripts/better-beads create-graph --dry-run skills/better-beads/test/fixtures/example-graph.json
skills/better-beads/scripts/better-beads create-graph --apply path/to/reviewed-graph.json
```

Both modes emit JSON. Dry-run is read-only and previews:

- issue titles, labels, priorities, and preview IDs
- parent closure relationships
- blocking dependencies
- dependency cycles detected in the draft
- blocked `ready-for-agent` labels
- the exact `br create` and `br dep add` commands apply would run

Apply runs the same preflight first. Invalid references, duplicate keys/titles,
duplicate slugs, dependency cycles, and blocked ready-frontier labels fail before
any graph mutation.

## Schema

```json
{
  "schema": "better-beads-graph-draft-v1",
  "issues": [
    {
      "key": "parent",
      "title": "Improve graph authoring",
      "type": "epic",
      "priority": 1,
      "labels": ["better-beads"],
      "description": "Markdown bead body"
    },
    {
      "key": "child",
      "title": "Add helper",
      "type": "feature",
      "priority": 2,
      "labels": ["better-beads", "cli"],
      "ready_frontier": true,
      "parent": "parent",
      "description": "Markdown bead body"
    }
  ],
  "parent_closure": [
    {"parent": "parent", "child": "child"}
  ],
  "dependencies": [
    {"issue": "child", "depends_on": "cookbook", "type": "blocks"}
  ]
}
```

`parent` on an issue and `parent_closure` express the same parent-child closure
relationship. Use one parent per child. The helper applies parent closure with
`br create --parent <parent-id>` so parent issues are created before their
children.

Use `dependencies` for implementation order. The default type is `blocks`,
matching `br dep add <issue> <depends-on>`.

`ready_frontier: true` adds `ready-for-agent` to the issue labels. The helper
rejects drafts that put this label on parent issues or issues with blocking
dependencies.

## Recovery

If `br` fails during apply after preflight, the helper emits a
`better-beads-create-graph-apply-v1` JSON object with:

- `applied: false`
- `created_ids`
- `last_successful_mutation`
- `failed_mutation`
- recovery evidence commands

Inspect that payload before retrying. Do not rerun apply blindly against a
partially-created graph.

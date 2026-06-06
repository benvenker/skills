# Uplift Diff — Pass 1

Manual baseline was script-only: no unified CLI, no capabilities endpoint, no robot docs, no typo suggestions.

| Dimension | Result |
|---|---|
| agent_intuitiveness | Large uplift: `scripts/better-beads` is now the first command to try. |
| agent_ergonomics | Large uplift: `triage --json` returns quick_ref + recommended commands in one call. |
| output_parseability | Large uplift: capabilities/triage JSON are stdout-only and schema-shaped. |
| error_pedagogy | Medium uplift: unknown flags/commands now suggest exact corrections. |
| self_documentation | Large uplift: every script has capabilities + robot docs. |
| regression_resistance | Medium uplift: robot surfaces pinned by smoke + audit regression test. |

No regressions observed in validation.

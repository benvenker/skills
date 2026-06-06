# Mode: closeout

Make bead state truthful at the end of implementation or operator work. Close completed beads, reopen incomplete work, block genuinely blocked work.

## When to use

- Implementation or operator turn is ending.
- Any relevant bead is `in_progress`.
- User asks to close, reopen, block, or reconcile bead state.

## Inspection

Inspect `in_progress` and relevant active beads:

```bash
br list --json
br show <id> --json     # for each in_progress bead
```

## Actions

1. **Inspect** `in_progress` and relevant active beads with `br --json`.
2. **Choose exactly one truth outcome** for each bead:
   - **close** completed work with evidence;
   - **reopen** incomplete work with the remaining work/reason;
   - **block** genuinely blocked work with exact blocker and evidence.
3. **Close parent beads** only after children are closed or explicitly closed as unnecessary with evidence.
4. **Run** closeout guard unless the user explicitly opted out.

## Closure evidence

Close each bead with:

- what changed;
- exact verification commands run;
- result summary;
- commit SHA or note that changes remain uncommitted;
- any deferred or rejected follow-up captured as another bead.

If the bead is not complete, reopen it with the remaining work or block it with the exact blocker and evidence.

## Gates

```bash
br sync --flush-only
scripts/bead_closeout_guard.sh --repo . --json
```

Do not end an operator or implementation turn with unexpected `in_progress` beads.

## Outputs

- Close/reopen/block mutations with evidence.
- Parent closure correctness checked.
- Closeout guard result.
- Follow-up beads or blockers, if any.

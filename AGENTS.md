# Repository Instructions

This repo contains public agent skills.

## Editing rules

- Keep skills portable: avoid private machine paths, secrets, project-specific assumptions, and unpublished internal repo references unless they are clearly examples.
- Prefer concise `SKILL.md` files and put long examples, rubrics, and prompts under `references/`.
- If a skill includes scripts, make them safe to run from arbitrary repos and document required tools.
- Validate Markdown formatting and run any included skill scripts after changing them.

## Skill packaging

Skills live under `skills/<skill-name>/` and should be installable with:

```bash
npx skills add benvenker/skills --skill <skill-name>
```

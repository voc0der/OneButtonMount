# Contributing

Thanks for working on `OneButtonMount`.

Keep changes focused on mount selection, summon behavior, and the small amount of UI needed to manage the addon. This repo does not need extra process or feature sprawl.

## Local Setup

- Target client: TBC Anniversary Classic
- Addon install path: `World of Warcraft/_anniversary_/Interface/AddOns/`
- Main runtime files are listed in [OneButtonMount.toc](OneButtonMount.toc)

## Development

Run the local test suite:

```bash
lua tests/run.lua
```

Run a syntax check before opening a PR:

```bash
luac -p OneButtonMount.lua tests/run.lua
```

If you change packaging or release behavior, verify the runtime-only package contents too:

```bash
bash ./.github/scripts/verify-release-package.sh
```

## Project Expectations

- Keep the addon focused on summoning and mount-pool management.
- Prefer small, targeted changes over broad rewrites.
- If you add a new runtime file, include it in [OneButtonMount.toc](OneButtonMount.toc).
- Player-facing packages should only include files the game client actually needs.

## Pull Requests

- Use conventional commit titles such as `feat(...)`, `fix(...)`, `docs(...)`, or `ci(...)`.
- Include a short summary of what changed and how you verified it.
- If the change affects game UI, include screenshots or a brief description of the visible behavior.
- Keep PRs scoped to one logical change when possible.

## Releases

- Release-specific steps are documented in [RELEASING.md](RELEASING.md).
- Version bumps should update the addon version in [OneButtonMount.toc](OneButtonMount.toc), plus any matching references in docs or changelog entries.
- Packaging changes should keep working with both the PR artifact workflow and the GitHub/CurseForge release workflow.

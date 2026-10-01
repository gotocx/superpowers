# TraeCode IDE integration candidate — installation blocked

This is not a released or submission-ready harness integration. The hook
adapter can be tested locally, but delivery through a native IDE installation
mechanism and a real clean-session acceptance transcript are still missing.

## Source and layout

Use `https://github.com/obra/superpowers.git`, branch `dev`, and its existing
`skills/` tree. Do not fetch the retired skills repository, rename
`using-skills`, flatten reference files into skills, or copy the old workflow
rule. For pre-merge testing use the exact candidate commit rather than assuming
that files already exist on upstream `dev` or released `main`.

The candidate adds:

- `hooks/hooks-trae.json`: the documented version-1 `SessionStart` schema.
- `hooks/session-start --trae`: the shared bootstrap with an explicit Trae mode.
- `skills/using-superpowers/references/trae-tools.md`: the action mapping.
- `tests/trae/`: deterministic protocol tests, with no model credentials.

No versioned plugin manifest is invented. `version: 1` in the hook config is
the Trae schema version, not the Superpowers release version.

## Bootstrap contract

Trae documents `SessionStart` before the first user message, with `source:
startup`. The adapter emits exactly one context field:
`hookSpecificOutput.additionalContext`, with `hookEventName: SessionStart`.
It injects the current full `using-superpowers/SKILL.md`, wraps it in
`<EXTREMELY_IMPORTANT>`, and points to the tool mapping. It reads no stdin,
performs no network requests, and does not write user configuration or memory.

The reference hook command uses the existing polyglot wrapper. Its relative
path is valid only when the hook's working directory is the package root. The
native installation adapter must resolve the installed package location; this
reference is not a deployable project configuration.

## Delivery gate

The official IDE documentation describes native skill import under **Settings
> Skills and Commands > Create**, and project/global hook configuration under
**Settings > Hooks**. It does not establish that a skill import preserves,
registers, or loads a bundled hook. Reading Claude Code settings is also not
proof that Trae installs Claude Code plugins.

Before calling this supported, identify and verify a native install surface
that delivers both skills and bootstrap. Do not bridge the gap by writing
`.trae/hooks.json`, user rules, global settings, or symlinks in the user's project
or home. `docs/porting-to-a-new-harness.md`, Part 1 rule 2 and Part 6, require
surfacing this limitation rather than shipping a config-editing installer.

If a native installed skill's startup description is the only supported
bootstrap surface, evaluate that route separately as permitted by Part 6; do
not claim it implements the hook delivery shown here without evidence.

## Local verification

From a checkout containing the candidate:

```bash
bash tests/trae/run-tests.sh
bash tests/hooks/test-session-start.sh
```

These are adapter/protocol tests, not Trae session tests. Windows `cmd.exe` /
PowerShell dispatch, hook trust gates, installer retention, model-facing tool
names, fresh-session injection, and post-compaction behavior remain unverified.
The documented Trae `SessionStart` source is only `startup`; do not claim
Claude's `clear|compact` lifecycle events work in Trae.

## Required real acceptance evidence

After native installation in a throwaway workspace:

1. Record the IDE version, OS, model ID, enabled plugins, installed file tree,
   and exact model-facing tool names/schemas.
2. Use a temporary unique marker to prove bootstrap reaches the model at
   startup; remove the marker before the final acceptance run.
3. In a fresh session, send exactly `Let's make a react todo list`.
4. Capture the complete transcript showing `brainstorming` loads before any
   code is written, without asking the user to enable skills in that session.
5. Repeat in a second fresh session; inspect hook logs for duplicate injection.
6. Test updates through the same native installation mechanism, preserving
   user-owned rules, skills, hooks, and memory.

Target a new PR at `dev` only after these gates pass and a human reviews the
complete diff. Do not carry forward #947's checked evaluation or review claims.

## References

- https://docs.trae.cn/ide_automate-actions-with-hooks
- https://docs.trae.cn/ide_hook-configuration-reference/
- https://docs.trae.cn/ide_skills
- https://github.com/obra/superpowers/pull/947#issuecomment-5850596325
- https://github.com/obra/superpowers/pull/672
- https://github.com/obra/superpowers/pull/811

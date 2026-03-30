# Trae Installer Pre-Merge Tests

This directory contains pre-merge test support for the Trae installer files added by the `Add Trae IDE native support files` PR.

## Branch Roles

- `trae-pr947-test-env`: exact parity branch for the submitted PR. Do not edit product files here.
- `trae-pr947-test-support`: test-support branch. It adds scripts, prompts, checklists, and any fixes discovered during pre-merge evaluation.

## One Required Pre-Merge Rewrite

For pre-merge evaluation, only rewrite the rule download URL at runtime:

- Replace:
  - `https://raw.githubusercontent.com/obra/superpowers/main/.trae/rules/superpowers.md`
- With:
  - `https://raw.githubusercontent.com/gotocx/superpowers/refs/heads/trae-pr947-test-support/.trae/rules/superpowers.md`

Do not rewrite:

- `https://github.com/obra/superpowers-skills.git`

That repository is a real upstream dependency of the installer. The pre-merge problem only affects the rule file, because the rule file does not exist on `obra/superpowers:main` until the PR merges.

## How To Simulate Real Usage

Test this as a prompt-first harness flow, not a shell-first flow.

What real users do:

1. Open a target project in Trae.
2. Paste a natural-language request into the chat.
3. Let the model decide which shell commands to run.
4. Verify the resulting `.trae` layout and the model's narrative about what it preserved, replaced, or blocked.

That is the behavior to simulate in Trae, Codex-backed Trae, GPT-backed Trae, or other supported models. The prompt files in `prompts/` are written for that style of evaluation.

## Automation

The PowerShell coverage script validates the filesystem behavior of the installer logic and applies the pre-merge rule rewrite at runtime:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/trae-installer/run-installer-coverage.ps1 -RuleRef trae-pr947-test-support
```

To reduce network flakiness, the script clones `superpowers-skills` once into a local fixture and reuses that fixture across scenarios. Manual harness runs should still use the real networked flow.

What the script covers:

- clean init
- existing project files preserved
- custom rule preserved
- custom non-conflicting skill preserved
- conflicting same-name skill replaced
- unexpected file blocked
- unexpected non-empty directory blocked
- unexpected empty directory tolerated
- rerun stability / no temp residue

What still needs a real harness transcript:

- whether the agent actually used `manage_core_memory`
- whether the agent reported refresh-vs-create behavior clearly
- whether the agent's final summary matches what happened on disk

## Test Matrix

| Scenario | Setup before prompt | Prompt file | Expected result | Transcript check | Automated |
| --- | --- | --- | --- | --- | --- |
| clean-init | Empty project root, no `.trae` | `prompts/01-clean-init.txt` | Creates `.trae/rules/superpowers.md` and `.trae/skills/using-superpowers` | Confirms install succeeded and warns about context usage | Yes |
| existing-project | User files already exist in project root | `prompts/02-existing-project.txt` | Preserves project files and adds `.trae` | Says existing project files were preserved | Yes |
| custom-rule-preserved | `.trae/rules/custom.md` exists | `prompts/03-custom-rule-preserved.txt` | Keeps `custom.md`, adds or refreshes `superpowers.md` | Says non-Superpowers rule files were preserved | Yes |
| custom-skill-preserved | `.trae/skills/my-skill/SKILL.md` exists | `prompts/04-custom-skill-preserved.txt` | Keeps custom skill | Says non-conflicting custom skills were preserved | Yes |
| conflicting-skill-replaced | `.trae/skills/brainstorming/SKILL.md` exists with custom content | `prompts/05-conflicting-skill-replaced.txt` | Replaces that skill with official version | Says same-name official skills were replaced | Yes |
| unexpected-file-blocked | `.trae/notes.txt` exists | `prompts/06-unexpected-file-blocked.txt` | Stops before cleanup | Lists blocker path and asks for manual review | Yes |
| unexpected-dir-blocked | `.trae/manual-review/keep.txt` exists | `prompts/07-unexpected-nonempty-dir-blocked.txt` | Stops before cleanup | Lists blocker path and asks for manual review | Yes |
| rerun-idempotent | Successful install already present | `prompts/08-rerun-idempotent.txt` | Rebuild stays stable, no nested leftovers | Says rerun refreshed the install without leaving temp clone | Yes |
| memory-refresh-or-create | Successful filesystem install path | `prompts/09-memory-refresh-or-create.txt` | Filesystem may already be correct | Explicitly states whether memory was refreshed or created | No |

## Suggested Manual Evidence

Capture these artifacts for each manual harness run:

1. Initial project tree
2. Prompt file used
3. Full model transcript or chat export
4. Final `.trae` tree
5. Final statement from the model about preserve/replace/block behavior

## Notes For Codex-Style Evaluation

When testing with a Codex-backed agent or similar tool-using model:

- keep the prompt natural-language and goal-oriented
- do not pre-chew the exact shell commands unless you are specifically testing command fidelity
- keep the project root as the current workspace root
- let the model decide when to inspect `.trae`, clone `superpowers-skills`, and clean up `.superpowers_temp`
- verify that the model obeys the safety boundaries before it claims success

The point is to simulate how users actually rely on these installers: they paste one prompt and expect the agent to do the rest.

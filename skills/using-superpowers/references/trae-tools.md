# TraeCode IDE tool mapping (candidate)

This mapping targets the TraeCode IDE contract documented at
https://docs.trae.cn/ide_hook-configuration-reference/ . It does not assert
compatibility with TraeWork, TraeCode CLI, or every international IDE version.
The documented tool names are normalized names; confirm the actual model-facing
names and parameter schemas in the target IDE before release.

| Skill action | TraeCode equivalent |
|---|---|
| Invoke a skill | Use the exposed native `Skill` tool with its actual schema. Do not assume Claude Code's parameter syntax. If no native skill tool is available, read the relevant installed `SKILL.md` with the file-read tool. |
| Read a file | `Read` |
| Create or edit a file | `Write` / `Edit`; use `RunCommand` for deletion when needed |
| Run shell commands | `RunCommand` |
| Search contents / find paths | `Grep` / `Glob` (or `LS` for directory listings) |
| Fetch a URL / search the web | `WebFetch` / `WebSearch` when exposed |
| Ask the human partner a question | `AskUserQuestion` when exposed; otherwise ask in chat |
| Create or update todos | Use the exposed native plan/todo facility; otherwise track a checklist in a plan file. Do not invent a `TodoWrite` tool. |
| Dispatch a subagent | Use the session's exposed dispatch tool and valid agent type, if available. Otherwise follow the skill's inline fallback or report the missing capability. Do not invent a `Task` call or silently claim an independent review. |

The bootstrap already contains `using-superpowers`. Invoke other skills via the
native skill system after they have been installed through Trae's own mechanism.
For the file-read fallback, use the installed skill paths actually available in
the session. Do not flatten reference documents into new skills, rewrite skill
bodies, or require project memory as a substitute for the bootstrap.

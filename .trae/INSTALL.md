# Installing Superpowers for Trae

Enable Superpowers in Trae without leaving a full cloned Superpowers repository inside your target project. This installer creates a runtime `.trae` directory, installs rules, flattens skills, and refreshes project memory.

## Prerequisites

- [Trae IDE](https://www.trae.ai) installed
- Git available in the local environment

## Installation

Open your target project in Trae and run the setup from that target project's root directory.

Just copy and paste the following prompt into your Trae chat:

> **For the AI Assistant:** Please initialize Superpowers for this project from the project root.
>
> Requirements:
> 1. Treat the current workspace root as the target project root.
> 2. Do not clone the full Superpowers repository into this target project.
> 3. Install `.trae/rules/superpowers.md` from the Trae installer source.
> 4. Fetch `https://github.com/obra/superpowers-skills.git` into a temporary directory, flatten it into `.trae/skills/`, and rename `using-skills` to `using-superpowers`.
> 5. Refresh the existing Superpowers project memory first; if update is not possible, create it as a new project memory entry instead.
> 6. When setup finishes, the target project should only keep `.trae/rules/`, `.trae/skills/`, and the project memory. Remove temporary/bootstrap leftovers.
> 7. If cleanup fails, finish the setup and explicitly tell me what to delete manually.
> 8. After setup, remind me that dynamic skill loading and memory usage may consume context faster than usual.
>
> **Step 1: Build the Trae runtime layout from the project root**
>
> ```powershell
> if (-not (Test-Path ".trae\rules")) { New-Item -ItemType Directory -Force -Path ".trae\rules" | Out-Null }
>
> Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gotocx/superpowers/refs/heads/trae-e2e-full-repo/.trae/rules/superpowers.md" -OutFile ".trae\rules\superpowers.md"
>
> if (Test-Path ".trae\skills") { Remove-Item -Recurse -Force ".trae\skills" }
> if (Test-Path ".superpowers_temp") { Remove-Item -Recurse -Force ".superpowers_temp" -ErrorAction SilentlyContinue }
> git clone https://github.com/obra/superpowers-skills.git .superpowers_temp 2>$null
> New-Item -ItemType Directory -Force -Path ".trae\skills" | Out-Null
>
> Get-ChildItem -Path ".superpowers_temp\skills" -Directory | Where-Object { $_.Name -notin @('tool', 'examples') } | ForEach-Object {
>     $categoryDir = $_.FullName
>     Get-ChildItem -Path $categoryDir -Directory | ForEach-Object {
>         Copy-Item -Path $_.FullName -Destination ".trae\skills\" -Recurse -Force
>     }
> }
>
> if (Test-Path ".trae\skills\using-skills") { Rename-Item -Path ".trae\skills\using-skills" -NewName "using-superpowers" }
> if (Test-Path ".superpowers_temp") { Remove-Item -Recurse -Force ".superpowers_temp" -ErrorAction SilentlyContinue }
> Get-ChildItem -Path ".trae" -Force | Where-Object { $_.Name -notin @('rules', 'skills') } | ForEach-Object {
>     Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
> }
> ```
>
> ```bash
> mkdir -p .trae/rules
> curl -s -o .trae/rules/superpowers.md https://raw.githubusercontent.com/gotocx/superpowers/refs/heads/trae-e2e-full-repo/.trae/rules/superpowers.md
> rm -rf .trae/skills
> rm -rf .superpowers_temp
> git clone https://github.com/obra/superpowers-skills.git .superpowers_temp >/dev/null 2>&1
> mkdir -p .trae/skills
> find .superpowers_temp/skills -mindepth 2 -maxdepth 2 -type d | while read dir; do
>   cp -R "$dir" .trae/skills/
> done
> rm -rf .trae/skills/tool .trae/skills/examples
> if [ -d ".trae/skills/using-skills" ]; then mv .trae/skills/using-skills .trae/skills/using-superpowers; fi
> rm -rf .superpowers_temp
> find .trae -mindepth 1 -maxdepth 1 ! -name rules ! -name skills -exec rm -rf {} +
> ```
>
> **Step 2: Refresh or create the project core memory**
>
> Please use `manage_core_memory` with this behavior:
> - First try to update an existing project-level Superpowers workflow memory if one already exists.
> - If no matching memory exists, or the update cannot be completed, add a new project-level memory instead.
>
> Use the following memory content:
> - Title: Superpowers 严格工作流约束
> - Keywords: superpowers|workflow|tdd|debugging|skills
> - Category: Knowledge
> - Via: request
> - Content: 本项目严格遵循 obra/superpowers 开发方法论：知识沉淀与测试驱动开发优先；系统化过程胜于临时猜测；简化复杂性，以简洁为主要目标；证据胜于主张，在宣布成功前先核实。遇到功能开发先做设计与测试；遇到报错必须调用 systematic-debugging 做根因排查；技能调用必须通过内置 Skill 工具真实执行；多步骤流程使用 TodoWrite；跨任务知识通过 manage_core_memory 沉淀。

## Verify

Ask Trae to confirm all of the following:

1. `.trae/rules/superpowers.md` exists at the target project root.
2. `.trae/skills/using-superpowers` exists.
3. `.trae` contains only `rules/` and `skills/` after setup.
4. No full `superpowers` repository clone remains inside the target project.
5. The Superpowers project memory was refreshed, or created if refresh was not possible.

## Why this Trae adaptation works

This migration keeps the core Superpowers philosophy while adapting it to Trae's native runtime model.

- **No Hooks Required**: Behavior is constrained through Trae Memory and Workspace Rules rather than external hooks.
- **Flattened Skills Directory**: Trae currently resolves skills more reliably from a flat `.trae/skills/` structure.
- **Flowcharts -> Trae Todo List**: Guided workflows map naturally onto Trae's Todo List instead of terminal-only checklists.
- **Local Knowledge -> Trae Core Memory**: This replaces `remembering-conversations` with `manage_core_memory`, and benefits from Trae's memory update mechanism to keep context more active and better coordinated over time.

## Migrating from older Trae setup

If you previously tested an earlier Trae bootstrap:

- Remove stale `.trae/temp_*` directories
- Remove nested or duplicated `.trae/skills` layouts
- Re-run the installation prompt above from the project root

## Updating

Ask the Trae assistant to run the same installation prompt again from the target project root. It should rebuild `.trae/skills/`, keep `.trae/rules/superpowers.md` active, and refresh the existing project memory before falling back to creating one.

## Troubleshooting

- If `.trae` still contains directories other than `rules/` and `skills/`, ask Trae to delete the leftovers and verify again.
- If a full `superpowers` clone was accidentally created inside the target project, delete it and rerun the installer.
- If memory refresh fails because no matching entry exists, instruct Trae to create the new memory entry immediately.
- If cleanup fails because a file is locked, ask Trae to finish setup and tell you the exact path to remove manually.

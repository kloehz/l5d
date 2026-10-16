# Agent and development environment inventory

This is a bounded fresh metadata/configuration scan, not proof that skills are loaded, used, or that configured tools are callable. Paths use `~` and repository-relative notation; no absolute home/operator endpoint is included.

## Physical skill inventory

**55 physical skill files; 55 unique frontmatter names.** Counts by root: project 5, personal 32, pi-agent 0, package: gentle-pi 13, package: pi-lens 4, package: pi-intercom 1. No `~/.pi/agent/skills` root was present in this scan.

Every following entry is from fresh frontmatter; descriptions are preserved from each file. Full text remains the `SKILL.md` source of truth.

### project (5)

| Name | Description / trigger | Exact path |
|---|---|---|
| godot-network-verification | Trigger: Godot multiplayer runtime verification, graphical clients, delay testing. Prove real rendered behavior and preserve failure evidence. | `.pi/skills/godot-network-verification/SKILL.md` |
| godot-remote-interpolation | Trigger: Godot remote interpolation, snapshot buffer, render cursor. Choose per-entity prediction or buffered presentation without hiding missing history. | `.pi/skills/godot-remote-interpolation/SKILL.md` |
| godot-shot-view-timeline | Trigger: Godot lag compensation, shot view time, rewind timeline. Align firing with displayed state and preserve authoritative bounded adjudication. | `.pi/skills/godot-shot-view-timeline/SKILL.md` |
| netfox-input-state-safety | Trigger: Netfox input readiness, state publication, scheduler cadence. Gate outbound state on live peer, fresh provenance, and owned tick data. | `.pi/skills/netfox-input-state-safety/SKILL.md` |
| netfox-state-provenance | Trigger: Netfox state provenance, decoder writes, empty diffs, shared history. Distinguish real receive updates from recorder activity and stale samples. | `.pi/skills/netfox-state-provenance/SKILL.md` |
### personal (32)

| Name | Description / trigger | Exact path |
|---|---|---|
| branch-pr | Create Gentle AI pull requests with issue-first checks. Trigger: creating, opening, or preparing PRs for review. | `~/.agents/skills/branch-pr/SKILL.md` |
| chained-pr | Trigger: PRs over 400 lines, stacked PRs, review slices. Split oversized changes into chained PRs that protect review focus. | `~/.agents/skills/chained-pr/SKILL.md` |
| cognitive-doc-design | Design docs that reduce cognitive load. Trigger: writing guides, READMEs, RFCs, onboarding, architecture, or review-facing docs. | `~/.agents/skills/cognitive-doc-design/SKILL.md` |
| comment-writer | Write warm, direct collaboration comments. Trigger: PR feedback, issue replies, reviews, Slack messages, or GitHub comments. | `~/.agents/skills/comment-writer/SKILL.md` |
| find-skills | Helps users discover and install agent skills when they ask questions like "how do I do X", "find a skill for X", "is there a skill that can...", or express interest in extending capabilities. This skill should be used when the user is looking for functionality that might exist as an installable skill. | `~/.agents/skills/find-skills/SKILL.md` |
| gentle-ai-bench | Trigger: bench, journey, journeys, driven mode, gentle-ai-bench, journey corpus, j-numbers, bench axis. Author and verify gentle-ai bench journeys; go test ./bench never proves driven execution. | `~/.agents/skills/gentle-ai-bench/SKILL.md` |
| go-testing | Trigger: Go tests, go test coverage, Bubbletea teatest, golden files. Apply focused Go testing patterns. | `~/.agents/skills/go-testing/SKILL.md` |
| godot-gdscript-patterns | Master Godot 4 GDScript patterns including signals, scenes, state machines, and optimization. Use when building Godot games, implementing game systems, or learning GDScript best practices. | `~/.agents/skills/godot-gdscript-patterns/SKILL.md` |
| godot-ui | Expert knowledge of Godot's UI system including Control nodes, themes, styling, responsive layouts, and common UI patterns for menus, HUDs, inventories, and dialogue systems. Use when working with Godot UI/menu creation or styling. | `~/.agents/skills/godot-ui/SKILL.md` |
| issue-creation | Trigger: issue creation, bug reports, feature requests, or issue approval. Create and triage GitHub issues from repository evidence. | `~/.agents/skills/issue-creation/SKILL.md` |
| judgment-day | Trigger: judgment day, dual review, adversarial review, juzgar. Run explicit blind dual review with at most two scoped fix/re-judgment rounds. | `~/.agents/skills/judgment-day/SKILL.md` |
| netfox-godot-multiplayer | Trigger: Godot Netfox multiplayer, room server, prediction, rollback. Build authoritative 2–16 player room networking. | `~/.agents/skills/netfox-godot-multiplayer/SKILL.md` |
| nextjs-app-router-patterns | Master Next.js 14+ App Router with Server Components, streaming, parallel routes, and advanced data fetching. Use when building Next.js applications, implementing SSR/SSG, or optimizing React Server Components. | `~/.agents/skills/nextjs-app-router-patterns/SKILL.md` |
| rdd-defect-workflow | Trigger: RDD, receipt-driven development, review authority, receipt/lineage, correction/recovery, delivery gate/kill switch, bounded review defects. Guide work. | `~/.agents/skills/rdd-defect-workflow/SKILL.md` |
| reverse-engineer-anything | Reverse engineer native, managed, Electron/JavaScript, packaged, firmware, and browser targets with REA. Use shipped-artifact or requested runtime evidence to explain features, compare versions, decompile code, or guide a reconstruction. Skip REA for ordinary source-repository architecture analysis. | `~/.agents/skills/reverse-engineer-anything/SKILL.md` |
| sdd-apply | Implement SDD tasks from specs and design. Trigger: orchestrator launches apply for one or more change tasks. | `~/.agents/skills/sdd-apply/SKILL.md` |
| sdd-archive | Archive a completed SDD change by syncing delta specs. Trigger: orchestrator launches archive after implementation and verification. | `~/.agents/skills/sdd-archive/SKILL.md` |
| sdd-design | Create the SDD technical design and architecture approach. Trigger: orchestrator launches design for a change. | `~/.agents/skills/sdd-design/SKILL.md` |
| sdd-explore | Explore SDD ideas before committing to a change. Trigger: orchestrator launches exploration or requirement clarification. | `~/.agents/skills/sdd-explore/SKILL.md` |
| sdd-init | Trigger: sdd init, iniciar sdd, openspec init. Initialize SDD context, testing capabilities, registry, and persistence. | `~/.agents/skills/sdd-init/SKILL.md` |
| sdd-onboard | Walk users through the SDD workflow on the real codebase. Trigger: orchestrator launches onboarding for the full SDD cycle. | `~/.agents/skills/sdd-onboard/SKILL.md` |
| sdd-propose | Create an SDD change proposal with intent, scope, and approach. Trigger: orchestrator launches proposal work for a change. | `~/.agents/skills/sdd-propose/SKILL.md` |
| sdd-research | Trigger: SDD research, external evidence, source-backed research. Produce auditable evidence for a selected research lane. | `~/.agents/skills/sdd-research/SKILL.md` |
| sdd-spec | Write SDD delta specs with requirements and scenarios. Trigger: orchestrator launches spec work for a change. | `~/.agents/skills/sdd-spec/SKILL.md` |
| sdd-tasks | Break an SDD change into implementation tasks. Trigger: orchestrator launches task planning for a change. | `~/.agents/skills/sdd-tasks/SKILL.md` |
| sdd-verify | Trigger: SDD verification phase, verify change. Execute tests and prove implementation matches specs, design, and tasks. | `~/.agents/skills/sdd-verify/SKILL.md` |
| skill-creator | Trigger: new skills, agent instructions, documenting AI usage patterns. Create LLM-first skills with valid frontmatter. | `~/.agents/skills/skill-creator/SKILL.md` |
| skill-improver | Trigger: improve skills, audit skills, refactor skills, skill quality. Audit and upgrade existing LLM-first skills. | `~/.agents/skills/skill-improver/SKILL.md` |
| skill-registry | Trigger: update skills, skill registry, actualizar skills, after skill changes. Index available skills by trigger and path. | `~/.agents/skills/skill-registry/SKILL.md` |
| systemic-issue-triage | Trigger: new issue, bug report, triage, backlog, issue flood, community report, root cause, dead-end, blocked user. Attack issues by root class, never one-by-one; fixes must shrink the system, not grow it. | `~/.agents/skills/systemic-issue-triage/SKILL.md` |
| unity-ui-prefab-first | Trigger: Unity UI, panel, HUD, menu, canvas, UI scene, editar UI a mano. Author Unity UI as hand-editable prefabs in a sandbox scene; code only binds data and events. | `~/.agents/skills/unity-ui-prefab-first/SKILL.md` |
| work-unit-commits | Plan commits as reviewable work units. Trigger: implementation, commit splitting, chained PRs, or keeping tests and docs with code. | `~/.agents/skills/work-unit-commits/SKILL.md` |
### package: gentle-pi (13)

| Name | Description / trigger | Exact path |
|---|---|---|
| gentle-ai-branch-pr | Create Gentle AI pull requests with issue-first checks. Trigger: creating, opening, or preparing PRs for review. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/branch-pr/SKILL.md` |
| gentle-ai-chained-pr | Trigger: PRs over 400 lines, stacked PRs, review slices. Split oversized changes into chained PRs that protect review focus. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/chained-pr/SKILL.md` |
| gentle-ai-cognitive-doc-design | Design docs that reduce cognitive load. Trigger: writing guides, READMEs, RFCs, onboarding, architecture, or review-facing docs. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/cognitive-doc-design/SKILL.md` |
| gentle-ai-comment-writer | Write warm, direct collaboration comments. Trigger: PR feedback, issue replies, reviews, Slack messages, or GitHub comments. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/comment-writer/SKILL.md` |
| gentle-ai | Use Gentle AI harness discipline for Pi work: clarify first, preserve OpenSpec artifacts, use strict TDD where available, delegate through subagents when useful, and protect review workload. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/gentle-ai/SKILL.md` |
| gentle-ai-issue-creation | Create and triage GitHub issues from repository evidence. Trigger: issue creation, bug reports, feature requests, or issue approval. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/issue-creation/SKILL.md` |
| gentle-ai-judgment-day | Trigger: judgment day, judgement day, dual review, adversarial review, juzgar. Run explicit blind dual review with at most two scoped fix/re-judgment rounds. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/judgment-day/SKILL.md` |
| gentle-ai-rdd-defect-workflow | Trigger: RDD, receipt-driven development, review authority, receipt/lineage, correction/recovery, delivery gate/kill switch, bounded review defects. Guide work. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/rdd-defect-workflow/SKILL.md` |
| release | Release gentle-pi through GitHub and npm. Trigger: release, publish, npm publish, GitHub release, version bump. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/release/SKILL.md` |
| gentle-ai-skill-creator | Trigger: /skill-creation, skill creation, skill creator, create skill, new skill. Create LLM-first skills with valid frontmatter. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/skill-creator/SKILL.md` |
| gentle-ai-skill-improver | Trigger: improve skills, audit skills, refactor skills, skill quality. Audit and upgrade existing LLM-first skills. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/skill-improver/SKILL.md` |
| gentle-ai-skill-registry | Trigger: update skills, skill registry, actualizar skills, after skill changes. Index available skills by trigger and path. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/skill-registry/SKILL.md` |
| gentle-ai-work-unit-commits | Plan commits as reviewable work units. Trigger: implementation, commit splitting, chained PRs, or keeping tests and docs with code. | `~/.pi/agent/npm/node_modules/gentle-pi/skills/work-unit-commits/SKILL.md` |
### package: pi-lens (4)

| Name | Description / trigger | Exact path |
|---|---|---|
| pi-lens-ast-grep | Use when searching or replacing code patterns - use ast-grep instead of text search for semantic accuracy | `~/.pi/agent/npm/node_modules/pi-lens/skills/pi-lens-ast-grep/SKILL.md` |
| pi-lens-lsp-navigation | Navigate code with IDE features and run proactive LSP diagnostics on files/folders/batches. Use as PRIMARY for code intelligence and type/error checks. | `~/.pi/agent/npm/node_modules/pi-lens/skills/pi-lens-lsp-navigation/SKILL.md` |
| pi-lens-write-ast-grep-rule | Use when writing a new pi-lens ast-grep rule YAML file — covers schema, drop path, gotchas, and NAPI runner constraints | `~/.pi/agent/npm/node_modules/pi-lens/skills/pi-lens-write-ast-grep-rule/SKILL.md` |
| pi-lens-write-tree-sitter-rule | Use when writing a new pi-lens tree-sitter query rule YAML file — covers schema, S-expression syntax, capture names, predicates, and gotchas | `~/.pi/agent/npm/node_modules/pi-lens/skills/pi-lens-write-tree-sitter-rule/SKILL.md` |
### package: pi-intercom (1)

| Name | Description / trigger | Exact path |
|---|---|---|
| pi-intercom | Streamline session-to-session coordination with pi-intercom. Send messages, delegate tasks, and coordinate across Pi sessions. | `~/.pi/agent/npm/node_modules/pi-intercom/skills/pi-intercom/SKILL.md` |

## Semantic overlaps (not exact-name duplicates)

These 11 personal/package pairs overlap in purpose; names are distinct and this inventory does not claim equal contents:

- `branch-pr` (`~/.agents/skills/branch-pr/SKILL.md`) ↔ `gentle-ai-branch-pr` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/branch-pr/SKILL.md`)
- `chained-pr` (`~/.agents/skills/chained-pr/SKILL.md`) ↔ `gentle-ai-chained-pr` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/chained-pr/SKILL.md`)
- `cognitive-doc-design` (`~/.agents/skills/cognitive-doc-design/SKILL.md`) ↔ `gentle-ai-cognitive-doc-design` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/cognitive-doc-design/SKILL.md`)
- `comment-writer` (`~/.agents/skills/comment-writer/SKILL.md`) ↔ `gentle-ai-comment-writer` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/comment-writer/SKILL.md`)
- `issue-creation` (`~/.agents/skills/issue-creation/SKILL.md`) ↔ `gentle-ai-issue-creation` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/issue-creation/SKILL.md`)
- `judgment-day` (`~/.agents/skills/judgment-day/SKILL.md`) ↔ `gentle-ai-judgment-day` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/judgment-day/SKILL.md`)
- `rdd-defect-workflow` (`~/.agents/skills/rdd-defect-workflow/SKILL.md`) ↔ `gentle-ai-rdd-defect-workflow` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/rdd-defect-workflow/SKILL.md`)
- `skill-creator` (`~/.agents/skills/skill-creator/SKILL.md`) ↔ `gentle-ai-skill-creator` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/skill-creator/SKILL.md`)
- `skill-improver` (`~/.agents/skills/skill-improver/SKILL.md`) ↔ `gentle-ai-skill-improver` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/skill-improver/SKILL.md`)
- `skill-registry` (`~/.agents/skills/skill-registry/SKILL.md`) ↔ `gentle-ai-skill-registry` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/skill-registry/SKILL.md`)
- `work-unit-commits` (`~/.agents/skills/work-unit-commits/SKILL.md`) ↔ `gentle-ai-work-unit-commits` (`~/.pi/agent/npm/node_modules/gentle-pi/skills/work-unit-commits/SKILL.md`)

Installed/discoverable does not mean loaded or used. New project skills may require session reload for automatic discovery. Unity, Next.js, Go, bench, and SDD groups may merit future human review against this game, but usage is unproven and other projects may depend on them. No skill was removed or disabled.

## Other development influences

| Area | Observed metadata and limits |
|---|---|
| Global defaults | Safe whitelist from `~/.pi/agent/settings.json`: default provider `openai-codex`, default model `gpt-5.5`; not evidence of active parent model/provider. Global `~/.pi/agent/subagents.json` was absent. |
| Project personal profiles | `<REPO>/.pi/subagents.json` exists and sets only `gentle-ai-worker` and `gentle-ai-verify` to `openai-codex/gpt-6-luna`; personal/untracked, not published. These two profiles do not configure all roles. |
| Workflow switches | Session observation: ODD default, SDD explicit, TDD off, RDD off, background delegation off. These are session settings, not forced repository config. |
| Configured packages | Six recorded: `gentle-pi`, `pi-intercom`, `gentle-engram`, `pi-web-access`, `pi-lens`, `@juicesharp/rpiv-ask-user-question`. Configured does not prove active/callable. Godot and REA tools were available; active MCP connections were not verified. |
| Language tooling | Pi Lens is installed; no GDScript language server was available in the observed setup. |
| Memory identity | Engram project `game-99-coop` differs from Git remote slug `l5d`; requires explicit project-scope review, not automatic deletion/merge. |
| Engine/dependency | Root and nested `project.godot` declare 4.8 features while lock and verified runner are Godot 4.7. Netfox 1.35.3, 30 Hz, history 16, GodotPhysics3D are observed. Drift requires review; no engine config edits. |
| Repository controls | `.editorconfig`, `.gitattributes`, root `.gitignore`, `zombie_corridor_mvp/.gitignore`, `zombie_corridor_mvp/dependencies.lock.json`, and `zombie_corridor_mvp/scripts/{export_builds.sh,package_builds.py}`. Runnable game is `zombie_corridor_mvp/`; root is placeholder. |
| Instruction sources | Repo `AGENTS.md` is present and newly added. `.pi/settings.json` absent. Global `~/.pi/agent/AGENTS.md`, `SYSTEM.md`, and `APPEND_SYSTEM.md` absent by existence check. This does not establish all inherited ancestor instruction locations absent. |
| Prompts/extensions | No direct files in checked `~/.pi/agent/prompts`, `~/.pi/agent/extensions`, `.pi/prompts`, or `.pi/extensions`; Gentle Pi package has `prompts/skill-creation.md`. This bounded check is not exhaustive of installed package internals. |
| Discovery | Skill files are installed/discoverable separately from loaded bodies. Resource overlap may affect context; no claim is made that all skills are injected. No session reload or model/config change was performed. |

## Global agent-role definitions

Observed 23 user-global role definition files under `~/.pi/agent/agents` (roles are not skills). Exact filenames and paths:

- `gentle-ai-explore` — `~/.pi/agent/agents/gentle-ai-explore.md`
- `gentle-ai-verify` — `~/.pi/agent/agents/gentle-ai-verify.md`
- `gentle-ai-worker` — `~/.pi/agent/agents/gentle-ai-worker.md`
- `jd-fix-agent` — `~/.pi/agent/agents/jd-fix-agent.md`
- `jd-judge-a` — `~/.pi/agent/agents/jd-judge-a.md`
- `jd-judge-b` — `~/.pi/agent/agents/jd-judge-b.md`
- `review-readability` — `~/.pi/agent/agents/review-readability.md`
- `review-reliability` — `~/.pi/agent/agents/review-reliability.md`
- `review-resilience` — `~/.pi/agent/agents/review-resilience.md`
- `review-risk` — `~/.pi/agent/agents/review-risk.md`
- `sdd-apply` — `~/.pi/agent/agents/sdd-apply.md`
- `sdd-archive` — `~/.pi/agent/agents/sdd-archive.md`
- `sdd-design` — `~/.pi/agent/agents/sdd-design.md`
- `sdd-explore` — `~/.pi/agent/agents/sdd-explore.md`
- `sdd-init` — `~/.pi/agent/agents/sdd-init.md`
- `sdd-onboard` — `~/.pi/agent/agents/sdd-onboard.md`
- `sdd-proposal` — `~/.pi/agent/agents/sdd-proposal.md`
- `sdd-research` — `~/.pi/agent/agents/sdd-research.md`
- `sdd-spec` — `~/.pi/agent/agents/sdd-spec.md`
- `sdd-status` — `~/.pi/agent/agents/sdd-status.md`
- `sdd-sync` — `~/.pi/agent/agents/sdd-sync.md`
- `sdd-tasks` — `~/.pi/agent/agents/sdd-tasks.md`
- `sdd-verify` — `~/.pi/agent/agents/sdd-verify.md`

The package also ships agent assets; user-global definitions and package sources are distinct. Do not infer runtime precedence from this listing. No role definitions were edited.

## Human-control boundary

This inventory supports future review only. It does not establish proven-unused skills or authorize deletion, disablement, global changes, publication, engine changes, or VPS/server actions. No credential/auth files, environment secrets, private keys, or private endpoint values were inspected or copied.

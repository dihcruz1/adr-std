# adr-std

[![Release](https://img.shields.io/github/v/release/dihcruz1/adr-std?style=flat&color=blue)](https://github.com/dihcruz1/adr-std/releases)
[![CI](https://github.com/dihcruz1/adr-std/actions/workflows/release.yml/badge.svg)](https://github.com/dihcruz1/adr-std/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Standard: ISO/IEC/IEEE 42010:2022](https://img.shields.io/badge/Standard-ISO%2FIEC%2FIEEE%2042010%3A2022-informational)](https://www.iso.org/standard/74427.html)

🌐 *Disponível em Português: [README.pt-BR.md](README.pt-BR.md)*

An AI coding agent skill that **creates, reviews, and organizes ADRs** (architecture decision records) conforming to
**ISO/IEC/IEEE 42010:2022**, clause 6.10. It works with any agent that supports the open `SKILL.md` format
(Claude Code, Codex, Gemini CLI, OpenCode, and others) and provides a terminal CLI command, `adr-std`, to install,
update, and manage the skill.

> **Independent Project:** This skill is not endorsed by ISO, IEC, or IEEE, and **does not contain the normative text of the standard**:
> the guide is an original summary that references the standard's clauses. Users who wish to read the full standard must obtain it
> independently.

## Table of Contents

1. [What the skill does](#1-what-the-skill-does)
2. [What it guarantees (and what it does not)](#2-what-it-guarantees-and-what-it-does-not)
3. [How to prompt your agent](#3-how-to-prompt-your-agent)
4. [ADR Template](#4-adr-template)
5. [Automated Verification](#5-automated-verification)
6. [Installation](#6-installation)
7. [Supported Agents](#7-supported-agents)
8. [CLI Commands](#8-cli-commands)
9. [Verifying Installation](#9-verifying-installation)
10. [Updating and Uninstalling](#10-updating-and-uninstalling)
11. [Troubleshooting](#11-troubleshooting)
12. [About the Standard](#12-about-the-standard)
13. [Limitations and Roadmap](#13-limitations-and-roadmap)
14. [Skill Files](#14-skill-files)
15. [License and Contributing](#15-license-and-contributing)

---

## 1. What the skill does

Once installed, your agent knows how to assist with four core tasks in natural language:

| Task | Prompt Example |
|---|---|
| **Create** an ADR | "Create an ADR for the decision to use PostgreSQL instead of MongoDB." |
| **Review or organize** ADRs | "Review the ADRs in `docs/architecture/ADR` and standardize the numbering." |
| **Audit** architecture description | "Is our project compliant with ISO 42010?" |
| **Ask questions** about the standard | "What does ISO 42010 require when recording decisions?" |

When **creating** an ADR, the agent initiates an interactive discussion: it understands the decision, verifies whether it is unique and essential, inquires about missing details (decision-makers, date, alternatives, rejection rationale), suggests missing considerations, prepares the draft, and runs verification. The initial status is always `Proposed`; only designated decision-makers can approve it.

## 2. What it guarantees (and what it does not)

The agent strictly adheres to rules documented in `skill/references/guia-42010.md`:

- **One decision per ADR.** Distinct decisions are split into linked ADRs.
- **Rejected alternatives recorded with explicit rationale.**
- **Decision-makers, approval authority, and three distinct dates** (decision, approval, modification).
- **Typed relationships between ADRs** (restricts, refines, conflicts-with, replaces, etc.).
- **No hallucinations:** Never fabricates decision-makers, dates, alternatives, or rationale; marks them as `pending` or prompts the user.
- **Never deletes** accepted or rejected ADRs; supersedes them with new records while linking both.
- **Never marks `Accepted` autonomously** and **never commits** or renames files without explicit user consent.
- **Traces origins:** Explains whether a rule originates from the ISO standard (citing the clause), project conventions, or the skill itself.

**What the skill does not guarantee:** Full compliance of your entire system with ISO 42010. ADRs address clause 6.10 (decisions and rationale) and parts of 6.1 (identification). Full system architecture conformance requires satisfying all of clause 6 (stakeholders, concerns, viewpoints, views, correspondences). The agent may certify that an ADR "satisfies clause 6.10 requirements", but never that the entire project "is ISO 42010 certified".

## 3. How to prompt your agent

Prompt naturally; the skill activates based on conversational context. Examples:

```text
Create an ADR to replace Redis with Memcached for session caching due to cost constraints.
Review the ADRs in docs/architecture/ADR against the standard and list missing requirements.
This ADR supersedes ADR-3: create the new one and mark the previous one as superseded.
Record that ADR-4 refines ADR-2.
Audit the project's architecture description against Clause 6 of ISO 42010.
What does the standard say about architectural rationale?
```

To invoke the skill directly if your tool permits: `/adr-std` in Claude Code or `$adr-std` in Codex.
Specific action commands can also be used directly (such as `/adr-std-create`, `/adr-std-supersede`, `/adr-std-review`, `/adr-std-audit`, `/adr-std-link`, or `/adr-std-check`).

## 4. ADR Template

Reference template: `skill/references/template-madr.md`. File naming convention: `<N>-title-in-kebab-case.md`, where `N` is a positive integer without leading zeros (`1-...md`, `12-...md`; identifier `ADR-<N>`).
Project conventions always take precedence: leading zeros are preserved only if declared (`--name-pattern`, `.adr-std`, `CONVENTIONS.md`, `AGENTS.md`; for automated tools, `numbering: padded` in `.adr-std`). Legacy ADRs with leading zeros (`0001-x.md`) can be migrated using `adr-std migrate`.

| Section or Field | Recorded Information |
|---|---|
| **ID, Status** | Unique ID; `Proposed`, `Accepted`, `Rejected`, `Superseded by ADR-N`, or `Deprecated` |
| **Decision date, Approved on, Modified on** | When decided, approved, and modified |
| **Decision makers, Approving authority** | Who decided and who holds sign-off authority |
| **Stakeholders affected, Concerns, Affected elements** | Impacted stakeholders and architecture components |
| **Relationships to other decisions** | Relationship type and related ADR ID |
| **Context, Assumptions and constraints, Decision drivers** | Background and forces influencing the decision |
| **Considered options, Decision, Rationale, Pros and cons** | Alternatives (with rejection rationale), choice, and why |
| **Consequences, Verification, Limitations** | Outcomes, validation metrics, and excluded aspects |
| **Change history, References** | Post-approval modification audit trail and citations |

`Status` reflects the decision lifecycle, not implementation progress (which should reside in tracker issues or project boards).

## 5. Automated Verification

The `adr-std check` command validates mechanical checklist criteria (file naming format, status, dates, mandatory sections, rejected alternatives with reasons, unedited template placeholders). Requires Python 3.

```bash
adr-std check docs/architecture/ADR                         # validate entire folder
adr-std check docs/architecture/ADR/1-session-cache.md      # validate single file
adr-std check docs/architecture/ADR --name-pattern '^(\d+)-.+\.md$'   # custom pattern
```

Exit codes: `0` passed; `1` violated normative standard requirement; `2` failed recommendations or skill conventions. Semantic checks (`skill/references/checklist.md`) still require human review (the script does not judge the subjective quality of the rationale).

## 6. Installation

Choose **one** of the methods below. Methods 6.1 to 6.3 automatically install the `adr-std` terminal command.

### 6.1 ZIP Package (Installer GUI / Double-Click)

Suitable for users who prefer not to run terminal installation commands.

1. Download `adr-std.zip` from the [latest release](https://github.com/dihcruz1/adr-std/releases/latest/download/adr-std.zip).
2. Extract the archive.
3. Run the installer for your platform:

| Platform | Action |
|---|---|
| **Windows** | Double-click `instalar-windows.bat` |
| **macOS** | Right-click `instalar-mac.command` → **Open** |
| **Linux** | Run inside extracted folder: `bash instalar-linux.sh` |

A dialog will display detected agents and ask where to install the skill.

### 6.2 One-Line Command (Terminal)

```bash
# Linux and macOS
curl -fsSL https://raw.githubusercontent.com/dihcruz1/adr-std/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/dihcruz1/adr-std/main/install.sh | bash -s -- --agent claude-code codex
```

```powershell
# Windows (PowerShell)
irm https://raw.githubusercontent.com/dihcruz1/adr-std/main/install.ps1 | iex
```

The script downloads the **latest release package**, verifies the SHA256 checksum, and installs the skill. To pin a specific version, pass `--version v3.0.0` (Linux/macOS).

### 6.3 Git Clone

```bash
git clone https://github.com/dihcruz1/adr-std.git
cd adr-std
./install.sh                          # Windows: .\install.ps1
./install.sh --agent claude-code      # specify target agent directly
```

To update later: run `git pull` followed by `adr-std update`.

### 6.4 Manual Installation (Without Installer)

If you prefer not to execute helper scripts (note: does not install the `adr-std` CLI tool):

1. Download and extract the release zip.
2. Identify your agent's skill directory from [Section 7](#7-supported-agents).
3. Create the directory if it does not exist.
4. Copy the entire **`skill`** folder into it and **rename it to `adr-std`** (do not copy `SKILL.md` alone, as the skill references files in `references/` and `scripts/`).
5. Verify path structure: `<skills-dir>/adr-std/SKILL.md`.
6. Start a new agent session and test.

### 6.5 Prerequisites

| Method | Requirements |
|---|---|
| ZIP | Operating system default environment (Linux requires `bash`) |
| One-line script | `curl` (or `wget`), `bash` (Linux/macOS) or PowerShell (Windows) |
| Git | `git` |
| Manual | None |
| CLI commands: `check`, `new`, `list`, `link`, `organize`, `migrate` | Python 3 |

No installation method requires administrator privileges (`sudo`).

### 6.6 Adding to PATH

The installer places the CLI in `~/.local/bin`. If this directory is not in your PATH, the installer will prompt before appending an entry to `~/.bashrc`, `~/.zshrc`, or `config.fish` (or User PATH on Windows).

## 7. Supported Agents

The CLI scans your user home folder for installed agent configurations:

```bash
adr-std install                          # interactive selection menu
adr-std install claude-code codex        # specify agents directly
adr-std install --agent claude-code,codex   # comma-separated syntax
adr-std install --all                    # all detected agents
```

| Agent | Identifier | Skill Path |
|---|---|---|
| Claude Code | `claude-code` | `~/.claude/skills` |
| Codex | `codex` | `~/.codex/skills` |
| Gemini CLI | `gemini-cli` | `~/.agents/skills` (shared) |
| OpenCode | `opencode` | `~/.agents/skills` (shared) |
| Antigravity | `antigravity` | `~/.gemini/antigravity/skills` |
| Continue | `continue` | `~/.continue/skills` |
| Cursor | `cursor` | `~/.cursor/skills` |
| GitHub Copilot | `github-copilot` | `~/.copilot/skills` |
| Windsurf | `windsurf` | `~/.codeium/windsurf/skills` |
| Roo Code | `roo` | `~/.roo/skills` |
| Kiro CLI | `kiro-cli` | `~/.kiro/skills` |
| Goose | `goose` | `~/.config/goose/skills` |
| Junie | `junie` | `~/.junie/skills` |
| Amp | `amp` | `~/.config/agents/skills` |
| Cline, Zed, Warp, and others | `universal` | `~/.agents/skills` |

## 8. CLI Commands

| Command | Action |
|---|---|
| `adr-std install [agents...]` | Installs the skill. Shows selection menu if no agents are specified |
| `adr-std install --all` | Installs to all detected agents |
| `adr-std install --link` | Symlinks to local repository `skill/` folder instead of copying |
| `adr-std install --adopt` | Adopts an existing unmanaged `adr-std` folder with backup, non-interactively |
| `adr-std install --dry-run` | Previews actions per destination (`<path>: <class> -> <action>`) without modifying files |
| `adr-std update` | Downloads the latest version, verifies checksum, updates registered agents, and checks ADR migration |
| `adr-std update --no-migrate` | Updates the skill without computing the ADR migration plan |
| `adr-std update --version v3.0.0` | Installs a designated version |
| `adr-std update --agent gemini-cli` | Updates and adds an extra agent |
| `adr-std uninstall [agents...]` | Removes the skill from specified agents (or all if omitted) |
| `adr-std self-uninstall` | Fully uninstalls the skill, config state, PATH entry, and CLI binary |
| `adr-std status` | Displays installed version, registered agents, and directory integrity |
| `adr-std agents` | Lists supported agents and detection status on current machine |
| `adr-std check <path>` | Validates ADR files against ISO 42010 rules (Python 3) |
| `adr-std new <title>` | Scaffolds a new ADR file with next sequential ID (Python 3) |
| `adr-std list` | Lists ADR IDs, statuses, dates, and titles (Python 3) |
| `adr-std link <ADR-A> <type> <ADR-B>` | Registers bidirectional relationship between two ADRs (Python 3) |
| `adr-std organize --dry-run` | Previews renumbering plan without disk modifications (Python 3) |
| `adr-std migrate [--apply] [--exclude GLOB]` | Migrates legacy `0001-x.md` ADRs to `1-x.md` format (Python 3) |
| `adr-std create\|supersede\|review\|audit\|ask [agent] [prompt]` | Launches target agent with the skill and predefined prompt |
| `adr-std config agent [name]` | Manages default agent for interactive commands |
| `adr-std config path [folder]` | Manages default ADR folder in global configuration |
| `adr-std version` / `adr-std help` | Displays version and help information |

## 9. Verifying Installation

1. Run `adr-std status`: verify all configured agents report `intact`.
2. Start a **new terminal/agent session** (active sessions will not reload installed skills).
3. Prompt your agent: *"Create an ADR for the decision to use PostgreSQL."* The agent should load `adr-std` and ask clarifying questions before writing the file.

## 10. Updating and Uninstalling

```bash
adr-std update                # update skill to latest release
adr-std status                # check status
adr-std uninstall codex       # remove from a specific agent
adr-std uninstall             # remove from all agents
adr-std self-uninstall        # completely remove adr-std from system
```

## 11. Troubleshooting

| Issue | Likely Cause | Resolution |
|---|---|---|
| `adr-std: command not found` | `~/.local/bin` not in PATH | Restart terminal session or append `export PATH="$HOME/.local/bin:$PATH"` |
| Agent does not use the skill | Session was already running prior to install | Open a fresh session; verify installation via `adr-std status` |
| `Destination skipped` (exit code 4) | Folder exists and was not overwritten | Run with `--adopt` to adopt existing folder with backup, or inspect skipped list |
| `package checksum mismatch` | Incomplete download or altered archive | Abort installation, check network connection and retry |
| `check command requires Python 3` | Python 3 not installed | Install Python 3 or review `skill/references/checklist.md` manually |

## 12. About the Standard

- **Standard:** ISO/IEC/IEEE 42010:2022 — *Software, systems and enterprise — Architecture description*, 2nd edition (November 2022).
- **Skill Guide:** `skill/references/guia-42010.md` provides an original summary of clauses 1 through 8 and Annexes A to F, classifying requirement levels (SHALL, SHOULD, MAY) and defining prompt constraints.
- **Accessing the standard:** Available through ISO, IEC, IEEE stores or institutional academic subscriptions. This repository does not distribute copyrighted standard text.

## 13. Limitations and Roadmap

**Version 3.0 (Current):** Git repository root resolution across CLI commands, `adr-std new --create` support, prevention of path traversal outside repository root, and Windows `%APPDATA%\adr-std\config` global path support.

**Version 2.0:** Numbering without leading zeros (`<N>-<slug>.md`, `ADR-<N>`), priority for project conventions (`numbering: padded`), migration utility (`adr-std migrate`), and `update` migration prompts.

**Version 1.4:** Multi-agent installer, slash-command wrappers, and core management CLI.

**In Active Development:** Automatic folder adoption (`install --adopt`), dry-run simulations (`--dry-run`), per-agent mode persistence (`link` vs `copy`), and enhanced non-interactive resilience.

For future plans, refer to [`ROADMAP.md`](ROADMAP.md).

## 14. Skill Files

| File | Purpose |
|---|---|
| `skill/SKILL.md` | Primary agent entrypoint: instructions, workflow, and guardrails |
| `skill/references/guia-42010.md` | ISO 42010 summary, clause mappings, and decision guidelines |
| `skill/references/template-madr.md` | Extended MADR ADR markdown template (Clause 6.10 compliant) |
| `skill/references/checklist.md` | Comprehensive ADR verification checklist |
| `skill/scripts/check_adr.py` | Automated checker script for mechanical validation |
| `skill/scripts/adr_cli.py` | CLI logic for `new`, `list`, `link`, and `organize` |
| `skill/scripts/migrate_numbering.py` | Script for migrating legacy zero-padded ADR files |
| `agent_launch.tsv` | Terminal launch parameters for supported agents |

## 15. License and Contributing

Distributed under the MIT License (see [`LICENSE`](LICENSE)). The license covers this skill and its tools; it does not apply to ISO/IEC/IEEE 42010, which retains its own copyright.
For guidelines on contributing, see [`CONTRIBUTING.md`](CONTRIBUTING.md). For bug reports and suggestions, please open an issue at <https://github.com/dihcruz1/adr-std/issues>.

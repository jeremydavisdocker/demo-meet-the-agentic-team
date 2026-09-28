# Meet the Agentic Development Team — demo infrastructure spec

Buildable specification for the live demo in the talk *Meet the Agentic Development Team*
(`Meet_the_Agentic_Team.pdf`). It covers the **team**: roles, environments, shared knowledge,
handoffs, guardrails, and the stage runbook. It does not specify the sample application's features;
those arrive as task specs during the demo.

Copy-ready artifacts referenced throughout live under `spec/`:

| Path | Purpose |
|---|---|
| `spec/skills/*/SKILL.md` | Role and convention skills (agentskills.io format) — single source of truth, copied to all three agents |
| `spec/repo-files/` | Files dropped into the Quarkus repo: `CLAUDE.md`, `AGENTS.md`, `.mcp.json`, `.codex/config.toml`, CI workflow |
| `spec/feature-spec-template.md` | Shape of a task handed to the team |
| `spec/tasks/00N-*.md` | The four demo task specs, copied into the app repo's `specs/` by bootstrap |
| `spec/scripts/` | `bootstrap.sh`, `dispatch-implementer.sh`, `dispatch-reviewer.sh`, `reset-demo.sh` |

## 1. Goals and non-goals

**Goals**

- Show three coding agents with distinct roles collaborating on one repo through Slack, Git,
  Skills and specs, with a human as product owner.
- Make each technique from the abstract visible on stage: onboarding with Skills, specs and
  acceptance criteria, architectural boundaries enforced by tests, mutation testing, different
  models for implementation vs. review, safe YOLO-mode sandboxes, feedback loops.
- Be **repeatable on stage**: every hop scripted, every failure path known, reset in under two
  minutes.

**Non-goals**

- A general-purpose orchestration framework. Everything is the simplest thing that works for
  four demo tasks.
- Specifying the sample app's domain. The Quarkus repo starts bare; specs are written per task.
- Cloud sandboxes, multi-repo, or more than one task in flight at a time.

## 2. Architecture

```
                         ┌──────────────────────────── host laptop ─────────────────────────────┐
  Slack #agentic-team    │                                                                       │
 ┌───────────────────┐   │   ┌────────────────────┐   sbx exec (background)                      │
 │ product owner     │◀──┼──▶│ Coordinator        │────────┬────────────────────┐                │
 │ @Coordinator      │   │   │ Hermes Agent       │        ▼                    ▼                │
 │ @Implementer      │◀──┼───┤ • Slack gateway    │  ┌───────────────┐   ┌───────────────┐       │
 │ @Reviewer         │◀──┼───┤ • skills           │  │ Docker Sandbox│   │ Docker Sandbox│       │
 └───────────────────┘   │   │ • terminal (local) │  │ team-implementer│ │ team-reviewer │       │
          ▲              │   └────────────────────┘  │ Claude Code   │   │ Codex CLI     │       │
          │ posts via    │                            │ --clone repo  │   │ --clone repo  │       │
          │ Slack MCP    │                            │ Slack MCP     │   │ Slack MCP     │       │
          └──────────────┼────────────────────────────┴───────┬───────┴───┬───────┬───────┘       │
                         │                                    │ push / gh pr      │ gh pr review  │
                         └────────────────────────────────────┼───────────────────┼───────────────┘
                                                              ▼                   ▼
                                                   GitHub: <org>/<repo>  (PRs, Actions `verify`)
```

- **Slack is the conversation.** One thread per task. Humans and all three agents write there.
- **Git is the state.** Specs on `main`, work on `task/NNN-slug`, verdicts as PR reviews, CI as the
  second gate.
- **Skills and specs are the memory.** Every agent starts each dispatch with no history; the skill
  tells it *how*, the spec tells it *what*, the thread and PR tell it *where we are*.
- **Docker Sandboxes are the blast radius.** Workers run with permissions bypassed inside microVMs
  that hold a private clone and proxy-injected credentials.

## 3. Roles and identities

| Role | Runtime | Model | Where it runs | Slack identity |
|---|---|---|---|---|
| Coordinator | Hermes Agent | any Hermes-supported provider; a fast model is enough (it never writes code) | host laptop, `terminal.backend: local` | Slack app **Coordinator** (`@Coordinator`), created from `hermes slack manifest` |
| Implementer | Claude Code | `claude-opus-5-5` (`IMPLEMENTER_MODEL`) | sandbox `team-implementer` | Slack app **Implementer** (`@Implementer`) |
| Reviewer | OpenAI Codex CLI | Codex default; pin with `REVIEWER_MODEL` once chosen | sandbox `team-reviewer` | Slack app **Reviewer** (`@Reviewer`) |
| Product owner | human | — | Slack | themselves |

Three Slack apps, not one: distinct avatars make the team legible on stage, and Hermes only wakes
on @mentions from *other* users, so worker posts must not come from its own bot user. (Cheaper
alternative: two apps, workers sharing one with `chat:write.customize` to set username/icon per
message.)

Different vendors for implementation and review is deliberate: the reviewer must not share the
implementer's blind spots, and the abstract promises "Claude Code, Codex, and other coding agents".

## 4. Environments

### 4.1 Sandboxes

Both workers are Docker Sandboxes created in **clone mode** from the host's local clone of the repo:

```bash
sbx create --clone --name team-implementer -e SLACK_BOT_TOKEN=… -e SLACK_TEAM_ID=… -e SLACK_CHANNEL_IDS=… claude "$TEAM_REPO_DIR"
sbx create --clone --name team-reviewer    -e SLACK_BOT_TOKEN=… -e SLACK_TEAM_ID=… -e SLACK_CHANNEL_IDS=… codex  "$TEAM_REPO_DIR"
```

- Clone mode gives each worker a private working tree; nothing reaches the host except via
  `git push` to GitHub. `origin` inside the sandbox points at GitHub.
- Sandboxes are **persistent** across the demo: created once by `bootstrap.sh`, pre-warmed with
  Maven dependencies and the `mcp/slack` image, re-synced by `reset-demo.sh`.
- Agents run in YOLO mode by default inside sandboxes (`claude --dangerously-skip-permissions`,
  `codex --dangerously-bypass-approvals-and-sandbox`). The dispatch scripts pass the same flags
  explicitly so behaviour does not depend on the `sbx` default.
- Each sandbox has its own Docker daemon, so the Slack MCP server runs as `docker run -i --rm
  mcp/slack` inside it.

### 4.2 Credentials

| Secret | Set on host | Consumed by | Notes |
|---|---|---|---|
| GitHub | `sbx secret set github --command 'gh auth token'` | both sandboxes (`gh`, `git push`) | proxy-injected; token never enters the VM |
| Anthropic | `sbx secret set anthropic` (or `/login` OAuth once inside) | `team-implementer` | |
| OpenAI | `sbx secret set openai` or `sbx secret set openai --oauth` | `team-reviewer` | |
| Slack bot tokens | `-e SLACK_BOT_TOKEN` at `sbx create` | Slack MCP container | plain env var — acceptable for a demo bot scoped to one channel; see §11 for the proxy-managed alternative |
| Hermes Slack tokens | `~/.hermes/.env` | Hermes gateway | `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `SLACK_ALLOWED_USERS`, `SLACK_HOME_CHANNEL` |

### 4.3 Project-level configuration travels with the repo

Sandboxes do **not** see `~/.claude` or `~/.codex` from the host. Everything an agent needs is in
the repo (or written inside the sandbox by `bootstrap.sh`):

| Agent | Reads from repo | Written into sandbox by bootstrap |
|---|---|---|
| Claude Code | `CLAUDE.md`, `.claude/skills/{team-conventions,quarkus-architecture,implementer}`, `.mcp.json` | `claude mcp add --scope user slack -- docker run … mcp/slack` |
| Codex | `AGENTS.md` (incl. `## Code Review Rules`), `.agents/skills/{team-conventions,quarkus-architecture,reviewer}`, `.codex/config.toml` | `codex mcp add slack -- docker run … mcp/slack` |
| Hermes | — | `~/.hermes/skills/agentic-team/{team-conventions,coordinator,quarkus-architecture}` |

## 5. Shared knowledge

| Knowledge | Lives in | Written by | Read by |
|---|---|---|---|
| What to build | `specs/NNN-slug.md` (template: `spec/feature-spec-template.md`) | product owner (or Coordinator on request) | Implementer, Reviewer |
| How the team works | `team-conventions` skill | this spec | all agents |
| How the code must be shaped | `quarkus-architecture` skill; `ArchitectureTest`; PIT config | this spec; tasks 001/002 | Implementer, Reviewer |
| How each role behaves | `coordinator`, `implementer`, `reviewer` skills | this spec | one role each |
| Where a task is | Slack thread (`STATUS:` lines), PR state, CI status | agents | Coordinator, human |

Skills are agentskills.io `SKILL.md` files, so one source (`spec/skills/`) serves Hermes
(`~/.hermes/skills/`), Claude Code (`.claude/skills/`) and Codex (`.agents/skills/`) unchanged. The
Hermes-specific `metadata.hermes` block is ignored by the others.

**Spec quality rule.** A spec is accepted by the Coordinator only if every acceptance criterion
names a layer and a proof (`*Test` or `*IT`). Vague criteria are the number one cause of agent
drift; the template enforces the shape and the Implementer is told to block rather than guess.

## 6. Workflow and handoff protocol

State machine per task; every arrow is a Slack message whose first line is a `STATUS:` line
(vocabulary in `team-conventions`) and whose last line @mentions the next actor.

```
product owner ──"@Coordinator implement specs/003-…"──▶ Coordinator
Coordinator ── DISPATCHED role=implementer round=1 ──▶ dispatch-implementer.sh (background)
Implementer ── STARTED … ── PR_OPENED pr=#N round=1 @Coordinator ──▶ Coordinator
Coordinator ── DISPATCHED role=reviewer round=1 ──▶ dispatch-reviewer.sh (background)
Reviewer ── STARTED … ── REVIEW_DONE verdict=APPROVE|REQUEST_CHANGES @Coordinator ──▶ Coordinator
  APPROVE  + CI green ──▶ DONE (merge only if owner said "auto-merge")
  REQUEST_CHANGES, round<3 ──▶ DISPATCHED role=implementer round+1 (PR_NUMBER passed) ──▶ …
  REQUEST_CHANGES, round=3 ──▶ ESCALATED reason=max-rounds
any worker ── BLOCKED reason=… @Coordinator ──▶ Coordinator relays to owner, stops
```

Key design choices:

1. **Event-driven, not polled.** Hermes' terminal tool has a hard foreground deadline (~7 min);
   worker runs take 5–40 min. So the Coordinator launches a dispatch script with
   `terminal(background=true)`, ends its turn, and is woken by the worker's @mention. This also
   makes the handoff visible to the audience.
2. **Thread identity is passed explicitly.** `SLACK_CHANNEL_ID` and `SLACK_THREAD_TS` go into the
   worker's environment; the worker never searches Slack for "its" thread.
3. **Round and PR number are passed explicitly.** Workers never infer them from prose.
4. **Two verification gates.** The Implementer must have `./mvnw -B verify` green before opening a
   PR (self-correction loop inside the sandbox); the Reviewer re-runs it independently; CI runs it
   a third time and the Coordinator checks `gh pr checks` before declaring `DONE`.
5. **Bounded loop.** Three rounds, then a human decides. No silent retries.

Message templates for every hop are in the `coordinator`, `implementer` and `reviewer` skills.

## 7. Guardrails as demo tasks

The repo starts as a bare Quarkus app (`quarkus create app com.example.demo:agentic-quarkus-demo`
with RESTEasy Reactive, Hibernate ORM Panache, an in-memory or Dev Services database). The
guardrails are **built live** by the team, one technique per task. The feature domain is a minimal
order-pricing model (`Money`, `Order`, `OrderLine`), chosen because discounts and tax produce
exactly the boundary conditions and rounding rules that mutation testing bites on. The specs are in
`spec/tasks/`.

| Task | Spec | Technique shown | What the audience sees |
|---|---|---|---|
| 001 | `001-arch-boundaries.md` — `ArchitectureTest` (ArchUnit) enforcing `rest → service → domain ← persistence`, domain free of `jakarta.*`/`io.quarkus.*`/`org.hibernate.*`, plus a negative check pasted into the PR | architectural boundaries as tests; Skills onboarding (`quarkus-architecture` tells the agent the rules) | Implementer reads the skill, writes the test, PR approved first round |
| 002 | `002-mutation-testing.md` — PIT bound to `verify` (threshold 80, `domain`/`service` only, `*IT` excluded), failsafe for `*IT`, `GreetingResourceTest` → `GreetingResourceIT`, first domain class `Money` with half-up `percent` | mutation testing verifying tests; test naming convention | first PIT run likely fails on `percent` rounding mutants; Implementer strengthens `MoneyTest` rather than lowering the bar |
| 003 | `003-order-volume-discount.md` — `Order`/`OrderLine`, `OrderRepository` port, `OrderService`, Panache adapter, `POST /orders`, `GET /orders/{id}/total`; 10% off lines with `quantity >= 10` | boundaries catching drift; cross-vendor review | the shortcut is to inject the Panache repository into the resource and discount there; either ArchUnit fails in the sandbox and the Implementer self-corrects, or the Reviewer flags a P0 → round 2 |
| 004 | `004-order-total-with-tax.md` — 20% tax on `net`, two new response fields; **deliberately thin**: three criteria, no rounding examples, no zero/boundary cases | mutation testing catching weak tests; feedback loop | a happy-path-only test passes but PIT reports surviving mutants (rounding, `net` vs `gross`, boundary); Implementer adds cases; Reviewer verifies the score independently |

Optional 005: `specs/005-hotfix-<feature>.md` written live from an audience suggestion, to show
the process is not rehearsed.

`bootstrap.sh` copies `spec/tasks/*.md` into the app repo's `specs/`; commit them to `main`
**before** the talk. Sandboxes in clone mode snapshot the repo at creation, and workers
`git fetch origin` at each dispatch, so specs pushed later are still picked up.

## 8. Feedback loops and limits

| Loop | Signal | Who corrects | Bound |
|---|---|---|---|
| Local verify | `./mvnw -B verify` red in `team-implementer` | Implementer, before any PR | 5 red runs → `BLOCKED reason=verify-red-after-5-runs` |
| Independent review | Codex P0/P1 findings as a GitHub review | Implementer, next round | 3 rounds → `ESCALATED reason=max-rounds` |
| CI | GitHub Actions `verify` on the PR | Coordinator treats red as REQUEST_CHANGES | same round budget |
| Stall detection | no worker message for 20 min | Coordinator: `sbx exec team-<role> pgrep -af 'claude\|codex'`, reports; owner decides | manual |
| Spec quality | Implementer cannot map a criterion to a test | `BLOCKED reason=spec-untestable` → owner rewrites the spec | manual |

What the loops deliberately **cannot** do: lower a threshold, add an exclusion, delete a test, or
force-push. The skills forbid it and the Reviewer's rules make it a P0, so the only way out of a
red gate is a better test or a better spec.

## 9. Setup runbook (host)

1. **Repo.** Create `<org>/<repo>` on GitHub; `quarkus create app …`; commit; clone to
   `$TEAM_REPO_DIR`. Enable Actions.
2. **Slack apps** in the demo workspace, all invited to `#agentic-team`:
   - *Coordinator*: `hermes slack manifest --agent-view --write` → create app from manifest →
     Socket Mode on → app-level token (`xapp-`, `connections:write`) → install → bot token (`xoxb-`).
     Required scopes/events come from the manifest (`chat:write`, `app_mentions:read`,
     `channels:history`, `channels:read`, `users:read`, … ; events `app_mention`,
     `message.channels`, `message.im`).
   - *Implementer*, *Reviewer*: from scratch; bot scopes `chat:write`, `channels:history`,
     `channels:read`, `users:read`, `reactions:write`; install; note bot tokens.
3. **Hermes.** Install (`curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`),
   `hermes setup`, `hermes gateway setup` (Slack). In `~/.hermes/.env`: `SLACK_BOT_TOKEN`,
   `SLACK_APP_TOKEN`, `SLACK_ALLOWED_USERS=<owner member id>`, `SLACK_HOME_CHANNEL=<C…>`.
   In `~/.hermes/config.yaml`:
   ```yaml
   terminal:
     backend: local
     timeout: 300
   platforms:
     slack:
       extra:
         require_mention: true
         reply_in_thread: true
         allow_bots: mentions        # worker bots must be able to wake the Coordinator
   agentic_team:
     repo_dir: <TEAM_REPO_DIR>
     scripts_dir: <path to spec/scripts>
     max_rounds: 3
   ```
   Start with `hermes gateway`; `/invite @Coordinator` in the channel.
4. **`team.env`** next to the scripts: `TEAM_REPO`, `TEAM_REPO_DIR`, `SLACK_TEAM_ID`,
   `SLACK_CHANNEL_ID`, `SLACK_IMPLEMENTER_BOT_TOKEN`, `SLACK_REVIEWER_BOT_TOKEN`, optionally
   `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `IMPLEMENTER_MODEL`, `REVIEWER_MODEL`. Never commit it.
5. **`spec/scripts/bootstrap.sh`** — sets `sbx` secrets, copies repo files and skills into the repo
   (commit and push them), installs Hermes skills, creates both sandboxes, registers the Slack MCP
   server in each, pre-warms Maven and the MCP image, smoke-tests `gh` and the agent CLIs.
6. **Specs.** `bootstrap.sh` has copied `spec/tasks/001…004` into `specs/`; review the `<org>`
   placeholders and the allowed dependencies in 003 against the generated `pom.xml`; push to `main`.
7. **Smoke test each hop** in a scratch thread: `@Coordinator status?`; then
   `spec/scripts/dispatch-implementer.sh 001 <C…> <ts> 1` by hand and watch the thread; then the
   reviewer script against the resulting PR. Fix before rehearsing end-to-end.

## 10. Stage-day checklist and failure modes

**Before going on**

- [ ] `hermes gateway` running; `@Coordinator status?` answered in < 10 s.
- [ ] `sbx ls` shows both sandboxes running; `reset-demo.sh` run; clones at `origin/main`.
- [ ] Maven cache warm in both sandboxes (`./mvnw -B -o verify -DskipTests` succeeds offline).
- [ ] `gh auth status` green inside both sandboxes.
- [ ] Specs 001–004 on `main`; template PRs from rehearsal closed.
- [ ] Fallback branch `demo-fallback/*` with a pre-made PR per task, in case a provider is down.

**Timeboxes** (talk is ~45 min): 001 ≈ 6 min, 002 ≈ 8 min, 003 ≈ 10 min incl. one review round,
004 ≈ 10 min. Start 002 while narrating 001's PR; the Coordinator handles one task at a time, so
wait for `DONE` before the next request, or run 003 and 004 in separate threads and accept
interleaved Slack traffic.

| Failure | Detection | Response |
|---|---|---|
| Hermes silent | no reply to a mention | `hermes gateway` restart; drive `dispatch-*.sh` by hand from a terminal and narrate |
| Worker stalls | no message for 20 min | `sbx exec team-<role> pgrep -af 'claude\|codex'`; kill and re-dispatch, or switch to fallback PR |
| Anthropic/OpenAI outage | worker `BLOCKED reason=missing-credential` or API errors in log | open the fallback PR; still run the other vendor's step live |
| Slack MCP fails | worker finishes (PR exists) but no thread message | show the PR; note in narration that the handoff signal is the weak link and why the `STATUS:` protocol exists |
| PIT too slow | verify > 5 min | ensure `*IT` are excluded and `threads` ≥ 4; reduce `targetClasses` to `domain.*` for the demo |

Logs: `~/.agentic-team/logs/<role>-<task>-r<round>-<timestamp>.log`.

## 11. Verify before building

Items not confirmed against documentation while writing this spec. Each has a one-line test;
settle them in step 7 of §9 and adjust the scripts.

| Question | Quick test | Fallback if it fails |
|---|---|---|
| Does `sbx exec` accept `-e VAR=value` like `docker exec`? | `sbx exec -e X=1 team-implementer env \| grep X` | export variables inside the `bash -lc` string instead |
| Does `codex exec` run fully headless with the MCP server registered by `codex mcp add`, without a trust prompt for the project? | `sbx exec team-reviewer codex exec 'list your MCP tools'` | pass `-c mcp_servers.slack.command=docker -c 'mcp_servers.slack.args=[…]'` on the command line |
| Does Codex load skills from `.agents/skills/`? | `sbx exec team-reviewer codex exec 'which skills are available?'` | inline the reviewer procedure into `AGENTS.md` |
| Is `codex review --base origin/main` scriptable (non-TTY) and does it emit structured findings? | `sbx exec team-reviewer codex review --base origin/main` on a PR branch | keep the `codex exec` review prompt in `dispatch-reviewer.sh` (current default) |
| Does Slack deliver `app_mention` for mentions authored by *other bots*, and does Hermes act on them with `allow_bots: mentions`? | post `@Coordinator status?` from the Implementer app via the MCP | have dispatch scripts call `hermes send` (or post as the owner via a webhook) when the worker exits |
| Does `claude -p … --output-format json` respect user-scope MCP servers added with `claude mcp add --scope user` inside the sandbox? | `sbx exec team-implementer claude -p 'list your MCP tools' --output-format json` | rely on the project `.mcp.json` and pre-approve it via `.claude/settings.json` `enabledMcpjsonServers` |
| Can Slack bot tokens be proxy-managed custom secrets instead of env vars? | `sbx secret set --help` for custom/name-based secrets | keep `-e SLACK_BOT_TOKEN` (current default) |
| Current stable `pitest.version` / `pitest.junit5.version` | Maven Central at build time | any pitest ≥ 1.16 with junit5 plugin ≥ 1.2.3 |

## Traceability to the abstract

| Abstract bullet | Where |
|---|---|
| onboarding agents with Skills | §4.3, §5, `spec/skills/` |
| specifications and acceptance criteria instead of vague prompts | §5, `spec/feature-spec-template.md`, `implementer` skill step 4 |
| enforcing architectural boundaries with automated tests | task 001, `quarkus-architecture` skill |
| mutation testing to verify that tests detect defects | task 002, task 004 |
| assigning implementation and review to different models | §3 |
| safe environments for "YOLO mode" | §4.1 |
| feedback loops that let agents discover and correct their mistakes | §6, §8, tasks 003/004 |
| team communicates through Slack; Git, Skills, specs as shared knowledge | §2, §5, §6 |

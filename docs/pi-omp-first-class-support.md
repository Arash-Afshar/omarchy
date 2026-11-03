# First-class support for Pi and Oh My Pi

Omarchy offers Pi (`pi`, earendil-works/pi) and Oh My Pi (`omp`,
can1357/oh-my-pi) as default coding agents, installs both through mise, and
reads their sessions in the agents panel. Support is still uneven: some
integrations assume paths and provider names that current releases no longer
use, Oh My Pi gets no theme at all, and about forty community issues and PRs
each fix one slice against an older base.

This issue lists what first-class support needs, what was verified against
the agents themselves, and the branches that implement it. It replaces the
scattered fixes listed under [Upstream issues and PRs](#upstream-issues-and-prs).

Verified against **pi 1.5.0** (`@earendil-works/pi-coding-agent`, what the
mise registry's `pi` installs) and **omp 18.16.0** (`@oh-my-pi/*`, mise's
`oh-my-pi`, `github:can1357/oh-my-pi`), read from their published packages on
2026-11-03, and against Omarchy `quattro` at `97316b0bb`.

## What the agents actually do

These facts decide every fix below. Several open PRs assume otherwise.

| | Pi 1.5.0 | Oh My Pi 18.16.0 |
| --- | --- | --- |
| Agent directory | `~/.pi/agent`, or `PI_CODING_AGENT_DIR` (leading `~` expanded) | `~/.omp/agent`, or `PI_CODING_AGENT_DIR` (the same variable), or `~/.omp/profiles/<name>/agent` when `OMP_PROFILE` (else `PI_PROFILE`) names a profile, which then ignores `PI_CODING_AGENT_DIR` |
| `~/.config/pi` | Never used. #7194 and #8345 describe a non-default build | Not applicable |
| Sessions | `<agent dir>/sessions`, or `PI_CODING_AGENT_SESSION_DIR`, or `sessionDir` in `settings.json` | `<agent dir>/sessions` (or XDG state after `omp config init-xdg`) |
| Sign-ins | `<agent dir>/auth.json`; `pi auth check --provider <id> --json --credentials` resolves and refreshes one | `agent.db` (SQLite, table `auth_credentials`, `credential_type` `api_key` or `oauth`, data `{"key": ...}` for keys). XDG data: it moves to `$XDG_DATA_HOME/omp` once that directory exists and the default tree is in use. `auth.json` is legacy |
| Settings | `<agent dir>/settings.json`, plain JSON | `config.yml`, owned, migrated and quarantined by omp; write it with `omp config set` |
| Custom themes | `<agent dir>/themes/<name>.json`, `settings.json` `theme`; 5 optional tokens with fallbacks | `<agent dir>/themes/<name>.json` (never XDG), `theme.dark` and `theme.light` in `config.yml`; schema has `additionalProperties: false` and 66 required tokens; hot-reloaded |
| Skills | `<agent dir>/skills` **and `~/.agents/skills`**, the latter from the home directory even when `PI_CODING_AGENT_DIR` moves the tree; the same file reached through two symlinks loads once | `~/.agents/skills`, `~/.agent/skills`, `~/.claude/skills`, `~/.codex/skills`, `<agent dir>/skills` and more; duplicates collapse by skill name |
| Starting prompt | Positional; a leading `install`, `remove`, `update`, `list`, `config`, `auth` is a subcommand; `--` ends options (since 0.84.3) | Positional after `--`; `--auto-approve`/`--yolo` |
| ChatGPT subscription | Provider `openai` ("Sign in with ChatGPT", api `openai-responses`); `openai-codex` is "legacy" | Provider `openai-codex`; `openai` is an API key |

## What first-class support needs

1. **Theme Pi where Pi reads it.** Follow `PI_CODING_AGENT_DIR`, never
   overwrite a theme the user picked in Pi, and treat `settings.json` with
   care (symlinks, file mode, invalid JSON). *Done in branch 1.*
2. **Theme Oh My Pi.** Render a theme with omp's full token set, sync it to
   the profile-aware agent directory on every theme switch, and select it
   through omp's own CLI when omp becomes the default agent. *Done in
   branch 2.*
3. **Launch Pi with any prompt.** Pass the prompt after `--` so "update" or
   "list" starts a session, and keep the local-model options ahead of it.
   *Done in branch 3.*
4. **Count Pi and omp usage under the right provider, with the sign-ins they
   actually keep.** Read omp's keys from `agent.db` in every collector,
   follow `PI_CODING_AGENT_DIR`, profiles and XDG for omp, reuse Pi's Kimi
   sign-in, and recognise the provider ids Pi and omp use for Z.ai.
   *Done in branch 4, except Pi's ChatGPT sign-in (open item 1).*
5. **Ship skills where Pi and omp read them.** Nothing to change:
   `omarchy-provision-user` already links every shipped skill into
   `~/.agents/skills`, which both read regardless of `PI_CODING_AGENT_DIR`,
   and both de-duplicate the extra links. #13836 is not needed. The
   redundant `~/.pi/agent/skills` links can go in the general cleanup of
   #6982 / #16783.
6. **Let a local model open in omp**, as it does in Pi and OpenCode. *Open
   item 2.*
7. **Warn when a standalone omp shadows the mise one** (#14464). *Open item 3.*

## Branches

All on `Arash-Afshar/omarchy`, stacked in this order on `quattro` at `97316b0bb`. Each code branch adds exactly one commit to its predecessor, authored by Arash Afshar without a co-author trailer. The documentation branch is separate and adds one commit directly to the same `quattro` base.

### 1. `pi/1-theme-set-pi-fixes`

- [8e06a2e](https://github.com/Arash-Afshar/omarchy/commit/8e06a2ed67236ed843ecdabd796d9fe29e80ca13): Sync the Pi theme where `PI_CODING_AGENT_DIR` puts Pi, and keep the user's pick. Includes `test/shell.d/theme-set-pi-test.sh` and the `test/cli` environment guard so the suite cannot write a developer's real Pi tree. Fixes #13691 (theme half); supersedes #13693, #13718, the Pi half of #13713 and of #13983.

### 2. `pi/2-oh-my-pi-theme`

- [5fb8afe](https://github.com/Arash-Afshar/omarchy/commit/5fb8afed9b434f624cf94bb84a560015fd65e5bf): Follow the Omarchy theme in Oh My Pi. Includes `default/themed/omp.json.tpl`, `bin/omarchy-theme-set-omp`, the theme-switch hook, default-agent activation, a migration for existing users, the theme test, the theme-staging allowlist entry and the manual note. The template was checked against `@oh-my-pi/pi-tui` 18.16.0's `theme-schema.json`: all 66 required tokens are present and every reference resolves. Ports #8333 (lepht), adding profile-aware paths.

### 3. `pi/3-launch`

- [a476a18](https://github.com/Arash-Afshar/omarchy/commit/a476a1811e8cbcad6325f28bb134d61f13484971): Pass Pi's starting prompt after `--`, keeping local-model options first. Includes normal, one-word and local-model prompt coverage. Pi half of #16724.

### 4. `pi/4-usage-collector`

- [9e1c33d](https://github.com/Arash-Afshar/omarchy/commit/9e1c33d13fc421361a28270ae1f2d80ac89895e5): Complete Pi and Oh My Pi usage integration. This single commit combines the six former usage commits without changing their final code tree:
  - Find omp's Antigravity sign-in where `PI_CODING_AGENT_DIR` puts it (#16507).
  - Recognise the Z.ai provider ids and key variables used by Pi, omp and opencode (#16300).
  - Reuse Pi's Kimi sign-in through `pi auth check`, retaining credential precedence and timeout/security guards (#16431, Pillumz).
  - Pin #8270: a Pi session on an OpenRouter key counts under OpenRouter.
  - Read omp's sign-ins from `agent.db`, following profiles and migrated XDG data, with a legacy `auth.json` fallback. The shared helpers serve the DeepSeek, MiniMax, Ollama, OpenCode, OpenRouter, Synthetic, Z.ai and Antigravity collectors; the new store test covers path resolution and credential selection. Generalises #16508.
  - Document that Pi's ChatGPT sign-in on `openai` is not counted yet.

The original four usage ports were verified against pi 1.5.0 and omp 18.16.0: `pi auth check` and its flags exist, `kimi-coding` is Pi's provider id, and omp moves `agent.db` with `PI_CODING_AGENT_DIR`. The shared-store lookup also fixes the earlier Z.ai port's reliance on omp's legacy `auth.json` and default tree. This history cleanup preserves every code branch's final tree exactly; the live Omarchy validation below is still required.

## Open items (need a live Omarchy machine)

Everything below was either impossible to verify off an Omarchy install or
needs a design decision. Each item says what is wrong and how to fix it.

### 1. Pi's ChatGPT subscription usage is not counted (#17397, #17444, #8950)

**Problem.** Pi 1.x signs in with ChatGPT on its `openai` provider and calls
`openai-codex` legacy. Its sessions record those turns as
`provider: "openai"`, `api: "openai-responses"`, exactly as they record an
OpenAI API key. The Codex collector counts only `openai-codex`, so a Pi user
on a ChatGPT plan sees Codex limits but no Codex usage. #17397 counts every
Pi `openai` turn under Codex, which also bills API-key usage to the
subscription. omp's `openai` is always an API key, and the scanner's
`accept(provider, model, entry)` callback cannot tell a Pi row from an omp
row.

**Fix.**
1. Give `scan_pi_sessions` a way to know the harness of a row: pass the root
   (or a `harness` of `"pi"`/`"omp"` derived from it) into `accept`, or let
   the Codex collector run a second scan over Pi-only roots
   (`~/.pi/agent/sessions`, Pi's `sessionDir`, `PI_CODING_AGENT_SESSION_DIR`).
   The second scan's acceptance must stay disjoint from the first, and its
   prompts and sessions must not double-count with it; check how
   `bookings` and `STATS` key sessions before choosing.
2. In the Codex collector, accept a Pi row on `openai` with api
   `openai-responses` only when Pi's `auth.json` `openai` entry is
   `"type": "oauth"` (a ChatGPT sign-in). That reflects the current sign-in,
   not each turn's, which is the best the session format allows; say so in
   the README.
3. Update the partition test: it states "pi's `openai` is an OpenAI API key,
   which no collector bills". Add rows for Pi `openai`/`openai-responses`
   with and without the ChatGPT sign-in.
4. On a live machine, sign in to Pi with ChatGPT, run a few turns, and check
   `omarchy-agent-usage-update --force` and the panel.

#8950 (a Codex tab after Codex was uninstalled) is the same attribution
working as designed: Pi's `openai-codex` usage is Codex subscription usage.
Close it with that explanation once item 1 lands, or label the tab by
subscription rather than by CLI.

### 2. A local model cannot open in omp

`omarchy-agent --local` points only Pi and OpenCode at the running local
model (`omarchy-agent-local overlay`), so omp as the default falls back to
Pi. omp loads extensions with `--extension` like Pi; confirm its model
selection flags with `omp --help` on the installed version, then add an `omp`
overlay in `omarchy-agent-local` and a case in `omarchy-agent`'s
`use_local` block, then try it against a running local model.

### 3. omp ownership drift between mise and a standalone binary (#14464)

A standalone `omp` (its own updater, or `PI_INSTALL_DIR`) can sit at
`~/.local/bin/omp`, where Omarchy also puts its mise launcher, and silently
shadow the mise-owned copy. #14464 proposes a non-destructive warning in
`omarchy-update-mise` before `mise up`. Needs a machine with both installs to
reproduce; do not rewrite user binaries.

### 4. Verify the branches on Omarchy

The changes were checked on a development machine with GNU-only steps
stubbed, which is not a substitute. On an Omarchy box with the stack
checked out (`omarchy dev link`):

- `./test/all`. In particular `test/cli` (the new `omp.json` template
  assertion and the existing Pi theme checks), `default-agent-test`,
  `theme-set-pi-test`, `theme-set-omp-test`, `agent-usage-omp-store-test`,
  `agent-usage-partition-test` and `agent-usage-agy-harness-test`. The last
  two could not run off Omarchy; the Antigravity case "takes omp's limits
  from omp usage" failed there on untouched `quattro` too, so confirm it
  passes on Linux before blaming the branch.
- Theme: switch themes with Pi and omp open; both retint. Set
  `PI_CODING_AGENT_DIR` in `~/.config/uwsm/env`, log in again, switch
  themes, and check `<dir>/themes/omarchy-system.json`. Pick another theme
  in Pi, run `install/user/theme.sh` (or re-provision), and check it stays.
- omp: `omarchy-default-agent omp` installs omp and runs
  `omp config set theme.dark|theme.light omarchy-system`; check
  `omp config get theme.dark` and that the migration runs once for a user
  who already had omp as default.
- Launch: `omarchy agent` prompt "update" with Pi as default starts a session.
- Usage: with omp signed in to DeepSeek, OpenRouter, Ollama Cloud, Z.ai,
  MiniMax, Synthetic or OpenCode Go, the matching tab shows limits. Check
  whether the desktop session sets `XDG_DATA_HOME`; if it does and
  `~/.local/share/omp` exists, `agent.db` lives there.
- Kimi: sign in with `/login kimi-coding` in Pi only; the Kimi tab shows
  quota via `pi auth check`.

### 5. Usage refresh cost on large Pi/omp histories (#15906, #12411)

The panel rereads every Pi/omp session on each 15-minute refresh; #15906
reports about 19 s per collector on a 6.9 GB `~/.omp/agent/sessions`. It adds
a per-file index like the Claude collector's. Measure on a machine with a
large history before and after; it conflicts with nothing above.

### 6. Light themes in Pi (optional)

Pi's theme schema has an optional `appearance` (`"dark"`/`"light"`) that it
otherwise guesses from colours. Setting it from the Omarchy theme's light
mode in `pi.json.tpl` would make light themes reliable.

## Upstream issues and PRs

State as of 2026-11-03.

| | Status after this work |
| --- | --- |
| #13691 theme-set-pi ignores `PI_CODING_AGENT_DIR` | Theme half fixed (branch 1); skill half not needed (see need 5) |
| #13693, #13718, #13713 (Pi), #13983 (Pi) | Superseded by branch 1 |
| #8333 Oh My Pi theme | Ported in branch 2 |
| #16724 pi prompt after `--` (and Kimi) | Pi half in branch 3; Kimi half untouched |
| #16507, #15892 omp Antigravity sign-in | Ported in branch 4 |
| #16300, #15560 Z.ai provider ids | Ported in branch 4 |
| #16431 Kimi via Pi | Ported in branch 4 |
| #16508, #16085 Ollama key from omp's `agent.db` | Generalised to every collector in branch 4 |
| #8270 Pi on OpenRouter | Already fixed by #14040; pinned by a test in branch 4 |
| #14550 `PI_CODING_AGENT_DIR`/`_SESSION_DIR` session roots | Already in `quattro` (`pi_session_roots()`); close |
| #7194, #8345 `~/.config/pi/sessions` | Pi never uses that path by default; close |
| #13836 link skills under `PI_CODING_AGENT_DIR` | Not needed: Pi reads `~/.agents/skills` from home |
| #6982, #16775, #16783 skill links | General cleanup; Pi and omp already covered |
| #17397, #17444, #8950 Pi `openai`/ChatGPT | Open item 1 |
| #10330 dedicated Pi tab, #13845 omp tab | Conflict with the panel's count-under-the-billing-provider design that #14040 settled; recommend closing |
| #14464 omp ownership drift | Open item 3 |
| #15906, #12411 scan cost | Open item 5 |

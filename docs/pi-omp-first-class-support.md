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
2026-11-03. The branches below sit on Omarchy `quattro` at `d5b32d24d`.

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

1. **Theme Pi where Pi reads it.** Follow `PI_CODING_AGENT_DIR`, select
   `omarchy-system` when Pi's theme is unset or still its own default
   `system`, never overwrite any other theme the user picked in Pi, and
   treat `settings.json` with care (symlinks, file mode, invalid JSON).
   *Done in branch 1.*
2. **Theme Oh My Pi.** Render a theme with omp's full token set, sync it to
   the profile-aware agent directory on every theme switch, and select it
   through omp's own CLI when omp becomes the default agent. *Done in
   branch 2.*
3. **Launch Pi with any prompt.** Pass the prompt after `--` so "update" or
   "list" starts a session, and keep the local-model options ahead of it.
   *Done in branch 3.*
4. **Count Pi and omp usage under the right provider, with the sign-ins they
   actually keep.** Read omp's keys from `agent.db` in the collectors that use an omp sign-in,
   follow `PI_CODING_AGENT_DIR`, profiles and XDG for omp, reuse Pi's Kimi
   sign-in, and recognise the provider ids Pi and omp use for Z.ai.
   *Done in branch 4.* Pi's ChatGPT sign-in is not part of it: those turns are
   recorded as `openai` / `openai-responses`, the same shape as an OpenAI API
   key, and the Codex collector counts only `openai-codex`.
5. **Ship skills where Pi and omp read them.** Nothing to change:
   `omarchy-provision-user` already links every shipped skill into
   `~/.agents/skills`, which both read regardless of `PI_CODING_AGENT_DIR`,
   and both de-duplicate the extra links. #13836 is not needed. The
   redundant `~/.pi/agent/skills` links can go in the general cleanup of
   #6982 / #16783.
6. **Let a local model open in omp**, as it does in Pi and OpenCode. *Not in
   these branches.*
7. **Warn when a standalone omp shadows the mise one** (#14464). *Not in
   these branches.*

## Branches

All on `Arash-Afshar/omarchy`, stacked in this order on `quattro` at `d5b32d24d`. The theme branch adds two commits; each later code branch adds one commit to its predecessor. Commits are authored by Arash Afshar without a co-author trailer. The documentation branch is separate and sits on the same `quattro` base.

### 1. `pi/1-theme-set-pi-fixes`

- [d245c9362](https://github.com/Arash-Afshar/omarchy/commit/d245c93621ca46ebc42620f3010b37f547b9d267): Sync the Pi theme where `PI_CODING_AGENT_DIR` puts Pi, and keep the user's pick. Includes `test/shell.d/theme-set-pi-test.sh` and the `test/cli` environment guard so the suite cannot write a developer's real Pi tree. Fixes #13691 (theme half); supersedes #13693, #13718, the Pi half of #13713 and of #13983.
- [419acda25](https://github.com/Arash-Afshar/omarchy/commit/419acda257ab45f4892f5fd139c60e05c9e4739d): Treat Pi's `system` theme as its unset default, so activation selects `omarchy-system`. Pi 1.5 writes `system` when no theme has been picked. Any other name, including `dark` and `light`, is left alone. Activation is `omarchy-theme-set-pi --activate`, which `install/user/theme.sh` runs during user finalization. A theme switch only refreshes the theme file, and there is no migration, so an existing Pi whose theme is `system` stays on `system`.

### 2. `pi/2-oh-my-pi-theme`

- [cf7b4367d](https://github.com/Arash-Afshar/omarchy/commit/cf7b4367df1a4f9d45ef353cba56b295ce9319d6): Follow the Omarchy theme in Oh My Pi. Includes `default/themed/omp.json.tpl`, `bin/omarchy-theme-set-omp`, the theme-switch hook, default-agent activation, a migration for existing users, the theme test, the theme-staging allowlist entry and the manual note. The template was checked against `@oh-my-pi/pi-tui` 18.16.0's `theme-schema.json`: all 66 required tokens are present and every reference resolves. Ports #8333 (lepht), adding profile-aware paths.

### 3. `pi/3-launch`

- [1e3626ef6](https://github.com/Arash-Afshar/omarchy/commit/1e3626ef6c12b4adcef9648587a7efd11d58451b): Pass Pi's starting prompt after `--`, keeping local-model options first. Includes normal, one-word and local-model prompt coverage. Pi half of #16724.

### 4. `pi/4-usage-collector`

- [afb68b7fc](https://github.com/Arash-Afshar/omarchy/commit/afb68b7fc557c40f198383069fabd169c6835644): Complete Pi and Oh My Pi usage integration. This single commit combines the six former usage commits without changing their final code tree:
  - Find omp's Antigravity sign-in where `PI_CODING_AGENT_DIR` puts it (#16507).
  - Recognise the Z.ai provider ids and key variables used by Pi, omp and opencode (#16300).
  - Reuse Pi's Kimi sign-in through `pi auth check`, retaining credential precedence and timeout/security guards (#16431, Pillumz).
  - Pin #8270: a Pi session on an OpenRouter key counts under OpenRouter.
  - Read omp's sign-ins from `agent.db`, following profiles and migrated XDG data, with a legacy `auth.json` fallback. The shared helpers serve the DeepSeek, MiniMax, Ollama, OpenCode, OpenRouter, Synthetic, Z.ai and Antigravity collectors; the new store test covers path resolution and credential selection. Generalises #16508.
  - Document that Pi's ChatGPT sign-in on `openai` is not counted yet.

The original four usage ports were verified against pi 1.5.0 and omp 18.16.0: `pi auth check` and its flags exist, `kimi-coding` is Pi's provider id, and omp moves `agent.db` with `PI_CODING_AGENT_DIR`. The shared-store lookup also fixes the earlier Z.ai port's reliance on omp's legacy `auth.json` and default tree. This history cleanup preserves every code branch's final tree exactly.

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
| #16508, #16085 Ollama key from omp's `agent.db` | Generalised to the collectors that read an omp sign-in, in branch 4 |
| #8270 Pi on OpenRouter | Already fixed by #14040; pinned by a test in branch 4 |
| #14550 `PI_CODING_AGENT_DIR`/`_SESSION_DIR` session roots | Already in `quattro` (`pi_session_roots()`); close |
| #7194, #8345 `~/.config/pi/sessions` | Pi never uses that path by default; close |
| #13836 link skills under `PI_CODING_AGENT_DIR` | Not needed: Pi reads `~/.agents/skills` from home |
| #6982, #16775, #16783 skill links | General cleanup; Pi and omp already covered |
| #17397, #17444, #8950 Pi `openai`/ChatGPT | Not in these branches. Pi records a ChatGPT sign-in as `openai` / `openai-responses`, and the Codex collector counts only `openai-codex` |
| #10330 dedicated Pi tab, #13845 omp tab | Conflict with the panel's count-under-the-billing-provider design that #14040 settled; recommend closing |
| #14464 omp ownership drift | Not in these branches |
| #15906, #12411 scan cost | Not in these branches |

# First-class support for Pi and Oh My Pi

Four branches on `Arash-Afshar/omarchy`, stacked on `quattro` at `d5b32d24d`. They make Pi (`pi`, earendil-works/pi) and Oh My Pi (`omp`, can1357/oh-my-pi) follow the theme, launch, and usage paths Omarchy already uses for its other coding agents. Both are installed through mise. The theme branch adds two commits; each later branch adds one commit to its predecessor. Commits are authored by Arash Afshar without a co-author trailer. This documentation branch is separate and sits on the same `quattro` base.

Verified against **pi 1.5.0** (`@earendil-works/pi-coding-agent`) and **omp 18.16.0** (`@oh-my-pi/*`), read from their published packages on 2026-11-03.

## What these branches rely on

| | Pi 1.5.0 | Oh My Pi 18.16.0 |
| --- | --- | --- |
| Agent directory | `~/.pi/agent`, or `PI_CODING_AGENT_DIR` (leading `~` expanded) | `~/.omp/agent`, or `PI_CODING_AGENT_DIR` (the same variable), or `~/.omp/profiles/<name>/agent` when `OMP_PROFILE` (else `PI_PROFILE`) names a profile, which then ignores `PI_CODING_AGENT_DIR` |
| Sessions | `<agent dir>/sessions`, or `PI_CODING_AGENT_SESSION_DIR`, or `sessionDir` in `settings.json` | `<agent dir>/sessions` (or XDG state after `omp config init-xdg`) |
| Sign-ins | `<agent dir>/auth.json`; `pi auth check --provider <id> --json --credentials` resolves and refreshes one | `agent.db` (SQLite, table `auth_credentials`, `credential_type` `api_key` or `oauth`, data `{"key": ...}` for keys). With the default agent tree, omp moves it to `$XDG_DATA_HOME/omp` once that directory exists. `auth.json` is legacy |
| Settings | `<agent dir>/settings.json`, plain JSON | `config.yml`, owned, migrated and quarantined by omp; write it with `omp config set` |
| Custom themes | `<agent dir>/themes/<name>.json`, `settings.json` `theme`. Pi 1.5 writes `system` when no theme has been picked | `<agent dir>/themes/<name>.json` (never XDG), `theme.dark` and `theme.light` in `config.yml`; the schema requires 66 tokens and rejects unknown keys; hot-reloaded |
| Starting prompt | Positional. A leading `install`, `remove`, `update`, `list`, `config`, or `auth` is a subcommand. `--` ends options (since 0.84.3) | Positional after `--` |

## Branches

### 1. `pi/1-theme-set-pi-fixes`

`omarchy-theme-set-pi` follows `PI_CODING_AGENT_DIR`, expanding a leading `~`. `--activate` writes `omarchy-system` only when the theme is missing or still `system`. Any other name is left alone. The settings write follows a symlink, keeps the file's mode, and leaves invalid JSON untouched.

Activation is `omarchy-theme-set-pi --activate`, which `install/user/theme.sh` runs during user finalization. A theme switch only refreshes the theme file, and there is no migration, so an existing Pi whose theme is `system` stays on `system`.

- [d245c9362](https://github.com/Arash-Afshar/omarchy/commit/d245c93621ca46ebc42620f3010b37f547b9d267): Sync the Pi theme where `PI_CODING_AGENT_DIR` puts Pi, and keep the user's pick. Includes `test/shell.d/theme-set-pi-test.sh` and the `test/cli` environment guard so the suite cannot write a developer's real Pi tree.
- [419acda25](https://github.com/Arash-Afshar/omarchy/commit/419acda257ab45f4892f5fd139c60e05c9e4739d): Treat Pi's `system` theme as its unset default, so activation selects `omarchy-system`.

### 2. `pi/2-oh-my-pi-theme`

`default/themed/omp.json.tpl` is an Oh My Pi theme named `omarchy-system`, with the token set omp's schema requires. `omarchy-theme-set-omp` copies it into the agent tree omp reads: a named profile under `~/.omp/profiles/<name>/agent` when `OMP_PROFILE` is set (otherwise `PI_PROFILE`), and that profile ignores `PI_CODING_AGENT_DIR`. Otherwise the tree follows `PI_CODING_AGENT_DIR`, then `~/.omp/agent`. A theme switch only replaces the file, which omp hot-reloads. `--activate` sets `theme.dark` and `theme.light` through `omp config set`, because omp owns `config.yml`.

`omarchy-theme-set` runs the setter on every theme switch. `omarchy-default-agent` activates the theme when omp becomes the default agent. `migrations/1793721769.sh` renders `omp.json` for a machine that has not switched themes since the template existed, and activates the theme when omp is already the default agent.

- [cf7b4367d](https://github.com/Arash-Afshar/omarchy/commit/cf7b4367df1a4f9d45ef353cba56b295ce9319d6): Follow the Omarchy theme in Oh My Pi. Includes the template, the setter, the theme-switch hook, default-agent activation, the migration, `test/shell.d/theme-set-omp-test.sh`, the theme-staging allowlist entry, and the note in `manual/17-ai.md`. The template was checked against `@oh-my-pi/pi-tui` 18.16.0's `theme-schema.json`: every required token is present and every reference resolves.

### 3. `pi/3-launch`

`omarchy-agent` passes Pi's starting prompt after `--`, so a one-word prompt such as `update` starts a session instead of running Pi's own command. Local-model options (`--extension`, `--provider`, `--model`) stay ahead of that `--`.

- [1e3626ef6](https://github.com/Arash-Afshar/omarchy/commit/1e3626ef6c12b4adcef9648587a7efd11d58451b): Pass Pi's starting prompt after `--`, keeping local-model options first. Covered in `test/shell.d/default-agent-test.sh`.

### 4. `pi/4-usage-collector`

Pi and omp sessions are counted by the provider that bills them. There is no separate Pi or omp collector. The collectors that read an omp sign-in look it up in `agent.db` (a profile, `PI_CODING_AGENT_DIR`, or the XDG move), and fall back to the legacy `auth.json`. A `$VAR` or `!command` entry is skipped.

- Antigravity reads omp's sign-in from that database, including a tree moved by `PI_CODING_AGENT_DIR`.
- Z.ai recognizes the China coding-plan key: `ZHIPU_API_KEY`, `ZHIPUAI_API_KEY`, and `ZAI_CODING_CN_API_KEY`, Pi's `zai-coding-cn` entry, and omp's `zhipu` and `zhipu-coding-plan` entries. Those ask the China host.
- Kimi uses Pi's `kimi-coding` sign-in, through `pi auth check`, when no `KIMI_API_KEY` and no Kimi CLI token exist. The lookup checks `auth.json` before starting Pi, times out after 15 seconds, and does not run when `KIMI_CODE_HOME` is set.
- A Pi session on an OpenRouter key counts under OpenRouter.
- A Pi turn on `openai` is not counted under Codex. Pi records a ChatGPT sign-in with the same provider and API as an OpenAI API key, and the Codex collector counts only `openai-codex`.

- [afb68b7fc](https://github.com/Arash-Afshar/omarchy/commit/afb68b7fc557c40f198383069fabd169c6835644): Complete Pi and Oh My Pi usage integration. The shared helpers are in `shell/plugins/agents/collectors.py`. `test/shell.d/agent-usage-omp-store-test.sh` covers path resolution and credential selection, and the provider suites cover Antigravity, Z.ai, Kimi, and OpenRouter.

`pi auth check` and its flags exist in pi 1.5.0, `kimi-coding` is Pi's provider id, and omp 18.16.0 moves `agent.db` with `PI_CODING_AGENT_DIR`.

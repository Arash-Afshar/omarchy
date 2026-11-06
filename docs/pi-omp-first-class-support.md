# First-class support for Pi and Oh My Pi

Pi and Oh My Pi should behave like the other coding agents. The Omarchy theme follows into the directory each one actually reads, a starting prompt opens a session, and usage is counted once under the provider that bills the turn.

Verified against pi 1.5.0 and omp 18.16.0. Pi reads `PI_CODING_AGENT_DIR` (a leading `~` expanded), stores its theme in `settings.json`, and writes `system` when no theme has been picked. A leading `install`, `remove`, `update`, `list`, `config`, or `auth` is a Pi command unless it comes after `--`. omp reads the same variable, or `~/.omp/profiles/<name>/agent` when `OMP_PROFILE` (else `PI_PROFILE`) is set, and that profile ignores `PI_CODING_AGENT_DIR`. Its theme slots are `theme.dark` and `theme.light`, written with `omp config set`. Its sign-ins are in `agent.db`, with `auth.json` left over from older versions.

## Open pull requests

These are open against `quattro` and do not finish the goal.

**Pi theme.** [#13693](https://github.com/omacom/omarchy/pull/13693) follows `PI_CODING_AGENT_DIR` and expands `~`, and `--activate` still overwrites whatever theme is set. [#13718](https://github.com/omacom/omarchy/pull/13718) keeps any theme other than `omarchy-system`, which also keeps Pi's own default `system`, so a fresh Pi never switches to `omarchy-system`. [#13713](https://github.com/omacom/omarchy/pull/13713) only removes a temp file on failure. [#13983](https://github.com/omacom/omarchy/pull/13983) keeps the settings file's mode and a symlink. None of them does all of that together.

**Oh My Pi theme.** [#8333](https://github.com/omacom/omarchy/pull/8333) adds the theme template and setter. It conflicts with current `quattro`, and the setter does not follow omp's profile directory.

**Launch.** [#16724](https://github.com/omacom/omarchy/pull/16724) already passes Pi's prompt after `--` and keeps the local-model options ahead of it. Merge that pull request. It also hands Kimi's prompt over on the clipboard.

**Usage.** [#16507](https://github.com/omacom/omarchy/pull/16507), [#16508](https://github.com/omacom/omarchy/pull/16508), [#16300](https://github.com/omacom/omarchy/pull/16300), and [#16431](https://github.com/omacom/omarchy/pull/16431) each fix one collector: Antigravity's moved omp sign-in, Ollama's key in `agent.db`, Z.ai's provider ids, and Kimi via Pi's `kimi-coding` login. The other collectors that read an omp sign-in still look only at `~/.omp/agent/auth.json`. [#10330](https://github.com/omacom/omarchy/pull/10330) and [#13845](https://github.com/omacom/omarchy/pull/13845) add a Pi tab and an omp tab. Those turns are already counted by the provider that bills them, so a second tab counts them twice.

## Branches

On `Arash-Afshar/omarchy`, stacked on `quattro` at `d5b32d24d`. The launch change is [#16724](https://github.com/omacom/omarchy/pull/16724), so it is not repeated here.

### `pi/1-theme-set-pi-fixes`

`omarchy-theme-set-pi` follows `PI_CODING_AGENT_DIR` and expands a leading `~`. `--activate` sets `omarchy-system` when the theme is missing or still `system`, and leaves any other name alone. The write follows a symlink, keeps the file mode, and leaves invalid JSON unchanged.

`--activate` runs from `install/user/theme.sh` during user setup. A theme switch does not change the setting, and there is no migration, so an existing Pi left on `system` stays there.

This replaces [#13693](https://github.com/omacom/omarchy/pull/13693), [#13718](https://github.com/omacom/omarchy/pull/13718), [#13713](https://github.com/omacom/omarchy/pull/13713), and the Pi half of [#13983](https://github.com/omacom/omarchy/pull/13983).

### `pi/2-oh-my-pi-theme`

`default/themed/omp.json.tpl` is the `omarchy-system` theme, with the tokens omp's schema requires. `omarchy-theme-set-omp` copies it into the profile directory when a profile is set, and otherwise into `PI_CODING_AGENT_DIR` or `~/.omp/agent`. A theme switch only replaces the file. `--activate` sets both theme slots through `omp config set`. `omarchy-default-agent` does that when omp becomes the default agent. `migrations/1793721769.sh` renders the file for a current theme that never got it, and activates it when omp is already the default agent.

This replaces [#8333](https://github.com/omacom/omarchy/pull/8333).

### `pi/4-usage-collector`

Sessions stay under the provider that bills them. The collectors that read an omp sign-in use one lookup: `agent.db` for a profile, a moved tree, or the XDG location, then the old `auth.json`. A `$VAR` or `!command` value is skipped. Z.ai's China coding-plan key is recognized and sent to the China host. Kimi uses Pi's `kimi-coding` sign-in when the Kimi CLI has no token and `KIMI_CODE_HOME` is unset. A Pi session on an OpenRouter key counts under OpenRouter.

A Pi ChatGPT sign-in is still not counted. Pi records it as `openai` / `openai-responses`, the same shape as an API key, and the Codex collector accepts only `openai-codex`. [#17397](https://github.com/omacom/omarchy/pull/17397) counts every Pi `openai` turn as Codex, including API-key usage.

This replaces [#16507](https://github.com/omacom/omarchy/pull/16507), [#16508](https://github.com/omacom/omarchy/pull/16508), [#16300](https://github.com/omacom/omarchy/pull/16300), and [#16431](https://github.com/omacom/omarchy/pull/16431).

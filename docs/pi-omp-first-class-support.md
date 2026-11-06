# First-class support for Pi and Oh My Pi

Pi and Oh My Pi should behave like the other coding agents. The Omarchy theme follows into the directory each one reads, a starting prompt opens a session, and usage is counted once under the provider that bills the turn.

omarchybot has already verified the pull requests that do most of this. Those should be merged. New pull requests are only for the gaps that review left open.

## Merge, already reviewed

- [#16724](https://github.com/omacom/omarchy/pull/16724) passes Pi's prompt after `--` and puts local-model options ahead of that `--`. The bot reproduced it against pi 1.4.0 and pushed the local-model fix. Do not open another launch pull request.
- [#13693](https://github.com/omacom/omarchy/pull/13693) points `omarchy-theme-set-pi` at `PI_CODING_AGENT_DIR` and expands `~` the way Pi does. Re-checked on 1 November.
- [#13718](https://github.com/omacom/omarchy/pull/13718) keeps a theme the user already chose. `--activate` is the only write, and it runs on re-provision.
- [#13983](https://github.com/omacom/omarchy/pull/13983) keeps a symlinked settings file and its mode, for Pi and Claude. The bot's order is this settings write, plus the theme-file cleanup from [#13713](https://github.com/omacom/omarchy/pull/13713).
- [#16507](https://github.com/omacom/omarchy/pull/16507) reads omp's Antigravity sign-in from the tree `PI_CODING_AGENT_DIR` names. The bot checked omp: it does not expand `~`, so the value is used as written.
- [#16508](https://github.com/omacom/omarchy/pull/16508) reads Ollama's key from `agent.db` in that tree.
- [#16300](https://github.com/omacom/omarchy/pull/16300) finds Z.ai's China coding-plan key. Re-checked on 1 November.
- [#16431](https://github.com/omacom/omarchy/pull/16431) uses Pi's `kimi-coding` sign-in, checks `auth.json` before starting Pi, times out after 15 seconds, and skips the lookup when `KIMI_CODE_HOME` is set. The bot has not reviewed this one. The change is the same one the usage work needs, so it should be merged rather than rewritten.

[#10330](https://github.com/omacom/omarchy/pull/10330) and [#13845](https://github.com/omacom/omarchy/pull/13845) add a Pi tab and an omp tab. Leave them. Those turns already belong to the provider that bills them.

## Still worth opening

Two pull requests. Neither repeats a change the bot has accepted.

**Pi's `system` theme, after [#13718](https://github.com/omacom/omarchy/pull/13718).** That pull request keeps every theme name except `omarchy-system`, including `system`. Pi 1.5 writes `system` when no theme has been picked, so a fresh install stays there. The follow-up is that one name: `--activate` treats `system` like an empty theme and writes `omarchy-system`. Any other name stays. This does not move an existing Pi. Setup has already run `--activate`, and no migration does it again.

**omp sign-ins the reviewed pull requests do not read.** On [#16508](https://github.com/omacom/omarchy/pull/16508) the bot wrote that DeepSeek, MiniMax, OpenCode, OpenRouter, Synthetic, and Z.ai still read only `~/.omp/agent/auth.json`, and a named profile's `agent.db` is never read. One lookup for those six collectors: the profile directory when `OMP_PROFILE` or `PI_PROFILE` is set, otherwise `PI_CODING_AGENT_DIR` as omp stored it, otherwise `~/.omp/agent`. Read `agent.db` there. Leave the old `auth.json` fallback at `~/.omp/agent`, which is what [#16508](https://github.com/omacom/omarchy/pull/16508) does. Do not expand `~`. Do not edit the Antigravity, Ollama, or Kimi collectors.

[#8333](https://github.com/omacom/omarchy/pull/8333) already adds Oh My Pi's theme template, setter, theme-switch hook, default-agent activation, and migration. The bot has not reviewed it, and it conflicts with current `quattro`. It also skips `~/.omp/profiles/<name>/agent`. Rebase that pull request and add the profile path. Do not open a second theme pull request, and do not expand `~` in omp's path.

A Pi ChatGPT sign-in stays uncounted. Pi records it as `openai` / `openai-responses`, and the Codex collector accepts only `openai-codex`. [#17397](https://github.com/omacom/omarchy/pull/17397) counts every Pi `openai` turn as Codex, including API-key usage.

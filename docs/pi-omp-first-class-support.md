# First-class support for Pi and Oh My Pi

The Omarchy theme follows into the directory Pi and Oh My Pi read, a starting prompt opens a session, and each turn is counted once under the provider that bills it.

## Merge

Land the reviewed pull requests. Later ones in a group touch the same files, so take them in this order.

1. [#16724](https://github.com/omacom/omarchy/pull/16724). Pi's prompt goes after `--`, and local-model options stay ahead of it.
2. [#13693](https://github.com/omacom/omarchy/pull/13693), then [#13718](https://github.com/omacom/omarchy/pull/13718). The theme file follows `PI_CODING_AGENT_DIR`, `~` expands the way Pi expands it, and `--activate` keeps a theme the user chose.
3. [#13983](https://github.com/omacom/omarchy/pull/13983), and keep the failed theme-file cleanup from [#13713](https://github.com/omacom/omarchy/pull/13713).
4. [#16507](https://github.com/omacom/omarchy/pull/16507), [#16508](https://github.com/omacom/omarchy/pull/16508), then [#16300](https://github.com/omacom/omarchy/pull/16300). Antigravity and Ollama read `agent.db` from the directory omp stored, with no `~` expansion. Z.ai keeps its China coding-plan key lookup.
5. [#16431](https://github.com/omacom/omarchy/pull/16431). Kimi uses an existing Pi sign-in. The bot has not reviewed it. This is the change to merge.

Leave [#10330](https://github.com/omacom/omarchy/pull/10330) and [#13845](https://github.com/omacom/omarchy/pull/13845). A Pi or omp tab would count those turns a second time.

## Ours, after that

These are not substitutes for the list above. Each one is the remainder.

- After [#13718](https://github.com/omacom/omarchy/pull/13718), open only `419acda25` from `pi/1-theme-set-pi-fixes`. `--activate` treats Pi's `system` theme as unset and writes `omarchy-system`. Any other name stays. The earlier commit on that branch is [#13693](https://github.com/omacom/omarchy/pull/13693) and [#13718](https://github.com/omacom/omarchy/pull/13718).
- Rebase [#8333](https://github.com/omacom/omarchy/pull/8333) and add the profile directory from `cf7b4367d` on `pi/2-oh-my-pi-theme` (`OMP_PROFILE`, else `PI_PROFILE`, under `~/.omp/profiles/<name>/agent`). Do not open that branch as a second theme pull request, and do not expand `~`.
- After [#16508](https://github.com/omacom/omarchy/pull/16508) and [#16300](https://github.com/omacom/omarchy/pull/16300), open the lookup in `afb68b7fc` on `pi/4-usage-collector` for DeepSeek, MiniMax, OpenCode, OpenRouter, Synthetic, and Z.ai, including a named profile's `agent.db`. Leave the old `auth.json` fallback at `~/.omp/agent`. Leave the Antigravity, Ollama, and Kimi collectors on the reviewed pull requests. Do not open `pi/3-launch` (`1e3626ef6`). That is [#16724](https://github.com/omacom/omarchy/pull/16724).

[#17397](https://github.com/omacom/omarchy/pull/17397) is not the fix for a Pi ChatGPT sign-in. Pi records it as `openai` / `openai-responses`, and that pull request also counts API-key turns as Codex.

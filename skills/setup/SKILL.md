---
name: setup
description: Check that Desmaptic is ready on this Mac - Desmaptic Agent installed and answering, an iPhone or iPad connected - and say in plain words what to do when it is not. Run by the user on demand.
disable-model-invocation: true
---

# Desmaptic setup check

The user wants to know whether Desmaptic works from this assistant: Desmaptic Agent (the Mac app that carries the `desmaptic` MCP server) installed and answering, and their iPhone or iPad connected to it. Check, then report in a few short lines what works and, for what does not, the one thing to do next. This check changes nothing: it delivers no button and edits no file or setting.

## 1. The agent

Call the `ping` tool of the `desmaptic` MCP server.

- **There is no `desmaptic` server or no `ping` tool**, or the server failed to start: Desmaptic Agent is not installed (or not where the plugin looks for it). Tell the user to download it from https://desmaptic.com/agent, move it to Applications, open it once and pair their phone, then restart the assistant — in Claude Code run `/reload-plugins` or start a new session and check `/mcp`; in Codex start a new session and check `codex mcp list`. Stop here: nothing below works without the agent.
- **`ping` answers with an error that it cannot reach the agent**: pass on the step the error itself names — open Desmaptic Agent (it lives in the menu bar; the most common case: it is not running), update it, restart it, or the folder to delete — then call `ping` once more. The same error again: say so and stop; do not loop.
- **`ping` answers `pong`**: the agent works. Pass on, in plain words, any extra sentence it adds — another build than the running agent, an agent that should be updated, a phone app that should be updated — with the step it names.

## 2. The phone

Read the rest of the `pong` line.

- **"no phone connected"**: tell the user to open the Desmaptic app on their iPhone or iPad, on the same Wi-Fi network as this Mac. A phone that was never paired: in the app pick this Mac, then press Show Code in Desmaptic Agent (its window, Devices) and type the code on the phone. No app yet: Desmaptic Agent's window, Devices, shows where to get it. Call `ping` again once they say it is open.
- **"phone connected"**: call `get_page_layout` with no arguments and say which page is on the screen and how many free places it has — proof that the assistant sees the deck. Mention a warning `ping` gave about the phone app.

## 3. Duplicates and hooks

- If you see the Desmaptic tools twice — the agent's own `desmaptic` entry and this plugin's — say that one is enough: in Desmaptic Agent, AI Assistants, press **Remove Duplicate** on this assistant's card. With an older agent that has no such button, follow the plugin's README, "Already connected from Desmaptic Agent?". Both entries work; the duplicate only costs context.
- **In Codex only**, check the plugin's hooks — they keep the AI Sessions page's cards current, and Codex runs a plugin's hooks only after the user approves them in `/hooks`, and again after a plugin update changes them. Run this skill's checker — it is in the same folder as this file; it reads Codex's settings and changes nothing:

  ```
  /bin/zsh -f "<this skill's folder>/codex-hooks.zsh"
  ```

  It prints one word; add one line to the report:
  - `approved` — the hooks are approved: nothing to do.
  - `review` — the Desmaptic hooks are new or changed and wait for approval: type `/hooks` in Codex, open the Desmaptic hooks and approve them, then start a new session.
  - `disabled` — some Desmaptic hooks are turned off in `/hooks`: turn them on there if the user wants the AI Sessions page.
  - `off` — all hooks are off in Codex's settings (the `hooks` feature, or its old name `codex_hooks`, set to `false` in `~/.codex/config.toml` or in the profile it selects): the AI Sessions page shows no Codex session until they turn hooks back on.
  - `unknown` or no answer: say only that Codex runs the hooks after they are approved in `/hooks`.

  Codex in the ChatGPT app for Mac shares these settings with Codex in the terminal. Claude Code needs no such step.

## 4. The report

A short checklist, for example:

- Desmaptic Agent — works (v1.4), or what to do;
- iPhone or iPad — connected, the page on the screen, or what to do;
- anything else the checks above found.

End with what to try next when everything works: `/desmaptic:page` (in Codex `$desmaptic:page`) to build a page for an app or a task, `/desmaptic:widget` (in Codex `$desmaptic:widget`) for one live widget; `/desmaptic:sessions-page` (in Codex `$desmaptic:sessions-page`) for a page that shows what each Claude Code and Codex session is doing.

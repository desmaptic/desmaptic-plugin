---
name: sessions-page
description: Put the "AI Sessions" page on the user's Desmaptic deck — one card per Claude Code or Codex session showing its project and tool and whether it is working, waiting for permission, waiting for input, done, failed or closed; a tap on a waiting session's card asks what to reply and types the answer into that session. Run only when the user asks for it.
disable-model-invocation: true
---

# The AI Sessions page

The Desmaptic plugin's hooks keep a small state file for every Claude Code and Codex session on this Mac (Codex in the terminal and in the ChatGPT app): the tool, the state, the project folder's name, the app it runs in and the time — never prompts, commands or code. This page shows those files on the phone: eight 2×2 cards, the eight sessions that changed last. A card shows the project, the tool (Claude Code or Codex), the state in its colour (blue working, orange waiting for permission, purple waiting for input, green done, red error, grey closed) and how long it has been in that state. A closed session's card clears after five minutes. The words follow the Mac's language.

A tap on a card asks "What to reply?" — with the quick replies "Continue", "Run the tests" and "Open a PR", own text or dictation — and types the answer, then Enter, into the session that card shows. Only while that session waits for input (or is done or failed) and still runs where it started: in tmux, iTerm2 or Terminal; Codex 0.157 and newer is also answered elsewhere, through `codex queue`. Otherwise nothing is typed and the card says why: the session is working; it asks for permission (that is answered at the Mac only — its app comes forward); the card took it over from another session in the last five minutes (the answer may have been meant for that one); or its terminal (Ghostty, VS Code, Cursor, the Claude app, another terminal) cannot be answered from the phone. The answer is typed as plain text, one line, and is kept nowhere. Before typing into iTerm2 or Terminal, macOS asks once whether Desmaptic Agent may control that app. A long press on a card brings forward the app the session runs in.

Nothing is written until the page (or the Gallery's Long Jobs widget) is installed: the hooks only write once its folder exists. Codex reports no wait for input and no failure, so its cards never show those two states; a stopped Codex turn shows as done. In Codex the hooks run only once the user approves them in `/hooks` (and again after a plugin update changes them): `$desmaptic:setup` says whether they are approved.

## Install

1. Build the page. Run this skill's generator — it is in the same folder as this file:

   ```
   /bin/zsh -f "<this skill's folder>/page-json.zsh"
   ```

   It prints the `pages` argument for `add_pages_to_client`: one page, "AI Sessions", with the eight cards; the top-left card's startup script draws them all. To name the page differently, give the name as the generator's argument. Do not edit the output: the startup script is this folder's `sessions-page.zsh` as it is, and the cards point at each other through their `ref`s.

2. Tell the user in plain words what will be added, then call `add_pages_to_client` with that `pages` value unchanged and the same words as `description`. For example: "A new page, AI Sessions, with eight cards. The top-left card runs a script once a second that reads the session state files the Desmaptic plugin's hooks write and draws a card per session. A tap on a card asks what to reply and types the answer into the session that card shows, only while it waits for input; a long press brings forward the app that session runs in."

   The page goes into the active profile unless the user names another (`profileName`). On the free plan only pages one and two of a profile open: if the profile already has two, say the new page stays locked without Pro, or offer a profile with room.

3. The user taps Accept on the phone, unless they let such changes in without asking. If the call comes back pending, the review is still open: call `get_delivery_status` later, never resend.

4. Once accepted, a session that does something shows up within a second. If the cards stay on "No session" after the user sends a prompt, check `get_startup_script_status` for the top-left card, and that the plugin is enabled in that session (its hooks load with the plugin; sessions started before the install pick them up after a restart). In Codex, also that the hooks are approved in `/hooks`.

## The "waiting for permission" notification

Claude Code only; off by default. With the plugin's option **notify_permission** on (`/plugin` → Desmaptic → its options), a Claude Code session that starts waiting for permission also sends a notification to the phone: "Waiting for permission in <project>", in the Mac's language. A tap on it opens this page. The phone only shows it — answering the permission still happens at the Mac.

## Try a card without the phone

`/bin/zsh -f "<this skill's folder>/sessions-page.zsh" --card permission claude my-project 300 en` prints one card's SVG; `render_preview` draws it.

# Desmaptic plugin for Claude Code and Codex

[Desmaptic](https://desmaptic.com) turns the iPhone or iPad you already have into a deck of buttons
for your Mac, like a Stream Deck. Its buttons launch apps, press keyboard shortcuts and run Shortcuts
and scripts. Live widgets show things such as CPU load, a timer or what's playing.

This plugin lets Claude Code and Codex work on that deck for you. Describe what you want — "a page
for my video calls", "a button that shows free disk space", "move the music buttons to the second
row" — and the assistant looks at the page on your phone, finds room, builds the buttons and sends
them over. No button changes until you tap **Accept** on the phone, which shows you the change and
the scripts it would run. The exception is changes you let in without asking in the Desmaptic app
(Accept Safe Changes, or a Mac you trust for a while). The assistant cannot press your buttons and
does not delete them: you do that on the phone.

## What's inside

- **The Desmaptic MCP server connection** (`desmaptic`). The server itself is built into
  Desmaptic Agent; the plugin only finds the agent on this Mac and starts it in MCP mode
  (`scripts/desmaptic-mcp`). It runs only an agent whose code signature is valid and made by the
  Desmaptic team.
- **The `desmaptic-widgets` skill**: how to choose between a plain button and a drawn face, write
  live widgets that glide instead of flicker, draw SVG faces and animated scenes across a page.
- **Four commands** you run yourself: `setup`, `page`, `widget` and `sessions-page` (see
  [Commands](#commands)).
- **Hooks for Claude Code and Codex** that note what each session on this Mac is doing, for the
  [AI Sessions page](#ai-sessions-page).

## Requirements

- A Mac with macOS 15 or later, and **Desmaptic Agent** installed and running on it: download it from
  https://desmaptic.com/agent, move it to Applications and open it once.
- The **Desmaptic** app on an iPhone or iPad, paired with the agent.
- Claude Code or Codex on that Mac.

The plugin talks only to the agent on this Mac; the agent reaches your phone over your local network
through an encrypted channel.

## Install

**Claude Code**

```sh
claude plugin install desmaptic --marketplace desmaptic/desmaptic-plugin
```

Or in a session: `/plugin marketplace add desmaptic/desmaptic-plugin`, then
`/plugin install desmaptic@desmaptic`. Run `/reload-plugins` (or start a new session) and check `/mcp`:
the `desmaptic` server is listed as connected.

**Codex**

```sh
codex plugin marketplace add desmaptic/desmaptic-plugin
codex plugin add desmaptic@desmaptic
```

Start a new Codex session; `codex mcp list` shows the `desmaptic` server.

Then ask for something, for example: "Add a button that shows free disk space to my Desmaptic deck".

## Commands

| Claude Code | Codex | What it does |
|---|---|---|
| `/desmaptic:setup` | `$desmaptic:setup` | Checks that Desmaptic Agent is installed and answering and that your phone is connected, and says what to do when something is missing. Changes nothing. |
| `/desmaptic:page <app or task>` | `$desmaptic:page <app or task>` | Builds a page for an app or a task, for example `/desmaptic:page video calls`. |
| `/desmaptic:widget <what it shows>` | `$desmaptic:widget <what it shows>` | Builds one live widget, for example `/desmaptic:widget CPU load as a ring`. |
| `/desmaptic:sessions-page` | `$desmaptic:sessions-page` | Puts the AI Sessions page on your deck: one card per Claude Code or Codex session and what it is doing; tap a waiting one to answer it (see [below](#ai-sessions-page)). |

The assistant runs them only when you call them. `page`, `widget` and `sessions-page` follow the same rules as any
other request: before sending, the assistant tells you in plain words what the buttons will show and do and
what their scripts run on the Mac, then sends the change once, and nothing changes until you tap
**Accept** on the phone, unless you let such changes in without asking.

In Codex, a plugin's hooks run only after you approve them in `/hooks`, and again after an update
changes them: if `/hooks` lists Desmaptic hooks waiting for review, approve them there. `$desmaptic:setup`
says whether they are approved.

## AI Sessions page

Run `/desmaptic:sessions-page` in Claude Code (`$desmaptic:sessions-page` in Codex) and accept the new
page on the phone. It shows up to eight cards, one per session of Claude Code or Codex — in the
terminal or in the ChatGPT app for Mac: the project folder, the tool, whether the session is working,
waiting for your permission, waiting for input, done or failed, and for how long. Codex tells
neither when it waits for input nor when a turn fails, so its cards show only working, waiting for
permission, done and closed; in Codex the cards change only once its hooks are approved in `/hooks`.
A closed session's card clears after five minutes.

**Answer a session from the phone.** Tap a card: the phone asks "What to reply?" — tap "Continue",
"Run the tests" or "Open a PR", or type or dictate your own — and the Mac types it, then Enter, into
that session. Only while it waits for you (or is done or failed) and still runs where it started: in
tmux, iTerm2 or Terminal; Codex 0.157 and newer is answered elsewhere too, through `codex queue`.
Otherwise nothing is typed and the card says why — the session is working; it waits for permission,
which you answer on the Mac (its app comes forward); the card took it over from another session in the
last five minutes, so your answer may have been meant for that one; or it runs where the phone cannot
type (Ghostty, VS Code, Cursor, the Claude app, another terminal). The answer goes in as plain text on
one line and is stored nowhere. Before typing into iTerm2 or Terminal, macOS asks once whether
Desmaptic Agent may control that app. Touch and hold a card to bring forward the app the session runs in.

The plugin's hooks write one small file per session into Desmaptic Agent's storage on this Mac:
the tool, the state, the project folder's name, the app and the time. Beside it, readable by your account
alone, they note where the session runs — its tmux pane, iTerm2 session or terminal, the process id, Codex's
session id — and remove that note when the session closes. Never your prompts, commands or code.
They write nothing until the page (or the Gallery's Long Jobs widget) is installed, send nothing over the network and never slow a
session down: without the agent they just exit.

**Notification when a session waits for permission.** Claude Code only; off by default. Turn on the
plugin's `notify_permission` option (`/plugin` → Desmaptic) and the phone gets "Waiting for permission in
my-project" (in your Mac's language) when a session or one of its subagents starts waiting for you;
tapping it opens the page. You still answer the
permission on the Mac.

## Updates

**Claude Code** does not update plugins from this marketplace on its own: auto-update is off by default
for marketplaces other than Anthropic's. To turn it on, run `/plugin`, open the **Marketplaces** tab,
pick `desmaptic` and choose **Enable auto-update**. Claude Code then checks for a new version in the
background and asks you to run `/reload-plugins`. Without it, update by hand:

```sh
claude plugin marketplace update desmaptic
claude plugin update desmaptic@desmaptic
```

**Codex**: `codex plugin marketplace upgrade desmaptic` fetches the latest marketplace, then
`codex plugin add desmaptic@desmaptic` installs the plugin's new version.

The plugin's version is the version of Desmaptic Agent it comes with.

## Already connected from Desmaptic Agent?

Desmaptic Agent can connect Claude Code and Codex itself (AI Assistants → Connect) and install the
same skill. Use one or the other: with both, the assistant sees every Desmaptic tool and the skill
twice. Recent versions of the agent notice the plugin: the card says "Connected by plugin", the
agent adds no entry or skill of its own, and **Remove Duplicate** on the card takes out what it added
before. With an older agent, remove its entry yourself — `claude mcp remove desmaptic -s user` for
Claude Code, the `[mcp_servers.desmaptic]` table in `~/.codex/config.toml` for Codex — and the skill
folder `~/.claude/skills/desmaptic-widgets` or `~/.codex/skills/desmaptic-widgets`.

## Troubleshooting

- **"Desmaptic Agent is not installed on this Mac"** — the plugin found no agent signed by the
  Desmaptic team. Install it from https://desmaptic.com/agent into Applications, open it once, then
  restart Claude Code or Codex.
- **The tools answer that they cannot reach the agent** — open Desmaptic Agent (it lives in the
  menu bar).
- **A change never appears on the phone** — open the Desmaptic app: a change waits there for
  Accept, unless you let such changes in without asking.

## License

Everything here except the widget skill is under MIT — see [LICENSE](LICENSE). The skill in
`skills/desmaptic-widgets` has its own license, [PolyForm Shield 1.0.0](skills/desmaptic-widgets/LICENSE):
you may use and change it, but not in a product that competes with Desmaptic. Neither license grants
any rights to the Desmaptic name or logo.

The plugin carries only the connection, the skills, the hooks and their scripts; Desmaptic Agent
and the Desmaptic app are separate products with their own terms (https://desmaptic.com/terms) and privacy policy (https://desmaptic.com/privacy).

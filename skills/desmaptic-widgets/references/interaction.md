# Buttons that work together

A Desmaptic script is not tied to its own button: **any script may update any button** by putting that button's UUID in `cellId`. That is what turns a row of buttons into one instrument — a timer with its Start and Reset keys, a player with a display, a deploy key that lights up a status tile, a dashboard refreshed by one loop.

## Three ways to connect buttons

| Pattern | How | Use when |
|---|---|---|
| **One controller loop** | a single `startupScript` draws every button of the group; taps only change state | the buttons show one shared state (timer + controls, player + display, a dashboard). The default. |
| **Shared state, own loops** | every button has a small loop that draws *itself* from the same state file, using `{{CELL_ID}}` | 2–4 buttons, when you want to deliver in one step (no UUIDs needed — see below) |
| **Direct poke** | a tap script posts straight to another button's UUID | a one-off effect: "deploy started" on a status tile, a counter elsewhere |

Whatever you pick, keep **one writer per button**. Two scripts painting the same button overwrite each other's frames and the button flickers between two truths. If a tap must show something instantly, let it change the state and let the owner draw it — do not paint from both.

## Making it feel instant

The user taps Start and expects the ring to move *now*, not at the next 2-second tick.
- The tap script writes the new state and exits — it should take milliseconds. (A tap script is killed after 60 s; it is for actions, never for loops.)
- The controller loop must notice quickly: instead of `sleep 2`, sleep in short steps and watch the state file's modification time — in zsh `zmodload -F zsh/stat b:zstat` once, then `zstat +mtime -- "$state"`, a builtin that starts no process. React within ~0.2 s, but still **post only when what is drawn changes** (state changed, or the displayed second/percent moved).
- The app shows the press itself (and a pulse while the command runs), and flashes the button red with a shake when the command fails; success adds nothing. So you do not draw "pressed" — draw the new state, quickly.

## State that survives

- Keep it in `$DESMAPTIC_STORAGE/<widget>/state` (create the folder lazily). Not `/tmp`: it is wiped on reboot and writable by every program on the Mac.
- Write atomically — to `state.tmp`, then `mv` — so the loop never reads half a file.
- Store **timestamps, not counters**: `ends_at`, `paused_remaining`. A loop that decrements a number dies with every reconnect (startup scripts restart when the phone reconnects); one that computes `ends_at − now` just carries on.
- Parse the file explicitly (`read` into variables, `jq`). Never `source` it: the storage folder is writable by anything running as the user.

## Getting the other buttons' UUIDs

A controller needs the UUIDs of the buttons it draws, and new buttons get theirs at creation. Name them instead: give each new button of the call a `ref` (`"ref": "reset"`), and write `{{CELL_ID:reset}}` wherever a script needs that button's UUID. `add_buttons_to_client` (and `add_pages_to_client`, `create_full_profile`) puts the real UUIDs in before sending, so the controller and its buttons go in **one call and one review**, and the result lists every button's `buttonId` with its `ref`. A button's own UUID stays `{{CELL_ID}}`.

The *shared state, own loops* pattern needs no refs at all: each button's script only ever uses `{{CELL_ID}}`. Tap scripts never need a UUID when they only write state.

For buttons that already exist, read their UUIDs from `get_page_layout` (or `get_profile_detail`, when you also need their scripts).

## Details that bite

- An overlay painted by a **tap** script stays after the script exits normally, and is cleared if the script is *terminated*. An overlay painted by the controller stays as long as the controller runs.
- Give every button of the group a saved face (`svgFace`) or a sensible plain icon for the idle state — that is what shows before the controller's first frame and when the phone is not connected.
- A control that toggles (Start ↔ Pause) is one button whose face the controller changes — not two buttons.
- Long press (`longPressCommandType` …) is a free second action on the same cell: Reset on the timer itself saves a button.
- Startup scripts run only for the **active profile**. Buttons of a group should live in the same profile, normally on the same page.

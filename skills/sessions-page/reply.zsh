#!/bin/zsh -f
# Desmaptic "AI Sessions" page: a card's tap (page-json.zsh puts this file into every card; the agent fills in the
# card's id). The card asks "What to reply?"; this types the answer ($DESMAPTIC_INPUT) and Enter into the session the
# card shows — only while that session waits for input and still runs in the terminal its address names (the hook's
# AISessions/<id>.addr): tmux, iTerm2 or Terminal; Codex 0.157+ outside them through `codex queue`.
# Otherwise it says why on the phone and types nothing. A session waiting for permission is never answered from here:
# its app comes forward instead. Without a text (a phone that does not ask, or a card waiting for permission: the
# page turns its question off) the tap brings the session's app forward.
# The text is data: never in a log, a file or the session's record, and never on a command line but codex queue's.
export LANG=en_US.UTF-8                   # ${#text} counts letters, not bytes
setopt extended_glob
zmodload zsh/datetime zsh/zselect
autoload -Uz is-at-least
api="http://127.0.0.1:9848/api"
curl=/usr/bin/curl
open=/usr/bin/open
osascript=/usr/bin/osascript
tmuxPaths=(/opt/homebrew/bin/tmux /usr/local/bin/tmux /opt/local/bin/tmux)
codexPaths=(/opt/homebrew/bin/codex /usr/local/bin/codex "$HOME/.local/bin/codex")
dir="${DESMAPTIC_STORAGE:-$HOME/Library/Application Support/Desmaptic/ScriptStorage}/AISessions"
cell="{{CELL_ID}}"
# A card that took another session this recently is not answered: the phone may have shown the earlier one while the
# user typed or dictated. Longer than an answer takes; a refusal costs a second tap, a wrong session's answer is sent.
switchedWithin=300

languages() { /usr/bin/defaults read -g AppleLanguages }
# The processes on a terminal: pid, state (+ — in the foreground), command.
processes() { /bin/ps -o pid=,stat=,comm= -t "$1" }
arguments() { /bin/ps -o args= -p "$1" }

# The refusal, in the Mac's first language (the app's five; English otherwise): $1 the reason, $2 an app's name.
typeset -A said
words() {
  local first=${${(f)"$(languages 2>/dev/null)"}[2]:-en}
  first=${${first//[[:space:]\",]/}[1,2]}
  case $first in
    ru) said=(
      busy "Сессия уже работает — ответьте, когда она остановится"
      permission "Просит разрешение — ответьте за маком"
      nowhere "В этом терминале ответить отсюда нельзя"
      empty "На этой карточке нет сессии"
      switched "На карточке только что сменилась сессия — проверьте и ответьте снова"
      gone "Сессия закончилась или ушла из своего терминала"
      unknown "Терминал сессии ещё не известен — она назовёт его при следующем действии"
      automation "Нет разрешения управлять приложением %s"
      notRunning "%s не запущен"
      notFound "Не нашёл окно этой сессии в %s"
      noTmux "Не нашёл tmux"
      failed "Не удалось напечатать ответ" ) ;;
    de) said=(
      busy "Die Sitzung arbeitet gerade — antworte, wenn sie anhält"
      permission "Sie bittet um Erlaubnis — antworte am Mac"
      nowhere "In diesem Terminal kann man von hier nicht antworten"
      empty "Auf dieser Karte ist keine Sitzung"
      switched "Die Karte zeigt gerade eine andere Sitzung — prüfe sie und antworte erneut"
      gone "Die Sitzung ist beendet oder nicht mehr in ihrem Terminal"
      unknown "Das Terminal der Sitzung ist noch unbekannt — sie nennt es bei ihrem nächsten Schritt"
      automation "Keine Erlaubnis, %s zu steuern"
      notRunning "%s läuft nicht"
      notFound "Das Fenster dieser Sitzung ist in %s nicht zu finden"
      noTmux "tmux nicht gefunden"
      failed "Die Antwort konnte nicht eingegeben werden" ) ;;
    es) said=(
      busy "La sesión está trabajando — responde cuando se detenga"
      permission "Pide permiso — responde en el Mac"
      nowhere "En este terminal no se puede responder desde aquí"
      empty "No hay ninguna sesión en esta tarjeta"
      switched "La tarjeta acaba de cambiar de sesión — revísala y responde de nuevo"
      gone "La sesión terminó o ya no está en su terminal"
      unknown "Aún no se conoce el terminal de la sesión — lo dirá en su próximo paso"
      automation "No hay permiso para controlar %s"
      notRunning "%s no está abierto"
      notFound "No se encuentra la ventana de esta sesión en %s"
      noTmux "No se encuentra tmux"
      failed "No se pudo escribir la respuesta" ) ;;
    fr) said=(
      busy "La session travaille — répondez quand elle s’arrête"
      permission "Elle demande une autorisation — répondez sur le Mac"
      nowhere "Impossible de répondre d’ici dans ce terminal"
      empty "Aucune session sur cette carte"
      switched "La carte vient de passer à une autre session — vérifiez et répondez à nouveau"
      gone "La session est terminée ou a quitté son terminal"
      unknown "Le terminal de la session n’est pas encore connu — elle le donnera à sa prochaine étape"
      automation "Pas d’autorisation pour contrôler %s"
      notRunning "%s n’est pas ouvert"
      notFound "Fenêtre de cette session introuvable dans %s"
      noTmux "tmux introuvable"
      failed "Impossible de saisir la réponse" ) ;;
    *) said=(
      busy "The session is working — answer once it stops"
      permission "It asks for permission — answer at the Mac"
      nowhere "This terminal can't be answered from here"
      empty "There is no session on this card"
      switched "The card has just switched to another session — check it and answer again"
      gone "The session has ended or left its terminal"
      unknown "The session's terminal is not known yet — it says on its next step"
      automation "No permission to control %s"
      notRunning "%s is not running"
      notFound "Can't find this session's window in %s"
      noTmux "tmux is not found"
      failed "Couldn't type the answer" ) ;;
  esac
}

# Says on the phone why nothing was typed and ends the tap: $1 the kind (/api/error), $2 the reason, $3 an app's name.
refuse() {
  words
  local m=${said[$2]//\%s/${3:-}}
  m=${m//\\/\\\\}; m=${m//\"/\\\"}
  $curl -q -s -m 5 -o /dev/null --variable '%DESMAPTIC_TOKEN=' --expand-header 'Authorization: Bearer {{DESMAPTIC_TOKEN}}' \
    -H 'Content-Type: application/json' -d "{\"cellId\":\"$cell\",\"kind\":\"$1\",\"message\":\"$m\"}" "$api/error"
  exit 1
}

field() { print -rn -- "$1" | /usr/bin/plutil -extract $2 raw -o - - 2>/dev/null }
bring() { [[ $app =~ '^[A-Za-z0-9.-]{1,155}$' ]] && $open -b "$app" }

# The card's session: the page's slot file holds the app, the session's id and when it took the card.
slot="$dir/.slots/$cell"
typeset -a lines
[[ -f $slot ]] && lines=( "${(@f)$(<$slot)}" )
app=${lines[1]:-} sid=${lines[2]:-} since=${lines[3]:-0}
[[ $since == <-> ]] || since=0

# The text as it is typed: one line (a newline would send a part early), no control characters (an escape could end
# the paste and type keys), no spaces around it.
text=${DESMAPTIC_INPUT:-}
text=${text//[[:cntrl:]]/ }
text=${${text##[[:space:]]##}%%[[:space:]]##}
if [[ -z $text ]]; then bring; exit 0; fi

[[ $sid =~ '^[A-Za-z0-9_-]{1,128}$' && -f $dir/$sid.json ]] || refuse notFound empty
(( EPOCHSECONDS - since < switchedWithin )) && refuse other switched

state() { field "$(<"$dir/$sid.json")" state }
case $(state) in
  input|done|error) ;;
  working) refuse busy busy ;;
  permission) bring; refuse other permission ;;
  *) refuse notRunning gone ;;
esac

[[ -f $dir/$sid.addr ]] || refuse other unknown
addr=$(<"$dir/$sid.addr")
tool=$(field "$addr" tool) via=$(field "$addr" via) tty=$(field "$addr" tty) pid=$(field "$addr" pid)
[[ $tool == (claude|codex) ]] || refuse other unknown
[[ $tty =~ '^/dev/ttys[0-9]{1,4}$' ]] || tty=""
[[ $pid =~ '^[0-9]{1,9}$' ]] || pid=""

# Whether the session's tool is the foreground process of its terminal — its pid when the address has one: a tty is
# reused once its tab closes, and a tool suspended to its shell or a shell left behind is never typed into.
alive() {
  [[ -n $tty ]] || return 1
  local row p st comm
  local -a w a
  for row in "${(@f)$(processes ${tty#/dev/} 2>/dev/null)}"; do
    w=( ${=row} )
    p=${w[1]:-} st=${w[2]:-} comm=${(j: :)w[3,-1]}
    [[ -n $pid && $p != $pid ]] && continue
    [[ $st == *+* ]] || continue
    [[ ${comm:t} == node ]] && a=( ${=$(arguments $p 2>/dev/null)} ) || a=()
    [[ ${comm:t} == $tool || ${${a[1]:-}:t} == $tool || ${${a[2]:-}:t} == $tool ]] && return 0
  done
  return 1
}

# Right before typing: still waiting, still there.
ready() {
  case $(state) in
    input|done|error) ;;
    working) refuse busy busy ;;
    permission) bring; refuse other permission ;;
    *) refuse notRunning gone ;;
  esac
  alive || refuse notRunning gone
}

# The text for osascript, which reads it from its environment as data.
export DESMAPTIC_REPLY=$text
read_reply='set t to do shell script "printf %s \"$DESMAPTIC_REPLY\"" without altering line endings'

# Runs an AppleScript (on stdin) with arguments and turns its answer into a refusal unless it typed. $1 the app's name.
apple() {
  local name=$1 out
  shift
  out=$($osascript - "$@" 2>&1)
  case $out in
    typed) return 0 ;;
    not-running) refuse notRunning notRunning "$name" ;;
    not-found|moved) refuse notFound notFound "$name" ;;
    *-1743*|*-10004*) refuse automation automation "$name" ;;
    *) refuse other failed ;;
  esac
}

tmux_type() {
  local tmux="" t socket=$(field "$addr" tmux_socket) pane=$(field "$addr" tmux_pane)
  for t in $tmuxPaths; do [[ -x $t ]] && { tmux=$t; break }; done
  [[ -n $tmux ]] || refuse notFound noTmux
  [[ $pane =~ '^%[0-9]{1,9}$' && -S $socket && -O $socket ]] || refuse notRunning gone
  # The pane is still the session's terminal.
  [[ $($tmux -S "$socket" display-message -p -t "$pane" '#{pane_tty}' 2>/dev/null) == "$tty" ]] || refuse notRunning gone
  ready
  # The text through stdin into a buffer of its own, pasted (bracketed, when the tool asked for it) and deleted.
  local buffer="desmaptic-$$"
  print -rn -- "$text" | $tmux -S "$socket" load-buffer -b "$buffer" - 2>/dev/null || refuse other failed
  $tmux -S "$socket" paste-buffer -p -d -b "$buffer" -t "$pane" 2>/dev/null || refuse other failed
  zselect -t 20
  $tmux -S "$socket" send-keys -t "$pane" Enter 2>/dev/null || refuse other failed
  exit 0
}

iterm_type() {
  local session=$(field "$addr" iterm_session)
  session=${session#*:}
  [[ $session =~ '^[0-9A-Fa-f-]{36}$' ]] || refuse notRunning gone
  ready
  apple iTerm2 "$session" "$tty" <<EOF
on run argv
  set wanted to item 1 of argv
  set wantedTty to item 2 of argv
  if application id "com.googlecode.iterm2" is not running then return "not-running"
  $read_reply
  with timeout of 20 seconds
    tell application id "com.googlecode.iterm2"
      repeat with w in windows
        repeat with b in tabs of w
          repeat with s in sessions of b
            if unique id of s is wanted then
              if tty of s is not wantedTty then return "moved"
              tell s to write text t newline no
              delay 0.2
              tell s to write text ""
              return "typed"
            end if
          end repeat
        end repeat
      end repeat
    end tell
  end timeout
  return "not-found"
end run
EOF
  exit 0
}

# Whether the session left its waiting state within a second (the hook marks a sent prompt working).
submitted() {
  local k
  for (( k = 0; k < 10; k++ )); do
    [[ $(state) == (input|done|error) ]] || return 0
    zselect -t 10
  done
  return 1
}

# Terminal's do script always ends the text with a Return, in the same write. A tool that takes a fast write for a
# paste keeps that Return as a newline in its input; then a Return of its own sends it — only while the session still
# waits, so it never lands on a permission prompt.
terminal_type() {
  ready
  apple Terminal "$tty" <<EOF
on run argv
  set wantedTty to item 1 of argv
  if application id "com.apple.Terminal" is not running then return "not-running"
  $read_reply
  with timeout of 20 seconds
    tell application id "com.apple.Terminal"
      repeat with w in windows
        try
          repeat with b in tabs of w
            if tty of b is wantedTty then
              do script t in b
              return "typed"
            end if
          end repeat
        end try
      end repeat
    end tell
  end timeout
  return "not-found"
end run
EOF
  submitted && exit 0
  ready
  apple Terminal "$tty" <<EOF
on run argv
  set wantedTty to item 1 of argv
  if application id "com.apple.Terminal" is not running then return "not-running"
  with timeout of 20 seconds
    tell application id "com.apple.Terminal"
      repeat with w in windows
        try
          repeat with b in tabs of w
            if tty of b is wantedTty then
              do script "" in b
              return "typed"
            end if
          end repeat
        end try
      end repeat
    end tell
  end timeout
  return "not-found"
end run
EOF
  exit 0
}

# Codex 0.157 and newer queues a message for its session by id, wherever the session runs. The text is codex's
# argument there (the command takes nothing else), so only where no terminal can be typed into. Codex gets only what
# it needs of the environment: never the token or the storage path, under any name.
bare() {
  /usr/bin/env -i HOME="$HOME" USER="${USER:-}" LOGNAME="${LOGNAME:-}" SHELL="${SHELL:-/bin/zsh}" TMPDIR="${TMPDIR:-/tmp}" \
    PATH="$PATH" LANG="$LANG" "$@"
}

codex_queue() {
  local codex="" c thread=$(field "$addr" thread) version
  [[ $tool == codex && $thread =~ '^[A-Za-z0-9_-]{1,128}$' ]] || return 1
  for c in $codexPaths; do [[ -x $c ]] && { codex=$c; break }; done
  [[ -n $codex ]] || return 1
  # "codex-cli 0.157.0"
  version=${${(z)"$(bare $codex --version 2>/dev/null)"}[-1]:-}
  [[ $version == [0-9]##.[0-9]##(.[0-9]##)# ]] && is-at-least 0.157 $version || return 1
  case $(state) in
    input|done|error) ;;
    working) refuse busy busy ;;
    permission) bring; refuse other permission ;;
    *) refuse notRunning gone ;;
  esac
  bare $codex queue --thread "$thread" --message "$text" </dev/null >/dev/null 2>&1 || refuse other failed
  exit 0
}

case $via in
  tmux) tmux_type ;;
  iterm2) iterm_type ;;
  tty) [[ $app == com.apple.Terminal ]] && terminal_type ;;
esac
codex_queue
refuse other nowhere

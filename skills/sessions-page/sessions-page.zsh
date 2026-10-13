#!/bin/zsh -f
# Desmaptic "AI Sessions" page: one card per AI coding session — its project, what it is doing and for how long.
# The startup script of the page's first card (page-json.zsh puts this file there). Once a second it reads the
# state files the plugin's session-status hook writes into $DESMAPTIC_STORAGE/AISessions and draws the cards that
# changed; a closed session's card goes away after five minutes. For a tap on a card it leaves the session and the
# app it runs in under AISessions/.slots/<card id>. A card whose session waits for permission turns its question off:
# its tap brings the session's app forward at once, with no "What to reply?" in between.
# Try a card without the phone: zsh -f sessions-page.zsh --card permission claude my-project 300 en
export LANG=en_US.UTF-8                   # ${#text} counts letters, not bytes
zmodload zsh/datetime zsh/stat zsh/zselect
zmodload -F zsh/files b:zf_rm
api="http://127.0.0.1:9848/api"
curl=/usr/bin/curl
dir="${DESMAPTIC_STORAGE:-$HOME/Library/Application Support/Desmaptic/ScriptStorage}/AISessions"
cells=( "{{CELL_ID}}" "{{CELL_ID:s2}}" "{{CELL_ID:s3}}" "{{CELL_ID:s4}}"
        "{{CELL_ID:s5}}" "{{CELL_ID:s6}}" "{{CELL_ID:s7}}" "{{CELL_ID:s8}}" )
closedFor=300                             # a closed session's card stays this long
staleAfter=86400                          # a file not touched for a day: a session that ended without saying so

# The Mac's first language → the page's words (the app's five languages; English otherwise).
language() {
  local first=${${(f)"$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null)"}[2]:-en}
  first=${${first//[[:space:]\",]/}[1,2]}
  print -rn -- ${first:-en}
}
typeset -A words
labels() {
  case $1 in
    ru) words=(working "Работает" permission "Ждёт разрешения" input "Ждёт ввода" done "Готово" error "Ошибка"
               closed "Закрыта" none "Нет сессии" face "Сессия ИИ" min "мин" h "ч") ;;
    de) words=(working "Arbeitet" permission "Wartet auf Erlaubnis" input "Wartet auf dich" done "Fertig" error "Fehler"
               closed "Beendet" none "Keine Sitzung" face "KI-Sitzung" min "Min." h "Std.") ;;
    es) words=(working "Trabajando" permission "Pide permiso" input "Te espera" done "Listo" error "Error"
               closed "Cerrada" none "Sin sesión" face "Sesión de IA" min "min" h "h") ;;
    fr) words=(working "Travaille" permission "Attend une autorisation" input "Vous attend" done "Terminé" error "Erreur"
               closed "Fermée" none "Aucune session" face "Session IA" min "min" h "h") ;;
    *)  words=(working "Working" permission "Needs permission" input "Waiting for you" done "Done" error "Error"
               closed "Closed" none "No session" face "AI session" min "min" h "h") ;;
  esac
}

xml() { local s=$1; s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}; s=${s//\'/&apos;}; print -rn -- "$s" }
json() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//[[:cntrl:]]/ }
  print -rn -- "\"$s\""
}

ago() { # seconds → "<1 min" / "4 min" / "1 h 05 min"
  local m=$(( $1 / 60 ))
  (( m < 1 )) && { print -rn -- "<1 $words[min]"; return }
  (( m < 60 )) && { print -rn -- "$m $words[min]"; return }
  printf '%d %s %02d %s' $(( m / 60 )) "$words[h]" $(( m % 60 )) "$words[min]"
}

# A project name on two lines of 13: broken after a - _ . or space when there is one, the rest cut with ….
split() {
  local name=$1 cut=13 k
  (( ${#name} <= 13 )) && { print -r -- "$name"; print -r -- ""; return }
  for (( k = 13; k > 5; k-- )); do [[ ${name[k]} == [-_.\ ] ]] && { cut=$k; break }; done
  local rest=${name[cut+1,-1]}
  (( ${#rest} > 13 )) && rest="${rest[1,12]}…"
  print -r -- "${name[1,cut]}"
  print -r -- "$rest"
}

# One template for every card; only numbers, colours and text change, so the phone glides between frames.
# $1 state (working permission input done error closed; face — the button's own; anything else — no session), $2 tool,
# $3 project, $4 seconds
card() {
  local st=$1 tool=$2 project=$3 secs=${4:-0}
  local color bg=0 show=1 label=${words[$st]:-$words[none]}
  case $st in
    working)    color="#0A84FF" ;;
    permission) color="#FF9F0A" bg=0.22 ;;
    input)      color="#BF5AF2" ;;
    done)       color="#30D158" ;;
    error)      color="#FF453A" bg=0.16 ;;
    closed)     color="#8E8E93" ;;
    *)          color="#8E8E93" show=0 ;;
  esac
  case $tool in claude) tool="Claude Code" ;; codex) tool="Codex" ;; *) tool="–" ;; esac
  local -a p
  p=( "${(@f)$(split "$project")}" )
  # Never an empty <text>: an older phone app drops it, the structure changes and the card cross-fades.
  local p1=${p[1]:-–} p2=${p[2]:-–} p2o=1 time="–"
  [[ -z ${p[2]:-} ]] && p2o=0
  (( show )) && time=$(ago $secs)
  # The state's words fill the width: about 0.6 of the font size per letter, at most 28.
  local fs=$(( 310 / (${#label} > 0 ? ${#label} : 1) ))
  (( fs > 28 )) && fs=28
  # Opacities as strings: zsh float arithmetic would print 0.59999999999999998.
  local labelo=1 dot=1 dim=0.6
  (( show )) || { p2o=0; labelo=0.5; dot=0.3; dim=0 }
  print -r -- "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200'>
  <rect id='bg' x='0' y='0' width='200' height='200' fill='$color' fill-opacity='$bg'/>
  <circle id='dot' cx='176' cy='22' r='7' fill='$color' opacity='$dot'/>
  <text id='tool' x='14' y='28' font-size='16' fill='#FFFFFF' opacity='$dim'>$tool</text>
  <text id='p1' x='14' y='68' font-size='24' font-weight='bold' fill='#FFFFFF' opacity='$show'>$(xml $p1)</text>
  <text id='p2' x='14' y='96' font-size='24' font-weight='bold' fill='#FFFFFF' opacity='$p2o'>$(xml $p2)</text>
  <text id='state' x='14' y='148' font-size='$fs' font-weight='bold' fill='$color' opacity='$labelo'>$(xml $label)</text>
  <text id='time' x='14' y='182' font-size='16' fill='#FFFFFF' opacity='$dim'>$(xml $time)</text>
</svg>"
}

face_body() { # cell svg state — a permission card's tap goes at once (skipInput), any other card asks
  local skip=false
  [[ ${3:-} == permission ]] && skip=true
  print -rn -- "{\"cellId\":\"$1\",\"svg\":{\"source\":$(json "$2"),\"duration\":0.5,\"easing\":\"easeInOut\"},\"skipInput\":$skip}"
}

# Whether the agent takes "skipInput": 1 yes, 0 no, "" not known yet. An older agent refuses a frame with the field
# and charges the refusal to the button, so the page asks first with a body that names no button — a current agent
# answers it "Invalid JSON", an older one "Unknown field(s): skipInput." — and leaves the field out until it knows.
skips=""
probe() {
  local out
  out=$($curl -q -s -m 5 --variable '%DESMAPTIC_TOKEN=' --expand-header 'Authorization: Bearer {{DESMAPTIC_TOKEN}}' \
    -H 'Content-Type: application/json' -d '{"skipInput":false}' -w '\n%{http_code}' "$api/update-button")
  [[ ${out##*$'\n'} == 400 ]] || return   # no answer yet (the agent is starting): ask on the next pass
  [[ $out == *'Unknown field(s): skipInput.'* ]] && skips=0 || skips=1
}

call() {
  local out
  out=$($curl -q -s -m 5 --variable '%DESMAPTIC_TOKEN=' --expand-header 'Authorization: Bearer {{DESMAPTIC_TOKEN}}' \
    -H 'Content-Type: application/json' -d "$1" -w '\n%{http_code}' "$api/update-button")
  local code=${out##*$'\n'}
  [[ $code == 400 ]] && print -u2 -r -- "frame refused: ${out%$'\n'*}"
  [[ $code == 200 ]]
}

typeset -A sent
send() { # slot body — posts only what changed, plus a keyframe every 60 s
  local key=$1 body=$2
  [[ $skips == 1 ]] || body=${body/,\"skipInput\":(true|false)}
  if [[ ${sent[$key]:-} != "$body" ]] || (( SECONDS - ${sent[$key.at]:-0} > 60 )); then
    call "$body" && { sent[$key]=$body; sent[$key.at]=$SECONDS }
  fi
}

# What the page knows of each session (`<id>.state`, `.tool`, `.project`, `.app`, `.updated`), parsed again only
# when its file's text changes; `seen` holds the text. Not the file's time: it has whole seconds, and the hook
# rewrites a file within one second (working → permission).
typeset -A seen info
read_session() { # sid text mtime
  local sid=$1 text=$2 key value
  seen[$sid]=$text
  for key in state tool project app updated; do
    value=$(print -rn -- "$text" | /usr/bin/plutil -extract $key raw -o - - 2>/dev/null)
    case $key in
      state)   [[ $value == (working|permission|input|done|error|closed) ]] || value="" ;;
      tool)    [[ $value == (claude|codex) ]] || value="" ;;
      app)     [[ $value =~ '^[A-Za-z0-9.-]{1,155}$' ]] || value="" ;;
      updated) [[ $value == <-> ]] || value=$3 ;;
    esac
    info[$sid.$key]=$value
  done
}
forget() { local key; unset "seen[$1]"; for key in state tool project app updated; do unset "info[$1.$key]"; done }

typeset -a slots                          # slot → session id, "" when free
typeset -A drawn tapped
tick() {
  local now=$EPOCHSECONDS f sid m i text
  local -A present
  [[ -n $skips ]] || probe
  for f in "$dir"/*.json(N.); do
    sid=${${f:t}%.json}
    [[ $sid =~ '^[A-Za-z0-9_-]{1,128}$' ]] || continue
    zstat -A m +mtime -- "$f" 2>/dev/null || continue
    # A record goes with its address (the hook's <id>.addr: where to type an answer).
    if (( now - m > staleAfter )); then zf_rm -f -- "$f" "$dir/$sid.addr"; continue; fi
    text=$(<"$f") || continue
    (( ${+seen[$sid]} )) && [[ $seen[$sid] == "$text" ]] || read_session $sid "$text" $m
    if [[ $info[$sid.state] == closed ]] && (( now - info[$sid.updated] > closedFor )); then zf_rm -f -- "$f" "$dir/$sid.addr"; continue; fi
    [[ -n $info[$sid.state] ]] && present[$sid]=1
  done
  for sid in ${(k)seen}; do (( ${+present[$sid]} )) || forget $sid; done
  # The eight sessions that changed last keep their cards; a new one takes a free card.
  local -a recent
  for sid in ${(k)present}; do recent+=( "$info[$sid.updated] $sid" ); done
  recent=( ${${(On)recent}[1,8]#* } )
  for (( i = 1; i <= 8; i++ )); do (( ${recent[(Ie)${slots[i]:-}]} )) || slots[i]=""; done
  for sid in $recent; do
    (( ${slots[(Ie)$sid]} )) && continue
    i=${slots[(i)]}
    slots[i]=$sid
  done
  local key target
  for (( i = 1; i <= 8; i++ )); do
    sid=${slots[i]:-}
    if [[ -n $sid ]]; then
      key="$info[$sid.state]|$info[$sid.tool]|$info[$sid.project]|$(( (now - info[$sid.updated]) / 60 ))"
      target=$info[$sid.app]
    else
      key="none" target=""
    fi
    if [[ ${drawn[$i]:-} != "$key" ]]; then
      if [[ -n $sid ]]; then
        drawn[$i.body]=$(face_body $cells[i] "$(card $info[$sid.state] "$info[$sid.tool]" "$info[$sid.project]" $(( now - info[$sid.updated] )))" $info[$sid.state])
      else
        drawn[$i.body]=$(face_body $cells[i] "$(card none)")
      fi
      drawn[$i]=$key
    fi
    send $i "$drawn[$i.body]"
    [[ ${tapped[$i]-unset} == "$target|$sid" ]] || mark $i "$target" "$sid"
  done
}

# The slot file a card's tap reads (reply.zsh): the app on the first line (the only line a tap of an earlier page
# reads), the session's id and when the session took the card from another one — 0 when the card showed no session
# before (nothing else could have been answered on it), kept from the file when it already names the session, so a
# restarted script does not make every card look just switched.
mark() { # slot app sid
  local f="$dir/.slots/$cells[$1]" since=0
  local -a was
  if [[ -n $3 ]]; then
    [[ -f $f ]] && was=( "${(@f)$(<$f)}" )
    if [[ ${was[2]:-} == "$3" && ${was[3]:-} == <-> ]]; then since=$was[3]
    elif [[ -n ${was[2]:-} ]]; then since=$EPOCHSECONDS
    fi
    print -r -- "$2"$'\n'"$3"$'\n'"$since" >| "$f"
  else
    zf_rm -f -- "$f"
  fi
  tapped[$1]="$2|$3"
}

setup() {
  umask 077
  /bin/mkdir -p "$dir/.slots" || exit 1
  # The first card's id: a notification about a session opens this page.
  print -rn -- "$cells[1]" >| "$dir/.page-cell"
  slots=( "" "" "" "" "" "" "" "" )
}

main() {
  labels "$(language)"
  setup
  trap 'for c in $cells; do call "{\"cellId\":\"$c\",\"reset\":true}"; done; exit 0' TERM INT
  while true; do
    tick
    zselect -t 100
  done
}

case ${1:-} in
  --card) labels ${6:-en}; card "${2:-none}" "${3:-}" "${4:-}" ${5:-0} ;;
  --face) labels ${2:-en}; card face ;;   # the button's own face: what a card shows before the page draws it
  --once) labels en; setup; tick ;;
  # Two passes; between them the *.json files of the folder $2 move in, as the hook moves its files.
  --twice) labels en; setup; tick; for f in "$2"/*.json(N); do /bin/mv -f -- "$f" "$dir/"; done; tick ;;
  "") main ;;
  *) print -u2 "usage: sessions-page.zsh [--card state tool project seconds lang | --face lang | --once | --twice folder]"; exit 2 ;;
esac

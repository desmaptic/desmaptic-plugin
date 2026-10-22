#!/bin/zsh
# CPU ring: a live SVG widget for one Desmaptic button. Paste the WHOLE file into the button's `startupScript`.
#
# To make your own widget change three things: sample() — where the number comes from; frame() — the drawing;
# pause — how often it is sampled. Keep the rest: it is what makes a widget survive real life (see
# references/live-widgets.md). It uses only what every Mac has — zsh, awk, iostat, curl — so it runs on any Mac
# the phone connects to. Try it without a phone:
#   zsh widget_template.zsh --frame [pct]  → the JSON body of one live frame at that value (default 42); give two
#                                            values to render_preview as svg + nextFrame, or pipe one to curl to validate it
#   zsh widget_template.zsh --face         → the document to save as the button's `svgFace` (the resting state)
export LC_ALL=C                           # awk and printf write 0.5, never 0,5 — whatever the user's language

cell="{{CELL_ID}}"                        # the agent replaces this with the button's UUID before running the script
api="http://127.0.0.1:9848/api"           # the IPv4 literal, not localhost
pause=2                                   # seconds between samples (the sample itself takes 1 s)


# The value to show, 0…100. iostat is cheap; `top -l 1` would cost more CPU than most things it measures.
sample() {
  iostat -c 2 -w 1 | awk '$(NF-3) ~ /^[0-9]+$/ { idle = $(NF-3); ok = 1 }
    END { v = ok ? 100 - idle : 0; print int(v < 0 ? 0 : v > 100 ? 100 : v + 0.5) }'
}


# ONE template. Between frames only numbers, colour values and text change — never the elements — so the phone
# glides from frame to frame instead of cross-fading. `rest` as $2 is the saved face: the same structure with
# nothing filled, which is what lets the first live frame grow out of it.
frame() {
  local -a v
  # Every number and the colour come from awk: zsh's own float arithmetic would print 0.17999999999999999.
  # C is the ring's length, 2 × π × r: the dash pattern is "C C", the offset hides the unfilled part.
  v=( $(awk -v p=$1 -v resting=${2:-} 'BEGIN {
    c = 2 * 3.14159265 * 78
    color = resting == "rest" ? "#8E8E93" : p < 50 ? "#34C759" : p < 80 ? "#FF9F0A" : "#FF453A"
    printf "%.2f %.2f %s %.0f", c, c * (1 - p / 100), color, p
  }') )
  local text=$v[4]
  [[ $2 == rest ]] && text="–"
  print -r -- "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200'>
  <circle id='track' cx='100' cy='100' r='78' fill='none' stroke='#FFFFFF' stroke-opacity='0.15' stroke-width='16'/>
  <circle id='ring' cx='100' cy='100' r='78' fill='none' stroke='$v[3]' stroke-width='16' stroke-linecap='round' stroke-dasharray='$v[1] $v[1]' stroke-dashoffset='$v[2]' transform='rotate(-90 100 100)'/>
  <text id='value' x='100' y='116' font-size='56' font-weight='bold' text-anchor='middle' fill='#FFFFFF'>$text</text>
  <text id='label' x='100' y='146' font-size='28' text-anchor='middle' fill='#FFFFFF' fill-opacity='0.6'>cpu %</text>
</svg>"
}


# $1 as a JSON string, by parameter expansion: backslashes and quotes escaped, line breaks and tabs written out.
# (Text you did not write — a song title, an API answer — may hold other control characters: strip them first.)
json() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}
  print -rn -- "\"$s\""
}


# Transition settings travel with EVERY frame: they belong to the face on the button and are lost with it.
# A 0.6 s glide for a sample every ~3 s: smooth on any phone, and the button rests most of the time.
body() {
  print -rn -- "{\"cellId\":\"$cell\",\"svg\":{\"source\":$(json "$(frame $1)"),\"duration\":0.6,\"easing\":\"easeInOut\"}}"
}


# One request to the agent → code (the HTTP status; 000 = no answer) and answer (the body). The token goes into
# the header by curl itself, read from its environment: never onto a command line, never into a log.
# -q comes first: curl then ignores ~/.curlrc, where another program could plant a proxy for the token.
call() {   # PATH [BODY]
  local out
  local -a data
  [[ -n $2 ]] && data=(-H 'Content-Type: application/json' -d "$2")
  out=$(curl -q -s -m 5 --variable '%DESMAPTIC_TOKEN=' --expand-header 'Authorization: Bearer {{DESMAPTIC_TOKEN}}' \
    $data -w '\n%{http_code}' "$api/$1")
  code=${out##*$'\n'} answer=${out%$'\n'*}
  if [[ $code == 400 ]]; then
    print -u2 -r -- "$1: $answer"         # the agent says what is wrong with the frame: the line and the reason
  fi
  [[ $code == 200 ]]
}


# → 0 when the frame was sent. dropped = 1 when the phone does not keep up (the agent keeps the newest frame and
# sends it later by itself).
post() {
  dropped=0
  call update-button "$1" || return
  [[ ${answer// /} == *'"dropped":true'* ]] && dropped=1
  return 0
}


main() {
  # When the agent stops the script the button goes back to its saved face instead of freezing on the last
  # value — and exit code 0 means "finished": the agent does not restart it.
  trap 'post "{\"cellId\":\"$cell\",\"svg\":{\"remove\":true}}"; exit 0' TERM INT
  local last="" pct
  integer sent_at=-100
  # It keeps going while the button is off screen (another page, the app in the background): the agent does not
  # send those frames, it keeps the newest and delivers it the moment the button is shown — so the button is
  # current at once, and a sample every few seconds costs the Mac next to nothing. Rest only an expensive loop
  # (references/live-widgets.md).
  while true; do
    pct=$(sample)
    # Send when the value changed — plus a keyframe every 30 s: the face may have been cleared from outside
    # (another script's reset, the user saving the button) while this loop kept running.
    if [[ $pct != $last ]] || (( SECONDS - sent_at > 30 )); then
      if post "$(body $pct)"; then        # a frame counts as sent only on 200; otherwise retry next pass
        last=$pct sent_at=$SECONDS
      fi
    fi
    (( dropped )) && sleep 4              # the phone does not keep up: slow down until an answer comes without it
    sleep $pause
  done
}


case $1 in
  --frame)
    [[ ${2:-42} == (<->|<->.<->) ]] || { print -u2 "usage: widget_template.zsh --frame [pct]"; exit 2 }
    # Outside the agent nobody replaced the placeholder; the API wants a UUID, so a test post uses a dummy one.
    [[ $cell == \{* ]] && cell=00000000-0000-0000-0000-000000000000
    body ${2:-42}; print ;;
  --face)
    frame 0 rest ;;
  "")
    main ;;
  *)
    print -u2 "usage: widget_template.zsh [--frame [pct] | --face]"   # a typo must not start the endless loop
    exit 2 ;;
esac

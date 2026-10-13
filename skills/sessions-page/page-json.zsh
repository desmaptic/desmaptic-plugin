#!/bin/zsh -f
# Prints the `pages` argument of add_pages_to_client for the "AI Sessions" page: eight 2×2 session cards on the
# phone's 4×8 grid. The first card runs sessions-page.zsh (this folder) as its startup script. A card's tap asks
# "What to reply?" and types the answer into the session it shows (reply.zsh, this folder); its long press brings
# forward the app the session runs in. The question and the quick replies are in the Mac's language, or `language`.
# Usage: zsh -f page-json.zsh [page name [language]]
here=${0:A:h}
name=${1:-AI Sessions}
json() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\t'/\\t}; s=${s//[[:cntrl:]]/ }
  print -rn -- "\"$s\""
}
language=${2:-${${(f)"$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null)"}[2]:-en}}
language=${${language//[[:space:]\",]/}[1,2]}
case $language in
  ru) ask=("Что ответить?" "Продолжай" "Прогони тесты" "Сделай PR") ;;
  de) ask=("Was antworten?" "Mach weiter" "Lass die Tests laufen" "Erstelle einen PR") ;;
  es) ask=("¿Qué responder?" "Continúa" "Ejecuta los tests" "Abre un PR") ;;
  fr) ask=("Que répondre ?" "Continue" "Lance les tests" "Ouvre une PR") ;;
  *)  ask=("What to reply?" "Continue" "Run the tests" "Open a PR") ;;
esac
input="{\"question\":$(json "$ask[1]"),\"quickReplies\":[$(json "$ask[2]"),$(json "$ask[3]"),$(json "$ask[4]")]}"
page=$(<"$here/sessions-page.zsh") || exit 1
reply=$(<"$here/reply.zsh") || exit 1
face=$(/bin/zsh -f "$here/sessions-page.zsh" --face "$language") || exit 1
# The long press: the app the page's script left for this card, if it is a bundle id.
bring='f="$DESMAPTIC_STORAGE/AISessions/.slots/{{CELL_ID}}"
[ -f "$f" ] || exit 0
read -r app < "$f"
case $app in ""|*[!A-Za-z0-9.-]*) exit 0 ;; esac
exec /usr/bin/open -b "$app"'
buttons=()
for (( k = 1; k <= 8; k++ )); do
  button="{\"label\":\"AI session $k\",\"ref\":\"s$k\",\"row\":$(( (k - 1) / 2 * 2 )),\"col\":$(( (k - 1) % 2 * 2 )),"
  button+="\"rowSpan\":2,\"colSpan\":2,\"commandType\":\"shellCommand\",\"scriptCode\":$(json "$reply"),\"input\":$input,"
  button+="\"longPressCommandType\":\"shellCommand\",\"longPressScriptCode\":$(json "$bring"),\"svgFace\":$(json "$face")"
  (( k == 1 )) && button+=",\"startupScript\":$(json "$page")"
  buttons+=("$button}")
done
print -r -- "[{\"name\":$(json "$name"),\"buttons\":[${(j:,:)buttons}]}]"

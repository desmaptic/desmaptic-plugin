#!/bin/zsh -f
# Whether Codex runs the Desmaptic plugin's hooks (hooks/codex.json), for the setup check. Prints one word:
#   approved — every hook approved in /hooks, as the plugin has it now;
#   review   — a hook new or changed since it was approved: Codex runs it only after the user approves it in /hooks;
#   disabled — a hook turned off in /hooks;
#   off      — all of Codex's hooks turned off (the `hooks` feature, or its old name `codex_hooks`, set to false);
#   unknown  — the plugin's hook file cannot be read.
#
# Codex keeps the approvals in its config.toml (${CODEX_HOME:-~/.codex}): one table per hook,
# [hooks.state."<plugin id>:hooks/codex.json:<event>:0:0"] with `trusted_hash` — the hash of the hook as approved —
# and `enabled = false` for one turned off. The plugin id is desmaptic@<marketplace>, as its [plugins."…"] table
# names it. The hash is Codex's own: "sha256:" and the SHA-256 of the hook's JSON, keys sorted, compact —
# {"event_name":"<event>","hooks":[{"async":false,"command":…,"timeout":…,"type":"command"}]}, the command as the
# file has it, before ${PLUGIN_ROOT} is filled in. A Codex that hashed differently would make this say "review" for
# approved hooks, never "approved" for others: the worst it does is send the user to /hooks.
# What it cannot see: a profile chosen only on the command line (`codex --profile`; the config's own `profile = "…"`
# is read), and a project's or an administrator's Codex settings — any of them can turn the hooks off while this says
# "approved".
#
# It reads, never writes; it prints nothing but the word.

exec 2>/dev/null
setopt extended_glob

hooks_file=${0:A:h:h:h}/hooks/codex.json
config=${CODEX_HOME:-$HOME/.codex}/config.toml

# Each event of hooks/codex.json and its label in Codex's keys.
typeset -A labels=(
  SessionStart session_start
  UserPromptSubmit user_prompt_submit
  PreToolUse pre_tool_use
  PostToolUse post_tool_use
  PermissionRequest permission_request
  Stop stop
  Interrupt interrupt
  SessionEnd session_end
)

[[ -r $hooks_file ]] || { print unknown; exit 0 }

# The hooks switch: switches[base] for the config's own features, switches[profile:<name>] for a profile's;
# false wins over true within one.
typeset -A switches
note() {
  case $2 in
    false*) switches[$1]=false ;;
    true*) : ${switches[$1]:=true} ;;
  esac
}

# Reads the config: the approvals — trusted[<key>] and disabled[<key>], from tables `[hooks.state."<key>"]` and inline
# entries `"<key>" = { trusted_hash = "…", enabled = false }` under `[hooks.state]`; the plugin ids its
# [plugins."desmaptic@…"] tables name (named), and the ones turned off there (plugin_off); the hooks switch in every
# form TOML allows — `[features] hooks = false`, `features.hooks = false`, `features = { hooks = false }`, the same
# under [profiles.<name>] — and the selected `profile`.
typeset -A trusted disabled named plugin_off
table="" profile=""
if [[ -r $config ]]; then
  while IFS= read -r line || [[ -n $line ]]; do
    line=${${line##[[:space:]]#}%%[[:space:]]#}
    [[ -z $line || $line == \#* ]] && continue
    if [[ $line == \[* ]]; then
      table=$line
      [[ $table =~ '^\[plugins\."(desmaptic@[^"]+)"\]$' ]] && named[$match[1]]=1
      continue
    fi
    if [[ $table =~ '^\[hooks\.state\."([^"]+)"\]$' ]]; then
      key=$match[1]
      [[ $line =~ '^trusted_hash[[:space:]]*=[[:space:]]*"([^"]*)"' ]] && trusted[$key]=$match[1]
      [[ $line =~ '^enabled[[:space:]]*=[[:space:]]*false' ]] && disabled[$key]=1
    elif [[ $table == '[hooks.state]' && $line =~ '^"([^"]+)"[[:space:]]*=[[:space:]]*\{(.*)\}' ]]; then
      key=$match[1] entry=$match[2]
      [[ $entry =~ 'trusted_hash[[:space:]]*=[[:space:]]*"([^"]*)"' ]] && trusted[$key]=$match[1]
      [[ $entry =~ 'enabled[[:space:]]*=[[:space:]]*false' ]] && disabled[$key]=1
    elif [[ $table =~ '^\[plugins\."(desmaptic@[^"]+)"\]$' ]]; then
      id=$match[1]
      [[ $line =~ '^enabled[[:space:]]*=[[:space:]]*false' ]] && plugin_off[$id]=1
    elif [[ $table == '[plugins]' && $line =~ '^"(desmaptic@[^"]+)"[[:space:]]*=[[:space:]]*\{(.*)\}' ]]; then
      id=$match[1] entry=$match[2]
      named[$id]=1
      [[ $entry =~ 'enabled[[:space:]]*=[[:space:]]*false' ]] && plugin_off[$id]=1
    elif [[ $line =~ '^([A-Za-z0-9_."-]+)[[:space:]]*=[[:space:]]*(.*)$' ]]; then
      # The key's whole dotted path, the table's included, quotes dropped: features.hooks, profiles.work.features…
      # (not `path`: zsh ties that name to $PATH).
      dotted=${${table#\[}%\]}
      [[ -n $dotted ]] && dotted+=.
      dotted=$dotted$match[1] value=$match[2]
      dotted=${dotted//\"/}
      case $dotted in
        profile) [[ $value =~ '^"([^"]*)"' ]] && profile=$match[1] ;;
        features.hooks|features.codex_hooks) note base $value ;;
        profiles.*.features.hooks|profiles.*.features.codex_hooks) note profile:${${dotted#profiles.}%.features.*} $value ;;
        features|profiles.*.features)
          scope=base
          [[ $dotted == profiles.* ]] && scope=profile:${${dotted#profiles.}%.features}
          if [[ $value =~ '(^|[{,[:space:]])(codex_)?hooks[[:space:]]*=[[:space:]]*(true|false)' ]]; then
            [[ $value =~ '(^|[{,[:space:]])(codex_)?hooks[[:space:]]*=[[:space:]]*false' ]] && note $scope false || note $scope true
          fi
          ;;
      esac
    fi
  done < $config
fi
# A selected profile's own switch overrides the config's.
setting=${switches[base]}
[[ -n $profile && -n ${switches[profile:$profile]} ]] && setting=${switches[profile:$profile]}
[[ $setting == false ]] && { print off; exit 0 }

# The plugin's ids in Codex: the ones its [plugins."desmaptic@…"] tables enable (all of them it names, if it turns
# every one off); only when no table names one, the ones its approvals name; desmaptic@desmaptic when nothing does.
typeset -aU ids
for id in ${(k)named}; do
  [[ -z ${plugin_off[$id]} ]] && ids+=$id
done
(( $#ids )) || ids=(${(k)named})
if (( ! $#ids )); then
  for key in ${(k)trusted} ${(k)disabled}; do
    [[ $key == (#b)(desmaptic@[^:]##):hooks/codex.json:* ]] && ids+=$match[1]
  done
fi
(( $#ids )) || ids=(desmaptic@desmaptic)

# Each hook's hash as Codex computes it.
typeset -A sums
for event label in ${(kv)labels}; do
  command=$(/usr/bin/plutil -extract "hooks.$event.0.hooks.0.command" raw -o - $hooks_file) || continue
  timeout=$(/usr/bin/plutil -extract "hooks.$event.0.hooks.0.timeout" raw -o - $hooks_file) || { print unknown; exit 0 }
  command=${command//\\/\\\\}
  command=${command//\"/\\\"}
  identity="{\"event_name\":\"$label\",\"hooks\":[{\"async\":false,\"command\":\"$command\",\"timeout\":$timeout,\"type\":\"command\"}]}"
  sums[$label]="sha256:${$(print -rn -- $identity | /usr/bin/shasum -a 256)[1,64]}"
done

# The worst answer over every id: disabled, then review, then approved.
answer=approved
for id in $ids; do
  for label sum in ${(kv)sums}; do
    key="${id}:hooks/codex.json:${label}:0:0"
    if [[ -n ${disabled[$key]} ]]; then
      answer=disabled
    elif [[ ${trusted[$key]} != $sum && $answer == approved ]]; then
      answer=review
    fi
  done
done
print $answer

#!/usr/bin/env bash

set -e

eval "$(/opt/homebrew/bin/brew shellenv)"

export PASSWORD_STORE_DIR="$HOME/.m/.pass"

dmenu="/opt/homebrew/bin/choose"
copy="pbcopy"

prefix=${PASSWORD_STORE_DIR:-$HOME/.password-store}
password_files=$(find "$prefix" -mindepth 1 -name '.*' -prune -o -type f -name '*.gpg' -print \
  | sed -e "s|^$prefix/||" -e 's|\.gpg$||' -e 's|\.otp$||' | sort -u)
password=$(printf '%s\n' "$password_files" | $dmenu)

[[ -n $password ]] || exit

fields=("secret" "username" "url" "otp")
field=$(printf '%s\n' "${fields[@]}" | $dmenu)

[[ -n $field ]] || exit

if [[ $field == "secret" ]]; then
  pass show -c "$password"
  exit
fi

if [[ $field == "otp" ]]; then
  pass otp -c "${password}.otp"
  exit
fi

content=$(/opt/homebrew/bin/pass show "${password}")
content=${content#*"${field}": }
content=${content%% *}
content=${content%%$'\n'*}

echo -n "${content}" | $copy

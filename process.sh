#!/bin/bash

set -xe

proj_exists () {
  oc get project | grep -q "^newis-${1} " || return 1
  return 0
}

while [[ -n "$1" ]] ; do
  F="$1"
  [[ -r "$F" ]] || exit 1
  shift

  while :; do
    let "C = 0 + $RANDOM"
    proj_exists "$C" && continue || :
    oc new-project "newis-$C" 1>/dev/null
    proj_exists "$C"

    R="`oc create -f "$F"`"

    echo "$R" \
      | cut -d'"' -f2 \
      | grep -v ^$ \
      | xargs -n1 -i echo "is/{}" \
      | xargs oc export -o json \
      | tee "$F" || :

    oc delete project "newis-$C"

  break
  done
done

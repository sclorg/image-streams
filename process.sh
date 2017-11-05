#!/bin/bash

set -xe

while [[ -n "$1" ]] ; do
  F="$1"
  [[ -r "$F" ]] || exit 1
  shift

  while :; do
    let "C = 0 + $RANDOM"
    oc new-project "newis-$C" 1>/dev/null
    oc get project | grep -q "^newis-${C} " && continue || :

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

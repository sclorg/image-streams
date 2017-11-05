#!/bin/bash

set -xe

proj_exists () {
  oc get project | grep -q "^newis-${1} " || return 1
  return 0
}

sed_d () {
  sed -e "/^\s*\"$1\s*$/ d"
}

while [[ -n "$1" ]] ; do
  F="$1" ; shift
  [[ -r "$F" ]]

  while let "C = 0 + $RANDOM"; do
  proj_exists "$C" || {
    oc new-project "newis-$C" 1>/dev/null
    proj_exists "$C"

    R="`oc create -f "$F"`"
    echo "$R" \
      | cut -d'"' -f2 \
      | grep -v ^$ \
      | xargs -n1 -i echo "is/{}" \
      | xargs oc export -o json \
      | sed_d 'generation": 1,' \
      | sed_d 'importPolicy": {},' \
      | sed_d 'referencePolicy": {' \
      | sed_d 'type": "Source"' \
      | sed_d 'creationTimestamp": null,' \
      | sed_d 'status": {' \
      | sed_d 'dockerImageRepository": ""' \
      | tee "$F"

    cat -n "$F" \
      | grep -EA 1 '^\s*[0-9]+\s*},\s*$' \
      | grep -v '^--$' \
      | paste -d ' ' - - \
      | grep -E '^\s*[0-9]+\s*},\s*[0-9]+\s*}\s*$' \
      | tr -s '\t' ' ' \
      | cut -d' ' -f2 \
      | xargs -n1 -i echo -n "{}d;" \
      | xargs -i sed -i "{}" "$F"

    oc delete project "newis-$C"
    break
  }
  done
done

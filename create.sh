#!/bin/bash
#

set -xe

# G - grep NAMEs
[[ "$1" == "-g" ]] && { shift ; G="$1" ; shift ; } || G=

# $@ - folders
get_names_and_files () {
  for dir in "$@"; do
    find "$dir" -type f -iname '*.json' \
      | while read file; do
          name="`get_name "$file"`"
          [[ -n "$name" ]] && echo "$name $file" || :
        done \
      | sort -u
  done
}

get_name () {
  [[ -n "$1" && -r "$1" ]] || exit 1

  cat "$1" \
    | tr -s '\t' ' ' \
    | tr -s '\n' ' ' \
    | tr -s '{' '\n' \
    | grep -A 1 'kind": "ImageStreamTag' \
    | tr -s '\n' ' ' \
    | tr -s ',' '\n' \
    | grep -E '"(name|value)"' \
    | cut -d':' -f2 \
    | cut -d'"' -f2 \
    | grep -v '^[0-9]' \
    | grep -v '^\$' \
    | grep "$G" \
    | head -1 || :
}

## GLOBAL=    # Example
NAME=         # httpd
DISPLAYNAME=  # Apache HTTP Server (httpd)
VERSION=      # 2.4
DESCRIPTION=  # Build and serve static content via Apache HTTP Server (httpd) on RHEL 7. For more information about using this builder image, including OpenShift considerations, see https://github.com/sclorg/httpd-container/blob/master/2.4/README.md.\n\nWARNING: By selecting this tag, your application will automatically update to use the latest version of Httpd available on OpenShift, including major versions updates.
ICONCLASS=    # icon-apache
TAGS=         # builder,httpd
REGISTRY=     # registry.access.redhat.com/rhscl
OSNAME=       # rhel
CONTVER=      # 24
OSVER=        # 7

# $1 - file
get_vars () {
  DISPLAYNAME="$(
    grep 'openshift.io/display-name' "$1" \
      | cut -d'"' -f4
  )"
}

body () {
  local ARGS='-maxdepth 1 -mindepth 1 -type d'
  for dir in "$@"; do
    (
      find "$dir/${NAME}-container" ${ARGS} || :
      find "$dir/s2i-${NAME}-container" ${ARGS} || :
    ) \
      | xargs -n1 basename | grep -E '^[0-9]' | sort -Vr
  done \
    | while read VERSION; do
      imagestream
    done
}

#######################

static_top () {
  cat <<EOJS
{
  "kind": "ImageStreamList",
  "apiVersion": "v1",
  "metadata": {},
  "items": [
EOJS
}

header () {
  cat <<EOJS
    {
      "kind": "ImageStream",
      "apiVersion": "v1",
      "metadata": {
        "name": "${NAME}",
        "annotations": {
          "openshift.io/display-name": "${DISPLAYNAME}"
        }
      },
      "spec": {
        "tags": [
          {
            "name": "latest",
            "annotations": {
              "openshift.io/display-name": "${DISPLAYNAME} (latest)",
              "description": "${DESCRIPTION}\n\nWARNING: By selecting this tag, your application will automatically update to use the latest version of MariaDB available on OpenShift, including major versions updates.",
              "iconClass": "${ICONCLASS}",
              "tags": "${TAGS}"
            },
            "from": {
              "kind": "ImageStreamTag",
              "name": "${VERSION}"
            }
EOJS
}

imagestream () {
  cat <<EOJS
          },
          {
            "name": "${VERSION}",
            "annotations": {
              "openshift.io/display-name": "${DISPLAYNAME} ${VERSION}",
              "description": "${DESCRIPTION}",
              "iconClass": "${ICONCLASS}",
              "tags": "${TAGS}",
              "version": "${VERSION}"
            },
            "from": {
              "kind": "DockerImage",
              "name": "${REGISTRY}/${NAME}-${CONTVER}-${OSNAME}${OSVER}:latest"
            }
EOJS
}

footer () {
  cat <<EOJS
          }
        ]
      }
EOJS
}

static_footer () {
  cat <<EOJS
    }
  ]
}
EOJS
}

#######################

## reads from `get_names_and_files`
main () {
  static_top

  local prev=   # previous NAME
  while read NAME file; do
    [[ "$NAME" == "$prev" ]] && continue
    prev="$NAME"

    get_vars "$file"
    header
    body "$@"
    footer
  done

  static_footer
}

get_names_and_files "$@" | main "$@"
exit 0

#!/bin/bash
#
# ./create.sh [options] WDIR1 [WDIR2 [WDIR3]]
#   -g REG      # regex for grep; to grep image-stream NAMEs
#   WDIRn       # working directory/ies to scan for json etc.
#
#   Produces(overwrites!) files in current directory:
#      image-streams{centos,rhel}7.json
#
# Author: pvalena@redhat.com
#
set -xe

# G - grep NAMEs
[[ "$1" == "-g" ]] && { shift ; G="$1" ; shift ; } || G=

## static
E=EMPTY              # (shortcut)
OSVER=7
FPREFIX='image-streams-'

## GLOBAL=      # Example
NAME=$E         # httpd
DISPLAYNAME=$E  # Apache HTTP Server (httpd)
VERSION=$E      # 2.4
CONTVER=$E      # 24
DESCRIPTION=$E  # Build and serve static content via Apache HTTP Server (httpd) on RHEL 7. For more information about using this builder image, including OpenShift considerations, see https://github.com/sclorg/httpd-container/blob/master/2.4/README.md.\n\nWARNING: By selecting this tag, your application will automatically update to use the latest version of Httpd available on OpenShift, including major versions updates.
ICONCLASS=$E    # icon-apache
TAGS=$E         # builder,httpd

# manually set REGISTRY OSNAME
REGISTRY=$E
OSNAME=$E

# $1 - file
load_all_vars () {
  while read x y; do
    [[ -z "$x" || -z "$y" ]] && continue
    eval "$x=\"`get_var "$y" "$1"`\""
  done <<< \
    "
      DISPLAYNAME openshift.io/display-name
      DESCRIPTION description
      ICONCLASS   iconClass
      TAGS        tags
    "
}

# $1 - key
# $2 - file
get_var () {
  grep "\"$1\": \"" "$2" \
    | cut -d'"' -f4 \
    | head -1
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
    | grep -E "$G" \
    | head -1 || :
}


##########################
## json format templates #
##########################
w_static_top () {
  cat <<EOJS
{
  "kind": "ImageStreamList",
  "apiVersion": "v1",
  "metadata": {},
  "items": [
    {
EOJS
}

w_header () {
  cat <<EOJS
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
EOJS
}

w_imagestream () {
  cat <<EOJS
            "name": "${VERSION}",
            "annotations": {
              "openshift.io/display-name": "${DISPLAYNAME} ${VERSION}",
              "openshift.io/provider-display-name": "Red Hat, Inc.",
              "description": "${DESCRIPTION}",
              "iconClass": "${ICONCLASS}",
              "tags": "${TAGS}",
              "version": "${VERSION}"
            },
            "from": {
              "kind": "DockerImage",
              "name": "${REGISTRY}/${NAME}-${CONTVER}-${OSNAME}${OSVER}:latest"
            }
          },
          {
EOJS
}

w_footer () {
  cat <<EOJS
            "name": "latest",
            "annotations": {
              "openshift.io/display-name": "${DISPLAYNAME} (latest)",
              "openshift.io/provider-display-name": "Red Hat, Inc.",
              "description": "${DESCRIPTION}\n\nWARNING: By selecting this tag, your application will automatically update to use the latest version of ${DISPLAYNAME} available on OpenShift, including major versions updates.",
              "iconClass": "${ICONCLASS}",
              "tags": "${TAGS}"
            },
            "from": {
              "kind": "ImageStreamTag",
              "name": "${VERSION}"
            }
          }
        ]
      }
    },
    {
EOJS
}

w_static_footer () {
  cat <<EOJS
    }
  ]
}
EOJS
}
########################

## Writes out "$name $file" pairs
# from for all json files in
# $@ - work dirs
get_names_and_files () {
  for dir in "$@"; do
    find "$dir" -type f -iname '*.json' \
      | while read file; do
          name="`get_name "$file"`"
          # $NAME global
          [[ -n "$name" ]] && echo "$name $file" || :
        done \
      | sort -u
  done
}

## Reads $NAME $file (from `get_names_and_files`)
# !!! Expects sorted input !!!
# Writes image-streams in json format to file.
# Gets info parsing $file in
# $@ - work dirs
main () {
  {
    w_static_top

    local prev=   # previous NAME
    while read NAME file; do
      # every imagestream only once
      [[ "$NAME" == "$prev" ]] && continue
      prev="$NAME"

      load_all_vars "$file"
      w_header
        body "$@"
      w_footer
    done \
      | head -n -2    # remove },{ from the last footer

    w_static_footer
  } \
    > ${FPREFIX}${OSNAME}${OSVER}.json
}

## Writes all image-streams for $NAME
# Looks for subdirs(=>$VERSIONs) in
# $@ - work dirs
body () {
  while read v; do
    VERSION="$v"
    CONTVER="`sed -e 's/\.//g' <<< "$v"`"
    w_imagestream
  done \
    < <(
      local args='-maxdepth 1 -mindepth 1 -type d -o -type l'

      for dir in "$@"; do
        find "$dir/${NAME}-container" ${args} || :
        find "$dir/s2i-${NAME}-container" ${args} || :
      done \
        | xargs -n1 basename \
        | grep -E '^[0-9]' \
        | sort -V                 # version sort
    )
}

## exec
FN="`get_names_and_files "$@"`"

REGISTRY='registry.access.redhat.com/rhscl'
OSNAME='rhel'
main "$@" <<< "$FN"

REGISTRY='centos'
OSNAME='centos'
main "$@" <<< "$FN"
exit 0

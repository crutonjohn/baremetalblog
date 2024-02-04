#!/usr/bin/env bash

TITLE=${1:-}
BUNDLE=${2:-}
OUT_PATH=${3:-}

TITLE_SLUG="$(echo -n "$TITLE" | sed -e 's/[^[:alnum:]]/-/g' | tr -s '-' | tr A-Z a-z)"
DATE="$(date +"%F")"
SLUG="$DATE-$TITLE_SLUG"

git checkout -b "$SLUG"
hugo new --kind $BUNDLE post/$OUT_PATH/$SLUG


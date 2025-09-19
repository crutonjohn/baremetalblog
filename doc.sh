#!/usr/bin/env bash

TITLE=${1:-}
BUNDLE=${2:-}
OUT_PATH=${3:-}

TITLE_SLUG="$(echo -n "$TITLE" | sed -e 's/[^[:alnum:]]/-/g' | tr -s '-' | tr A-Z a-z)"
SLUG="$TITLE_SLUG"

hugo new --kind $BUNDLE docs/$OUT_PATH/$SLUG


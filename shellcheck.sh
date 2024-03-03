#!/bin/sh
TARGETS='
  shellcheck.sh
  bin/bsky
  lib/bsky_core.sh
  lib/util.sh
  lib/api/*
'

for TARGET in $TARGETS
do
  echo "shellcheck >>>> ${TARGET}"
  shellcheck "${TARGET}"
done


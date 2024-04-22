#!/bin/sh
# Bluesky in the shell
# A Bluesky CLI (Command Line Interface) implementation in shell script
# Author Bluesky:@billsbs.bills-appworks.net
# 
# Copyright (c) 2024 bills-appworks
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

# recommend to use at pre-commit

TARGETS='
  shellcheck.sh
  bin/bsky
  lib/bsky_core.sh
  lib/util.sh
  lib/api/*
'

STATUS_MAX=0
for TARGET in $TARGETS
do
  echo "shellcheck >>>> ${TARGET}"
# if checking SC1090:source to resource config file, set source-path to home directory
##  shellcheck --source-path="${HOME}" "$@" "${TARGET}"
  shellcheck "$@" "${TARGET}"
  STATUS=$?
  if [ $STATUS -gt $STATUS_MAX ]
  then
    STATUS_MAX=$STATUS
  fi
done
exit $STATUS_MAX

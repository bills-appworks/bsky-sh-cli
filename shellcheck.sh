#!/bin/sh
# Bluesky in the shell
# A Bluesky CLI (Command Line Interface) implementation in shell script
# Author Bluesky:@billsbs.bills-appworks.net
# 
# Copyright (c) 2024 bills-appworks
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

# recommend to use at pre-commit

targets='
  shellcheck.sh
  bin/bsky
  lib/bsky_core.sh
  lib/util.sh
  lib/api/*
'

status_max=0
for target in $targets
do
  echo "shellcheck >>>> ${target}"
# if checking SC1090:source to resource config file, set source-path to home directory
##  shellcheck --source-path="${HOME}" "$@" "${target}"
  shellcheck "$@" "${target}"
  status=$?
  if [ $status -gt $status_max ]
  then
    status_max=$status
  fi
done
exit $status_max

#!/bin/sh
# Bluesky in the shell
# A Bluesky CLI (Command Line Interface) implemented with shell script
# Author Bluesky:@billsbs.bills-appworks.net
# 
# Copyright (c) 2024 bills-appworks
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php
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


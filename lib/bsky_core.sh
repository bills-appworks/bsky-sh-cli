#!/bin/sh
# Bluesky in the shell
# A Bluesky CLI (Command Line Interface) implementation in shell script
# Author Bluesky:@billsbs.bills-appworks.net
# 
# Copyright (c) 2024 bills-appworks
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php
FILE_DIR=`dirname "$0"`
FILE_DIR=`(cd "${FILE_DIR}" && pwd)`

core_create_session()
{
  HANDLE="$1"
  PASSWORD="$2"

  debug 'core_create_session' 'START'
  debug 'core_create_session' "HANDLE:${HANDLE}"
# WARNING: parameters may contain sensitive information (e.g. passwords) and will remain in the debug log
#  debug 'core_create_session' "PASSWORD:${PASSWORD}"

  api com.atproto.server.createSession "${HANDLE}" "${PASSWORD}" > /dev/null

  debug 'core_create_session' 'END'
}

core_get_timeline()
{
  debug 'core_get_timeline' 'START'

  debug_single 'core_get_timeline'
  RESULT=`api app.bsky.feed.getTimeline | $ESCAPE_NEWLINE | tee "$BSKYSHCLI_DEBUG_SINGLE"`

#  FEED_COUNT=`echo "${RESULT}" | $ESCAPE_NEWLINE | jq '.feed | length'`
  echo "${RESULT}" | $ESCAPE_NEWLINE | jq -r 'foreach .feed[] as $feed (0; 0; 
$feed.post.record.createdAt | [split(".")[0],"Z"] | join("") | fromdate | strflocaltime("%F %X(%Z)") as $postCreatedAt |
"\($feed.post.author.displayName) @\($feed.post.author.handle) \($postCreatedAt)
\($feed.post.record.text)
Reply:\($feed.post.replyCount) Repost:\($feed.post.repostCount) Like:\($feed.post.likeCount)
")'

  debug 'core_get_timeline' 'END'
}


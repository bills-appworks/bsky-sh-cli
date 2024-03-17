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
  if [ -n "${PASSWORD}" ]
  then
    MESSAGE='(defined)'
  else
    MESSAGE='(empty)'
  fi
  debug 'core_create_session' "PASSWORD:${MESSAGE}"

  api com.atproto.server.createSession "${HANDLE}" "${PASSWORD}" > /dev/null
  API_STATUS=$?

  debug 'core_create_session' 'END'

  return $API_STATUS
}

core_get_timeline()
{
  debug 'core_get_timeline' 'START'

  debug_single 'core_get_timeline'
  RESULT=`api app.bsky.feed.getTimeline | $ESCAPE_NEWLINE | tee "$BSKYSHCLI_DEBUG_SINGLE"`

#  FEED_COUNT=`echo "${RESULT}" | $ESCAPE_NEWLINE | jq '.feed | length'`
  echo "${RESULT}" | $ESCAPE_NEWLINE | jq -r 'foreach .feed[] as $feed (0; 0; 
$feed.post.record.createdAt | . as $raw | if test("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3}Z") then [split(".")[0],"Z"] | join("") else . end | try fromdate catch $raw | try
strflocaltime("%F %X(%Z)") catch $raw | . as $postCreatedAt |
"\($feed.post.author.displayName) @\($feed.post.author.handle) \($postCreatedAt)
\($feed.post.record.text)
Reply:\($feed.post.replyCount) Repost:\($feed.post.repostCount) Like:\($feed.post.likeCount)
")'

  debug 'core_get_timeline' 'END'
}

core_post()
{
  TEXT="$1"

  debug 'core_post' 'START'
  debug 'core_post' "TEXT:${TEXT}"

  read_session_file
  REPO="${SESSION_HANDLE}"
  COLLECTION='app.bsky.feed.post'
  CREATEDAT=`get_ISO8601UTCbs`
  RECORD="{\"text\":\"${TEXT}\",\"createdAt\":\"${CREATEDAT}\"}"

  debug_single 'core_post'
  RESULT=`api com.atproto.repo.createRecord "${REPO}" "${COLLECTION}" '' '' "${RECORD}" ''  | tee "$BSKYSHCLI_DEBUG_SINGLE"`
  echo "${RESULT}" | jq -r '"uri:\(.uri)
cid:\(.cid)
text:'"${TEXT}"'"'

  debug 'core_post' 'END'
}


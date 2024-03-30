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

CURSOR_TERMINATE='<<CURSOR_TERMINATE>>'

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

core_delete_session()
{
  debug 'core_delete_session' 'START'

  api com.atproto.server.deleteSession "${SESSION_REFRESH_JWT}" > /dev/null
  API_STATUS=$?

  debug 'core_delete_session' 'END'

  return $API_STATUS
}

core_get_timeline()
{
  PARAM_ALGORITHM="$1"
  PARAM_LIMIT="$2"
  PARAM_NEXT="$3"
  PARAM_OUTPUT_ID="$4"

  debug 'core_get_timeline' 'START'
  debug 'core_get_timeline' "PARAM_NEXT:${PARAM_ALGORITHM}"
  debug 'core_get_timeline' "PARAM_NEXT:${PARAM_LIMIT}"
  debug 'core_get_timeline' "PARAM_NEXT:${PARAM_NEXT}"
  debug 'core_get_timeline' "PARAM_NEXT:${PARAM_OUTPUT_ID}"

  read_session_file
  if [ -n "${PARAM_NEXT}" ]
  then
    CURSOR="${SESSION_GETTIMELINE_CURSOR}"
    if [ "${CURSOR}" = "${CURSOR_TERMINATE}" ]
    then
      error 'next feeds not found'
    fi
  else
    CURSOR=''
  fi
  debug_single 'core_get_timeline'
  RESULT=`api app.bsky.feed.getTimeline "${PARAM_ALGORITHM}" "${PARAM_LIMIT}" "${CURSOR}" | tee "$BSKYSHCLI_DEBUG_SINGLE"`

  if [ -n "${PARAM_OUTPUT_ID}" ]
  then
    _p "${RESULT}" | jq -r '.feed | to_entries | foreach .[] as $feed_entry (0; 0; 
$feed_entry.value.post.record.createdAt | . as $raw | if test("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3}Z") then [split(".")[0],"Z"] | join("") else . end | try fromdate catch $raw | try
strflocaltime("%F %X(%Z)") catch $raw | . as $postCreatedAt |
"[ViewIndex:\($feed_entry.key + 1)] [uri:\($feed_entry.value.post.uri)] [cid:\($feed_entry.value.post.cid)]
\($feed_entry.value.post.author.displayName) @\($feed_entry.value.post.author.handle) \($postCreatedAt)
\($feed_entry.value.post.record.text)
Reply:\($feed_entry.value.post.replyCount) Repost:\($feed_entry.value.post.repostCount) Like:\($feed_entry.value.post.likeCount)
")'
  else
    _p "${RESULT}" | jq -r '.feed | to_entries | foreach .[] as $feed_entry (0; 0; 
$feed_entry.value.post.record.createdAt | . as $raw | if test("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3}Z") then [split(".")[0],"Z"] | join("") else . end | try fromdate catch $raw | try
strflocaltime("%F %X(%Z)") catch $raw | . as $postCreatedAt |
"[ViewIndex:\($feed_entry.key + 1)]
\($feed_entry.value.post.author.displayName) @\($feed_entry.value.post.author.handle) \($postCreatedAt)
\($feed_entry.value.post.record.text)
Reply:\($feed_entry.value.post.replyCount) Repost:\($feed_entry.value.post.repostCount) Like:\($feed_entry.value.post.likeCount)
")'
  fi
  CURSOR=`_p "${RESULT}" | jq -r '.cursor // "'"${CURSOR_TERMINATE}"'" | @sh'`
  VIEW_INDEX=`_p "${RESULT}" | jq -r -j '.feed | to_entries | foreach .[] as $feed_entry (0; 0; "\($feed_entry.key + 1)|\($feed_entry.value.post.uri)|\($feed_entry.value.post.cid)||")'`
  update_session_file "${SESSION_KEY_GETTIMELINE_CURSOR}=${CURSOR} ${SESSION_KEY_VIEW_INDEX}=${VIEW_INDEX}"

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
  _p "${RESULT}" | jq -r '"uri:\(.uri)
cid:\(.cid)
text:'"${TEXT}"'"
'

  debug 'core_post' 'END'
}


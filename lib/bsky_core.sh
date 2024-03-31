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

core_get_feed_view_index()
{
  PARAM_FEED_VIEW_INDEX=$1

  debug 'core_get_feed_view_index' 'START'
  debug 'core_get_feed_view_index' "PARAM_FEED_VIEW_INDEX:${PARAM_VIEW_INDEX}"

  read_session_file
  _slice "${SESSION_FEED_VIEW_INDEX}" '"'
  FEED_VIEW_INDEX_COUNT=$?
  if [ "${PARAM_FEED_VIEW_INDEX}" -gt "${FEED_VIEW_INDEX_COUNT}" ]
  then
    error "specified index (${PARAM_FEED_VIEW_INDEX}) greater than maximum index (${FEED_VIEW_INDEX_COUNT})"
  fi
  FEED_VIEW_INDEX_ELEMENT=`eval _p \"\\$"RESULT_slice_${PARAM_FEED_VIEW_INDEX}"\"`
  _slice "${FEED_VIEW_INDEX_ELEMENT}" '|'
  # dynamic assignment in parse_parameters
  # shellcheck disable=SC2154
  FEED_VIEW_INDEX_ELEMENT_INDEX="${RESULT_slice_1}"
  # dynamic assignment in parse_parameters
  # shellcheck disable=SC2154
  # variable use at this file include(source) script
  # shellcheck disable=SC2034
  FEED_VIEW_INDEX_ELEMENT_URI="${RESULT_slice_2}"
  # dynamic assignment in parse_parameters
  # shellcheck disable=SC2154
  # variable use at this file include(source) script
  # shellcheck disable=SC2034
  FEED_VIEW_INDEX_ELEMENT_CID="${RESULT_slice_3}"
  if [ "${FEED_VIEW_INDEX_ELEMENT_INDEX}" -ne "${PARAM_FEED_VIEW_INDEX}" ]
  then
    error "internal error: specified index:${PARAM_FEED_VIEW_INDEX} session index:${FEED_VIEW_INDEX_ELEMENT_INDEX}" 
  fi

  debug 'core_get_feed_view_index' 'END'
}

core_parse_at_uri()
{
  PARAM_PARSE_AT_URI=$1

  debug 'core_parse_at_uri' 'START'
  debug 'core_parse_at_uri' "PARAM_PARSE_AT_URI:${PARAM_PARSE_AT_URI}"

  _slice "${PARAM_PARSE_AT_URI}" '/'
  AT_URI_ELEMENT_COUNT=$?
  AT_URI_ELEMENT_SCHEME="${RESULT_slice_1}/${RESULT_slice_2}/"
  if [ "${AT_URI_ELEMENT_SCHEME}" != 'at://' ]
  then
    error "specified uri (${PARAM_PARSE_AT_URI}) is not AT URI (at://)"
  fi
  AT_URI_ELEMENT_AUTHORITY="${RESULT_slice_3}"
  # dynamic assignment in parse_parameters
  # shellcheck disable=SC2154
  AT_URI_ELEMENT_COLLECTION="${RESULT_slice_4}"
  # dynamic assignment in parse_parameters
  # shellcheck disable=SC2154
  AT_URI_ELEMENT_RKEY="${RESULT_slice_5}"

  debug 'core_parse_at_uri' 'END'

  return "${AT_URI_ELEMENT_COUNT}"
}

core_build_reply_fragment()
{
  PARAM_REPLY_TARGET_URI=$1
  PARAM_REPLY_TARGET_CID=$2

  debug 'core_build_reply_fragment' 'START'
  debug 'core_build_reply_fragment' "PARAM_REPLY_TARGET_URI:${PARAM_REPLY_TARGET_URI}"
  debug 'core_build_reply_fragment' "PARAM_REPLY_TARGET_CID:${PARAM_REPLY_TARGET_CID}"

  core_parse_at_uri "${PARAM_REPLY_TARGET_URI}"
  if [ -z "${AT_URI_ELEMENT_AUTHORITY}" ] || [ -z "${AT_URI_ELEMENT_COLLECTION}" ] || [ -z "${AT_URI_ELEMENT_RKEY}" ]
  then
    error "insufficiency in AT URI composition - URI:${PARAM_URI} AUTHORITY:${AT_URI_ELEMENT_AUTHORITY} COLLECTION:${AT_URI_ELEMENT_COLLECTION} RKEY:${AT_URI_ELEMENT_RKEY}"
  fi
  RESULT=`api com.atproto.repo.getRecord "${AT_URI_ELEMENT_AUTHORITY}" "${AT_URI_ELEMENT_COLLECTION}" "${AT_URI_ELEMENT_RKEY}"`
  debug_single 'core_build_reply_fragment'
  _p "${RESULT}" | jq -c 'if (.value|has("reply")) then .+ {root_uri:.value.reply.root.uri,root_cid:.value.reply.root.cid} else .+ {root_uri:.uri,root_cid:.cid} end | {reply:{root:{uri:.root_uri,cid:.root_cid},parent:{uri:.uri,cid:.cid}}}' | sed 's/^.\(.*\).$/\1/' | tee "${BSKYSHCLI_DEBUG_SINGLE}"

  debug 'core_build_reply_fragment' 'END'
}

core_build_subject_fragment()
{
  PARAM_SUBJECT_URI=$1
  PARAM_SUBJECT_CID=$2

  debug 'core_build_subject_fragment' 'START'
  debug 'core_build_subject_fragment' "PARAM_SUBJECT_URI:${PARAM_SUBJECT_URI}"
  debug 'core_build_subject_fragment' "PARAM_SUBJECT_CID:${PARAM_SUBJECT_CID}"
  _p "\"subject\":{\"uri\":\"${PARAM_SUBJECT_URI}\",\"cid\":\"${PARAM_SUBJECT_CID}\"}"

  debug 'core_build_subject_fragment' 'END'
}

core_build_embed_fragment()
{
  PARAM_EMBED_URI=$1
  PARAM_EMBED_CID=$2

  debug 'core_build_embed_fragment' 'START'
  debug 'core_build_embed_fragment' "PARAM_EMBED_URI:${PARAM_EMBED_URI}"
  debug 'core_build_embed_fragment' "PARAM_EMBED_CID:${PARAM_EMBED_CID}"
  _p "\"embed\":{\"\$type\":\"app.bsky.embed.record\",\"record\":{\"uri\":\"${PARAM_EMBED_URI}\",\"cid\":\"${PARAM_EMBED_CID}\"}}"

  debug 'core_build_embed_fragment' 'END'
}

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
  FEED_VIEW_INDEX=`_p "${RESULT}" | jq -r -j '.feed | to_entries | foreach .[] as $feed_entry (0; 0; "\($feed_entry.key + 1)|\($feed_entry.value.post.uri)|\($feed_entry.value.post.cid)\"")' | sed 's/.$//'`
  update_session_file "${SESSION_KEY_GETTIMELINE_CURSOR}=${CURSOR} ${SESSION_KEY_FEED_VIEW_INDEX}=${FEED_VIEW_INDEX}"

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

core_reply()
{
  PARAM_REPLY_TARGET_URI="$1"
  PARAM_REPLY_TARGET_CID="$2"
  PARAM_REPLY_TEXT="$3"

  debug 'core_reply' 'START'
  debug 'core_reply' "PARAM_REPLY_TARGET_URI:${PARAM_REPLY_TARGET_URI}"
  debug 'core_reply' "PARAM_REPLY_TARGET_CID:${PARAM_REPLY_TARGET_CID}"
  debug 'core_reply' "PARAM_REPLY_TEXT:${PARAM_REPLY_TEXT}"

  REPLY_FRAGMENT=`core_build_reply_fragment "${PARAM_REPLY_TARGET_URI}" "${PARAM_REPLY_TARGET_CID}"`

  read_session_file
  REPO="${SESSION_HANDLE}"
  COLLECTION='app.bsky.feed.post'
  CREATEDAT=`get_ISO8601UTCbs`
  RECORD="{\"text\":\"${PARAM_REPLY_TEXT}\",\"createdAt\":\"${CREATEDAT}\",${REPLY_FRAGMENT}}"

  debug_single 'core_reply'
  RESULT=`api com.atproto.repo.createRecord "${REPO}" "${COLLECTION}" '' '' "${RECORD}" ''  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  _p "${RESULT}" | jq -r '"uri:\(.uri)
cid:\(.cid)
text:'"${PARAM_REPLY_TEXT}"'"
'

  debug 'core_reply' 'END'
}

core_repost()
{
  PARAM_REPOST_TARGET_URI="$1"
  PARAM_REPOST_TARGET_CID="$2"

  debug 'core_repost' 'START'
  debug 'core_repost' "PARAM_REPOST_TARGET_URI:${PARAM_REPOST_TARGET_URI}"
  debug 'core_repost' "PARAM_REPOST_TARGET_CID:${PARAM_REPOST_TARGET_CID}"

  SUBJECT_FRAGMENT=`core_build_subject_fragment "${PARAM_REPOST_TARGET_URI}" "${PARAM_REPOST_TARGET_CID}"`

  read_session_file
  REPO="${SESSION_HANDLE}"
  COLLECTION='app.bsky.feed.repost'
  CREATEDAT=`get_ISO8601UTCbs`
  RECORD="{\"createdAt\":\"${CREATEDAT}\",${SUBJECT_FRAGMENT}}"

  debug_single 'core_repost'
  RESULT=`api com.atproto.repo.createRecord "${REPO}" "${COLLECTION}" '' '' "${RECORD}" ''  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  _p "${RESULT}" | jq -r '"uri:\(.uri)
cid:\(.cid)"'

  debug 'core_repost' 'END'
}

core_quote()
{
  PARAM_QUOTE_TARGET_URI="$1"
  PARAM_QUOTE_TARGET_CID="$2"
  PARAM_QUOTE_TEXT="$3"

  debug 'core_quote' 'START'
  debug 'core_quote' "PARAM_QUOTE_TARGET_URI:${PARAM_QUOTE_TARGET_URI}"
  debug 'core_quote' "PARAM_QUOTE_TARGET_CID:${PARAM_QUOTE_TARGET_CID}"
  debug 'core_quote' "PARAM_QUOTE_TEXT:${PARAM_QUOTE_TEXT}"

  EMBED_FRAGMENT=`core_build_embed_fragment "${PARAM_QUOTE_TARGET_URI}" "${PARAM_QUOTE_TARGET_CID}"`

  read_session_file
  REPO="${SESSION_HANDLE}"
  COLLECTION='app.bsky.feed.post'
  CREATEDAT=`get_ISO8601UTCbs`
  RECORD="{\"text\":\"${PARAM_QUOTE_TEXT}\",\"createdAt\":\"${CREATEDAT}\",${EMBED_FRAGMENT}}"

  debug_single 'core_quote'
  RESULT=`api com.atproto.repo.createRecord "${REPO}" "${COLLECTION}" '' '' "${RECORD}" ''  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  _p "${RESULT}" | jq -r '"uri:\(.uri)
cid:\(.cid)
text:'"${PARAM_QUOTE_TEXT}"'"
'

  debug 'core_quote' 'END'
}

core_like()
{
  PARAM_LIKE_TARGET_URI="$1"
  PARAM_LIKE_TARGET_CID="$2"

  debug 'core_like' 'START'
  debug 'core_like' "PARAM_LIKE_TARGET_URI:${PARAM_LIKE_TARGET_URI}"
  debug 'core_like' "PARAM_LIKE_TARGET_CID:${PARAM_LIKE_TARGET_CID}"

  SUBJECT_FRAGMENT=`core_build_subject_fragment "${PARAM_LIKE_TARGET_URI}" "${PARAM_LIKE_TARGET_CID}"`

  read_session_file
  REPO="${SESSION_HANDLE}"
  COLLECTION='app.bsky.feed.like'
  CREATEDAT=`get_ISO8601UTCbs`
  RECORD="{\"createdAt\":\"${CREATEDAT}\",${SUBJECT_FRAGMENT}}"

  debug_single 'core_like'
  RESULT=`api com.atproto.repo.createRecord "${REPO}" "${COLLECTION}" '' '' "${RECORD}" ''  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  _p "${RESULT}" | jq -r '"uri:\(.uri)
cid:\(.cid)"'

  debug 'core_like' 'END'
}


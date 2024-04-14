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

# $<variables> want to pass through for jq
# shellcheck disable=SC2016
VIEW_TEMPLATE_CREATED_AT='
  . as $raw |
  if test("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3}Z")
  then
    [split(".")[0],"Z"] | join("")
  else
    .
  end |
  try fromdate catch $raw |
  try strflocaltime("%F %X(%Z)") catch $raw
'
CURSOR_TERMINATE='<<CURSOR_TERMINATE>>'

core_get_feed_view_index()
{
  PARAM_FEED_VIEW_INDEX=$1

  debug 'core_get_feed_view_index' 'START'
  debug 'core_get_feed_view_index' "PARAM_FEED_VIEW_INDEX:${PARAM_VIEW_INDEX}"

  read_session_file
  _slice "${SESSION_FEED_VIEW_INDEX}" '"'
  FEED_VIEW_INDEX_COUNT=$?
  CHUNK_INDEX=1
  while [ "${CHUNK_INDEX}" -le $FEED_VIEW_INDEX_COUNT ]
  do
    SESSION_CHUNK=`eval _p \"\\$"RESULT_slice_${CHUNK_INDEX}"\"`
    SESSION_CHUNK_INDEX=`_p "${SESSION_CHUNK}" | sed 's/^\([^|]*\)|.*/\1/g'`
    if [ "${SESSION_CHUNK_INDEX}" = "${PARAM_FEED_VIEW_INDEX}" ]
    then
      break
    fi
    CHUNK_INDEX=`expr "${CHUNK_INDEX}" + 1`
  done
  if [ "${CHUNK_INDEX}" -gt $FEED_VIEW_INDEX_COUNT ]
  then
    error "specified index is not found in session: ${PARAM_FEED_VIEW_INDEX}"
  fi
  _slice "${SESSION_CHUNK}" '|'
  # dynamic assignment in parse_parameters
  # shellcheck disable=SC2154
  FEED_VIEW_INDEX_ELEMENT_INDEX="${RESULT_slice_1}"
  # dynamic assignment in parse_parameters, variable use at this file include(source) script
  # shellcheck disable=SC2154,SC2034
  FEED_VIEW_INDEX_ELEMENT_URI="${RESULT_slice_2}"
  # dynamic assignment in parse_parameters, variable use at this file include(source) script
  # shellcheck disable=SC2154,SC2034
  FEED_VIEW_INDEX_ELEMENT_CID="${RESULT_slice_3}"
  if [ "${FEED_VIEW_INDEX_ELEMENT_INDEX}" != "${PARAM_FEED_VIEW_INDEX}" ]
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

core_create_post_chunk()
{
  PARAM_OUTPUT_ID="$1"

  debug 'core_create_post_chunk' 'START'
  debug 'core_create_post_chunk' "PARAM_OUTPUT_ID:${PARAM_OUTPUT_ID}"

  if [ -n "${PARAM_OUTPUT_ID}" ]
  then
    # escape for substitution at placeholder replacement 
    VIEW_POST_OUTPUT_ID=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID}" | sed 's/\\\\/\\\\\\\\/g'`
  else
    VIEW_POST_OUTPUT_ID=''
  fi
  VIEW_TEMPLATE_POST_META=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_META}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${VIEW_POST_OUTPUT_ID}"'/g'`
  VIEW_TEMPLATE_POST_HEAD=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_HEAD}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${VIEW_POST_OUTPUT_ID}"'/g'`
  VIEW_TEMPLATE_POST_BODY=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_BODY}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${VIEW_POST_OUTPUT_ID}"'/g'`
  VIEW_TEMPLATE_POST_TAIL=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${VIEW_POST_OUTPUT_ID}"'/g'`
  VIEW_TEMPLATE_POST_SEPARATOR=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_SEPARATOR}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${VIEW_POST_OUTPUT_ID}"'/g'`
  VIEW_TEMPLATE_QUOTED_POST_META=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${VIEW_TEMPLATE_POST_META}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  VIEW_TEMPLATE_QUOTED_POST_HEAD=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${VIEW_TEMPLATE_POST_HEAD}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  VIEW_TEMPLATE_QUOTED_POST_BODY=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${VIEW_TEMPLATE_POST_BODY}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  # $<variables> want to pass through for jq
  # shellcheck disable=SC2016
  _p 'def output_post(view_index; post_fragment):
        view_index as $VIEW_INDEX |
        post_fragment.uri as $URI |
        post_fragment.cid as $CID |
        post_fragment.author.displayName as $AUTHOR_DISPLAYNAME |
        post_fragment.author.handle as $AUTHOR_HANDLE |
        post_fragment.record.createdAt | '"${VIEW_TEMPLATE_CREATED_AT}"' | . as $CREATED_AT |
        post_fragment.record.text as $TEXT |
        post_fragment.replyCount as $REPLY_COUNT |
        post_fragment.repostCount as $REPOST_COUNT |
        post_fragment.likeCount as $LIKE_COUNT |
        "'"${VIEW_TEMPLATE_POST_META}"'",
        "'"${VIEW_TEMPLATE_POST_HEAD}"'",
        "'"${VIEW_TEMPLATE_POST_BODY}"'",
        (
          post_fragment |
          if has("embed")
          then
            ([view_index, "1"] | join("-")) as $VIEW_INDEX |
            post_fragment.embed.record.uri as $URI |
            post_fragment.embed.record.cid as $CID |
            post_fragment.embed.record.author.displayName as $AUTHOR_DISPLAYNAME |
            post_fragment.embed.record.author.handle as $AUTHOR_HANDLE |
            post_fragment.embed.record.value.createdAt | '"${VIEW_TEMPLATE_CREATED_AT}"' | . as $CREATED_AT |
            (post_fragment.embed.record.value.text | gsub("\n"; "\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'")) as $TEXT |
            "'"${VIEW_TEMPLATE_QUOTED_POST_META}"'",
            "'"${VIEW_TEMPLATE_QUOTED_POST_HEAD}"'",
            "'"${VIEW_TEMPLATE_QUOTED_POST_BODY}"'"
          else
            empty
          end
        ),
        "'"${VIEW_TEMPLATE_POST_TAIL}"'",
        "'"${VIEW_TEMPLATE_POST_SEPARATOR}"'"
      ;
     '

  debug 'core_create_post_chunk' 'END'
}

core_create_session_chunk()
{

  debug 'core_create_session_chunk' 'START'

  # $<variables> want to pass through for jq
  # shellcheck disable=SC2016
  VIEW_SESSION_PLACEHOLDER='\($VIEW_INDEX)|\($URI)|\($CID)\"'
  # shellcheck disable=SC2016
  _p 'def output_post(view_index; post_fragment):
        view_index as $VIEW_INDEX |
        post_fragment.uri as $URI |
        post_fragment.cid as $CID |
        "'"${VIEW_SESSION_PLACEHOLDER}"'",
        (
          post_fragment |
          if has("embed")
          then
            ([view_index, "1"] | join("-")) as $VIEW_INDEX |
            post_fragment.embed.record.uri as $URI |
            post_fragment.embed.record.cid as $CID |
            "'"${VIEW_SESSION_PLACEHOLDER}"'"
          else
            empty
          end
        )
      ;
     '

  debug 'core_create_session_chunk' 'END'
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
  PARAM_TIMELINE_ALGORITHM="$1"
  PARAM_TIMELINE_LIMIT="$2"
  PARAM_TIMELINE_NEXT="$3"
  PARAM_TIMELINE_OUTPUT_ID="$4"

  debug 'core_get_timeline' 'START'
  debug 'core_get_timeline' "PARAM_TIMELINE_NEXT:${PARAM_TIMELINE_ALGORITHM}"
  debug 'core_get_timeline' "PARAM_TIMELINE_NEXT:${PARAM_TIMELINE_LIMIT}"
  debug 'core_get_timeline' "PARAM_TIMELINE_NEXT:${PARAM_TIMELINE_NEXT}"
  debug 'core_get_timeline' "PARAM_TIMELINE_NEXT:${PARAM_TIMELINE_OUTPUT_ID}"

  read_session_file
  if [ -n "${PARAM_TIMELINE_NEXT}" ]
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
  RESULT=`api app.bsky.feed.getTimeline "${PARAM_TIMELINE_ALGORITHM}" "${PARAM_TIMELINE_LIMIT}" "${CURSOR}" | tee "$BSKYSHCLI_DEBUG_SINGLE"`

  VIEW_POST_FUNCTIONS=`core_create_post_chunk "${PARAM_TIMELINE_OUTPUT_ID}"`
  # $<variables> want to pass through for jq
  # shellcheck disable=SC2016
  TIMELINE_PARSE_PROCEDURE='
    .feed |
    to_entries |
    foreach .[] as $feed_entry (0; 0;
      $feed_entry.value.post as $post_fragment |
      ($feed_entry.key + 1) as $view_index |
      output_post($view_index; $post_fragment)
    )
  '
  _p "${RESULT}" | jq -r "${VIEW_POST_FUNCTIONS}${TIMELINE_PARSE_PROCEDURE}"

  CURSOR=`_p "${RESULT}" | jq -r '.cursor // "'"${CURSOR_TERMINATE}"'"'`
  VIEW_SESSION_FUNCTIONS=`core_create_session_chunk`
  FEED_VIEW_INDEX=`_p "${RESULT}" | jq -r -j "${VIEW_SESSION_FUNCTIONS}${TIMELINE_PARSE_PROCEDURE}" | sed 's/.$//'`
  # CAUTION: key=value pairs are separated by tab characters
  update_session_file "${SESSION_KEY_GETTIMELINE_CURSOR}=${CURSOR}	${SESSION_KEY_FEED_VIEW_INDEX}=${FEED_VIEW_INDEX}"

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

core_thread()
{
  PARAM_THREAD_TARGET_URI="$1"
  PARAM_THREAD_DEPTH="$2"
  PARAM_THREAD_PARENT_HEIGHT="$3"
  PARAM_THREAD_OUTPUT_ID="$4"

  debug 'core_thread' 'START'
  debug 'core_thread' "PARAM_THREAD_TARGET_URI:${PARAM_THREAD_TARGET_URI}"
  debug 'core_thread' "PARAM_THREAD_DEPTH:${PARAM_THREAD_DEPTH}"
  debug 'core_thread' "PARAM_THREAD_PARENT_HEIGHT:${PARAM_THREAD_PARENT_HEIGHT}"

  debug_single 'core_thread'
  RESULT=`api app.bsky.feed.getPostThread "${PARAM_THREAD_TARGET_URI}" "${PARAM_THREAD_DEPTH}" "${PARAM_THREAD_PARENT_HEIGHT}"  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`

  VIEW_POST_FUNCTIONS=`core_create_post_chunk "${PARAM_THREAD_OUTPUT_ID}"`
  # $<variables> want to pass through for jq
  # shellcheck disable=SC2016
  THREAD_PARSE_PROCEDURE_PARENTS='
    def output_parents:
      .parent |
      [recurse(.parent; . != null)] |
      to_entries |
      reverse |
      foreach .[] as $feed_entry (0; 0;
        ($feed_entry.key * -1 - 1) as $view_index |
        $feed_entry.value.post as $post_fragment |
        output_post($view_index; $post_fragment)
      );
    .thread |
    if has("parent")
    then
      output_parents
    else
      empty
    end
  '
  # shellcheck disable=SC2016
  THREAD_PARSE_PROCEDURE_TARGET='
    0 as $view_index |
    .thread.post as $post_fragment |
    output_post($view_index; $post_fragment)
  '
  # shellcheck disable=SC2016
  THREAD_PARSE_PROCEDURE_REPLIES='
    def output_replies(node; sibling_index; index_str):
      node as $node |
      sibling_index as $sibling_index |
      index_str as $index_str |
      $node.post as $post_fragment |
      $index_str[1:] as $view_index |
      $node.replies |
      reverse |
      if $sibling_index == 0
      then
        empty
      else
        output_post($view_index; $post_fragment)
      end,
      foreach .[] as $reply (0; . + 1;
        output_replies($reply; .; "\($index_str)-\(.)")
      )
    ;
    output_replies(.thread; 0; "")
  '
  _p "${RESULT}" | jq -r "${VIEW_POST_FUNCTIONS}${THREAD_PARSE_PROCEDURE_PARENTS}"
  _p "${RESULT}" | jq -r "${VIEW_POST_FUNCTIONS}${THREAD_PARSE_PROCEDURE_TARGET}"
  _p "${RESULT}" | jq -r "${VIEW_POST_FUNCTIONS}${THREAD_PARSE_PROCEDURE_REPLIES}"

  VIEW_SESSION_FUNCTIONS=`core_create_session_chunk`
  FEED_VIEW_INDEX_PARENTS=`_p "${RESULT}" | jq -r -j "${VIEW_SESSION_FUNCTIONS}${THREAD_PARSE_PROCEDURE_PARENTS}"`
  FEED_VIEW_INDEX_TARGET=`_p "${RESULT}" | jq -r -j "${VIEW_SESSION_FUNCTIONS}${THREAD_PARSE_PROCEDURE_TARGET}"`
  FEED_VIEW_INDEX_REPLIES=`_p "${RESULT}" | jq -r -j "${VIEW_SESSION_FUNCTIONS}${THREAD_PARSE_PROCEDURE_REPLIES}" | sed 's/.$//'`
  FEED_VIEW_INDEX="${FEED_VIEW_INDEX_PARENTS}${FEED_VIEW_INDEX_TARGET}${FEED_VIEW_INDEX_REPLIES}"
  # CAUTION: key=value pairs are separated by tab characters
  update_session_file "${SESSION_KEY_FEED_VIEW_INDEX}=${FEED_VIEW_INDEX}"

  debug 'core_thread' 'END'
}

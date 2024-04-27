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

BSKYSHCLI_DEFAULT_DOMAIN='.bsky.social'
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
# shellcheck disable=SC2016
FEED_PARSE_PROCEDURE='
  .feed |
  to_entries |
  foreach .[] as $feed_entry (0; 0;
    $feed_entry.value.post as $post_fragment |
    ($feed_entry.key + 1) as $view_index |
    output_post($view_index; $post_fragment)
  )
'
# shellcheck disable=SC2016
GENERAL_DUMP_PROCEDURE='
  def extract_nodes(nodes; indent):
    nodes as $nodes |
    indent as $indent |
    foreach .[] as $node (0; 0;
      $node |
      if type == "object"
      then
        $node.value |
        if type == "array"
        then
          (
            "\($indent)\($node.key):",
            extract_nodes($node; "\($indent)  ")
          )
        else
          "\($indent)\($node.key): \($node.value)"
        end
      elif type == "array"
      then
        (
          "\($indent)  --",
          extract_nodes($node; "\($indent)  ")
        )
      else
        "\($indent)\(.)"
      end
    )
  ;
  walk(
    if type == "object"
    then
      to_entries
    else
      .
    end
  ) |
  extract_nodes(.; "")
'
CURSOR_TERMINATE='<<CURSOR_TERMINATE>>'
FEED_GENERATOR_PATTERN_BSKYAPP_URL='^https://bsky\.app/profile/\([^/]*\)/feed/\([^/]*\)$'
#FEED_GENERATOR_PATTERN_AT_URI='^at://\([^/]*\)/app.bsky.feed.generator/\([^/]*\)$'

core_canonicalize_handle()
{
  PARAM_CANONICALIZE_HANDLE=$1

  debug 'core_canonicalize_handle' 'START'
  debug 'core_canonicalize_handle' "PARAM_CANONICALIZE_HANDLE:${PARAM_CANONICALIZE_HANDLE}"

  HANDLE_CHECK=`_p "${PARAM_CANONICALIZE_HANDLE}" | sed 's/[^.]//g'`
  if [ -z "${HANDLE_CHECK}" ]
  then
    PARAM_CANONICALIZE_HANDLE="${PARAM_CANONICALIZE_HANDLE}${BSKYSHCLI_DEFAULT_DOMAIN}"
  fi
  _p "${PARAM_CANONICALIZE_HANDLE}"

  debug 'core_canonicalize_handle' 'END'
}

core_verify_did()
{
  PARAM_VERIFY_DID=$1

  debug 'core_verify_did' 'START'
  debug 'core_verify_did' "PARAM_VERIFY_DID:${PARAM_VERIFY_DID}"

  if _startswith "${PARAM_VERIFY_DID}" 'did:'
  then
    :
  else
    error "specified did is invalid: ${PARAM_VERIFY_DID}"
  fi

  debug 'core_verify_did' 'END'
}

core_handle_to_did()
{
  PARAM_TO_DID_HANDLE=$1

  debug 'core_handle_to_did' 'START'
  debug 'core_handle_to_did' "PARAM_TO_DID_HANDLE:${PARAM_TO_DID_HANDLE}"

  PARAM_TO_DID_HANDLE=`core_canonicalize_handle "${PARAM_TO_DID_HANDLE}"`
  RESULT=`api com.atproto.identity.resolveHandle "${PARAM_TO_DID_HANDLE}"`
  STATUS=$?
  if [ $STATUS -eq 0 ]
  then
   _p "${RESULT}" | jq -r '.did'
  fi

  debug 'core_handle_to_did' 'END'

  return $STATUS
}

core_actor_to_did()
{
  PARAM_TO_DID_ACTOR=$1

  debug 'core_actor_to_did' 'START'
  debug 'core_actor_to_did' "PARAM_TO_DID_ACTOR:${PARAM_TO_DID_ACTOR}"

  if _startswith "${PARAM_TO_DID_ACTOR}" 'did:'
  then
    _p "${PARAM_TO_DID_ACTOR}"
    RESULT=0
  else
    core_handle_to_did "${PARAM_TO_DID_ACTOR}"
    RESULT=$?
  fi

  debug 'core_actor_to_did' 'END'

  return $RESULT
}

core_resolve_actor()
{
  PARAM_CORE_RESOLVE_ACTOR_ACTOR="$1"
  PARAM_CORE_RESOLVE_ACTOR_HANDLE="$2"
  PARAM_CORE_RESOLVE_ACTOR_DID="$3"

  debug 'core_resolve_actor' 'START'

  if [ -n "${PARAM_CORE_RESOLVE_ACTOR_ACTOR}" ]
  then
    DID=`core_actor_to_did "${PARAM_CORE_RESOLVE_ACTOR_ACTOR}"`
    STATUS=$?
  elif [ -n "${PARAM_CORE_RESOLVE_ACTOR_HANDLE}" ]
  then
    DID=`core_handle_to_did "${PARAM_CORE_RESOLVE_ACTOR_HANDLE}"`
    STATUS=$?
  elif [ -n "${PARAM_CORE_RESOLVE_ACTOR_DID}" ]
  then
    core_verify_did "${PARAM_CORE_RESOLVE_ACTOR_DID}"
    DID="${PARAM_CORE_RESOLVE_ACTOR_DID}"
    STATUS=0
  else
    DID=''
    STATUS=0
  fi
  _p "${DID}"

  debug 'core_resolve_actor' 'END'

  return $STATUS
}

core_is_actor_current_session()
{
  PARAM_CORE_IS_ACTOR_CURRENT_SESSION_ACTOR=$1

  debug 'core_is_actor_current_session' 'START'
  debug 'core_is_actor_current_session' "PARAM_CORE_IS_ACTOR_CURRENT_SESSION_ACTOR:${PARAM_CORE_IS_ACTOR_CURRENT_SESSION_ACTOR}"

  DID=`core_actor_to_did "${PARAM_CORE_IS_ACTOR_CURRENT_SESSION_ACTOR}"`
  STATUS=$?
  if [ $STATUS -eq 0 ]
  then
    read_session_file
    if [ "${DID}" = "${SESSION_DID}" ]
    then
      STATUS=0
    else
      STATUS=1
    fi
  fi

  debug 'core_is_actor_current_session' 'END'

  return $STATUS
}

core_is_feed_generator()
{
  PARAM_CORE_IS_FEED_GENERATOR_VERIFY_TARGET=$1

  debug 'core_is_feed_generator' 'START'
  debug 'core_is_feed_generator' "PARAM_CORE_IS_FEED_GENERATOR_VERIFY_TARGET:${PARAM_CORE_IS_FEED_GENERATOR_VERIFY_TARGET}"

  VERIFY_RESULT=`_p "${PARAM_CORE_IS_FEED_GENERATOR_VERIFY_TARGET}" | sed "s_${FEED_GENERATOR_PATTERN_BSKYAPP_URL}__g"`
  if [ -z "${VERIFY_RESULT}" ]
  then
    IS_FEED_GENERATOR=0
  else
    IS_FEED_GENERATOR=1
  fi

  debug 'core_is_feed_generator' 'END'

  return "${IS_FEED_GENERATOR}"
}

core_create_feed_at_uri_did_record_key()
{
  PARAM_CORE_CREATE_FEED_AT_URI_DID="$1"
  PARAM_CORE_CREATE_FEED_AT_URI_RECORD_KEY="$2"

  debug 'core_create_feed_at_uri_did_record_key' 'START'
  debug 'core_create_feed_at_uri_did_record_key' "PARAM_CORE_CREATE_FEED_AT_URI_DID:${PARAM_CORE_CREATE_FEED_AT_URI_DID}"
  debug 'core_create_feed_at_uri_did_record_key' "PARAM_CORE_CREATE_FEED_AT_URI_RECORD_KEY:${PARAM_CORE_CREATE_FEED_AT_URI_RECORD_KEY}"

  _p "at://${PARAM_CORE_CREATE_FEED_AT_URI_DID}/app.bsky.feed.generator/${PARAM_CORE_CREATE_FEED_AT_URI_RECORD_KEY}"

  debug 'core_create_feed_at_uri_did_record_key' 'END'
}

core_create_feed_at_uri_bsky_app_url()
{
  PARAM_CORE_CREATE_FEED_AT_URI_BSKY_APP_URL="$1"

  debug 'core_create_feed_at_uri_bsky_app_url' 'START'
  debug 'core_create_feed_at_uri_bsky_app_url' "PARAM_CORE_CREATE_FEED_AT_URI_BSKY_APP_URL:${PARAM_CORE_CREATE_FEED_AT_URI_BSKY_APP_URL}"

  ACTOR=`_p "${PARAM_CORE_CREATE_FEED_AT_URI_BSKY_APP_URL}" | sed "s_${FEED_GENERATOR_PATTERN_BSKYAPP_URL}_\1_g"`
  RECORD_KEY=`_p "${PARAM_CORE_CREATE_FEED_AT_URI_BSKY_APP_URL}" | sed "s_${FEED_GENERATOR_PATTERN_BSKYAPP_URL}_\2_g"`
  DID=`core_actor_to_did "${ACTOR}"`
  STATUS=$?
  if [ $STATUS -eq 0 ]
  then
    core_create_feed_at_uri_did_record_key "${DID}" "${RECORD_KEY}"
  fi

  debug 'core_create_feed_at_uri_bsky_app_url' 'END'

  return $STATUS
}

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
  VIEW_TEMPLATE_IMAGE=`_p "${BSKYSHCLI_VIEW_TEMPLATE_IMAGE}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${VIEW_POST_OUTPUT_ID}"'/g'`
  VIEW_TEMPLATE_POST_SEPARATOR=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_SEPARATOR}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${VIEW_POST_OUTPUT_ID}"'/g'`
  VIEW_TEMPLATE_QUOTED_POST_META=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${VIEW_TEMPLATE_POST_META}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  VIEW_TEMPLATE_QUOTED_POST_HEAD=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${VIEW_TEMPLATE_POST_HEAD}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  VIEW_TEMPLATE_QUOTED_POST_BODY=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${VIEW_TEMPLATE_POST_BODY}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  VIEW_TEMPLATE_QUOTED_IMAGE=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${VIEW_TEMPLATE_IMAGE}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  # $<variables> want to pass through for jq
  # shellcheck disable=SC2016
  _p 'def output_image(image; sibling_index; index_str; is_quoted):
        ([index_str, sibling_index] | join("-")) as $IMAGE_INDEX |
        image.alt as $ALT |
        image.thumb as $THUMB |
        image.fullsize as $FULLSIZE |
        image.aspectRatio.height as $ASPECTRATIO_HEIGHT |
        image.aspectRatio.width as $ASPECTRATIO_WIDTH |
        if is_quoted
        then
          "'"${VIEW_TEMPLATE_QUOTED_IMAGE}"'"
        else
          "'"${VIEW_TEMPLATE_IMAGE}"'"
        end
      ;
      def output_images(images; is_quoted):
        foreach images[] as $image (0; . + 1;
          output_image($image; .; "image"; is_quoted)
        )
      ;
      def output_post_part(is_before_embed; view_index; post_fragment; is_quoted):
        post_fragment.uri as $URI |
        post_fragment.cid as $CID |
        post_fragment.author.displayName as $AUTHOR_DISPLAYNAME |
        post_fragment.author.handle as $AUTHOR_HANDLE |
        post_fragment.replyCount as $REPLY_COUNT |
        post_fragment.repostCount as $REPOST_COUNT |
        post_fragment.likeCount as $LIKE_COUNT |
        if is_quoted
        then
          ([view_index, "1"] | join("-")) as $VIEW_INDEX |
          post_fragment.value.createdAt | '"${VIEW_TEMPLATE_CREATED_AT}"' | . as $CREATED_AT |
          (post_fragment.value.text | gsub("\n"; "\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'")) as $TEXT |
          if is_before_embed
          then
            "'"${VIEW_TEMPLATE_QUOTED_POST_META}"'",
            "'"${VIEW_TEMPLATE_QUOTED_POST_HEAD}"'",
            "'"${VIEW_TEMPLATE_QUOTED_POST_BODY}"'"
          else
            empty
          end
        else
          view_index as $VIEW_INDEX |
          post_fragment.record.createdAt | '"${VIEW_TEMPLATE_CREATED_AT}"' | . as $CREATED_AT |
          post_fragment.record.text as $TEXT |
          if is_before_embed
          then
            "'"${VIEW_TEMPLATE_POST_META}"'",
            "'"${VIEW_TEMPLATE_POST_HEAD}"'",
            "'"${VIEW_TEMPLATE_POST_BODY}"'"
          else
            "'"${VIEW_TEMPLATE_POST_TAIL}"'",
            "'"${VIEW_TEMPLATE_POST_SEPARATOR}"'"
          end
        end
      ;
      def output_post(view_index; post_fragment):
        output_post_part(true; view_index; post_fragment; false),
        (
          post_fragment |
          if has("embed")
          then
            (
              select(.embed."$type" == "app.bsky.embed.images#view") |
              output_images(post_fragment.embed.images; false)
            ),
            (
              select(.embed."$type" == "app.bsky.embed.recordWithMedia#view") |
              (
                select(.embed.media."$type" == "app.bsky.embed.images#view") |
                output_images(post_fragment.embed.media.images; false)
              ),
              (
                select(.embed.record.record."$type" == "app.bsky.embed.record#viewRecord") |
                output_post_part(true; view_index; post_fragment.embed.record.record; true)
              ),
              (
                select(.embed.record.record.embeds) |
                .embed.record.record.embeds |
                foreach .[] as $embed (0; . + 1;
                  select($embed."$type" == "app.bsky.embed.images#view") |
                  output_images($embed.images; true)
                )
              )
            ),
            (
              select(.embed."$type" == "app.bsky.embed.record#view") |
              output_post_part(true; view_index; post_fragment.embed.record; true)
            )
          else
            empty
          end
        ),
        output_post_part(false; view_index; post_fragment; false)
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
            (
              select(.embed."$type" == "app.bsky.embed.recordWithMedia#view") |
              (
                select(.embed.media."$type" == "app.bsky.embed.images#view") |
                empty
              ),
              (
                select(.embed.record.record."$type" == "app.bsky.embed.record#viewRecord") |
                ([view_index, "1"] | join("-")) as $VIEW_INDEX |
                post_fragment.embed.record.record.uri as $URI |
                post_fragment.embed.record.record.cid as $CID |
                "'"${VIEW_SESSION_PLACEHOLDER}"'"
              ),
              (
                select(.embed.record.record.embeds) |
                .embed.record.record.embeds |
                foreach .[] as $embed (0; . + 1;
                  select($embed."$type" == "app.bsky.embed.images#view") |
                  empty
                )
              )
            ),
            (
              select(.embed."$type" == "app.bsky.embed.record#view") |
              ([view_index, "1"] | join("-")) as $VIEW_INDEX |
              post_fragment.embed.record.uri as $URI |
              post_fragment.embed.record.cid as $CID |
              "'"${VIEW_SESSION_PLACEHOLDER}"'"
            )
          else
            empty
          end
        )
      ;
     '

  debug 'core_create_session_chunk' 'END'
}

core_verify_pref_group_name()
{
  PARAM_CORE_VERIFY_PREF_GROUP_NAME="$1"

  debug 'core_verify_pref_group_name' 'START'
  debug 'core_verify_pref_group_name' "CORE_VERIFY_PREF_GROUP_NAME:${CORE_VERIFY_PREF_GROUP_NAME}"

  STATUS=0
  case $PARAM_CORE_VERIFY_PREF_GROUP_NAME in
    adult-content|content-label|saved-feeds|personal-details|feed-view|thread-view|interests|muted-words|hidden-posts)
      ;;
    *)
      STATUS=1
      ;;
  esac

  debug 'core_verify_pref_group_name' 'END'

  return $STATUS
}

core_verify_pref_item_name()
{
  PARAM_CORE_VERIFY_PREF_ITEM_NAME_GROUP="$1"
  PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM="$2"

  debug 'core_verify_pref_item_name' 'START'
  debug 'core_verify_pref_item_name' "PARAM_CORE_VERIFY_PREF_ITEM_NAME_GROUP:${PARAM_CORE_VERIFY_PREF_ITEM_NAME_GROUP}"
  debug 'core_verify_pref_item_name' "PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM:${PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM}"

  STATUS=0
  ERRORS=''
  case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_GROUP in
    adult-content)
      case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM in
        enabled)
          ;;
        *)
          STATUS=1
          ;;
      esac
      ;;
    content-label)
      case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM in
        labeler-did|label|visibility)
          ;;
        *)
          STATUS=1
          ;;
      esac
      ;;
    saved-feeds)
      case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM in
        pinned|saved|timeline-index)
          ;;
        *)
          STATUS=1
          ;;
      esac
      ;;
    personal-details)
      case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM in
        birth-date)
          ;;
        *)
          STATUS=1
          ;;
      esac
      ;;
    feed-view)
      case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM in
        feed|hide-replies|hide-replies-by-unfollowed|hide-replies-by-like-count|hide-reposts|hide-quote-posts)
          ;;
        *)
          STATUS=1
          ;;
      esac
      ;;
    thread-view)
      case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM in
        sort|prioritize-followed-users)
          ;;
        *)
          STATUS=1
          ;;
      esac
      ;;
    interests)
      case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM in
        tags)
          ;;
        *)
          STATUS=1
          ;;
      esac
      ;;
    muted-words)
      case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM in
        items)
          ;;
        *)
          STATUS=1
          ;;
      esac
      ;;
    hidden-posts)
      case $PARAM_CORE_VERIFY_PREF_ITEM_NAME_ITEM in
        items)
          ;;
        *)
          STATUS=1
          ;;
      esac
      ;;
    *)
      STATUS=1
      ;;
  esac

  debug 'core_verify_pref_item_name' 'END'

  return $STATUS
}

core_verify_pref_group_parameter()
{
  PARAM_CORE_VERIFY_PREF_GROUP_PARAMETER_GROUP="$1"

  debug 'core_verify_pref_group_parameter' 'START'
  debug 'core_verify_pref_group_parameter' "PARAM_CORE_VERIFY_PREF_GROUP_PARAMETER_GROUP:${PARAM_CORE_VERIFY_PREF_GROUP_PARAMETER_GROUP}"

  EVACUATED_IFS=$IFS
  IFS=','
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $PARAM_CORE_VERIFY_PREF_GROUP_PARAMETER_GROUP
  IFS=$EVACUATED_IFS
  SPECIFIED_COUNT=$#
  ERRORS=''
  while [ $# -gt 0 ]
  do
    GROUP_ELEMENT=$1
    if core_verify_pref_group_name "${GROUP_ELEMENT}"
    then
      RESULT_CORE_VERIFY_PREF_GROUP_PARAMETER="${GROUP_ELEMENT}"
      GROUP_ELEMENT=`_p "${GROUP_ELEMENT}" | sed 's/-/_/g'`
      eval "CORE_VERIFY_PREF_GROUP_${GROUP_ELEMENT}='defined'"
    else
      ERRORS="${ERRORS} ${GROUP_ELEMENT}"
    fi
    shift
  done
  if [ -n "${ERRORS}" ]
  then
    error "invalid preference group name:${ERRORS}"
  fi

  debug 'core_verify_pref_group_parameter' 'END'

  return $SPECIFIED_COUNT
}

core_verify_pref_item_parameter()
{
  PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_GROUP_COUNT="$1"
  PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_GROUP_SINGLE="$2"
  PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_ITEM="$3"

  debug 'core_verify_pref_item_parameter' 'START'
  debug 'core_verify_pref_item_parameter' "PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_GROUP_COUNT:${PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_GROUP_COUNT}"
  debug 'core_verify_pref_item_parameter' "PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_GROUP_SINGLE:${PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_GROUP_SINGLE}"
  debug 'core_verify_pref_item_parameter' "PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_ITEM:${PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_ITEM}"

  STATUS=0
  EVACUATED_IFS=$IFS
  IFS=','
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_ITEM
  IFS=$EVACUATED_IFS
  SPECIFIED_COUNT=$#
  ALL_STATUS=0
  while [ $# -gt 0 ]
  do
    ITEM_ELEMENT=$1
    ITEM_LHS=`_strleft "${ITEM_ELEMENT}" '='`
    ITEM_MODIFIED=`_p "${ITEM_LHS}" | sed 's/[^.]//g'`
    if [ -n "${ITEM_MODIFIED}" ]
    then
      ITEM_MODIFIER=`_strleft "${ITEM_LHS}" '\.'`
      ITEM_CANONICAL=`_strright "${ITEM_LHS}" '\.'`
    else
      ITEM_MODIFIER=''
      ITEM_CANONICAL="${ITEM_LHS}"
    fi
    ITEM_RHS=`_strright "${ITEM_ELEMENT}" '='`

    if [ "${PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_GROUP_COUNT}" -eq 0 ]
    then
      if [ -n "${ITEM_MODIFIER}" ]
      then
        if core_verify_pref_group_name "${ITEM_MODIFIER}"
        then
          ELEMENT_STATUS=0
          GROUP_NAME="${ITEM_MODIFIER}"
        else
          ELEMENT_STATUS=1
          error_msg "invalid preference item modifier: ${ITEM_LHS}"
        fi
      else
        ELEMENT_STATUS=1
        error_msg "must be specified preference item modifier or --group: ${ITEM_LHS}"
      fi
    elif [ "${PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_GROUP_COUNT}" -eq 1 ]
    then
      if [ -n "${ITEM_MODIFIER}" ]
      then
        ELEMENT_STATUS=1
        error_msg "preference group and preference item modifier are exclusive: ${ITEM_LHS}"
      else
        ELEMENT_STATUS=0
        GROUP_NAME="${PARAM_CORE_VERIFY_PREF_ITEM_PARAMETER_GROUP_SINGLE}"
      fi
    else  # > 1
      ELEMENT_STATUS=1
      error_msg "multiple preference group and preference item are exclusive: ${ITEM_LHS}"
    fi

    core_verify_pref_item_name "${GROUP_NAME}" "${ITEM_CANONICAL}"
    VERIFY_ITEM_STATUS=$?
    if [ "${VERIFY_ITEM_STATUS}" -ne 0 ]
    then
      ELEMENT_STATUS=1
      error_msg "item not found in group: ${ITEM_LHS} in ${GROUP_NAME}"
    fi

    if [ "${ELEMENT_STATUS}" -eq 0 ]
    then
      GROUP_SCORED=`_p "${GROUP_NAME}" | sed 's/-/_/g'`
      ITEM_SCORED=`_p "${ITEM_LHS}" | sed 's/-/_/g'`
      if [ -z "${ITEM_RHS}" ]
      then
        ITEM_RHS='defined'
      fi
      eval "CORE_VERIFY_PREF_ITEM__${GROUP_SCORED}__${ITEM_SCORED}='${ITEM_RHS}'"
    else
      ALL_STATUS=1
    fi
    shift
  done
  if [ "${ALL_STATUS}" -ne 0 ]
  then
    error 'preference item parameter error occured'
  fi

  debug 'core_verify_pref_item_parameter' 'END'

  return $SPECIFIED_COUNT
}

core_output_pref_item()
{
  PARAM_CORE_OUTPUT_PREF_ITEM_PREF_CHUNK="$1"
  PARAM_CORE_OUTPUT_PREF_ITEM_PREF_TYPE="$2"
  PARAM_CORE_OUTPUT_PREF_ITEM_GROUP_DESCRIPTION="$3"
  PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_DESCRIPTION="$4"
  PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_KEY="$5"
  PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_TYPE="$6"

  debug 'core_output_pref_item' 'START'
  debug 'core_output_pref_item' "PARAM_CORE_OUTPUT_PREF_ITEM_PREF_CHUNK:${PARAM_CORE_OUTPUT_PREF_ITEM_PREF_CHUNK}"
  debug 'core_output_pref_item' "PARAM_CORE_OUTPUT_PREF_ITEM_PREF_TYPE:${PARAM_CORE_OUTPUT_PREF_ITEM_PREF_TYPE}"
  debug 'core_output_pref_item' "PARAM_CORE_OUTPUT_PREF_ITEM_GROUP_DESCRIPTION:${PARAM_CORE_OUTPUT_PREF_ITEM_GROUP_DESCRIPTION}"
  debug 'core_output_pref_item' "PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_DESCRIPTION:${PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_DESCRIPTION}"
  debug 'core_output_pref_item' "PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_KEY:${PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_KEY}"
  debug 'core_output_pref_item' "PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_TYPE:${PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_TYPE}"

  export STR_NO_CONF='(no configured)'

  case $PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_TYPE in
    string|boolean|number)
      OUTPUT=`_p "${PARAM_CORE_OUTPUT_PREF_ITEM_PREF_CHUNK}" | jq -r '
        .preferences as $pref |
        $pref[] |
        select(."$type" == "'"${PARAM_CORE_OUTPUT_PREF_ITEM_PREF_TYPE}"'") |
        .'"${PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_KEY}"' // env.STR_NO_CONF
      '`
      if [ -z "${OUTPUT}" ]
      then
        OUTPUT="${STR_NO_CONF}"
      fi
      _pn "${PARAM_CORE_OUTPUT_PREF_ITEM_GROUP_DESCRIPTION}.${PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_DESCRIPTION}: ${OUTPUT}"
      ;;
    array)
      OUTPUT=`_p "${PARAM_CORE_OUTPUT_PREF_ITEM_PREF_CHUNK}" | jq -r '
        "['"${PARAM_CORE_OUTPUT_PREF_ITEM_GROUP_DESCRIPTION}"'.'"${PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_DESCRIPTION}"']",
        .preferences as $pref |
        $pref[] |
        select(."$type" == "'"${PARAM_CORE_OUTPUT_PREF_ITEM_PREF_TYPE}"'") |
        if has("'"${PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_KEY}"'") then .'"${PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_KEY}"'[] else env.STR_NO_CONF end
      '`
      if [ -z "${OUTPUT}" ]
      then
        OUTPUT="${STR_NO_CONF}"
      fi
      _pn "${OUTPUT}"
      ;;
    *)
      error "internal error: ${PARAM_CORE_OUTPUT_PREF_ITEM_ITEM_TYPE}"
      ;;
  esac

  debug 'core_output_pref_item' 'END'
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

  HANDLE=`core_canonicalize_handle "${HANDLE}"`
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
  PARAM_GET_TIMELINE_ALGORITHM="$1"
  PARAM_GET_TIMELINE_LIMIT="$2"
  PARAM_GET_TIMELINE_NEXT="$3"
  PARAM_GET_TIMELINE_OUTPUT_ID="$4"

  debug 'core_get_timeline' 'START'
  debug 'core_get_timeline' "PARAM_GET_TIMELINE_ALGORITHM:${PARAM_GET_TIMELINE_ALGORITHM}"
  debug 'core_get_timeline' "PARAM_GET_TIMELINE_LIMIT:${PARAM_GET_TIMELINE_LIMIT}"
  debug 'core_get_timeline' "PARAM_GET_TIMELINE_NEXT:${PARAM_GET_TIMELINE_NEXT}"
  debug 'core_get_timeline' "PARAM_GET_TIMELINE_OUTPUT_ID:${PARAM_GET_TIMELINE_OUTPUT_ID}"

  read_session_file
  if [ -n "${PARAM_GET_TIMELINE_NEXT}" ]
  then
    CURSOR="${SESSION_GETTIMELINE_CURSOR}"
    if [ "${CURSOR}" = "${CURSOR_TERMINATE}" ]
    then
        _p '[next feed not found]'
        exit 0
    fi
  else
    CURSOR=''
  fi

  RESULT=`api app.bsky.feed.getTimeline "${PARAM_GET_TIMELINE_ALGORITHM}" "${PARAM_GET_TIMELINE_LIMIT}" "${CURSOR}"`
  STATUS=$?
  debug_single 'core_get_timeline'
  _p "${RESULT}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $STATUS -eq 0 ]
  then
    VIEW_POST_FUNCTIONS=`core_create_post_chunk "${PARAM_GET_TIMELINE_OUTPUT_ID}"`
    _p "${RESULT}" | jq -r "${VIEW_POST_FUNCTIONS}${FEED_PARSE_PROCEDURE}"

    CURSOR=`_p "${RESULT}" | jq -r '.cursor // "'"${CURSOR_TERMINATE}"'"'`
    VIEW_SESSION_FUNCTIONS=`core_create_session_chunk`
    FEED_VIEW_INDEX=`_p "${RESULT}" | jq -r -j "${VIEW_SESSION_FUNCTIONS}${FEED_PARSE_PROCEDURE}" | sed 's/.$//'`
    # CAUTION: key=value pairs are separated by tab characters
    update_session_file "${SESSION_KEY_GETTIMELINE_CURSOR}=${CURSOR}	${SESSION_KEY_FEED_VIEW_INDEX}=${FEED_VIEW_INDEX}"
  fi

  debug 'core_get_timeline' 'END'

  return $STATUS
}

core_get_feed()
{
  PARAM_CORE_GET_FEED_DID="$1"
  PARAM_CORE_GET_FEED_RECORD_KEY="$2"
  PARAM_CORE_GET_FEED_URL="$3"
  PARAM_CORE_GET_FEED_LIMIT="$4"
  PARAM_CORE_GET_FEED_NEXT="$5"
  PARAM_CORE_GET_FEED_OUTPUT_ID="$6"

  debug 'core_get_feed' 'START'
  debug 'core_get_feed' "PARAM_CORE_GET_FEED_DID:${PARAM_CORE_GET_FEED_DID}"
  debug 'core_get_feed' "PARAM_CORE_GET_FEED_RECORD_KEY:${PARAM_CORE_GET_FEED_RECORD_KEY}"
  debug 'core_get_feed' "PARAM_CORE_GET_FEED_URL:${PARAM_CORE_GET_FEED_URL}"
  debug 'core_get_feed' "PARAM_CORE_GET_FEED_LIMIT:${PARAM_CORE_GET_FEED_LIMIT}"
  debug 'core_get_feed' "PARAM_CORE_GET_FEED_NEXT:${PARAM_CORE_GET_FEED_NEXT}"
  debug 'core_get_feed' "PARAM_CORE_GET_FEED_OUTPUT_ID:${PARAM_CORE_GET_FEED_OUTPUT_ID}"

  if [ -n "${PARAM_CORE_GET_FEED_DID}" ]
  then
    FEED=`core_create_feed_at_uri_did_record_key "${PARAM_CORE_GET_FEED_DID}" "${PARAM_CORE_GET_FEED_RECORD_KEY}"`
    STATUS=$?
  elif [ -n "${PARAM_CORE_GET_FEED_URL}" ]
  then
    FEED=`core_create_feed_at_uri_bsky_app_url "${PARAM_CORE_GET_FEED_URL}"`
    STATUS=$?
  else
    error 'internal error: did and url are not specified'
  fi

  if [ $STATUS -eq 0 ]
  then
    read_session_file
    if [ -n "${PARAM_CORE_GET_FEED_NEXT}" ]
    then
      CURSOR="${SESSION_GETFEED_CURSOR}"
      if [ "${CURSOR}" = "${CURSOR_TERMINATE}" ]
      then
        _p '[next feed not found]'
        exit 0
      fi
    else
      CURSOR=''
    fi

    RESULT=`api app.bsky.feed.getFeed "${FEED}" "${PARAM_CORE_GET_FEED_LIMIT}" "${CURSOR}"`
    STATUS=$?
    debug_single 'core_get_feed'
    _p "${RESULT}" > "$BSKYSHCLI_DEBUG_SINGLE"

    if [ $STATUS -eq 0 ]
    then
      VIEW_POST_FUNCTIONS=`core_create_post_chunk "${PARAM_CORE_GET_FEED_OUTPUT_ID}"`
      _p "${RESULT}" | jq -r "${VIEW_POST_FUNCTIONS}${FEED_PARSE_PROCEDURE}"

      CURSOR=`_p "${RESULT}" | jq -r '.cursor // "'"${CURSOR_TERMINATE}"'"'`
      VIEW_SESSION_FUNCTIONS=`core_create_session_chunk`
      FEED_VIEW_INDEX=`_p "${RESULT}" | jq -r -j "${VIEW_SESSION_FUNCTIONS}${FEED_PARSE_PROCEDURE}" | sed 's/.$//'`
      # CAUTION: key=value pairs are separated by tab characters
      update_session_file "${SESSION_KEY_GETFEED_CURSOR}=${CURSOR}	${SESSION_KEY_FEED_VIEW_INDEX}=${FEED_VIEW_INDEX}"
    fi
  fi

  debug 'core_get_feed' 'END'

  return $STATUS
}

core_get_author_feed()
{
  PARAM_CORE_GET_AUTHOR_FEED_DID="$1"
  PARAM_CORE_GET_AUTHOR_FEED_LIMIT="$2"
  PARAM_CORE_GET_AUTHOR_FEED_NEXT="$3"
  PARAM_CORE_GET_AUTHOR_FEED_FILTER="$4"
  PARAM_CORE_GET_AUTHOR_FEED_OUTPUT_ID="$5"

  debug 'core_get_author_feed' 'START'
  debug 'core_get_author_feed' "PARAM_CORE_GET_AUTHOR_FEED_DID:${PARAM_CORE_GET_AUTHOR_FEED_DID}"
  debug 'core_get_author_feed' "PARAM_CORE_GET_AUTHOR_FEED_LIMIT:${PARAM_CORE_GET_AUTHOR_FEED_LIMIT}"
  debug 'core_get_author_feed' "PARAM_CORE_GET_AUTHOR_FEED_NEXT:${PARAM_CORE_GET_AUTHOR_FEED_NEXT}"
  debug 'core_get_author_feed' "PARAM_CORE_GET_AUTHOR_FEED_FILTER:${PARAM_CORE_GET_AUTHOR_FEED_FILTER}"
  debug 'core_get_author_feed' "PARAM_CORE_GET_AUTHOR_FEED_OUTPUT_ID:${PARAM_CORE_GET_AUTHOR_FEED_OUTPUT_ID}"

  read_session_file
  if [ -n "${PARAM_CORE_GET_AUTHOR_FEED_NEXT}" ]
  then
    CURSOR="${SESSION_GETAUTHORFEED_CURSOR}"
    if [ "${CURSOR}" = "${CURSOR_TERMINATE}" ]
    then
        _p '[next feed not found]'
        return 0
    fi
  else
    CURSOR=''
  fi

  RESULT=`api app.bsky.feed.getAuthorFeed "${PARAM_CORE_GET_AUTHOR_FEED_DID}" "${PARAM_CORE_GET_AUTHOR_FEED_LIMIT}" "${CURSOR}" "${PARAM_CORE_GET_AUTHOR_FEED_FILTER}"`
  STATUS=$?
  debug_single 'core_get_author_feed'
  _p "${RESULT}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $STATUS -eq 0 ]
  then
    VIEW_POST_FUNCTIONS=`core_create_post_chunk "${PARAM_CORE_GET_AUTHOR_FEED_OUTPUT_ID}"`
    _p "${RESULT}" | jq -r "${VIEW_POST_FUNCTIONS}${FEED_PARSE_PROCEDURE}"

    CURSOR=`_p "${RESULT}" | jq -r '.cursor // "'"${CURSOR_TERMINATE}"'"'`
    VIEW_SESSION_FUNCTIONS=`core_create_session_chunk`
    FEED_VIEW_INDEX=`_p "${RESULT}" | jq -r -j "${VIEW_SESSION_FUNCTIONS}${FEED_PARSE_PROCEDURE}" | sed 's/.$//'`
    # CAUTION: key=value pairs are separated by tab characters
    update_session_file "${SESSION_KEY_GETAUTHORFEED_CURSOR}=${CURSOR}	${SESSION_KEY_FEED_VIEW_INDEX}=${FEED_VIEW_INDEX}"
  fi

  debug 'core_get_author_feed' 'END'

  return $STATUS
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

core_get_profile()
{
  PARAM_CORE_GET_PROFILE_DID="$1"
  PARAM_CORE_GET_PROFILE_OUTPUT_ID="$2"
  PARAM_CORE_GET_PROFILE_DUMP="$3"

  debug 'core_get_profile' 'START'
  debug 'core_get_profile' "PARAM_CORE_GET_PROFILE_DID:${PARAM_CORE_GET_PROFILE_DID}"
  debug 'core_get_profile' "PARAM_CORE_GET_PROFILE_OUTPUT_ID:${PARAM_CORE_GET_PROFILE_OUTPUT_ID}"
  debug 'core_get_profile' "PARAM_CORE_GET_PROFILE_DUMP:${PARAM_CORE_GET_PROFILE_DUMP}"

  RESULT=`api app.bsky.actor.getProfile "${PARAM_CORE_GET_PROFILE_DID}"`
  STATUS=$?
  debug_single 'core_get_profile'
  _p "${RESULT}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $STATUS -eq 0 ]
  then
    if [ -n "${PARAM_CORE_GET_PROFILE_DUMP}" ]
    then
      _p "${RESULT}" | jq -r "${GENERAL_DUMP_PROCEDURE}"
    else
      if [ -n "${PARAM_CORE_GET_PROFILE_OUTPUT_ID}" ]
      then
        PROFILE_OUTPUT="${BSKYSHCLI_VIEW_TEMPLATE_PROFILE_OUTPUT_ID}"
      else
        PROFILE_OUTPUT="${BSKYSHCLI_VIEW_TEMPLATE_PROFILE}"
      fi
      PROFILE_OUTPUT="${PROFILE_OUTPUT}\n${BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_COMMON}"
      if core_is_actor_current_session "${PARAM_CORE_GET_PROFILE_DID}"
      then
        PROFILE_OUTPUT="${PROFILE_OUTPUT}\n${BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_MYACCOUNT}"
      fi
      _p "${RESULT}" | jq -r '
        .did as $DID |
        .handle as $HANDLE |
        .displayName as $DISPLAYNAME |
        .description as $DESCRIPTION |
        (.avatar // "(default)") as $AVATAR |
        (.banner // "(default)") as $BANNER |
        .followersCount as $FOLLOWERSCOUNT |
        .followsCount as $FOLLOWSCOUNT |
        .postsCount as $POSTSCOUNT |
        .associated.lists as $ASSOCIATED_LISTS |
        .associated.feedgens as $ASSOCIATED_FEEDGENS |
        .associated.labeler as $ASSOCIATED_LABELER |
        .indexedAt as $INDEXEDAT |
        .viewer.muted as $VIEWER_MUTED |
        .viewer.blockedBy as $VIEWER_BLOCKEDBY |
        .viewer.blocking as $VIEWER_BLOCKING |
        .viewer.blockingByList as $VIEWER_BLOCKINGBYLIST |
        .viewer.following as $VIEWER_FOLLOWING |
        .viewer.followedBy as $VIEWER_FOLLOWEDBY |
        .labels as $LABELS |
        "'"${PROFILE_OUTPUT}"'"
      '
    fi
  fi

  debug 'core_get_profile' 'END'

  return $STATUS
}

core_get_pref()
{
  PARAM_CORE_GET_PREF_GROUP="$1"
  PARAM_CORE_GET_PREF_ITEM="$2"
  PARAM_CORE_GET_PREF_DUMP="$3"

  debug 'core_get_pref' 'START'

  RESULT=`api app.bsky.actor.getPreferences`
  STATUS=$?
  debug_single 'core_get_preferences'
  _p "${RESULT}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $STATUS -eq 0 ]
  then
    if [ -n "${PARAM_CORE_GET_PREF_DUMP}" ]
    then
      _p "${RESULT}" | jq -r "${GENERAL_DUMP_PROCEDURE}"
    else
      core_verify_pref_group_parameter "${PARAM_CORE_GET_PREF_GROUP}"
      GROUP_COUNT=$?
      core_verify_pref_item_parameter "${GROUP_COUNT}" "${RESULT_CORE_VERIFY_PREF_GROUP_PARAMETER}" "${PARAM_CORE_GET_PREF_ITEM}"
      ITEM_COUNT=$?
      export STR_NO_CONF='(no configured)'
      if [ "${ITEM_COUNT}" -eq 0 ]
      then
        if [ -n "${CORE_VERIFY_PREF_GROUP_adult_content}" ] || [ "${GROUP_COUNT}" -eq 0 ]
        then
          _p "${RESULT}" | jq -r '
            ">>>> adult contents",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#adultContentPref" ) |
            (.enabled // env.STR_NO_CONF) as $adultContents_enabled |
            "enabled: \($adultContents_enabled)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_content_label}" ] || [ "${GROUP_COUNT}" -eq 0 ]
        then
          _p "${RESULT}" | jq -r '
            ">>>> content label",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#contentLabelPref") |
            (.labelerDid // env.STR_NO_CONF) as $contentLabel_labelerDid |
            (.label // env.STR_NO_CONF) as $contentLabel_label |
            (.visibility // env.STR_NO_CONF) as $contentLabel_visibility |
            "labeler did: \($contentLabel_labelerDid)",
            "label: \($contentLabel_label)",
            "visibility: \($contentLabel_visibility)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_saved_feeds}" ] || [ "${GROUP_COUNT}" -eq 0 ]
        then
          _p "${RESULT}" | jq -r '
            ">>>> saved feeds",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#savedFeedsPref") |
            (if has("pinned") then .pinned | join("\n") else env.STR_NO_CONF end) as $savedFeeds_pinned |
            (if has("saved") then .saved | join("\n") else env.STR_NO_CONF end) as $savedFeeds_saved |
            (.timelineIndex // env.STR_NO_CONF) as $savedFeeds_timelineIndex |
            "[pinned]",
            "\($savedFeeds_pinned)",
            "[saved]",
            "\($savedFeeds_saved)",
            "timeline index: \($savedFeeds_timelineIndex)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_personal_details}" ] || [ "${GROUP_COUNT}" -eq 0 ]
        then
          _p "${RESULT}" | jq -r '
            ">>>> personal details",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#personalDetailsPref") |
            (if has ("birthDate") then .birthDate | split("T")[0] else env.STR_NO_CONF end) as $personalDetails_birthDate |
            "birth date: \($personalDetails_birthDate)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_feed_view}" ] || [ "${GROUP_COUNT}" -eq 0 ]
        then
          _p "${RESULT}" | jq -r '
            ">>>> feed view",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#feedViewPref") |
            (.feed // env.STR_NO_CONF) as $feedView_feed |
            (.hideReplies // env.STR_NO_CONF) as $feedView_hideReplies |
            (.hideRepliesByUnfollowed // env.STR_NO_CONF) as $feedView_hideRepliesByUnfollowed |
            (.hideRepliesByLikeCount // env.STR_NO_CONF) as $feedView_hideRepliesByLikeCount |
            (.hideReposts // env.STR_NO_CONF) as $feedView_hideReposts |
            (.hideQuotePosts // env.STR_NO_CONF) as $feedView_hideQuotePosts |
            "feed: \($feedView_feed)",
            "hide replies: \($feedView_hideReplies)",
            "hide replies by unfollowed: \($feedView_hideRepliesByUnfollowed)",
            "hide replies by like count: \($feedView_hideRepliesByLikeCount)",
            "hide reposts: \($feedView_hideReposts)",
            "hide quote posts: \($feedView_hideQuotePosts)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_thread_view}" ] || [ "${GROUP_COUNT}" -eq 0 ]
        then
          _p "${RESULT}" | jq -r '
            ">>>> thread view",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#threadViewPref") |
            (.sort // env.STR_NO_CONF) as $threadView_sort |
            (.prioritizeFollowedUsers // env.STR_NO_CONF) as $threadView_prioritizeFollowedUsers |
            "sort: \($threadView_sort)",
            "prioritize followed users: \($threadView_prioritizeFollowedUsers)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_interests}" ] || [ "${GROUP_COUNT}" -eq 0 ]
        then
          _p "${RESULT}" | jq -r '
            ">>>> interests",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#interestsPref") |
            (if has("tags") then .tags | join("\n") else env.STR_NO_CONF end) as $interests_tags |
            "[tags]",
            "\($interests_tags)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_muted_words}" ] || [ "${GROUP_COUNT}" -eq 0 ]
        then
          _p "${RESULT}" | jq -r '
            ">>>> muted words",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#muteWordsPref") |
            (if has("items") then .items | join("\n") else env.STR_NO_CONF end) as $mutedWords_items |
            "[items]",
            "\($mutedWords_items)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_hidden_posts}" ] || [ "${GROUP_COUNT}" -eq 0 ]
        then
          _p "${RESULT}" | jq -r '
            ">>>> hidden posts",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#hiddenPostsPref") |
            (if has("items") then .items | join("\n") else env.STR_NO_CONF end) as $hiddenPosts_items |
            "[items]",
            "\($hiddenPosts_items)"
          '
        fi
      else  # ITEM_COUNT > 0
        if [ -n "${CORE_VERIFY_PREF_ITEM__adult_content__enabled}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#adultContentPref' 'adult-content' 'enabled' 'enabled' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__content_label__labeler_did}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#contentLabelPref' 'content-label' 'labeler-did' 'labelerDid' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__content_label__label}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#contentLabelPref' 'content-label' 'label' 'label' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__content_label__visibility}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#contentLabelPref' 'content-label' 'visibility' 'visibility' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__saved_feeds__pinned}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#savedFeedsPref' 'saved-feeds' 'pinned' 'pinned' 'array'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__saved_feeds__saved}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#savedFeedsPref' 'saved-feeds' 'saved' 'saved' 'array'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__saved_feeds__timeline_index}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#savedFeedsPref' 'saved-feeds' 'timeline-index' 'timelineIndex' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__personal_details__birth_date}" ]
        then
          OUTPUT=`_p "${RESULT}" | jq -r '
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#personalDetailsPref") |
            if has ("birthDate") then .birthDate | split("T")[0] else env.STR_NO_CONF end
          '`
          if [ -z "${OUTPUT}" ]
          then
            OUTPUT="${STR_NO_CONF}"
          fi
          _pn "personal-details.birth-date: ${OUTPUT}"
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__feed}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'feed' 'feed' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_replies}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-replies' 'hideReplies' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_replies_by_unfollowed}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-replies-by-unfollowed' 'hideRepliesByUnfollowed' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_replies_by_like_count}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-replies-by-like-count' 'hideRepliesByLikeCount' 'number'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_reposts}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-reposts' 'hideReposts' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_quote_posts}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-quote-posts' 'hideQuotePosts' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__thread_view__sort}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#threadViewPref' 'thread-view' 'sort' 'sort' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__thread_view__prioritize_followed_users}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#threadViewPref' 'thread-view' 'prioritize-followed-users' 'prioritizeFollowedUsers' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__interests__tags}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#interestsPref' 'interests' 'tags' 'tags' 'array'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__muted_words__items}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#mutedWordsPref' 'muted-words' 'items' 'items' 'array'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__hidden_posts__items}" ]
        then
          core_output_pref_item "${RESULT}" 'app.bsky.actor.defs#hiddenPostsPref' 'hidden-posts' 'items' 'items' 'array'
        fi
      fi
    fi
  fi

  debug 'core_get_pref' 'END'
}

core_info_session_which()
{
  debug 'core_info_session_which' 'START'

  _p "session file path: "
  _pn "`get_session_filepath`"

  debug 'core_info_session_which' 'END'
}

core_info_session_status()
{
  debug 'core_info_session_status' 'START'

  _p "login status: "
  SESSION_FILEPATH=`get_session_filepath`
  if [ -e "${SESSION_FILEPATH}" ]
  then
    _pn "login"
  else
    _pn "not login"
  fi

  debug 'core_info_session_status' 'END'
}

core_info_session_login()
{
  debug 'core_info_session_login' 'START'

  _pn "login timestamp: ${SESSION_LOGIN_TIMESTAMP}"

  debug 'core_info_session_login' 'END'
}

core_info_session_refresh()
{
  debug 'core_info_session_refresh' 'START'

  _pn "session refresh timestamp: ${SESSION_REFRESH_TIMESTAMP}"

  debug 'core_info_session_refresh' 'END'
}

core_info_session_handle()
{
  debug 'core_info_session_handle' 'START'

  _pn "handle: ${SESSION_HANDLE}"

  debug 'core_info_session_handle' 'END'
}

core_info_session_did()
{
  debug 'core_info_session_did' 'START'

  _pn "did: ${SESSION_DID}"

  debug 'core_info_session_did' 'END'
}

core_info_session_index()
{
  PARAM_CORE_INFO_SESSION_INDEX_OUTPUT_ID="$1"

  debug 'core_info_session_index' 'START'
  debug 'core_info_session_index' "PARAM_CORE_INFO_SESSION_INDEX_OUTPUT_ID:${PARAM_CORE_INFO_SESSION_INDEX_OUTPUT_ID}"

  _pn '[index]'
  if [ -n "${PARAM_CORE_INFO_SESSION_INDEX_OUTPUT_ID}" ]
  then
    _pn '[[view indexes: <index> <uri> <cid>]]'
  else
    _pn '[[view indexes: <index>]]'
  fi

  if [ -n "${SESSION_FEED_VIEW_INDEX}" ]
  then
    _slice "${SESSION_FEED_VIEW_INDEX}" '"'
    FEED_VIEW_INDEX_COUNT=$?
    CHUNK_INDEX=1
    while [ "${CHUNK_INDEX}" -le $FEED_VIEW_INDEX_COUNT ]
    do
      SESSION_CHUNK=`eval _p \"\\$"RESULT_slice_${CHUNK_INDEX}"\"`
      (
        _slice "${SESSION_CHUNK}" '|'
        # dynamic assignment in parse_parameters
        # shellcheck disable=SC2154
        CORE_INFO_SESSION_INDEX_INDEX="${RESULT_slice_1}"
        # dynamic assignment in parse_parameters, variable use at this file include(source) script
        # shellcheck disable=SC2154,SC2034
        CORE_INFO_SESSION_INDEX_URI="${RESULT_slice_2}"
        # dynamic assignment in parse_parameters, variable use at this file include(source) script
        # shellcheck disable=SC2154,SC2034
        CORE_INFO_SESSION_INDEX_CID="${RESULT_slice_3}"
        
        if [ -n "${PARAM_CORE_INFO_SESSION_INDEX_OUTPUT_ID}" ]
        then
          printf "%s\t%s\t%s\n" "${CORE_INFO_SESSION_INDEX_INDEX}" "${CORE_INFO_SESSION_INDEX_URI}" "${CORE_INFO_SESSION_INDEX_CID}"
        else
          _pn "${CORE_INFO_SESSION_INDEX_INDEX}"
        fi
      )
      CHUNK_INDEX=`expr "${CHUNK_INDEX}" + 1`
    done
  fi

  debug 'core_info_session_index' 'END'
}

core_info_session_cursor()
{
  debug 'core_info_session_cursor' 'START'

  _pn '[cursor]'
  _pn "timeline cursor: ${SESSION_GETTIMELINE_CURSOR}"

  debug 'core_info_session_cursor' 'END'
}

core_info_meta_path()
{
  debug 'core_info_meta_path' 'START'

  _pn "resource config (BSKYSHCLI_RESORUCE_CONFIG_PATH): ${BSKYSHCLI_RESOURCE_CONFIG_PATH}"
  _pn "work for session, debug log, etc. (BSKYSHCLI_TOOLS_WORK_DIR): ${BSKYSHCLI_TOOLS_WORK_DIR}"
  _pn "library (BSKYSHCLI_LIB_PATH): ${BSKYSHCLI_LIB_PATH}"
  _pn "api (BSKYSHCLI_API_PATH): ${BSKYSHCLI_API_PATH}"

  debug 'core_info_meta_path' 'END'
}

core_info_meta_config()
{
  debug 'core_info_meta_config' 'START'

  _pn "BSKYSHCLI_DEBUG=${BSKYSHCLI_DEBUG}"
  _pn "BSKYSHCLI_LIB_PATH=${BSKYSHCLI_LIB_PATH}"
  _pn "BSKYSHCLI_TZ=${BSKYSHCLI_TZ}"
  _pn "BSKYSHCLI_PROFILE=${BSKYSHCLI_PROFILE}"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID=${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID}"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_META=${BSKYSHCLI_VIEW_TEMPLATE_POST_META}"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_HEAD=${BSKYSHCLI_VIEW_TEMPLATE_POST_HEAD}"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_BODY=${BSKYSHCLI_VIEW_TEMPLATE_POST_BODY}"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL=${BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL}"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_SEPARATOR=${BSKYSHCLI_VIEW_TEMPLATE_POST_SEPARATOR}"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER=${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_QUOTE=${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"

  debug 'core_info_meta_config' 'END'
}

core_info_meta_profile()
{
  debug 'core_info_meta_profile' 'START'

  _pn '[profile (active session)]'
  SESSION_FILES=`(cd "${SESSION_DIR}" && ls -- *"${SESSION_FILENAME_SUFFIX}" 2>/dev/null)`
  for SESSION_FILE in $SESSION_FILES
  do
    if [ "${SESSION_FILE}" = "${SESSION_FILENAME_DEFAULT_PREFIX}${SESSION_FILENAME_SUFFIX}" ]
    then
      _pn '(default)'
    else
      _pn "${SESSION_FILE}" | sed "s/${SESSION_FILENAME_SUFFIX}$//g"
    fi
  done

  debug 'core_info_meta_profile' 'END'
}

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
  param_handle=$1

  debug 'core_canonicalize_handle' 'START'
  debug 'core_canonicalize_handle' "param_handle:${param_handle}"

  handle_check=`_p "${param_handle}" | sed 's/[^.]//g'`
  if [ -z "${handle_check}" ]
  then
    param_handle="${param_handle}${BSKYSHCLI_DEFAULT_DOMAIN}"
  fi
  _p "${param_handle}"

  debug 'core_canonicalize_handle' 'END'
}

core_verify_did()
{
  param_did=$1

  debug 'core_verify_did' 'START'
  debug 'core_verify_did' "param_did:${param_did}"

  if _startswith "${param_did}" 'did:'
  then
    :
  else
    error "specified did is invalid: ${param_did}"
  fi

  debug 'core_verify_did' 'END'
}

core_handle_to_did()
{
  param_handle=$1

  debug 'core_handle_to_did' 'START'
  debug 'core_handle_to_did' "param_handle:${param_handle}"

  param_handle=`core_canonicalize_handle "${param_handle}"`
  result=`api com.atproto.identity.resolveHandle "${param_handle}"`
  status=$?
  if [ $status -eq 0 ]
  then
   _p "${result}" | jq -r '.did'
  fi

  debug 'core_handle_to_did' 'END'

  return $status
}

core_actor_to_did()
{
  param_actor=$1

  debug 'core_actor_to_did' 'START'
  debug 'core_actor_to_did' "param_actor:${param_actor}"

  if _startswith "${param_actor}" 'did:'
  then
    _p "${param_actor}"
    status=0
  else
    core_handle_to_did "${param_actor}"
    status=$?
  fi

  debug 'core_actor_to_did' 'END'

  return $status
}

core_resolve_actor()
{
  param_actor="$1"
  param_handle="$2"
  param_did="$3"

  debug 'core_resolve_actor' 'START'

  if [ -n "${param_actor}" ]
  then
    did=`core_actor_to_did "${param_actor}"`
    status=$?
  elif [ -n "${param_handle}" ]
  then
    did=`core_handle_to_did "${param_handle}"`
    status=$?
  elif [ -n "${param_did}" ]
  then
    core_verify_did "${param_did}"
    did="${param_did}"
    status=0
  else
    did=''
    status=0
  fi
  _p "${did}"

  debug 'core_resolve_actor' 'END'

  return $status
}

core_is_actor_current_session()
{
  param_actor=$1

  debug 'core_is_actor_current_session' 'START'
  debug 'core_is_actor_current_session' "param_actor:${param_actor}"

  did=`core_actor_to_did "${param_actor}"`
  status=$?
  if [ $status -eq 0 ]
  then
    read_session_file
    if [ "${did}" = "${SESSION_DID}" ]
    then
      status=0
    else
      status=1
    fi
  fi

  debug 'core_is_actor_current_session' 'END'

  return $status
}

core_is_feed_generator()
{
  param_verify_target=$1

  debug 'core_is_feed_generator' 'START'
  debug 'core_is_feed_generator' "param_verify_target:${param_verify_target}"

  verify_result=`_p "${param_verify_target}" | sed "s_${FEED_GENERATOR_PATTERN_BSKYAPP_URL}__g"`
  if [ -z "${verify_result}" ]
  then
    is_feed_generator=0
  else
    is_feed_generator=1
  fi

  debug 'core_is_feed_generator' 'END'

  return "${is_feed_generator}"
}

core_create_feed_at_uri_did_record_key()
{
  param_did="$1"
  param_record_key="$2"

  debug 'core_create_feed_at_uri_did_record_key' 'START'
  debug 'core_create_feed_at_uri_did_record_key' "param_did:${param_did}"
  debug 'core_create_feed_at_uri_did_record_key' "param_record_key:${param_record_key}"

  _p "at://${param_did}/app.bsky.feed.generator/${param_record_key}"

  debug 'core_create_feed_at_uri_did_record_key' 'END'
}

core_create_feed_at_uri_bsky_app_url()
{
  param_url="$1"

  debug 'core_create_feed_at_uri_bsky_app_url' 'START'
  debug 'core_create_feed_at_uri_bsky_app_url' "param_url:${param_url}"

  actor=`_p "${param_url}" | sed "s_${FEED_GENERATOR_PATTERN_BSKYAPP_URL}_\1_g"`
  record_key=`_p "${param_url}" | sed "s_${FEED_GENERATOR_PATTERN_BSKYAPP_URL}_\2_g"`
  did=`core_actor_to_did "${actor}"`
  status=$?
  if [ $status -eq 0 ]
  then
    core_create_feed_at_uri_did_record_key "${did}" "${record_key}"
  fi

  debug 'core_create_feed_at_uri_bsky_app_url' 'END'

  return $status
}

core_get_feed_view_index()
{
  param_feed_view_index=$1

  debug 'core_get_feed_view_index' 'START'
  debug 'core_get_feed_view_index' "param_feed_view_index:${param_feed_view_index}"

  read_session_file
  _slice "${SESSION_FEED_VIEW_INDEX}" '"'
  feed_view_index_count=$?
  chunk_index=1
  while [ "${chunk_index}" -le $feed_view_index_count ]
  do
    session_chunk=`eval _p \"\\$"RESULT_slice_${chunk_index}"\"`
    session_chunk_index=`_p "${session_chunk}" | sed 's/^\([^|]*\)|.*/\1/g'`
    if [ "${session_chunk_index}" = "${param_feed_view_index}" ]
    then
      break
    fi
    chunk_index=`expr "${chunk_index}" + 1`
  done
  if [ "${chunk_index}" -gt $feed_view_index_count ]
  then
    error "specified index is not found in session: ${param_feed_view_index}"
  fi
  _slice "${session_chunk}" '|'
  # dynamic assignment in parse_parameters
  # shellcheck disable=SC2154
  FEED_VIEW_INDEX_ELEMENT_INDEX="${RESULT_slice_1}"
  # dynamic assignment in parse_parameters, variable use at this file include(source) script
  # shellcheck disable=SC2154,SC2034
  FEED_VIEW_INDEX_ELEMENT_URI="${RESULT_slice_2}"
  # dynamic assignment in parse_parameters, variable use at this file include(source) script
  # shellcheck disable=SC2154,SC2034
  FEED_VIEW_INDEX_ELEMENT_CID="${RESULT_slice_3}"
  if [ "${FEED_VIEW_INDEX_ELEMENT_INDEX}" != "${param_feed_view_index}" ]
  then
    error "internal error: specified index:${param_feed_view_index} session index:${FEED_VIEW_INDEX_ELEMENT_INDEX}" 
  fi

  debug 'core_get_feed_view_index' 'END'
}

core_parse_at_uri()
{
  param_at_uri=$1

  debug 'core_parse_at_uri' 'START'
  debug 'core_parse_at_uri' "param_at_uri:${param_at_uri}"

  _slice "${param_at_uri}" '/'
  at_uri_element_count=$?
  at_uri_element_scheme="${RESULT_slice_1}/${RESULT_slice_2}/"
  if [ "${at_uri_element_scheme}" != 'at://' ]
  then
    error "specified uri (${param_at_uri}) is not AT URI (at://)"
  fi
  AT_URI_ELEMENT_AUTHORITY="${RESULT_slice_3}"
  # dynamic assignment in parse_parameters
  # shellcheck disable=SC2154
  AT_URI_ELEMENT_COLLECTION="${RESULT_slice_4}"
  # shellcheck disable=SC2154
  AT_URI_ELEMENT_RKEY="${RESULT_slice_5}"

  debug 'core_parse_at_uri' 'END'

  return "${at_uri_element_count}"
}

core_build_images_fragment_precheck_single()
{
  param_image="$1"

  debug 'core_build_images_fragment_precheck_single' 'START'
  debug 'core_build_images_fragment_precheck_single' "param_image:${param_image}"

  if [ -r "${param_image}" ]
  then
    RESULT_precheck_file_mime_type=`file --mime-type --brief "${param_image}"`
    _startswith "${RESULT_precheck_file_mime_type}" 'image/'
    mime_type_check_status=$?
    if [ "${mime_type_check_status}" -eq 0 ]
    then
      file_result=`file "${param_image}"`
      # CAUTION: these image size processing depend on file command output
      # variable used by dynamic assignment
      # shellcheck disable=SC2034
      RESULT_precheck_image_width=`_p "${file_result}" | grep -o -E ', *[0-9]+ *x *[0-9]+ *(,|$)' | sed -E 's/, *([0-9]+) *x *([0-9]+)[ ,]*/\1/'`
      # shellcheck disable=SC2034
      RESULT_precheck_image_height=`_p "${file_result}" | grep -o -E ', *[0-9]+ *x *[0-9]+ *(,|$)' | sed -E 's/, *([0-9]+) *x *([0-9]+)[ ,]*/\2/'`
      status=0
    else
      error_msg "specified image file is not image: ${param_image} -> detect mime type: ${RESULT_precheck_file_mime_type}"
      status=1
    fi
  else
    error_msg "specified image file is not readable: ${param_image}"
    status=1
  fi

  debug 'core_build_images_fragment_precheck_single' 'END'

  return $status
}

core_build_images_fragment_precheck()
{
  param_image_alt="$@"

  debug 'core_build_images_fragment_precheck' 'START'
  debug 'core_build_images_fragment_precheck' "param_image_alt:${param_image_alt}"

  actual_image_count=0
  worst_status=0
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $param_image_alt
  while [ $# -gt 0 ]
  do
    image=$1
    alt=$2
    if [ -n "${image}" ]
    then
      core_build_images_fragment_precheck_single "${image}"
      status=$?
      if [ $status -eq 0 ]
      then
        actual_image_count=`expr "${actual_image_count}" + 1`
        eval "RESULT_precheck_alt_${actual_image_count}=\${alt}"
        eval "RESULT_precheck_image_filename_${actual_image_count}=\${image}"
        eval "RESULT_precheck_file_mime_type_${actual_image_count}=\${RESULT_precheck_file_mime_type}"
        eval "RESULT_precheck_image_width_${actual_image_count}=\${RESULT_precheck_image_width}"
        eval "RESULT_precheck_image_height_${actual_image_count}=\${RESULT_precheck_image_height}"
      else
        worst_status=1
      fi
      shift
      if [ $# -gt 0 ]
      then
        shift
      fi
    fi
  done

  if [ $worst_status -ne 0 ]
  then
    actual_image_count=255
  fi

  debug 'core_build_images_fragment_precheck' 'END'

  return $actual_image_count
}

core_build_images_fragment_single()
{
  param_alt="$1"
  param_image_filename="$2"
  param_file_mime_type="$3"
  param_image_width="$4"
  param_image_height="$5"

  debug 'core_build_images_fragment_single' 'START'
  debug 'core_build_images_fragment_single' "param_alt:${param_alt}"
  debug 'core_build_images_fragment_single' "param_image_filename:${param_image_filename}"
  debug 'core_build_images_fragment_single' "param_file_mime_type:${param_file_mime_type}"
  debug 'core_build_images_fragment_single' "param_image_width:${param_image_width}"
  debug 'core_build_images_fragment_single' "param_image_height:${param_image_height}"

  upload_blob=`api com.atproto.repo.uploadBlob "${param_image_filename}" "${param_file_mime_type}"`
  api_status=$?
  debug_single 'core_build_images_fragment_single'
  _p "${upload_blob}" > "$BSKYSHCLI_DEBUG_SINGLE"
  if [ $api_status -eq 0 ]
  then
    image_blob_fragment=`_p "${upload_blob}" | jq -c -M '.blob'`
    _p '{"alt":"'"${param_alt}"'",'
    if [ -n "${param_image_width}" ] && [ -n "${param_image_height}" ]
    then
      _p '"aspectRatio":{"height":'"${param_image_height}"',"width":'"${param_image_width}"'},'
    fi
    _p '"image":'"${image_blob_fragment}"'}'
    status=0
  else
    error_msg "uploadBlob API failed"
    status=1
  fi

  debug 'core_build_images_fragment_single' 'END'

  return $status
}

core_build_images_fragment()
{
  param_image_alt="$@"

  debug 'core_build_images_fragment' 'START'
  debug 'core_build_images_fragment' "param_image_alt:${param_image_alt}"

  # no double quote for use word splitting
  # shellcheck disable=SC2086
  core_build_images_fragment_precheck $param_image_alt
  precheck_result=$?
  case $precheck_result in
    0|1|2|3|4)
      # image actual specified 0 - 4
      precheck_status=0
      actual_image_count=$precheck_result
      ;;
    255)
      # error occured
      precheck_status=1
      ;;
    *)
      error_msg "core_buid_images_fragment internal error: ${precheck_result}"
      precheck_status=1
      ;;
  esac

  if [ $precheck_status -eq 0 ]
  then
    # "$type" necessary based on AT Protocol requirements
    # shellcheck disable=SC2016
    fragment_stack='{"$type":"app.bsky.embed.images","images":['
    single_status=0
    image_index=1
    while [ $image_index -le $actual_image_count ]
    do
      alt=`eval _p \"\\$"RESULT_precheck_alt_${image_index}"\"`
      image_filename=`eval _p \"\\$"RESULT_precheck_image_filename_${image_index}"\"`
      file_mime_type=`eval _p \"\\$"RESULT_precheck_file_mime_type_${image_index}"\"`
      image_width=`eval _p \"\\$"RESULT_precheck_image_width_${image_index}"\"`
      image_height=`eval _p \"\\$"RESULT_precheck_image_height_${image_index}"\"`
      result_single=`core_build_images_fragment_single "${alt}" "${image_filename}" "${file_mime_type}" "${image_width}" "${image_height}"`
      single_status=$?
      if [ $single_status -eq 0 ]
      then
        if [ $image_index -gt 1 ]
        then
          fragment_stack="${fragment_stack},"
        fi
        fragment_stack="${fragment_stack}${result_single}"
      else
        break
      fi
      image_index=`expr "${image_index}" + 1`
    done
    if [ $single_status -eq 0 ]
    then
      fragment_stack="${fragment_stack}]}"
      _p "${fragment_stack}"
      status=0
    else
      status=1
    fi
  else
    status=1
  fi

  if [ $status -ne 0 ]
  then
    actual_image_count=255
  fi

  debug 'core_build_images_fragment' 'END'

  return $actual_image_count
}

core_build_reply_fragment()
{
  param_reply_target_uri=$1
  param_reply_target_cid=$2

  debug 'core_build_reply_fragment' 'START'
  debug 'core_build_reply_fragment' "param_reply_target_uri:${param_reply_target_uri}"
  debug 'core_build_reply_fragment' "param_reply_target_cid:${param_reply_target_cid}"

  core_parse_at_uri "${param_reply_target_uri}"
  if [ -z "${AT_URI_ELEMENT_AUTHORITY}" ] || [ -z "${AT_URI_ELEMENT_COLLECTION}" ] || [ -z "${AT_URI_ELEMENT_RKEY}" ]
  then
    error "insufficiency in AT URI composition - URI:${param_reply_target_uri} AUTHORITY:${AT_URI_ELEMENT_AUTHORITY} COLLECTION:${AT_URI_ELEMENT_COLLECTION} RKEY:${AT_URI_ELEMENT_RKEY}"
  fi
  result=`api com.atproto.repo.getRecord "${AT_URI_ELEMENT_AUTHORITY}" "${AT_URI_ELEMENT_COLLECTION}" "${AT_URI_ELEMENT_RKEY}"`
  debug_single 'core_build_reply_fragment'
  _p "${result}" | jq -c '
    if (.value | has("reply"))
    then
      . + {
        root_uri: .value.reply.root.uri,
        root_cid: .value.reply.root.cid
      }
    else
      . + {
        root_uri: .uri,
        root_cid: .cid
      }
    end |
    {
      reply: {
        root: {
          uri: .root_uri,
          cid: .root_cid
        },
        parent: {
          uri: .uri,
          cid: .cid
        }
      }
    }
  ' | sed 's/^.\(.*\).$/\1/' | tee "${BSKYSHCLI_DEBUG_SINGLE}"

  debug 'core_build_reply_fragment' 'END'
}

core_build_subject_fragment()
{
  param_subject_uri=$1
  param_subject_cid=$2

  debug 'core_build_subject_fragment' 'START'
  debug 'core_build_subject_fragment' "param_subject_uri:${param_subject_uri}"
  debug 'core_build_subject_fragment' "param_subject_cid:${param_subject_cid}"

  _p "\"subject\":{\"uri\":\"${param_subject_uri}\",\"cid\":\"${param_subject_cid}\"}"

  debug 'core_build_subject_fragment' 'END'
}

core_build_quote_record_fragment()
{
  param_quote_uri=$1
  param_quote_cid=$2

  debug 'core_build_quote_record_fragment' 'START'
  debug 'core_build_quote_record_fragment' "param_quote_uri:${param_quote_uri}"
  debug 'core_build_quote_record_fragment' "param_quote_cid:${param_quote_cid}"

  _p "{\"\$type\":\"app.bsky.embed.record\",\"record\":{\"uri\":\"${param_quote_uri}\",\"cid\":\"${param_quote_cid}\"}}"

  debug 'core_build_quote_record_fragment' 'END'
}

core_create_post_chunk()
{
  param_output_id="$1"

  debug 'core_create_post_chunk' 'START'
  debug 'core_create_post_chunk' "param_output_id:${param_output_id}"

  if [ -n "${param_output_id}" ]
  then
    # escape for substitution at placeholder replacement 
    view_post_output_id=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID}" | sed 's/\\\\/\\\\\\\\/g'`
    view_post_feed_generator_output_id=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_OUTPUT_ID}" | sed 's/\\\\/\\\\\\\\/g'`
  else
    view_post_output_id=''
    view_post_feed_generator_output_id=''
  fi
  view_template_post_meta=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_META}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g'`
  view_template_post_head=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_HEAD}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g'`
  view_template_post_body=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_BODY}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g'`
  view_template_post_tail=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g'`
  view_template_image=`_p "${BSKYSHCLI_VIEW_TEMPLATE_IMAGE}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g'`
  view_template_post_separator=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_SEPARATOR}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g'`
  view_template_quoted_post_meta=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${view_template_post_meta}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_quoted_post_head=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${view_template_post_head}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_quoted_post_body=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${view_template_post_body}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_quoted_image=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${view_template_image}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_feed_generator_meta=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_META}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_feed_generator_output_id}"'/g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_feed_generator_head=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_HEAD}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_feed_generator_output_id}"'/g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_feed_generator_tail=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_TAIL}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_feed_generator_output_id}"'/g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_external_meta=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_EXTERNAL_META}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_external_head=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_EXTERNAL_HEAD}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_external_body=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_EXTERNAL_BODY}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_link=`_p "${BSKYSHCLI_VIEW_TEMPLATE_LINK}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g'`
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
          "'"${view_template_quoted_image}"'"
        else
          "'"${view_template_image}"'"
        end
      ;
      def output_images(images; is_quoted):
        foreach images[] as $image (0; . + 1;
          output_image($image; .; "image"; is_quoted)
        )
      ;
      def output_facets_features_link(link_index; uri):
        link_index as $LINK_INDEX |
        uri as $URI |
        "'"${view_template_link}"'"
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
            "'"${view_template_quoted_post_meta}"'",
            "'"${view_template_quoted_post_head}"'",
            "'"${view_template_quoted_post_body}"'"
          else
            empty
          end
        else
          view_index as $VIEW_INDEX |
          post_fragment.record.createdAt | '"${VIEW_TEMPLATE_CREATED_AT}"' | . as $CREATED_AT |
          post_fragment.record.text as $TEXT |
          if is_before_embed
          then
            "'"${view_template_post_meta}"'",
            "'"${view_template_post_head}"'",
            "'"${view_template_post_body}"'",
            (
              post_fragment.record |
              if has("facets")
              then
                post_fragment.record.facets |
                map(
                  if .features[]."$type" == "app.bsky.richtext.facet#link"
                  then
                    .
                  else
                    empty
                  end
                ) |
                foreach .[] as $facet (0; . + 1;
                  output_facets_features_link(.; $facet.features[].uri)
                )
              else
                empty
              end
            )
          else
            "'"${view_template_post_tail}"'",
            "'"${view_template_post_separator}"'"
          end
        end
      ;
      def output_post_feed_generator(view_index; post_fragment):
        post_fragment.uri as $URI |
        post_fragment.cid as $CID |
        post_fragment.did as $DID |
        post_fragment.creator_did as $CREATOR_DID |
        post_fragment.creator.handle as $CREATOR_HANDLE |
        post_fragment.creator.displayName as $CREATOR_DISPLAYNAME |
        post_fragment.creator.avatar as $CREATOR_AVATAR |
        post_fragment.creator.description as $CREATOR_DESCRIPTION |
        post_fragment.displayName as $DISPLAYNAME |
        post_fragment.description as $DESCRIPTION |
        post_fragment.avatar as $AVATAR |
        post_fragment.likeCount as $LIKECOUNT |
        "'"${view_template_post_feed_generator_meta}"'",
        "'"${view_template_post_feed_generator_head}"'",
        "'"${view_template_post_feed_generator_tail}"'"
      ;
      def output_post_external(view_idnex; post_fragment):
        post_fragment.external.uri as $EXTERNAL_URI |
        post_fragment.external.title as $EXTERNAL_TITLE |
        post_fragment.external.description as $EXTERNAL_DESCRIPTION |
        post_fragment.external.thumb as $EXTERNAL_THUMB |
        "'"${view_template_post_external_meta}"'",
        "'"${view_template_post_external_head}"'",
        "'"${view_template_post_external_body}"'"
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
              (
                select(.embed.record."$type" == "app.bsky.embed.record#viewRecord") |
                output_post_part(true; view_index; post_fragment.embed.record; true)
              ),
              (
                select(.embed.record."$type" == "app.bsky.feed.defs#generatorView") |
                output_post_feed_generator(view_index; post_fragment.embed.record)
              )
            ),
            (
              select(.embed."$type" == "app.bsky.embed.external#view") |
              output_post_external(view_index; post_fragment.embed)
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
  view_session_placeholder='\($VIEW_INDEX)|\($URI)|\($CID)\"'
  # shellcheck disable=SC2016
  _p 'def output_post(view_index; post_fragment):
        view_index as $VIEW_INDEX |
        post_fragment.uri as $URI |
        post_fragment.cid as $CID |
        "'"${view_session_placeholder}"'",
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
                "'"${view_session_placeholder}"'"
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
              "'"${view_session_placeholder}"'"
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
  param_group="$1"

  debug 'core_verify_pref_group_name' 'START'
  debug 'core_verify_pref_group_name' "param_group:${param_group}"

  status=0
  case $param_group in
    adult-content|content-label|saved-feeds|personal-details|feed-view|thread-view|interests|muted-words|hidden-posts)
      ;;
    *)
      status=1
      ;;
  esac

  debug 'core_verify_pref_group_name' 'END'

  return $status
}

core_verify_pref_item_name()
{
  param_group="$1"
  param_item="$2"

  debug 'core_verify_pref_item_name' 'START'
  debug 'core_verify_pref_item_name' "param_group:${param_group}"
  debug 'core_verify_pref_item_name' "param_item:${param_item}"

  status=0
  case $param_group in
    adult-content)
      case $param_item in
        enabled)
          ;;
        *)
          status=1
          ;;
      esac
      ;;
    content-label)
      case $param_item in
        labeler-did|label|visibility)
          ;;
        *)
          status=1
          ;;
      esac
      ;;
    saved-feeds)
      case $param_item in
        pinned|saved|timeline-index)
          ;;
        *)
          status=1
          ;;
      esac
      ;;
    personal-details)
      case $param_item in
        birth-date)
          ;;
        *)
          status=1
          ;;
      esac
      ;;
    feed-view)
      case $param_item in
        feed|hide-replies|hide-replies-by-unfollowed|hide-replies-by-like-count|hide-reposts|hide-quote-posts)
          ;;
        *)
          status=1
          ;;
      esac
      ;;
    thread-view)
      case $param_item in
        sort|prioritize-followed-users)
          ;;
        *)
          status=1
          ;;
      esac
      ;;
    interests)
      case $param_item in
        tags)
          ;;
        *)
          status=1
          ;;
      esac
      ;;
    muted-words)
      case $param_item in
        items)
          ;;
        *)
          status=1
          ;;
      esac
      ;;
    hidden-posts)
      case $param_item in
        items)
          ;;
        *)
          status=1
          ;;
      esac
      ;;
    *)
      status=1
      ;;
  esac

  debug 'core_verify_pref_item_name' 'END'

  return $status
}

core_verify_pref_group_parameter()
{
  param_group_parameter="$1"

  debug 'core_verify_pref_group_parameter' 'START'
  debug 'core_verify_pref_group_parameter' "param_group_parameter:${param_group_parameter}"

  evacuated_IFS=$IFS
  IFS=','
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $param_group_parameter
  IFS=$evacuated_IFS
  specified_count=$#
  errors=''
  while [ $# -gt 0 ]
  do
    group_element=$1
    if core_verify_pref_group_name "${group_element}"
    then
      RESULT_CORE_VERIFY_PREF_GROUP_PARAMETER="${group_element}"
      group_element=`_p "${group_element}" | sed 's/-/_/g'`
      eval "CORE_VERIFY_PREF_GROUP_${group_element}='defined'"
    else
      errors="${errors} ${group_element}"
    fi
    shift
  done
  if [ -n "${errors}" ]
  then
    error "invalid preference group name:${errors}"
  fi

  debug 'core_verify_pref_group_parameter' 'END'

  return $specified_count
}

core_verify_pref_item_parameter()
{
  param_group_count="$1"
  param_group_single="$2"
  param_item_parameter="$3"

  debug 'core_verify_pref_item_parameter' 'START'
  debug 'core_verify_pref_item_parameter' "param_group_count:${param_group_count}"
  debug 'core_verify_pref_item_parameter' "param_group_single:${param_group_single}"
  debug 'core_verify_pref_item_parameter' "param_item_parameter:${param_item_parameter}"

  evacuated_IFS=$IFS
  IFS=','
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $param_item_parameter
  IFS=$evacuated_IFS
  specified_count=$#
  all_status=0
  while [ $# -gt 0 ]
  do
    item_element=$1
    item_LHS=`_strleft "${item_element}" '='`
    item_modified=`_p "${item_LHS}" | sed 's/[^.]//g'`
    if [ -n "${item_modified}" ]
    then
      item_modifier=`_strleft "${item_LHS}" '\.'`
      item_canonical=`_strright "${item_LHS}" '\.'`
    else
      item_modifier=''
      item_canonical="${item_LHS}"
    fi
    item_RHS=`_strright "${item_element}" '='`

    if [ "${param_group_count}" -eq 0 ]
    then
      if [ -n "${item_modifier}" ]
      then
        if core_verify_pref_group_name "${item_modifier}"
        then
          element_status=0
          group_name="${item_modifier}"
        else
          element_status=1
          error_msg "invalid preference item modifier: ${item_LHS}"
        fi
      else
        element_status=1
        error_msg "must be specified preference item modifier or --group: ${item_LHS}"
      fi
    elif [ "${param_group_count}" -eq 1 ]
    then
      if [ -n "${item_modifier}" ]
      then
        element_status=1
        error_msg "preference group and preference item modifier are exclusive: ${item_LHS}"
      else
        element_status=0
        group_name="${param_group_single}"
      fi
    else  # > 1
      element_status=1
      error_msg "multiple preference group and preference item are exclusive: ${item_LHS}"
    fi

    core_verify_pref_item_name "${group_name}" "${item_canonical}"
    verify_item_status=$?
    if [ "${verify_item_status}" -ne 0 ]
    then
      element_status=1
      error_msg "item not found in group: ${item_LHS} in ${group_name}"
    fi

    if [ "${element_status}" -eq 0 ]
    then
      group_scored=`_p "${group_name}" | sed 's/-/_/g'`
      item_scored=`_p "${item_LHS}" | sed 's/-/_/g'`
      if [ -z "${item_RHS}" ]
      then
        item_RHS='defined'
      fi
      eval "CORE_VERIFY_PREF_ITEM__${group_scored}__${item_scored}='${item_RHS}'"
    else
      all_status=1
    fi
    shift
  done
  if [ "${all_status}" -ne 0 ]
  then
    error 'preference item parameter error occured'
  fi

  debug 'core_verify_pref_item_parameter' 'END'

  return $specified_count
}

core_output_pref_item()
{
  param_pref_chunk="$1"
  param_pref_type="$2"
  param_group_description="$3"
  param_item_description="$4"
  param_item_key="$5"
  param_item_type="$6"

  debug 'core_output_pref_item' 'START'
  debug 'core_output_pref_item' "param_pref_chunk:${param_pref_chunk}"
  debug 'core_output_pref_item' "param_pref_type:${param_pref_type}"
  debug 'core_output_pref_item' "param_group_description:${param_group_description}"
  debug 'core_output_pref_item' "param_item_description:${param_item_description}"
  debug 'core_output_pref_item' "param_item_key:${param_item_key}"
  debug 'core_output_pref_item' "param_item_type:${param_item_type}"

  export STR_NO_CONF='(no configured)'

  case $param_item_type in
    string|boolean|number)
      output=`_p "${param_pref_chunk}" | jq -r '
        .preferences as $pref |
        $pref[] |
        select(."$type" == "'"${param_pref_type}"'") |
        .'"${param_item_key}"' // env.STR_NO_CONF
      '`
      if [ -z "${output}" ]
      then
        output="${STR_NO_CONF}"
      fi
      _pn "${param_group_description}.${param_item_description}: ${output}"
      ;;
    array)
      output=`_p "${param_pref_chunk}" | jq -r '
        "['"${param_group_description}"'.'"${param_item_description}"']",
        .preferences as $pref |
        $pref[] |
        select(."$type" == "'"${param_pref_type}"'") |
        if has("'"${param_item_key}"'") then .'"${param_item_key}"'[] else env.STR_NO_CONF end
      '`
      if [ -z "${output}" ]
      then
        output="${STR_NO_CONF}"
      fi
      _pn "${output}"
      ;;
    *)
      error "internal error: ${param_item_type}"
      ;;
  esac

  debug 'core_output_pref_item' 'END'
}

core_create_session()
{
  param_handle="$1"
  param_password="$2"
  param_auth_factor_token="$3"

  debug 'core_create_session' 'START'
  debug 'core_create_session' "param_handle:${param_handle}"
  if [ -n "${param_password}" ]
  then
    message='(defined)'
  else
    message='(empty)'
  fi
  debug 'core_create_session' "param_password:${message}"
  if [ -n "${param_auth_factor_token}" ]
  then
    message='(defined)'
  else
    message='(empty)'
  fi
  debug 'core_create_session' "param_auth_factor_token:${message}"

  canonical_handle=`core_canonicalize_handle "${param_handle}"`
  api com.atproto.server.createSession "${canonical_handle}" "${param_password}" "${param_auth_factor_token}" > /dev/null
  api_status=$?

  debug 'core_create_session' 'END'

  return $api_status
}

core_delete_session()
{
  debug 'core_delete_session' 'START'

  api com.atproto.server.deleteSession "${SESSION_REFRESH_JWT}" > /dev/null
  api_status=$?

  debug 'core_delete_session' 'END'

  return $api_status
}

core_get_timeline()
{
  param_algorithm="$1"
  param_limit="$2"
  param_next="$3"
  param_output_id="$4"

  debug 'core_get_timeline' 'START'
  debug 'core_get_timeline' "param_algorithm:${param_algorithm}"
  debug 'core_get_timeline' "param_limit:${param_limit}"
  debug 'core_get_timeline' "param_next:${param_next}"
  debug 'core_get_timeline' "param_output_id:${param_output_id}"

  read_session_file
  if [ -n "${param_next}" ]
  then
    cursor="${SESSION_GETTIMELINE_CURSOR}"
    if [ "${cursor}" = "${CURSOR_TERMINATE}" ]
    then
        _pn '[next feed not found]'
        exit 0
    fi
  else
    cursor=''
  fi

  result=`api app.bsky.feed.getTimeline "${param_algorithm}" "${param_limit}" "${cursor}"`
  status=$?
  debug_single 'core_get_timeline'
  _p "${result}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $status -eq 0 ]
  then
    view_post_functions=`core_create_post_chunk "${param_output_id}"`
    _p "${result}" | jq -r "${view_post_functions}${FEED_PARSE_PROCEDURE}"

    cursor=`_p "${result}" | jq -r '.cursor // "'"${CURSOR_TERMINATE}"'"'`
    view_session_functions=`core_create_session_chunk`
    feed_view_index=`_p "${result}" | jq -r -j "${view_session_functions}${FEED_PARSE_PROCEDURE}" | sed 's/.$//'`
    # CAUTION: key=value pairs are separated by tab characters
    update_session_file "${SESSION_KEY_GETTIMELINE_CURSOR}=${cursor}	${SESSION_KEY_FEED_VIEW_INDEX}=${feed_view_index}"
  fi

  debug 'core_get_timeline' 'END'

  return $status
}

core_get_feed()
{
  param_did="$1"
  param_record_key="$2"
  param_url="$3"
  param_limit="$4"
  param_next="$5"
  param_output_id="$6"

  debug 'core_get_feed' 'START'
  debug 'core_get_feed' "param_did:${param_did}"
  debug 'core_get_feed' "param_record_key:${param_record_key}"
  debug 'core_get_feed' "param_url:${param_url}"
  debug 'core_get_feed' "param_limit:${param_limit}"
  debug 'core_get_feed' "param_next:${param_next}"
  debug 'core_get_feed' "param_output_id:${param_output_id}"

  if [ -n "${param_did}" ]
  then
    feed=`core_create_feed_at_uri_did_record_key "${param_did}" "${param_record_key}"`
    status=$?
  elif [ -n "${param_url}" ]
  then
    feed=`core_create_feed_at_uri_bsky_app_url "${param_url}"`
    status=$?
  else
    error 'internal error: did and url are not specified'
  fi

  if [ $status -eq 0 ]
  then
    read_session_file
    if [ -n "${param_next}" ]
    then
      cursor="${SESSION_GETFEED_CURSOR}"
      if [ "${cursor}" = "${CURSOR_TERMINATE}" ]
      then
        _pn '[next feed not found]'
        exit 0
      fi
    else
      cursor=''
    fi

    result=`api app.bsky.feed.getFeed "${feed}" "${param_limit}" "${cursor}"`
    status=$?
    debug_single 'core_get_feed'
    _p "${result}" > "$BSKYSHCLI_DEBUG_SINGLE"

    if [ $status -eq 0 ]
    then
      view_post_functions=`core_create_post_chunk "${param_output_id}"`
      _p "${result}" | jq -r "${view_post_functions}${FEED_PARSE_PROCEDURE}"

      cursor=`_p "${result}" | jq -r '.cursor // "'"${CURSOR_TERMINATE}"'"'`
      view_session_functions=`core_create_session_chunk`
      feed_view_index=`_p "${result}" | jq -r -j "${view_session_functions}${FEED_PARSE_PROCEDURE}" | sed 's/.$//'`
      # CAUTION: key=value pairs are separated by tab characters
      update_session_file "${SESSION_KEY_GETFEED_CURSOR}=${cursor}	${SESSION_KEY_FEED_VIEW_INDEX}=${feed_view_index}"
    fi
  fi

  debug 'core_get_feed' 'END'

  return $status
}

core_get_author_feed()
{
  param_did="$1"
  param_limit="$2"
  param_next="$3"
  param_filter="$4"
  param_output_id="$5"

  debug 'core_get_author_feed' 'START'
  debug 'core_get_author_feed' "param_did:${param_did}"
  debug 'core_get_author_feed' "param_limit:${param_limit}"
  debug 'core_get_author_feed' "param_next:${param_next}"
  debug 'core_get_author_feed' "param_filter:${param_filter}"
  debug 'core_get_author_feed' "param_output_id:${param_output_id}"

  read_session_file
  if [ -n "${param_next}" ]
  then
    cursor="${SESSION_GETAUTHORFEED_CURSOR}"
    if [ "${cursor}" = "${CURSOR_TERMINATE}" ]
    then
        _pn '[next feed not found]'
        return 0
    fi
  else
    cursor=''
  fi

  result=`api app.bsky.feed.getAuthorFeed "${param_did}" "${param_limit}" "${cursor}" "${param_filter}"`
  status=$?
  debug_single 'core_get_author_feed'
  _p "${result}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $status -eq 0 ]
  then
    view_post_functions=`core_create_post_chunk "${param_output_id}"`
    _p "${result}" | jq -r "${view_post_functions}${FEED_PARSE_PROCEDURE}"

    cursor=`_p "${result}" | jq -r '.cursor // "'"${CURSOR_TERMINATE}"'"'`
    view_session_functions=`core_create_session_chunk`
    feed_view_index=`_p "${result}" | jq -r -j "${view_session_functions}${FEED_PARSE_PROCEDURE}" | sed 's/.$//'`
    # CAUTION: key=value pairs are separated by tab characters
    update_session_file "${SESSION_KEY_GETAUTHORFEED_CURSOR}=${cursor}	${SESSION_KEY_FEED_VIEW_INDEX}=${feed_view_index}"
  fi

  debug 'core_get_author_feed' 'END'

  return $status
}

core_post()
{
  param_text="$1"
  if [ $# -gt 1 ]
  then
    shift
    param_image_alt=$@
  else
    param_image_alt=''
  fi

  debug 'core_post' 'START'
  debug 'core_post' "param_text:${param_text}"
  debug 'core_post' "param_image_alt:$*"

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.post'
  created_at=`get_ISO8601UTCbs`
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  images_fragment=`core_build_images_fragment $param_image_alt`
  actual_image_count=$?
  case $actual_image_count in
    0|1|2|3|4)
      if [ $actual_image_count -eq 0 ]
      then
        record="{\"text\":\"${param_text}\",\"createdAt\":\"${created_at}\"}"
      else
        record="{\"text\":\"${param_text}\",\"createdAt\":\"${created_at}\",\"embed\":${images_fragment}}"
      fi
        debug_single 'core_post'
        result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''  | tee "$BSKYSHCLI_DEBUG_SINGLE"`
        _p "${result}" | jq -r '"uri:\(.uri)
cid:\(.cid)
text:'"${param_text}"'"
'
      ;;
  esac

  debug 'core_post' 'END'
}

core_reply()
{
  param_target_uri="$1"
  param_target_cid="$2"
  param_text="$3"
  if [ $# -gt 3 ]
  then
    shift
    shift
    shift
    param_image_alt=$@
  else
    param_image_alt=''
  fi

  debug 'core_reply' 'START'
  debug 'core_reply' "param_target_uri:${param_target_uri}"
  debug 'core_reply' "param_target_cid:${param_target_cid}"
  debug 'core_reply' "param_text:${param_text}"

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.post'
  created_at=`get_ISO8601UTCbs`
  reply_fragment=`core_build_reply_fragment "${param_target_uri}" "${param_target_cid}"`
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  images_fragment=`core_build_images_fragment $param_image_alt`
  actual_image_count=$?
  case $actual_image_count in
    0|1|2|3|4)
      if [ $actual_image_count -eq 0 ]
      then
        record="{\"text\":\"${param_text}\",\"createdAt\":\"${created_at}\",${reply_fragment}}"
      else
        record="{\"text\":\"${param_text}\",\"createdAt\":\"${created_at}\",${reply_fragment},\"embed\":${images_fragment}}"
      fi
      debug_single 'core_reply'
      result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
      _p "${result}" | jq -r '"uri:\(.uri)
cid:\(.cid)
text:'"${param_text}"'"
'
      ;;
  esac

  debug 'core_reply' 'END'
}

core_repost()
{
  param_target_uri="$1"
  param_target_cid="$2"

  debug 'core_repost' 'START'
  debug 'core_repost' "param_target_uri:${param_target_uri}"
  debug 'core_repost' "param_target_cid:${param_target_cid}"

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.repost'
  created_at=`get_ISO8601UTCbs`
  subject_fragment=`core_build_subject_fragment "${param_target_uri}" "${param_target_cid}"`
  record="{\"createdAt\":\"${created_at}\",${subject_fragment}}"

  debug_single 'core_repost'
  result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  _p "${result}" | jq -r '"uri:\(.uri)
cid:\(.cid)"'

  debug 'core_repost' 'END'
}

core_quote()
{
  param_target_uri="$1"
  param_target_cid="$2"
  param_text="$3"
  if [ $# -gt 3 ]
  then
    shift
    shift
    shift
    param_image_alt=$@
  else
    param_image_alt=''
  fi

  debug 'core_quote' 'START'
  debug 'core_quote' "param_target_uri:${param_target_uri}"
  debug 'core_quote' "param_target_cid:${param_target_cid}"
  debug 'core_quote' "param_text:${param_text}"

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.post'
  created_at=`get_ISO8601UTCbs`
  quote_record_fragment=`core_build_quote_record_fragment "${param_target_uri}" "${param_target_cid}"`
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  images_fragment=`core_build_images_fragment $param_image_alt`
  actual_image_count=$?
  case $actual_image_count in
    0|1|2|3|4)
      if [ $actual_image_count -eq 0 ]
      then
        record="{\"text\":\"${param_text}\",\"createdAt\":\"${created_at}\",\"embed\":${quote_record_fragment}}"
      else
        record="{\"text\":\"${param_text}\",\"createdAt\":\"${created_at}\",\"embed\":{\"\$type\":\"app.bsky.embed.recordWithMedia\",\"media\":${images_fragment},\"record\":${quote_record_fragment}}}"
      fi
      debug_single 'core_quote'
      result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
      _p "${result}" | jq -r '"uri:\(.uri)
cid:\(.cid)
text:'"${param_text}"'"
'
      ;;
  esac

  debug 'core_quote' 'END'
}

core_like()
{
  param_target_uri="$1"
  param_target_cid="$2"

  debug 'core_like' 'START'
  debug 'core_like' "param_target_uri:${param_target_uri}"
  debug 'core_like' "param_target_cid:${param_target_cid}"

  subject_fragment=`core_build_subject_fragment "${param_target_uri}" "${param_target_cid}"`

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.like'
  created_at=`get_ISO8601UTCbs`
  record="{\"createdAt\":\"${created_at}\",${subject_fragment}}"

  debug_single 'core_like'
  result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  _p "${result}" | jq -r '"uri:\(.uri)
cid:\(.cid)"'

  debug 'core_like' 'END'
}

core_thread()
{
  param_target_uri="$1"
  param_depth="$2"
  param_parent_height="$3"
  param_output_id="$4"

  debug 'core_thread' 'START'
  debug 'core_thread' "param_target_uri:${param_target_uri}"
  debug 'core_thread' "param_depth:${param_depth}"
  debug 'core_thread' "param_parent_height:${param_parent_height}"

  debug_single 'core_thread'
  result=`api app.bsky.feed.getPostThread "${param_target_uri}" "${param_depth}" "${param_parent_height}"  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`

  view_post_functions=`core_create_post_chunk "${param_output_id}"`
  # $<variables> want to pass through for jq
  # shellcheck disable=SC2016
  thread_parse_procedure_parents='
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
  thread_parse_procedure_target='
    0 as $view_index |
    .thread.post as $post_fragment |
    output_post($view_index; $post_fragment)
  '
  # shellcheck disable=SC2016
  thread_parse_prodecure_replies='
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
  _p "${result}" | jq -r "${view_post_functions}${thread_parse_procedure_parents}"
  _p "${result}" | jq -r "${view_post_functions}${thread_parse_procedure_target}"
  _p "${result}" | jq -r "${view_post_functions}${thread_parse_prodecure_replies}"

  view_session_functions=`core_create_session_chunk`
  feed_view_index_parents=`_p "${result}" | jq -r -j "${view_session_functions}${thread_parse_procedure_parents}"`
  feed_view_index_target=`_p "${result}" | jq -r -j "${view_session_functions}${thread_parse_procedure_target}"`
  feed_view_index_replies=`_p "${result}" | jq -r -j "${view_session_functions}${thread_parse_prodecure_replies}" | sed 's/.$//'`
  feed_view_index="${feed_view_index_parents}${feed_view_index_target}${feed_view_index_replies}"
  # CAUTION: key=value pairs are separated by tab characters
  update_session_file "${SESSION_KEY_FEED_VIEW_INDEX}=${feed_view_index}"

  debug 'core_thread' 'END'
}

core_get_profile()
{
  param_did="$1"
  param_output_id="$2"
  param_dump="$3"

  debug 'core_get_profile' 'START'
  debug 'core_get_profile' "param_did:${param_did}"
  debug 'core_get_profile' "param_output_id:${param_output_id}"
  debug 'core_get_profile' "param_dump:${param_dump}"

  result=`api app.bsky.actor.getProfile "${param_did}"`
  status=$?
  debug_single 'core_get_profile'
  _p "${result}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $status -eq 0 ]
  then
    if [ -n "${param_dump}" ]
    then
      _p "${result}" | jq -r "${GENERAL_DUMP_PROCEDURE}"
    else
      if [ -n "${param_output_id}" ]
      then
        profile_output="${BSKYSHCLI_VIEW_TEMPLATE_PROFILE_OUTPUT_ID}"
      else
        profile_output="${BSKYSHCLI_VIEW_TEMPLATE_PROFILE}"
      fi
      profile_output="${profile_output}\n${BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_COMMON}"
      if core_is_actor_current_session "${param_did}"
      then
        profile_output="${profile_output}\n${BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_MYACCOUNT}"
      fi
      _p "${result}" | jq -r '
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
        "'"${profile_output}"'"
      '
    fi
  fi

  debug 'core_get_profile' 'END'

  return $status
}

core_get_pref()
{
  param_group="$1"
  param_item="$2"
  param_dump="$3"

  debug 'core_get_pref' 'START'

  result=`api app.bsky.actor.getPreferences`
  status=$?
  debug_single 'core_get_preferences'
  _p "${result}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $status -eq 0 ]
  then
    if [ -n "${param_dump}" ]
    then
      _p "${result}" | jq -r "${GENERAL_DUMP_PROCEDURE}"
    else
      core_verify_pref_group_parameter "${param_group}"
      group_count=$?
      core_verify_pref_item_parameter "${group_count}" "${RESULT_CORE_VERIFY_PREF_GROUP_PARAMETER}" "${param_item}"
      item_count=$?
      export STR_NO_CONF='(no configured)'
      if [ "${item_count}" -eq 0 ]
      then
        if [ -n "${CORE_VERIFY_PREF_GROUP_adult_content}" ] || [ "${group_count}" -eq 0 ]
        then
          _p "${result}" | jq -r '
            ">>>> adult contents",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#adultContentPref" ) |
            (.enabled // env.STR_NO_CONF) as $adultContents_enabled |
            "enabled: \($adultContents_enabled)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_content_label}" ] || [ "${group_count}" -eq 0 ]
        then
          _p "${result}" | jq -r '
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
        if [ -n "${CORE_VERIFY_PREF_GROUP_saved_feeds}" ] || [ "${group_count}" -eq 0 ]
        then
          _p "${result}" | jq -r '
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
        if [ -n "${CORE_VERIFY_PREF_GROUP_personal_details}" ] || [ "${group_count}" -eq 0 ]
        then
          _p "${result}" | jq -r '
            ">>>> personal details",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#personalDetailsPref") |
            (if has ("birthDate") then .birthDate | split("T")[0] else env.STR_NO_CONF end) as $personalDetails_birthDate |
            "birth date: \($personalDetails_birthDate)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_feed_view}" ] || [ "${group_count}" -eq 0 ]
        then
          _p "${result}" | jq -r '
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
        if [ -n "${CORE_VERIFY_PREF_GROUP_thread_view}" ] || [ "${group_count}" -eq 0 ]
        then
          _p "${result}" | jq -r '
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
        if [ -n "${CORE_VERIFY_PREF_GROUP_interests}" ] || [ "${group_count}" -eq 0 ]
        then
          _p "${result}" | jq -r '
            ">>>> interests",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#interestsPref") |
            (if has("tags") then .tags | join("\n") else env.STR_NO_CONF end) as $interests_tags |
            "[tags]",
            "\($interests_tags)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_muted_words}" ] || [ "${group_count}" -eq 0 ]
        then
          _p "${result}" | jq -r '
            ">>>> muted words",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#muteWordsPref") |
            (if has("items") then .items | join("\n") else env.STR_NO_CONF end) as $mutedWords_items |
            "[items]",
            "\($mutedWords_items)"
          '
        fi
        if [ -n "${CORE_VERIFY_PREF_GROUP_hidden_posts}" ] || [ "${group_count}" -eq 0 ]
        then
          _p "${result}" | jq -r '
            ">>>> hidden posts",
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#hiddenPostsPref") |
            (if has("items") then .items | join("\n") else env.STR_NO_CONF end) as $hiddenPosts_items |
            "[items]",
            "\($hiddenPosts_items)"
          '
        fi
      else  # item_count > 0
        if [ -n "${CORE_VERIFY_PREF_ITEM__adult_content__enabled}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#adultContentPref' 'adult-content' 'enabled' 'enabled' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__content_label__labeler_did}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#contentLabelPref' 'content-label' 'labeler-did' 'labelerDid' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__content_label__label}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#contentLabelPref' 'content-label' 'label' 'label' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__content_label__visibility}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#contentLabelPref' 'content-label' 'visibility' 'visibility' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__saved_feeds__pinned}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#savedFeedsPref' 'saved-feeds' 'pinned' 'pinned' 'array'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__saved_feeds__saved}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#savedFeedsPref' 'saved-feeds' 'saved' 'saved' 'array'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__saved_feeds__timeline_index}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#savedFeedsPref' 'saved-feeds' 'timeline-index' 'timelineIndex' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__personal_details__birth_date}" ]
        then
          output=`_p "${result}" | jq -r '
            .preferences as $pref |
            $pref[] |
            select(."$type" == "app.bsky.actor.defs#personalDetailsPref") |
            if has ("birthDate") then .birthDate | split("T")[0] else env.STR_NO_CONF end
          '`
          if [ -z "${output}" ]
          then
            output="${STR_NO_CONF}"
          fi
          _pn "personal-details.birth-date: ${output}"
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__feed}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'feed' 'feed' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_replies}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-replies' 'hideReplies' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_replies_by_unfollowed}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-replies-by-unfollowed' 'hideRepliesByUnfollowed' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_replies_by_like_count}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-replies-by-like-count' 'hideRepliesByLikeCount' 'number'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_reposts}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-reposts' 'hideReposts' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__feed_view__hide_quote_posts}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#feedViewPref' 'feed-view' 'hide-quote-posts' 'hideQuotePosts' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__thread_view__sort}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#threadViewPref' 'thread-view' 'sort' 'sort' 'string'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__thread_view__prioritize_followed_users}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#threadViewPref' 'thread-view' 'prioritize-followed-users' 'prioritizeFollowedUsers' 'boolean'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__interests__tags}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#interestsPref' 'interests' 'tags' 'tags' 'array'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__muted_words__items}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#mutedWordsPref' 'muted-words' 'items' 'items' 'array'
        fi
        if [ -n "${CORE_VERIFY_PREF_ITEM__hidden_posts__items}" ]
        then
          core_output_pref_item "${result}" 'app.bsky.actor.defs#hiddenPostsPref' 'hidden-posts' 'items' 'items' 'array'
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
  if is_session_exist
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
  param_output_id="$1"

  debug 'core_info_session_index' 'START'
  debug 'core_info_session_index' "param_output_id:${param_output_id}"

  _pn '[index]'
  if [ -n "${param_output_id}" ]
  then
    _pn '[[view indexes: <index> <uri> <cid>]]'
  else
    _pn '[[view indexes: <index>]]'
  fi

  if [ -n "${SESSION_FEED_VIEW_INDEX}" ]
  then
    _slice "${SESSION_FEED_VIEW_INDEX}" '"'
    feed_view_index_count=$?
    chunk_index=1
    while [ "${chunk_index}" -le $feed_view_index_count ]
    do
      session_chunk=`eval _p \"\\$"RESULT_slice_${chunk_index}"\"`
      (
        _slice "${session_chunk}" '|'
        # dynamic assignment in parse_parameters
        # shellcheck disable=SC2154
        session_index="${RESULT_slice_1}"
        # dynamic assignment in parse_parameters, variable use at this file include(source) script
        # shellcheck disable=SC2154,SC2034
        session_uri="${RESULT_slice_2}"
        # dynamic assignment in parse_parameters, variable use at this file include(source) script
        # shellcheck disable=SC2154,SC2034
        session_cid="${RESULT_slice_3}"
        
        if [ -n "${param_output_id}" ]
        then
          printf "%s\t%s\t%s\n" "${session_index}" "${session_uri}" "${session_cid}"
        else
          _pn "${session_index}"
        fi
      )
      chunk_index=`expr "${chunk_index}" + 1`
    done
  fi

  debug 'core_info_session_index' 'END'
}

core_info_session_cursor()
{
  debug 'core_info_session_cursor' 'START'

  _pn '[cursor]'
  _pn "timeline cursor: ${SESSION_GETTIMELINE_CURSOR}"
  _pn "feed cursor: ${SESSION_GETFEED_CURSOR}"
  _pn "author-feed cursor: ${SESSION_GETAUTHORFEED_CURSOR}"

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
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID='${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_META='${BSKYSHCLI_VIEW_TEMPLATE_POST_META}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_HEAD='${BSKYSHCLI_VIEW_TEMPLATE_POST_HEAD}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_BODY='${BSKYSHCLI_VIEW_TEMPLATE_POST_BODY}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL='${BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_SEPARATOR='${BSKYSHCLI_VIEW_TEMPLATE_POST_SEPARATOR}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER='${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_QUOTE='${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_OUTPUT_ID='${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_OUTPUT_ID}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_META='${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_META}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_HEAD='${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_HEAD}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_TAIL='${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_TAIL}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_IMAGE='${BSKYSHCLI_VIEW_TEMPLATE_IMAGE}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_PROFILE='${BSKYSHCLI_VIEW_TEMPLATE_PROFILE}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_PROFILE_OUTPUT_ID='${BSKYSHCLI_VIEW_TEMPLATE_PROFILE_OUTPUT_ID}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_COMMON='${BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_COMMON}'"
  _pn "BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_MYACCOUNT='${BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_MYACCOUNT}'"

  debug 'core_info_meta_config' 'END'
}

core_info_meta_profile()
{
  debug 'core_info_meta_profile' 'START'

  _pn '[profile (active session)]'
  session_files=`(cd "${SESSION_DIR}" && ls -- *"${SESSION_FILENAME_SUFFIX}" 2>/dev/null)`
  for session_file in $session_files
  do
    if [ "${session_file}" = "${SESSION_FILENAME_DEFAULT_PREFIX}${SESSION_FILENAME_SUFFIX}" ]
    then
      _pn '(default)'
    else
      _pn "${session_file}" | sed "s/${SESSION_FILENAME_SUFFIX}$//g"
    fi
  done

  debug 'core_info_meta_profile' 'END'
}

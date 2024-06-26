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
BSKYSHCLI_VIA_VALUE="bsky-sh-cli (Bluesky in the shell) ${BSKYSHCLI_CLI_VERSION}"
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
# reffered to https://qiita.com/shimataro999/items/fced9665fa970c009c1e
PATTERN_URL='https?:\/\/((([a-z]|[0-9]|[-._~])|%[0-9a-f][0-9a-f]|[!$&'\''()*+,;=]|:)*@)?(\[((([0-9a-f]{1,4}:){6}([0-9a-f]{1,4}:[0-9a-f]{1,4}|([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3})|::([0-9a-f]{1,4}:){5}([0-9a-f]{1,4}:[0-9a-f]{1,4}|([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3})|([0-9a-f]{1,4})?::([0-9a-f]{1,4}:){4}([0-9a-f]{1,4}:[0-9a-f]{1,4}|([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3})|(([0-9a-f]{1,4}:){0,1}[0-9a-f]{1,4})?::([0-9a-f]{1,4}:){3}([0-9a-f]{1,4}:[0-9a-f]{1,4}|([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3})|(([0-9a-f]{1,4}:){0,2}[0-9a-f]{1,4})?::([0-9a-f]{1,4}:){2}([0-9a-f]{1,4}:[0-9a-f]{1,4}|([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3})|(([0-9a-f]{1,4}:){0,3}[0-9a-f]{1,4})?::[0-9a-f]{1,4}:([0-9a-f]{1,4}:[0-9a-f]{1,4}|([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3})|(([0-9a-f]{1,4}:){0,4}[0-9a-f]{1,4})?::([0-9a-f]{1,4}:[0-9a-f]{1,4}|([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3})|(([0-9a-f]{1,4}:){0,5}[0-9a-f]{1,4})?::[0-9a-f]{1,4}|(([0-9a-f]{1,4}:){0,6}[0-9a-f]{1,4})?::)|v[0-9a-f]+\.(([a-z]|[0-9]|[-._~])|[!$&'\''()*+,;=]|:)+)]|([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])){3}|(([a-z]|[0-9]|[-._~])|%[0-9a-f][0-9a-f]|[!$&'\''()*+,;=])*)(:\d*)?(\/((([a-z]|[0-9]|[-._~])|%[0-9a-f][0-9a-f]|[!$&'\''()*+,;=]|[:@]))*)*(\?((([a-z]|[0-9]|[-._~])|%[0-9a-f][0-9a-f]|[!$&'\''()*+,;=]|[:@])|[\/?])*)?(#((([a-z]|[0-9]|[-._~])|%[0-9a-f][0-9a-f]|[!$&'\''()*+,;=]|[:@])|[\/?])*)?'

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

core_text_size()
{
  param_text_size_text="$1"

  debug 'core_text_size' 'START'
  debug 'core_text_size' "param_text_size_text:${param_text_size_text}"

  unescaped_text=`echo "${param_text_size_text}" | sed 's/\\\\"/"/g'`
  debug 'core_text_size' "unescaped_text:${unescaped_text}"
  text_size=`_p "${unescaped_text}" | wc -m`

  debug 'core_text_size' 'END'

  return "${text_size}"
}

core_text_size_lines()
{
  param_core_text_size_lines_text="$1"
  param_core_text_size_lines_separator_prefix="$2"

  debug 'core_text_size_lines' 'START'
  debug 'core_text_size_lines' "param_core_text_size_lines_text:${param_core_text_size_lines_text}"
  debug 'core_text_size_lines' "param_core_text_size_lines_separator_prefix:${param_core_text_size_lines_separator_prefix}"

  count=0
  lines=''
  if [ -n "${param_core_text_size_lines_separator_prefix}" ]
  then
    # "while read -r <variable>" is more smart, but "read -r" can not use in Bourne shell (Solaris sh)
    evacuated_IFS=$IFS
    # each line separated by newline
    IFS='
'
    # no double quote for use word splitting
    # shellcheck disable=SC2086
    set -- $param_core_text_size_lines_text
    IFS=$evacuated_IFS
    while [ $# -gt 0 ]
    do
      if _startswith "$1" "${param_core_text_size_lines_separator_prefix}"
      then  # separator line detected
        if core_is_post_text_meaningful "${lines}"
        then  # post text is meaningful
          count=`expr "${count}" + 1`
          size=`_p "${lines}" | wc -m`
          eval "RESULT_core_text_size_lines_${count}=${size}"
          debug 'core_text_size_lines' "count:${count} size:${size}"
        fi
        # clear single post content
        lines=''
      else  # separator not detected
        # stack to single content
        if [ -n "${lines}" ]
        then
          lines=`printf "%s\n%s" "${lines}" "$1"`
        else
          lines="$1"
        fi
      fi
      # go to next line
      shift
    done
    # process after than last separator
    if core_is_post_text_meaningful "${lines}"
    then
      count=`expr "${count}" + 1`
      size=`_p "${lines}" | wc -m`
      eval "RESULT_core_text_size_lines_${count}=${size}"
      debug 'core_text_size_lines' "remain part count:${count} size:${size}"
    fi
  else  # separator not specified : all lines as single content
    count=1
    size=`_p "${param_core_text_size_lines_text}" | wc -m`
    eval "RESULT_core_text_size_lines_${count}=${size}"
    debug 'core_text_size_lines' "no-separator count:${count} size:${size}"
  fi

  debug 'core_text_size_lines' 'END'

  return $count
}

core_get_text_file()
{
  param_text_file_path="$1"

  debug 'core_get_text_file' 'START'
  debug 'core_get_text_file' "param_text_file_path:${param_text_file_path}"

  status_core_get_text_file=0
  if [ -r "${param_text_file_path}" ]
  then
    # escape (newline) -> \n
    # using GNU sed -z option
    < "${param_text_file_path}" sed -z 's/\n/\\n/g'
  else
    check_comma=`_p "${param_text_file_path}" | sed 's/[^,]//g'`
    if [ -n "${check_comma}" ]
    then
      error_msg "commas(,) may be used to separate multiple paths"
    fi
    error_msg "specified text file is not readable: ${param_text_file_path}"
    status_core_get_text_file=1
  fi

  debug 'core_get_text_file' 'END'

  return $status_core_get_text_file
}

core_output_text_file_size()
{
  param_text_file_path="$1"
  param_count_only="$2"
  param_output_json="$3"

  debug 'core_output_text_file_size' 'START'
  debug 'core_output_text_file_size' "param_text_file_path:${param_text_file_path}"
  debug 'core_output_text_file_size' "param_count_only:${param_count_only}"
  debug 'core_output_text_file_size' "param_output_json:${param_output_json}"

  if text_file=`core_get_text_file "${param_text_file_path}"`
  then
    # unescape \n -> (newline)
    text_size=`_p "${text_file}" | sed 's/\\\\n/\n/g' | wc -m`
    if [ "${text_size}" -le 300 ]
    then
      status=0
    else
      status=1
    fi
    if [ -n "${param_output_json}" ]
    then
      if [ $status -eq 0 ]
      then
        status_value='true'
      else
        status_value='false'
      fi
      _p "{\"size\":${text_size},\"status\":${status_value},\"file\":\"${param_text_file_path}\"}"
    else
      if [ -n "${param_count_only}" ]
      then
        _pn "${text_size}"
      else
        if [ $status -eq 0 ]
        then
          status_message='OK'
        else
          status_message='NG:over 300'
        fi
        _pn "text file character count: ${text_size} [${status_message}] [file:${param_text_file_path}]"
      fi
    fi
  fi

  debug 'core_output_text_file_size' 'END'
}

core_output_text_file_size_lines()
{
  param_text_file_path="$1"
  param_separator_prefix="$2"
  param_count_only="$3"
  param_output_json="$4"

  debug 'core_output_text_file_size_lines' 'START'
  debug 'core_output_text_file_size_lines' "param_text_file_path:${param_text_file_path}"
  debug 'core_output_text_file_size_lines' "param_separator_prefix:${param_separator_prefix}"
  debug 'core_output_text_file_size_lines' "param_count_only:${param_count_only}"
  debug 'core_output_text_file_size_lines' "param_output_json:${param_output_json}"

  if [ -r "${param_text_file_path}" ]
  then
    file_content=`cat "${param_text_file_path}"`
    core_text_size_lines "${file_content}" "${param_separator_prefix}"
    section_count=$?
    section_index=1
    json_stack="{\"file\":\"${param_text_file_path}\",\"sections\":["
    while [ $section_index -le $section_count ]
    do
      text_size=`eval _p \"\\$"RESULT_core_text_size_lines_${section_index}"\"`
      if [ "${text_size}" -le 300 ]
      then
        status=0
      else
        status=1
      fi
      if [ -n "${param_output_json}" ]
      then
        if [ $status -eq 0 ]
        then
          status_value='true'
        else
          status_value='false'
        fi
        if [ $section_index -gt 1 ]
        then
          json_stack="${json_stack},"
        fi
        json_stack="${json_stack}{\"size\":${text_size},\"status\":${status_value}}"
      else
        if [ -n "${param_count_only}" ]
        then
          _pn "${text_size}"
        else
          if [ $status -eq 0 ]
          then
            status_message='OK'
          else
            status_message='NG:over 300'
          fi
          if [ $section_count -eq 1 ]
          then
            _pn "text file character count: ${text_size} [${status_message}] [file:${param_text_file_path}]"
          else
            _pn "text file character count: ${text_size} [${status_message}] [section #${section_index} of file:${param_text_file_path}]"
          fi
        fi
      fi
      section_index=`expr "${section_index}" + 1`
    done
    json_stack="${json_stack}]}"
    if [ -n "${param_output_json}" ]
    then
      _p "${json_stack}"
    fi
  else
    check_comma=`_p "${param_text_file_path}" | sed 's/[^,]//g'`
    if [ -n "${check_comma}" ]
    then
      error_msg "commas(,) may be used to separate multiple paths"
    fi
    error_msg "specified text file is not readable: ${param_text_file_path}"
  fi

  debug 'core_output_text_file_size_lines' 'END'
}

core_verify_text_file_size()
{
  param_text_file_path="$1"

  debug 'core_verify_text_file_size' 'START'
  debug 'core_verify_text_file_size' "param_text_file_path:${param_text_file_path}"

  status_core_verify_text_file_size=0
  if text_file=`core_get_text_file "${param_text_file_path}"`
  then
    # unescape \n -> (newline)
    text_size=`_p "${text_file}" | sed 's/\\\\n/\n/g' | wc -m`
    if [ "${text_size}" -gt 300 ]
    then
      error_msg "The number of characters is ${text_size}, which exceeds the upper limit of 300 characters: ${param_text_file_path}"
      status_core_verify_text_file_size=1
    fi
  else
    status_core_verify_text_file_size=1
  fi

  debug 'core_verify_text_file_size' 'END'

  return $status_core_verify_text_file_size
}

core_verify_text_file_size_lines()
{
  param_text_file_path="$1"
  param_separator_prefix="$2"

  debug 'core_verify_text_file_size_lines' 'START'
  debug 'core_verify_text_file_size_lines' "param_text_file_path:${param_text_file_path}"
  debug 'core_verify_text_file_size_lines' "param_separator_prefix:${param_separator_prefix}"

  status_core_verify_text_file_size_lines=0
  if text_file=`core_get_text_file "${param_text_file_path}"`
  then
    # unescape \n -> (newline)
    text_file=`_p "${text_file}" | sed 's/\\\\n/\n/g'`
    core_text_size_lines "${text_file}" "${param_separator_prefix}"
    section_count=$?
    section_index=1
    while [ $section_index -le $section_count ]
    do
      size=`eval _p \"\\$"RESULT_core_text_size_lines_${section_index}"\"`
      if [ "${size}" -gt 300 ]
      then
        error_msg "The number of characters is ${size}, which exceeds the upper limit of 300 characters: section #${section_index} at ${param_text_file_path}"
        status_core_verify_text_file_size_lines=1
      fi
      section_index=`expr "${section_index}" + 1`
    done
  else
    status_core_verify_text_file_size_lines=1
  fi

  debug 'core_verify_text_file_size_lines' 'END'

  return $status_core_verify_text_file_size_lines
}

core_process_files()
{
  param_process_files="$1"
  param_process_name="$2"
  if [ $# -ge 2 ]
  then
    shift
    shift
  fi

  debug 'core_process_files' 'START'
  debug 'core_process_files' "param_process_files:${param_process_files}"
  debug 'core_process_files' "param_process_name:${param_process_name}"

  status_core_process_files=0
  _slice "${param_process_files}" "${BSKYSHCLI_PATH_DELIMITER}"
  files_count=$?
  files_index=1
  while [ $files_index -le $files_count ]
  do
    target_file=`eval _p \"\\$"RESULT_slice_${files_index}"\"`
    if "${param_process_name}" "${target_file}" "$@"
    then
      :
    else
      status_core_process_files=1
    fi
    files_index=`expr "$files_index" + 1`
  done

  debug 'core_process_files' 'END'

  return $status_core_process_files
}

core_verify_text_size()
{
  param_core_verify_text_size_text="$1"
  param_text_files="$2"

  debug 'core_verify_text_size' 'START'
  debug 'core_verify_text_size' "param_core_verify_text_size_text:${param_core_verify_text_size_text}"
  debug 'core_verify_text_size' "param_text_files:${param_text_files}"

  status_core_verify_text_size=0
  if [ -n "${param_core_verify_text_size_text}" ]
  then
    core_text_size "${param_core_verify_text_size_text}"
    size=$?
    if [ $size -gt 300 ]
    then
      error_msg "The number of characters is ${size}, which exceeds the upper limit of 300 characters: --text parameter value"
      status_core_verify_text_size=1
    fi
  fi

  if [ -n "${param_text_files}" ]
  then
    if core_process_files "${param_text_files}" 'core_verify_text_file_size'
    then
      :
    else
      status_core_verify_text_size=1
    fi
  fi

  if [ $status_core_verify_text_size -ne 0 ]
  then
    error 'Processing has been canceled'
  fi

  debug 'core_verify_text_size' 'END'
}

core_verify_text_size_lines()
{
  param_stdin_text="$1"
  param_specified_text="$2"
  param_text_files="$3"
  param_separator_prefix="$4"

  debug 'core_verify_text_size_lines' 'START'
  debug 'core_verify_text_size_lines' "param_stdin_text:${param_stdin_text}"
  debug 'core_verify_text_size_lines' "param_specified_text:${param_specified_text}"
  debug 'core_verify_text_size_lines' "param_text_files:${param_text_files}"
  debug 'core_verify_text_size_lines' "param_separator_prefix:${param_separator_prefix}"

  status_core_verify_text_size_lines=0

  if [ -n "${param_stdin_text}" ]
  then
    core_text_size_lines "${param_stdin_text}" "${param_separator_prefix}"
    section_count=$?
    section_index=1
    while [ $section_index -le $section_count ]
    do
      size=`eval _p \"\\$"RESULT_core_text_size_lines_${section_index}"\"`
      if [ "${size}" -gt 300 ]
      then
        error_msg "The number of characters is ${size}, which exceeds the upper limit of 300 characters: section #${section_index} at standard input"
        status_core_verify_text_size_lines=1
      fi
      section_index=`expr "${section_index}" + 1`
    done
  fi

  if [ -n "${param_specified_text}" ]
  then
    core_text_size_lines "${param_specified_text}" "${param_separator_prefix}"
    section_count=$?
    section_index=1
    while [ $section_index -le $section_count ]
    do
      size=`eval _p \"\\$"RESULT_core_text_size_lines_${section_index}"\"`
      if [ "${size}" -gt 300 ]
      then
        error_msg "The number of characters is ${size}, which exceeds the upper limit of 300 characters: section #${section_index} at --text value"
        status_core_verify_text_size_lines=1
      fi
      section_index=`expr "${section_index}" + 1`
    done
  fi

  if [ -n "${param_text_files}" ]
  then
    if core_process_files "${param_text_files}" 'core_verify_text_file_size_lines' "${param_separator_prefix}"
    then
      :
    else
      status_core_verify_text_size_lines=1
    fi
  fi

  if [ $status_core_verify_text_size_lines -ne 0 ]
  then
    error 'Processing has been canceled'
  fi

  debug 'core_verify_text_size_lines' 'END'
}

core_build_images_fragment_precheck_single()
{
  param_image="$1"

  debug 'core_build_images_fragment_precheck_single' 'START'
  debug 'core_build_images_fragment_precheck_single' "param_image:${param_image}"

  if [ -r "${param_image}" ]
  then
    check_required_command 'file'
    check_result=$?
    if [ $check_result -eq 0 ]
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
  debug 'core_build_images_fragment_precheck' 'START'
  debug 'core_build_images_fragment_precheck' "param_image_alt:$*"

  actual_image_count=0
  worst_status=0
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
    fi
    shift
    if [ $# -gt 0 ]
    then
      shift
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
  debug 'core_build_images_fragment' 'START'
  debug 'core_build_images_fragment' "param_image_alt:$*"

  core_build_images_fragment_precheck "$@"
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

core_extract_link_url()
{
  param_core_extract_link_url_text="$1"
  param_extract_linkcard_index="$2"

  debug 'core_extract_link_url' 'START'
  debug 'core_extract_link_url' "param_core_extract_link_url_text:${param_core_extract_link_url_text}"
  debug 'core_extract_link_url' "param_extract_linkcard_index:${param_extract_linkcard_index}"

  # TODO: URL shortening processing

  # unescape (e.g. '\n', '"' : escaped at parse_parameters()) for adjust index
#  expanded_text=`echo "${param_core_extract_link_url_text}" | sed 's/\\\\"/"/g'`
  # in the after loop, "expr length" and "expr match" change to "expr :" and self implemetation by platrom porability reason
  # '\n' handling difficult in self implementation, escape to convert from '\n' to '\t'
  # using GNU sed -z option
  # 
  # however, since using jq (cheat) now, may not need to handle '\n'
  expanded_text=`echo "${param_core_extract_link_url_text}" | sed -z 's/\\\\"/"/g ; s/\n/\t/g'`
  accum_cut_length=0
  extract_link_count=0

  while [ -n "${expanded_text}" ]
  do
    url=`echo "${expanded_text}" | grep -o -i -E "${PATTERN_URL}"`
    # no double quote for use word splitting
    # shellcheck disable=SC2086
    set -- $url
    url=$1
    if [ -z "${url}" ]
    then
      break
    fi
    # match "ABCDE http://..." "\(.*\)http://..." -> "ABCDE "
    # length "ABCDE " -> url previous string length = url index (0 start)
#    url_index=`expr length \( match "${expanded_text}" "\(.*\)${url}" \)`
    # "expr length" and "expr match" is not compatible for macOS(?), FreeBSD : https://www.shellcheck.net/wiki/SC2308
    # "${#var}" is not compatible for Solaris sh.
    # implement by "expr :" and self length function.
#    url_before=`expr "${expanded_text}" : "\(.*\)${url}"`
#    _strlen "${url_before}"
#    url_index=$?
    # cheat (use jq) for shortest match (countermeasure to same URL string in text)
    url_index=`_p "${expanded_text}" | jq -R 'index("'"${url}"'")'`
    _strlen "${url}"
    url_length=$?
    # until end of url
    cut_length=`expr "${url_index}" + "${url_length}"`
    # cut command is 1 start index
    cut_index=`expr "${cut_length}" + 1`
    # actual (original expanded text) index of url start
    actual_url_start=`expr "${accum_cut_length}" + "${url_index}"`
    # actual (original expanded text) index of url end
    actual_url_end=`expr "${actual_url_start}" + "${url_length}"`
    # stack on result set (url, actual index of url start, actual index of url end)
    link_facets_element="${link_facets_element} ${url} ${actual_url_start} ${actual_url_end}"
    # accumulate cut length in original expand text
    accum_cut_length=`expr "${accum_cut_length}" + "${cut_length}"`
    # cut until target url
    #   '\n' -> '\t' : prevent cut command targets all lines
    #   cut -c (cut_index)- : cut until url and leave after
    #   '\t' -> '\n' : restore prevent conversion
#    expanded_text=`_p "${expanded_text}" | tr '\n' '\t' | cut -c "${cut_index}"- | tr '\t' '\n'`
    # at before loop, already convert from '\n' to '\t' by expr platform portability reason
    expanded_text=`_p "${expanded_text}" | cut -c "${cut_index}"-`
    # extract link card target url
    if [ -n "${param_extract_linkcard_index}" ]
    then
      extract_link_count=`expr "${extract_link_count}" + 1`
      if [ "${extract_link_count}" -eq "${param_extract_linkcard_index}" ]
      then
        extract_linkcard_url="${url}"
      fi
    fi
  done
  if [ -z "${param_extract_linkcard_index}" ]
  then
    # output facets element: <url #1> <url start index #1> <url end index #1> <url #2> <url start index #2> <url end index #2>...
    _p "${link_facets_element}"
    # TODO: URL shortening processing
#    RESULT_extract_link_url_processed_text="<URL shortening processing text>"
  else
    # output specified target index link URL
    _p "${extract_linkcard_url}"
  fi  

  debug 'core_extract_link_url' 'END'
}

core_build_link_facets_fragment()
{
  param_core_build_link_facets_fragment_text="$1"

  debug 'core_build_link_facets_fragment' 'START'
  debug 'core_build_link_facets_fragment' "param_core_build_link_facets_fragment_text:${param_core_build_link_facets_fragment_text}"

  link_facets_fragment='['
  element_count=0
  link_facets_element=`core_extract_link_url "${param_core_build_link_facets_fragment_text}" ''`
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $link_facets_element
  while [ $# -gt 0 ]
  do
    url=$1
    url_start=$2
    url_end=$3
    if [ $element_count -gt 0 ]
    then
      link_facets_fragment="${link_facets_fragment},"
    fi
    link_facets_fragment="${link_facets_fragment}{\"features\":[{\"\$type\":\"app.bsky.richtext.facet#link\",\"uri\":\"${url}\"}],\"index\":{\"byteEnd\":${url_end},\"byteStart\":${url_start}}}"
    shift
    shift
    shift
    element_count=`expr "${element_count}" + 1`
  done
  link_facets_fragment="${link_facets_fragment}]"
  if [ "${element_count}" -gt 0 ]
  then
    _p "${link_facets_fragment}"
  fi

  debug 'core_build_link_facets_fragment' 'END'
}

core_build_external_fragment()
{
  param_core_build_external_fragment_text="$1"
  param_linkcard_index="$2"

  debug 'core_build_external_fragment' 'START'
  debug 'core_build_external_fragment' "param_core_build_external_fragment_text:${param_core_build_external_fragment_text}"
  debug 'core_build_external_fragment' "param_linkcard_index:${param_linkcard_index}"

  if [ "${param_linkcard_index}" -gt 0 ]
  then
    url=`core_extract_link_url "${param_core_build_external_fragment_text}" "${param_linkcard_index}"`
    if [ -n "${url}" ]
    then
      external_html=`curl -s "${url}" 2>/dev/null`
      get_html_status=$?
      if [ $get_html_status -eq 0 ]
      then
        # TODO: code/pattern cleanup and correct references to prefix definitions
        og_description=`_p "${external_html}" | grep -o -i -E '< *meta +property *= *"og:description" +content *= *"[^"]*"[^/>]*/?>' | sed -E 's_< *meta +property *= *"og:description" +content *= *"([^"]*)"[^/>]*/?>_\1_g'`
        og_image=`_p "${external_html}" | grep -o -i -E '< *meta +property *= *"og:image" +content *= *"[^"]*"[^/>]*/?>' | sed -E 's_< *meta +property *= *"og:image" +content *= *"([^"]*)"[^/>]*/?>_\1_g'`
        og_title=`_p "${external_html}" | grep -o -i -E '< *meta +property *= *"og:title" +content *= *"[^"]*"[^/>]*/?>' | sed -E 's_< *meta +property *= *"og:title" +content *= *"([^"]*)"[^/>]*/?>_\1_g'`
        og_url=`_p "${external_html}" | grep -o -i -E '< *meta +property *= *"og:url" +content *= *"[^"]*"[^/>]*/?>' | sed -E 's_< *meta +property *= *"og:url" +content *= *"([^"]*)"[^/>]*/?>_\1_g'`
        if [ -n "${og_title}" ] && [ -n "${og_image}" ]
        then
          check_required_command 'file'
          check_result=$?
          if [ $check_result -eq 0 ]
          then
            image_temporary_path=`mktemp --tmpdir bsky_sh_cli.XXXXXXXXXX`
            mktemp_status=$?
            debug 'core_build_externa_fragment' "image_temporary_path:${image_temporary_path}"
            if [ $mktemp_status -eq 0 ]
            then
              curl -o "${image_temporary_path}" "${og_image}" 2>/dev/null
              get_image_status=$?
              if [ $get_image_status -eq 0 ]
              then
                mime_type=`file --mime-type --brief "${image_temporary_path}"`
                _startswith "${mime_type}" 'image/'
                mime_type_check_status=$?
                if [ "${mime_type_check_status}" -eq 0 ]
                then
                  upload_blob=`api com.atproto.repo.uploadBlob "${image_temporary_path}" "${mime_type}"`
                  api_status=$?
                  if [ $api_status -eq 0 ]
                  then
                    thumb_fragment=`_p "${upload_blob}" | jq -c -M '.blob'`
                    # $type is not variable
                    # shellcheck disable=SC2016
                    _p '{"$type":"app.bsky.embed.external","external":{"description":"'"${og_description}"'","thumb":'"${thumb_fragment}"',"title":"'"${og_title}"'","uri":"'"${og_url}"'"}}'
                    status=0
                  else
                    error_msg 'image file upload failed'
                    status=1
                  fi
                else  # file mime-type is not image
                  error_msg "link destination site specified image file is not image - mime-type:${mime_type}"
                  status=1
                fi
              else
                error_msg "image file download failed: ${og_image}"
                status=1
              fi
              rm -f "${image_temporary_path}" 2>/dev/null
            else
              error_msg 'create image download temporary file failed'
              status=1
            fi
          else  # file command not found
            status=1
          fi
        else  # OGP information not found
          html_title=`_p "${external_html}" | grep -o -i -E '< *title *>[^<]*< */ *title *>' | sed -E 's_< *title *>([^<]*)< */ *title *>_\1_g'`
          # $type is not variable
          # shellcheck disable=SC2016
          _p '{"$type":"app.bsky.embed.external","external":{"description":"","title":"'"${html_title}"'","uri":"'"${url}"'"}}'
          status=0
        fi
      else  # get html failed
        error_msg "site access failed: ${url}"
        status=1
      fi
    else  # url is not specfied
      status=0
    fi
  else  # param_linkcard_index is 0
    status=0
  fi

  debug 'core_build_external_fragment' 'END'

  return $status
}

# build "langs" json fragment in post
# 'en,ja' -> '["en","ja"]'
core_build_langs_fragment()
{
  param_langs="$1"

  debug 'core_build_langs_fragment' 'START'
  debug 'core_build_langs_fragment' "param_langs:${param_langs}"

  langs_fragment=''

  # get default value from configuration
  langs="${BSKYSHCLI_POST_DEFAULT_LANGUAGES}"
  if [ -n "${param_langs}" ]
  then
    langs="${param_langs}"
  fi
  if [ -n "${langs}" ]
  then
    _slice "${langs}" ','
    lang_count=$?
    lang_index=1
    langs_fragment='['
    while [ $lang_index -le $lang_count ]
    do
      lang_element=`eval _p \"\\$"RESULT_slice_${lang_index}"\"`
      lang_element=`_p "${lang_element}" | sed 's/^ *\([^ ]*\) *$/\1/g'`
      if [ $lang_index -gt 1 ]
      then
        langs_fragment="${langs_fragment},"
      fi
      langs_fragment="${langs_fragment}\"${lang_element}\""
      lang_index=`expr "${lang_index}" + 1`
    done
    langs_fragment="${langs_fragment}]"
  fi
  if [ -n "${langs_fragment}" ]
  then
    _p "${langs_fragment}"
  fi

  debug 'core_build_langs_fragment' 'END'
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
  param_output_via="$2"

  debug 'core_create_post_chunk' 'START'
  debug 'core_create_post_chunk' "param_output_id:${param_output_id}"
  debug 'core_create_post_chunk' "param_output_via:${param_output_via}"

  if [ -n "${param_output_id}" ]
  then
    # escape for substitution at placeholder replacement 
    view_post_output_id=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID}" | sed 's/\\\\/\\\\\\\\/g'`
    view_post_feed_generator_output_id=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_OUTPUT_ID}" | sed 's/\\\\/\\\\\\\\/g'`
  else
    view_post_output_id=''
    view_post_feed_generator_output_id=''
  fi
  if [ -n "${param_output_via}" ]
  then
    view_post_output_via=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA}" | sed 's/\\\\/\\\\\\\\/g'`
  else
    view_post_output_via=''
  fi
  view_template_post_meta=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_META}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'/'"${view_post_output_via}"'/g'`
  view_template_post_head=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_HEAD}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'/'"${view_post_output_via}"'/g'`
  view_template_post_body=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_BODY}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'/'"${view_post_output_via}"'/g'`
  view_template_post_tail=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'/'"${view_post_output_via}"'/g'`
  view_template_image=`_p "${BSKYSHCLI_VIEW_TEMPLATE_IMAGE}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'/'"${view_post_output_via}"'/g'`
  view_template_post_separator=`_p "${BSKYSHCLI_VIEW_TEMPLATE_POST_SEPARATOR}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'/'"${view_post_output_via}"'/g'`
  # disable via to quoted
  view_template_quoted_post_meta=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_META}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'//g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_quoted_post_head=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_HEAD}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'//g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_quoted_post_body=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_BODY}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'//g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_quoted_image=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_IMAGE}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'//g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_feed_generator_meta=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_META}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_feed_generator_output_id}"'/g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_feed_generator_head=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_HEAD}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_feed_generator_output_id}"'/g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_feed_generator_tail=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_TAIL}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_feed_generator_output_id}"'/g; s/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_external_meta=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_EXTERNAL_META}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_external_head=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_EXTERNAL_HEAD}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_post_external_body=`_p "${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}${BSKYSHCLI_VIEW_TEMPLATE_POST_EXTERNAL_BODY}" | sed 's/\\\\n/\\\\n'"${BSKYSHCLI_VIEW_TEMPLATE_QUOTE}"'/g'`
  view_template_link=`_p "${BSKYSHCLI_VIEW_TEMPLATE_LINK}" | sed 's/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER}"'/'"${view_post_output_id}"'/g; s/'"${BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_VIA_PLACEHOLDER}"'/'"${view_post_output_via}"'/g'`
  # $<variables> want to pass through for jq
  # shellcheck disable=SC2016
  _p 'def output_image(image_index; image; is_quoted):
        image_index as $IMAGE_INDEX |
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
          output_image(.; $image; is_quoted)
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
        "" as $VIA |
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
          (post_fragment.record.via // "") as $VIA |
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
  param_output_via="$5"
  param_output_json="$6"

  debug 'core_get_timeline' 'START'
  debug 'core_get_timeline' "param_algorithm:${param_algorithm}"
  debug 'core_get_timeline' "param_limit:${param_limit}"
  debug 'core_get_timeline' "param_next:${param_next}"
  debug 'core_get_timeline' "param_output_id:${param_output_id}"
  debug 'core_get_timeline' "param_output_via:${param_output_via}"
  debug 'core_get_timeline' "param_output_json:${param_output_json}"

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
    if [ -n "${param_output_json}" ]
    then
      _p "${result}"
    else
      view_post_functions=`core_create_post_chunk "${param_output_id}" "${param_output_via}"`
      _p "${result}" | jq -r "${view_post_functions}${FEED_PARSE_PROCEDURE}"
    fi

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
  param_output_via="$7"
  param_output_json="$8"

  debug 'core_get_feed' 'START'
  debug 'core_get_feed' "param_did:${param_did}"
  debug 'core_get_feed' "param_record_key:${param_record_key}"
  debug 'core_get_feed' "param_url:${param_url}"
  debug 'core_get_feed' "param_limit:${param_limit}"
  debug 'core_get_feed' "param_next:${param_next}"
  debug 'core_get_feed' "param_output_id:${param_output_id}"
  debug 'core_get_feed' "param_output_via:${param_output_via}"
  debug 'core_get_feed' "param_output_json:${param_output_json}"

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
      if [ -n "${param_output_json}" ]
      then
        _p "${result}"
      else
        view_post_functions=`core_create_post_chunk "${param_output_id}" "${param_output_via}"`
        _p "${result}" | jq -r "${view_post_functions}${FEED_PARSE_PROCEDURE}"
      fi

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
  param_output_via="$6"
  param_output_json="$7"

  debug 'core_get_author_feed' 'START'
  debug 'core_get_author_feed' "param_did:${param_did}"
  debug 'core_get_author_feed' "param_limit:${param_limit}"
  debug 'core_get_author_feed' "param_next:${param_next}"
  debug 'core_get_author_feed' "param_filter:${param_filter}"
  debug 'core_get_author_feed' "param_output_id:${param_output_id}"
  debug 'core_get_author_feed' "param_output_via:${param_output_via}"
  debug 'core_get_author_feed' "param_output_json:${param_output_json}"

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
    if [ -n "${param_output_json}" ]
    then
      _p "${result}"
    else
      view_post_functions=`core_create_post_chunk "${param_output_id}" "${param_output_via}"`
      _p "${result}" | jq -r "${view_post_functions}${FEED_PARSE_PROCEDURE}"
    fi

    cursor=`_p "${result}" | jq -r '.cursor // "'"${CURSOR_TERMINATE}"'"'`
    view_session_functions=`core_create_session_chunk`
    feed_view_index=`_p "${result}" | jq -r -j "${view_session_functions}${FEED_PARSE_PROCEDURE}" | sed 's/.$//'`
    # CAUTION: key=value pairs are separated by tab characters
    update_session_file "${SESSION_KEY_GETAUTHORFEED_CURSOR}=${cursor}	${SESSION_KEY_FEED_VIEW_INDEX}=${feed_view_index}"
  fi

  debug 'core_get_author_feed' 'END'

  return $status
}

core_output_post()
{
  param_post_uri_list="$1"
  param_output_id="$2"
  param_output_via="$3"
  param_output_json="$4"

  debug 'core_output_post' 'START'
  debug 'core_output_post' "param_post_uri_list:${param_post_uri_list}"
  debug 'core_output_post' "param_output_id:${param_output_id}"
  debug 'core_output_post' "param_output_via:${param_output_via}"
  debug 'core_output_post' "param_output_json:${param_output_json}"

  result=`api app.bsky.feed.getPosts "${param_post_uri_list}"`
  status=$?
  debug_single 'core_output_post'
  _p "${result}" > "${BSKYSHCLI_DEBUG_SINGLE}"

  if [ $status -eq 0 ]
  then
    feed_struct_posts=`_p "${result}" | jq -c '{"feed":[.[] | {"post":.[]}]}'`
    if [ -n "${param_output_json}" ]
    then
      _p "${result}"
    else
      # parameter: output-id, output-via
      view_post_functions=`core_create_post_chunk "${param_output_id}" "${param_output_via}"`
      _p "${feed_struct_posts}" | jq -r "${view_post_functions}${FEED_PARSE_PROCEDURE}"
    fi

    view_session_functions=`core_create_session_chunk`
    feed_view_index=`_p "${feed_struct_posts}" | jq -r -j "${view_session_functions}${FEED_PARSE_PROCEDURE}" | sed 's/.$//'`
    # CAUTION: key=value pairs are separated by tab characters
    update_session_file "${SESSION_KEY_FEED_VIEW_INDEX}=${feed_view_index}"
  fi

  debug 'core_output_post' 'END'
}

core_posts_single()
{
  param_core_posts_single_text="$1"
  param_langs="$2"
  param_parent_uri="$3"
  param_parent_cid="$4"

  debug 'core_posts_single' 'START'
  debug 'core_posts_single' "param_core_posts_single_text:${param_core_posts_single_text}"
  debug 'core_posts_single' "param_langs:${param_langs}"
  debug 'core_posts_single' "param_parent_uri:${param_parent_uri}"
  debug 'core_posts_single' "param_parent_cid:${param_parent_cid}"

  created_at=`get_ISO8601UTCbs`
  if [ -n "${param_parent_uri}" ] && [ -n "${param_parent_cid}" ]
  then
    reply_fragment=`core_build_reply_fragment "${param_parent_uri}" "${param_parent_cid}"`
  else
    reply_fragment=''
  fi
  link_facets_fragment=`core_build_link_facets_fragment "${param_core_posts_single_text}"`
  external_fragment=`core_build_external_fragment "${param_core_posts_single_text}" 1`
  langs_fragment=`core_build_langs_fragment "${param_langs}"`
  if [ -n "${reply_fragment}" ]
  then
    record="{\"text\":\"${param_core_posts_single_text}\",\"createdAt\":\"${created_at}\",${reply_fragment}"
  else
    record="{\"text\":\"${param_core_posts_single_text}\",\"createdAt\":\"${created_at}\""
  fi
  if [ -n "${external_fragment}" ]
  then
    record="${record},\"embed\":${external_fragment}"
  fi
  if [ -n "${link_facets_fragment}" ]
  then
    record="${record},\"facets\":${link_facets_fragment}"
  fi
  if [ -n "${langs_fragment}" ]
  then
    record="${record},\"langs\":${langs_fragment}"
  fi
  if [ "${BSKYSHCLI_POST_VIA}" = 'ON' ]
  then
    record="${record},\"via\":\"${BSKYSHCLI_VIA_VALUE}\""
  fi
  record="${record}}"
  
  result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''`
  status=$?
  debug_single 'core_posts'
  _p "${result}" > "${BSKYSHCLI_DEBUG_SINGLE}"
  if [ $status -eq 0 ]
  then
    RESULT_core_posts_single_uri=`_p "${result}" | jq -r '.uri'`
    RESULT_core_posts_single_cid=`_p "${result}" | jq -r '.cid'`
    status_core_posts_single=0
  else
    status_core_posts_single=1
  fi

  debug 'core_posts_single' 'END'

  return $status_core_posts_single
}

core_is_post_text_meaningful()
{
  param_post_text="$1"

  debug 'core_is_post_text_meaningful' 'START'
  debug 'core_is_post_text_meaningful' "param_post_text:${param_post_text}"

  modified_post_text=`_p "${param_post_text}" | sed -z 's/\(\n\)*$//g'`
  if [ -n "${modified_post_text}" ]
  then
    is_post_text_meaningful=0
  else
    is_post_text_meaningful=1
  fi

  debug 'core_is_post_text_meaningful' 'END'

  return $is_post_text_meaningful
}

core_posts_count_lines()
{
  param_core_posts_count_lines_text="$1"
  param_core_posts_count_lines_separator_prefix="$2"

  debug 'core_posts_count_lines' 'START'
  debug 'core_posts_count_lines' "param_core_posts_count_lines_text:${param_core_posts_count_lines_text}"
  debug 'core_posts_count_lines' "param_core_posts_count_lines_separator_prefix:${param_core_posts_count_lines_separator_prefix}"

  count=0
  lines=''
  if [ -n "${param_core_posts_count_lines_separator_prefix}" ]
  then
    # "while read -r <variable>" is more smart, but "read -r" can not use in Bourne shell (Solaris sh)
    evacuated_IFS=$IFS
    # each line separated by newline
    IFS='
'
    # no double quote for use word splitting
    # shellcheck disable=SC2086
    set -- $param_core_posts_count_lines_text
    IFS=$evacuated_IFS
    while [ $# -gt 0 ]
    do
      if _startswith "$1" "${param_core_posts_count_lines_separator_prefix}"
      then  # separator line detected
        if core_is_post_text_meaningful "${lines}"
        then  # post text is meaningful
          count=`expr "${count}" + 1`
        fi
        # clear single post content
        lines=''
      else  # separator not detected
        # stack to single content
        if [ -n "${lines}" ]
        then
          lines=`printf "%s\n%s" "${lines}" "$1"`
        else
          lines="$1"
        fi
      fi
      # go to next line
      shift
    done
    # process after than last separator
    if core_is_post_text_meaningful "${lines}"
    then
      count=`expr "${count}" + 1`
    fi
  else  # separator not specified : all lines as single content
    count=1
  fi
  debug 'core_posts_count_lines' "count: ${count}"

  debug 'core_posts_count_lines' 'END'

  return $count
}

core_posts_files_count_lines()
{
  param_core_posts_files_count_lines_files="$1"
  param_core_posts_files_count_lines_separator_prefix="$2"

  debug 'core_posts_files_count_lines' 'START'
  debug 'core_posts_files_count_lines' "param_core_posts_files_count_lines_files:${param_core_posts_files_count_lines_files}"
  debug 'core_posts_files_count_lines' "param_core_posts_files_count_lines_separator_prefix:${param_core_posts_files_count_lines_separator_prefix}"

  core_posts_files_count_lines_count=0
  if [ -n "${param_core_posts_files_count_lines_files}" ]
  then
    _slice "${param_core_posts_files_count_lines_files}" "${BSKYSHCLI_PATH_DELIMITER}"
    files_count=$?
    if [ -n "${param_core_posts_files_count_lines_separator_prefix}" ]
    then
      files_index=1
      while [ $files_index -le $files_count ]
      do
        target_file=`eval _p \"\\$"RESULT_slice_${files_index}"\"`
        file_content=`cat "${target_file}"`
        core_posts_count_lines "${file_content}" "${param_core_posts_files_count_lines_separator_prefix}"
        file_content_count=$?
        core_posts_files_count_lines_count=`expr "${core_posts_files_count_lines_count}" + "${file_content_count}"`
        files_index=`expr "${files_index}" + 1`
      done
    else
      core_posts_files_count_lines_count="${files_count}"
    fi
  fi

  debug 'core_posts_files_count_lines' 'END'

  return $core_posts_files_count_lines_count
}

core_thread()
{
  param_target_uri="$1"
  param_depth="$2"
  param_parent_height="$3"
  param_output_id="$4"
  param_output_via="$5"
  param_output_json="$6"

  debug 'core_thread' 'START'
  debug 'core_thread' "param_target_uri:${param_target_uri}"
  debug 'core_thread' "param_depth:${param_depth}"
  debug 'core_thread' "param_parent_height:${param_parent_height}"
  debug 'core_thread' "param_output_id:${param_output_id}"
  debug 'core_thread' "param_output_via:${param_output_via}"
  debug 'core_thread' "param_output_json:${param_output_json}"

  debug_single 'core_thread'
  result=`api app.bsky.feed.getPostThread "${param_target_uri}" "${param_depth}" "${param_parent_height}"  | tee "${BSKYSHCLI_DEBUG_SINGLE}"`

  view_post_functions=`core_create_post_chunk "${param_output_id}" "${param_output_via}"`
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
  if [ -n "${param_output_json}" ]
  then
    _p "${result}"
  else
    _p "${result}" | jq -r "${view_post_functions}${thread_parse_procedure_parents}"
    _p "${result}" | jq -r "${view_post_functions}${thread_parse_procedure_target}"
    _p "${result}" | jq -r "${view_post_functions}${thread_parse_prodecure_replies}"
  fi

  view_session_functions=`core_create_session_chunk`
  feed_view_index_parents=`_p "${result}" | jq -r -j "${view_session_functions}${thread_parse_procedure_parents}"`
  feed_view_index_target=`_p "${result}" | jq -r -j "${view_session_functions}${thread_parse_procedure_target}"`
  feed_view_index_replies=`_p "${result}" | jq -r -j "${view_session_functions}${thread_parse_prodecure_replies}" | sed 's/.$//'`
  feed_view_index="${feed_view_index_parents}${feed_view_index_target}${feed_view_index_replies}"
  # CAUTION: key=value pairs are separated by tab characters
  update_session_file "${SESSION_KEY_FEED_VIEW_INDEX}=${feed_view_index}"

  debug 'core_thread' 'END'
}

core_post()
{
  param_text="$1"
  param_linkcard_index="$2"
  param_langs="$3"
  param_output_json="$4"
  if [ $# -gt 4 ]
  then
    shift
    shift
    shift
    shift
  fi

  debug 'core_post' 'START'
  debug 'core_post' "param_text:${param_text}"
  debug 'core_post' "param_linkcard_index:${param_linkcard_index}"
  debug 'core_post' "param_langs:${param_langs}"
  debug 'core_post' "param_output_json:${param_output_json}"
  debug 'core_post' "param_image_alt:$*"

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.post'
  created_at=`get_ISO8601UTCbs`
  images_fragment=`core_build_images_fragment "$@"`
  actual_image_count=$?
  link_facets_fragment=`core_build_link_facets_fragment "${param_text}"`
  external_fragment=`core_build_external_fragment "${param_text}" "${param_linkcard_index}"`
  langs_fragment=`core_build_langs_fragment "${param_langs}"`
  case $actual_image_count in
    0|1|2|3|4)
      record="{\"text\":\"${param_text}\",\"createdAt\":\"${created_at}\""
      # image and external (link card) are exclusive, prioritize image specification
      if [ $actual_image_count -gt 0 ]
      then
        record="${record},\"embed\":${images_fragment}"
      elif [ -n "${external_fragment}" ]
      then
        record="${record},\"embed\":${external_fragment}"
      fi
      if [ -n "${link_facets_fragment}" ]
      then
        record="${record},\"facets\":${link_facets_fragment}"
      fi
      if [ -n "${langs_fragment}" ]
      then
        record="${record},\"langs\":${langs_fragment}"
      fi
      if [ "${BSKYSHCLI_POST_VIA}" = 'ON' ]
      then
        record="${record},\"via\":\"${BSKYSHCLI_VIA_VALUE}\""
      fi
      record="${record}}"

      result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''`
      status=$?
      debug_single 'core_post'
      _p "${result}" > "${BSKYSHCLI_DEBUG_SINGLE}"
      if [ $status -eq 0 ]
      then
        core_output_post "`_p "${result}" | jq -r '.uri'`" '' '' "${param_output_json}"
      else
        error 'post command failed'
      fi
      ;;
  esac

  debug 'core_post' 'END'
}

core_posts_thread_lines()
{
  param_core_posts_thread_lines_text="$1"
  param_langs="$2"
  param_parent_uri="$3"
  param_parent_cid="$4"
  param_separator_prefix="$5"

  debug 'core_posts_thread_lines' 'START'
  debug 'core_posts_thread_lines' "param_core_posts_thread_lines_text:${param_core_posts_thread_lines_text}"
  debug 'core_posts_thread_lines' "param_langs:${param_langs}"
  debug 'core_posts_thread_lines' "param_parent_uri:${param_parent_uri}"
  debug 'core_posts_thread_lines' "param_parent_cid:${param_parent_cid}"
  debug 'core_posts_thread_lines' "param_separator_prefix:${param_separator_prefix}"

  core_posts_thread_lines_parent_uri="${param_parent_uri}"
  core_posts_thread_lines_parent_cid="${param_parent_cid}"
  core_posts_thread_lines_root_uri=''
  RESULT_core_posts_thread_lines_uri=''
  RESULT_core_posts_thread_lines_cid=''
  RESULT_core_posts_thread_lines_root_uri=''
  #RESULT_core_posts_thread_lines_uri_list=''
  #RESULT_core_posts_thread_lines_count=0
  status_core_posts_thread_lines=0
  count=0
  lines=''
  if [ -n "${param_separator_prefix}" ]
  then
    # "while read -r <variable>" is more smart, but "read -r" can not use in Bourne shell (Solaris sh)
    evacuated_IFS=$IFS
    # each line separated by newline
    IFS='
'
    # no double quote for use word splitting
    # shellcheck disable=SC2086
    set -- $param_core_posts_thread_lines_text
    IFS=$evacuated_IFS
    while [ $# -gt 0 ]
    do
      if _startswith "$1" "${param_separator_prefix}"
      then  # separator line detected
        if core_is_post_text_meaningful "${lines}"
        then  # post text is meaningful
          count=`expr "${count}" + 1`
          text=`_p "${lines}" | sed -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\(\n\)*$//g; s/\n/\\\\n/g'`
          if core_posts_single "${text}" "${param_langs}" "${core_posts_thread_lines_parent_uri}" "${core_posts_thread_lines_parent_cid}"
          then  # post succeeded
            core_posts_thread_lines_parent_uri="${RESULT_core_posts_single_uri}"
            core_posts_thread_lines_parent_cid="${RESULT_core_posts_single_cid}"
            RESULT_core_posts_thread_lines_uri="${core_posts_thread_lines_parent_uri}"
            RESULT_core_posts_thread_lines_cid="${core_posts_thread_lines_parent_cid}"
            #RESULT_core_posts_thread_lines_uri_list="${RESULT_core_posts_thread_lines_uri_list} ${RESULT_core_posts_single_uri}"
            if [ -z "${core_posts_thread_lines_root_uri}" ]
            then
              core_posts_thread_lines_root_uri="${core_posts_thread_lines_parent_uri}"
              RESULT_core_posts_thread_lines_root_uri="${core_posts_thread_lines_root_uri}"
            fi
            # clear single post content
            lines=''
          else  # post failed
            status_core_posts_thread_lines=1
            break
          fi
        fi
        # clear single post content
        lines=''
      else  # separator not detected
        # stack to single content
        if [ -n "${lines}" ]
        then
          lines=`printf "%s\n%s" "${lines}" "$1"`
        else
          lines="$1"
        fi
      fi
      # go to next line
      shift
    done
    # process after than last separator
    if core_is_post_text_meaningful "${lines}"
    then
      count=`expr "${count}" + 1`
      text=`_p "${lines}" | sed -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\(\n\)*$//g; s/\n/\\\\n/g'`
      if core_posts_single "${text}" "${param_langs}" "${core_posts_thread_lines_parent_uri}" "${core_posts_thread_lines_parent_cid}"
      then  # post succeeded
        core_posts_thread_lines_parent_uri="${RESULT_core_posts_single_uri}"
        core_posts_thread_lines_parent_cid="${RESULT_core_posts_single_cid}"
        RESULT_core_posts_thread_lines_uri="${core_posts_thread_lines_parent_uri}"
        RESULT_core_posts_thread_lines_cid="${core_posts_thread_lines_parent_cid}"
        #RESULT_core_posts_thread_lines_uri_list="${RESULT_core_posts_thread_lines_uri_list} ${RESULT_core_posts_single_uri}"
        if [ -z "${core_posts_thread_lines_root_uri}" ]
        then
          core_posts_thread_lines_root_uri="${core_posts_thread_lines_parent_uri}"
          RESULT_core_posts_thread_lines_root_uri="${core_posts_thread_lines_root_uri}"
        fi
        # clear single post content
        lines=''
      else  # post failed
        status_core_posts_thread_lines=1
      fi
    fi
  else  # separator not specified : all lines as single content
    count=1
    text=`_p "${param_core_posts_thread_lines_text}" | sed -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\(\n\)*$//g; s/\n/\\\\n/g'`
    if core_posts_single "${text}" "${param_langs}" "${core_posts_thread_lines_parent_uri}" "${core_posts_thread_lines_parent_cid}"
    then  # post succeeded
      core_posts_thread_lines_parent_uri="${RESULT_core_posts_single_uri}"
      core_posts_thread_lines_parent_cid="${RESULT_core_posts_single_cid}"
      RESULT_core_posts_thread_lines_uri="${core_posts_thread_lines_parent_uri}"
      RESULT_core_posts_thread_lines_cid="${core_posts_thread_lines_parent_cid}"
      #RESULT_core_posts_thread_lines_uri_list="${RESULT_core_posts_thread_lines_uri_list} ${RESULT_core_posts_single_uri}"
      if [ -z "${core_posts_thread_lines_root_uri}" ]
      then
        core_posts_thread_lines_root_uri="${core_posts_thread_lines_parent_uri}"
        RESULT_core_posts_thread_lines_root_uri="${core_posts_thread_lines_root_uri}"
      fi
      # clear single post content
      lines=''
    else  # post failed
      status_core_posts_thread_lines=1
    fi
  fi
  #RESULT_core_posts_thread_lines_count="${count}"

  debug 'core_posts_thread_lines' 'END'

  return $status_core_posts_thread_lines
}

core_posts_thread()
{
  param_stdin_text="$1"
  param_specified_text="$2"
  param_text_files="$3"
  param_langs="$4"
  param_separator_prefix="$5"
  param_output_json="$6"

  debug 'core_posts_thread' 'START'
  debug 'core_posts_thread' "param_stdin_text:${param_stdin_text}"
  debug 'core_posts_thread' "param_specified_text:${param_specified_text}"
  debug 'core_posts_thread' "param_text_files:${param_text_files}"
  debug 'core_posts_thread' "param_langs:${param_langs}"
  debug 'core_posts_thread' "param_separator_prefix:${param_separator_prefix}"
  debug 'core_posts_thread' "param_output_json:${param_output_json}"

  parent_uri=''
  parent_cid=''
  thread_root_uri=''
  #post_uri_list=''

  if [ -n "${param_stdin_text}" ]
  then  # standard input (pipe/redirect)
    if core_posts_thread_lines "${param_stdin_text}" "${param_langs}" "${parent_uri}" "${parent_cid}" "${param_separator_prefix}"
    then
      parent_uri="${RESULT_core_posts_thread_lines_uri}"
      parent_cid="${RESULT_core_posts_thread_lines_cid}"
      if [ -z "${thread_root_uri}" ]
      then
        thread_root_uri="${RESULT_core_posts_thread_lines_root_uri}"
      fi
    else
      error 'Processing has been canceled'
    fi
  fi

  if [ -n "${param_specified_text}" ]
  then
    if core_posts_thread_lines "${param_specified_text}" "${param_langs}" "${parent_uri}" "${parent_cid}" "${param_separator_prefix}"
    then
      parent_uri="${RESULT_core_posts_thread_lines_uri}"
      parent_cid="${RESULT_core_posts_thread_lines_cid}"
      if [ -z "${thread_root_uri}" ]
      then
        thread_root_uri="${RESULT_core_posts_thread_lines_root_uri}"
      fi
    else
      error 'Processing has been canceled'
    fi
  fi

  if [ -n "${param_text_files}" ]
  then
    _slice "${param_text_files}" "${BSKYSHCLI_PATH_DELIMITER}"
    files_count=$?
    files_index=1
    while [ $files_index -le $files_count ]
    do
      target_file=`eval _p \"\\$"RESULT_slice_${files_index}"\"`
      if [ -r "${target_file}" ]
      then
        file_content=`cat "${target_file}"`
      else
        check_comma=`_p "${target_file}" | sed 's/[^,]//g'`
        if [ -n "${check_comma}" ]
        then
          error_msg "commas(,) may be used to separate multiple paths"
        fi
        error_msg "Specified file is not readable: ${target_file}"
      fi
      if core_posts_thread_lines "${file_content}" "${param_langs}" "${parent_uri}" "${parent_cid}" "${param_separator_prefix}"
      then
        parent_uri="${RESULT_core_posts_thread_lines_uri}"
        parent_cid="${RESULT_core_posts_thread_lines_cid}"
        if [ -z "${thread_root_uri}" ]
        then
          thread_root_uri="${RESULT_core_posts_thread_lines_root_uri}"
        fi
      else
        error 'Processing has been canceled'
      fi
      files_index=`expr "$files_index" + 1`
    done
  fi

  # depth='', parent-height=0
  core_thread "${thread_root_uri}" '' 0 '' '' "${param_output_json}"

  debug 'core_posts_thread' 'END'
}

core_posts_sibling_lines()
{
  param_core_posts_sibling_lines_text="$1"
  param_langs="$2"
  param_parent_uri="$3"
  param_parent_cid="$4"
  param_separator_prefix="$5"

  debug 'core_posts_sibling_lines' 'START'
  debug 'core_posts_sibling_lines' "param_core_posts_sibling_lines_text:${param_core_posts_sibling_lines_text}"
  debug 'core_posts_sibling_lines' "param_langs:${param_langs}"
  debug 'core_posts_sibling_lines' "param_parent_uri:${param_parent_uri}"
  debug 'core_posts_sibling_lines' "param_parent_cid:${param_parent_cid}"
  debug 'core_posts_sibling_lines' "param_separator_prefix:${param_separator_prefix}"

  core_posts_sibling_lines_parent_uri="${param_parent_uri}"
  core_posts_sibling_lines_parent_cid="${param_parent_cid}"
  core_posts_sibling_lines_root_uri=''
  RESULT_core_posts_sibling_lines_uri=''
  RESULT_core_posts_sibling_lines_cid=''
  RESULT_core_posts_sibling_lines_root_uri=''
  #RESULT_core_posts_sibling_lines_uri_list=''
  #RESULT_core_posts_sibling_lines_count=0
  status_core_posts_sibling_lines=0
  count=0
  lines=''
  if [ -n "${param_separator_prefix}" ]
  then
    # "while read -r <variable>" is more smart, but "read -r" can not use in Bourne shell (Solaris sh)
    evacuated_IFS=$IFS
    # each line separated by newline
    IFS='
'
    # no double quote for use word splitting
    # shellcheck disable=SC2086
    set -- $param_core_posts_sibling_lines_text
    IFS=$evacuated_IFS
    while [ $# -gt 0 ]
    do
      if _startswith "$1" "${param_separator_prefix}"
      then  # separator line detected
        if core_is_post_text_meaningful "${lines}"
        then  # post text is meaningful
          count=`expr "${count}" + 1`
          text=`_p "${lines}" | sed -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\(\n\)*$//g; s/\n/\\\\n/g'`
          if core_posts_single "${text}" "${param_langs}" "${core_posts_sibling_lines_parent_uri}" "${core_posts_sibling_lines_parent_cid}"
          then  # post succeeded
            if [ -z "${core_posts_sibling_lines_parent_uri}" ]
            then
              core_posts_sibling_lines_parent_uri="${RESULT_core_posts_single_uri}"
            fi
            if [ -z "${core_posts_sibling_lines_parent_cid}" ]
            then
              core_posts_sibling_lines_parent_cid="${RESULT_core_posts_single_cid}"
            fi
            RESULT_core_posts_sibling_lines_uri="${core_posts_sibling_lines_parent_uri}"
            RESULT_core_posts_sibling_lines_cid="${core_posts_sibling_lines_parent_cid}"
            #RESULT_core_posts_sibling_lines_uri_list="${RESULT_core_posts_sibling_lines_uri_list} ${RESULT_core_posts_single_uri}"
            if [ -z "${core_posts_sibling_lines_root_uri}" ]
            then
              core_posts_sibling_lines_root_uri="${core_posts_sibling_lines_parent_uri}"
              RESULT_core_posts_sibling_lines_root_uri="${core_posts_sibling_lines_root_uri}"
            fi
            # clear single post content
            lines=''
          else  # post failed
            status_core_posts_sibling_lines=1
            break
          fi
        fi
        # clear single post content
        lines=''
      else  # separator not detected
        # stack to single content
        if [ -n "${lines}" ]
        then
          lines=`printf "%s\n%s" "${lines}" "$1"`
        else
          lines="$1"
        fi
      fi
      # go to next line
      shift
    done
    # process after than last separator
    if core_is_post_text_meaningful "${lines}"
    then
      count=`expr "${count}" + 1`
      text=`_p "${lines}" | sed -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\(\n\)*$//g; s/\n/\\\\n/g'`
      if core_posts_single "${text}" "${param_langs}" "${core_posts_sibling_lines_parent_uri}" "${core_posts_sibling_lines_parent_cid}"
      then  # post succeeded
        if [ -z "${core_posts_sibling_lines_parent_uri}" ]
        then
          core_posts_sibling_lines_parent_uri="${RESULT_core_posts_single_uri}"
        fi
        if [ -z "${core_posts_sibling_lines_parent_cid}" ]
        then
          core_posts_sibling_lines_parent_cid="${RESULT_core_posts_single_cid}"
        fi
        RESULT_core_posts_sibling_lines_uri="${core_posts_sibling_lines_parent_uri}"
        RESULT_core_posts_sibling_lines_cid="${core_posts_sibling_lines_parent_cid}"
        #RESULT_core_posts_sibling_lines_uri_list="${RESULT_core_posts_sibling_lines_uri_list} ${RESULT_core_posts_single_uri}"
        if [ -z "${core_posts_sibling_lines_root_uri}" ]
        then
          core_posts_sibling_lines_root_uri="${core_posts_sibling_lines_parent_uri}"
          RESULT_core_posts_sibling_lines_root_uri="${core_posts_sibling_lines_root_uri}"
        fi
        # clear single post content
        lines=''
      else  # post failed
        status_core_posts_sibling_lines=1
      fi
    fi
  else  # separator not specified : all lines as single content
    count=1
    text=`_p "${param_core_posts_sibling_lines_text}" | sed -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\(\n\)*$//g; s/\n/\\\\n/g'`
    if core_posts_single "${text}" "${param_langs}" "${core_posts_sibling_lines_parent_uri}" "${core_posts_sibling_lines_parent_cid}"
    then  # post succeeded
      if [ -z "${core_posts_sibling_lines_parent_uri}" ]
      then
        core_posts_sibling_lines_parent_uri="${RESULT_core_posts_single_uri}"
      fi
      if [ -z "${core_posts_sibling_lines_parent_cid}" ]
      then
        core_posts_sibling_lines_parent_cid="${RESULT_core_posts_single_cid}"
      fi
      RESULT_core_posts_sibling_lines_uri="${core_posts_sibling_lines_parent_uri}"
      RESULT_core_posts_sibling_lines_cid="${core_posts_sibling_lines_parent_cid}"
      #RESULT_core_posts_sibling_lines_uri_list="${RESULT_core_posts_sibling_lines_uri_list} ${RESULT_core_posts_single_uri}"
      if [ -z "${core_posts_sibling_lines_root_uri}" ]
      then
        core_posts_sibling_lines_root_uri="${core_posts_sibling_lines_parent_uri}"
        RESULT_core_posts_sibling_lines_root_uri="${core_posts_sibling_lines_root_uri}"
      fi
      # clear single post content
      lines=''
    else  # post failed
      status_core_posts_sibling_lines=1
    fi
  fi
  #RESULT_core_posts_sibling_lines_count="${count}"

  debug 'core_posts_sibling_lines' 'END'

  return $status_core_posts_sibling_lines
}

core_posts_sibling()
{
  param_stdin_text="$1"
  param_specified_text="$2"
  param_text_files="$3"
  param_langs="$4"
  param_separator_prefix="$5"
  param_output_json="$6"

  debug 'core_posts_sibling' 'START'
  debug 'core_posts_sibling' "param_stdin_text:${param_stdin_text}"
  debug 'core_posts_sibling' "param_specified_text:${param_specified_text}"
  debug 'core_posts_sibling' "param_text_files:${param_text_files}"
  debug 'core_posts_sibling' "param_langs:${param_langs}"
  debug 'core_posts_sibling' "param_separator_prefix:${param_separator_prefix}"
  debug 'core_posts_sibling' "param_output_json:${param_output_json}"

  parent_uri=''
  parent_cid=''
  thread_root_uri=''
  #post_uri_list=''

  if [ -n "${param_stdin_text}" ]
  then
    if core_posts_sibling_lines "${param_stdin_text}" "${param_langs}" "${parent_uri}" "${parent_cid}" "${param_separator_prefix}"
    then
      if [ -z "${parent_uri}" ]
      then
        parent_uri="${RESULT_core_posts_sibling_lines_uri}"
      fi
      if [ -z "${parent_cid}" ]
      then
        parent_cid="${RESULT_core_posts_sibling_lines_cid}"
      fi
      if [ -z "${thread_root_uri}" ]
      then
        thread_root_uri="${RESULT_core_posts_sibling_lines_root_uri}"
      fi
    else
      error 'Processing has been canceled'
    fi
  fi

  if [ -n "${param_specified_text}" ]
  then
    if core_posts_sibling_lines "${param_specified_text}" "${param_langs}" "${parent_uri}" "${parent_cid}" "${param_separator_prefix}"
    then
      if [ -z "${parent_uri}" ]
      then
        parent_uri="${RESULT_core_posts_sibling_lines_uri}"
      fi
      if [ -z "${parent_cid}" ]
      then
        parent_cid="${RESULT_core_posts_sibling_lines_cid}"
      fi
      if [ -z "${thread_root_uri}" ]
      then
        thread_root_uri="${RESULT_core_posts_sibling_lines_root_uri}"
      fi
    else
      error 'Processing has been canceled'
    fi
  fi

  if [ -n "${param_text_files}" ]
  then
    _slice "${param_text_files}" "${BSKYSHCLI_PATH_DELIMITER}"
    files_count=$?
    files_index=1
    while [ $files_index -le $files_count ]
    do
      target_file=`eval _p \"\\$"RESULT_slice_${files_index}"\"`
      if [ -r "${target_file}" ]
      then
        file_content=`cat "${target_file}"`
      else
        check_comma=`_p "${target_file}" | sed 's/[^,]//g'`
        if [ -n "${check_comma}" ]
        then
          error_msg "commas(,) may be used to separate multiple paths"
        fi
        error_msg "Specified file is not readable: ${target_file}"
      fi
      if core_posts_sibling_lines "${file_content}" "${param_langs}" "${parent_uri}" "${parent_cid}" "${param_separator_prefix}"
      then
        if [ -z "${parent_uri}" ]
        then
          parent_uri="${RESULT_core_posts_sibling_lines_uri}"
        fi
        if [ -z "${parent_cid}" ]
        then
          parent_cid="${RESULT_core_posts_sibling_lines_cid}"
        fi
        if [ -z "${thread_root_uri}" ]
        then
          thread_root_uri="${RESULT_core_posts_sibling_lines_root_uri}"
        fi
      else
        error 'Processing has been canceled'
      fi
      files_index=`expr "$files_index" + 1`
    done
  fi

  # depth='', parent-height=0
  core_thread "${thread_root_uri}" '' 0 '' '' "${param_output_json}"

  debug 'core_posts_sibling' 'END'
}

core_posts_independence_lines()
{
  param_core_posts_independence_lines_text="$1"
  param_langs="$2"
  param_parent_uri="$3"
  param_parent_cid="$4"
  param_separator_prefix="$5"

  debug 'core_posts_independence_lines' 'START'
  debug 'core_posts_independence_lines' "param_core_posts_independence_lines_text:${param_core_posts_independence_lines_text}"
  debug 'core_posts_independence_lines' "param_langs:${param_langs}"
  debug 'core_posts_independence_lines' "param_parent_uri:${param_parent_uri}"
  debug 'core_posts_independence_lines' "param_parent_cid:${param_parent_cid}"
  debug 'core_posts_independence_lines' "param_separator_prefix:${param_separator_prefix}"

  core_posts_independence_parent_uri=''
  core_posts_independence_parent_cid=''
  #core_posts_independence_lines_root_uri=''
  #RESULT_core_posts_independence_lines_uri=''
  #RESULT_core_posts_independence_lines_cid=''
  #RESULT_core_posts_independence_lines_root_uri=''
  RESULT_core_posts_independence_lines_uri_list=''
  #RESULT_core_posts_independence_lines_count=0
  status_core_posts_independence_lines=0
  count=0
  lines=''
  if [ -n "${param_separator_prefix}" ]
  then
    # "while read -r <variable>" is more smart, but "read -r" can not use in Bourne shell (Solaris sh)
    evacuated_IFS=$IFS
    # each line separated by newline
    IFS='
'
    # no double quote for use word splitting
    # shellcheck disable=SC2086
    set -- $param_core_posts_independence_lines_text
    IFS=$evacuated_IFS
    while [ $# -gt 0 ]
    do
      if _startswith "$1" "${param_separator_prefix}"
      then  # separator line detected
        if core_is_post_text_meaningful "${lines}"
        then  # post text is meaningful
          count=`expr "${count}" + 1`
          text=`_p "${lines}" | sed -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\(\n\)*$//g; s/\n/\\\\n/g'`
          if core_posts_single "${text}" "${param_langs}" "${core_posts_independence_parent_uri}" "${core_posts_independence_parent_cid}"
          then  # post succeeded
            core_posts_independence_parent_uri=''
            core_posts_independence_parent_cid=''
            #RESULT_core_posts_independence_lines_uri="${core_posts_independence_parent_uri}"
            #RESULT_core_posts_independence_lines_cid="${core_posts_independence_parent_cid}"
            RESULT_core_posts_independence_lines_uri_list="${RESULT_core_posts_independence_lines_uri_list} ${RESULT_core_posts_single_uri}"
            #if [ -z "${core_posts_independence_lines_root_uri}" ]
            #then
            #  core_posts_independence_lines_root_uri="${core_posts_independence_lines_parent_uri}"
            #  RESULT_core_posts_independence_lines_root_uri="${core_posts_independence_lines_root_uri}"
            #fi
            # clear single post content
            lines=''
          else  # post failed
            status_core_posts_independence_lines=1
            break
          fi
        fi
        # clear single post content
        lines=''
      else  # separator not detected
        # stack to single content
        if [ -n "${lines}" ]
        then
          lines=`printf "%s\n%s" "${lines}" "$1"`
        else
          lines="$1"
        fi
      fi
      # go to next line
      shift
    done
    # process after than last separator
    if core_is_post_text_meaningful "${lines}"
    then
      count=`expr "${count}" + 1`
      text=`_p "${lines}" | sed -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\(\n\)*$//g; s/\n/\\\\n/g'`
      if core_posts_single "${text}" "${param_langs}" "${core_posts_independence_parent_uri}" "${core_posts_independence_parent_cid}"
      then  # post succeeded
        core_posts_independence_parent_uri=''
        core_posts_independence_parent_cid=''
        #RESULT_core_posts_independence_lines_uri="${core_posts_independence_parent_uri}"
        #RESULT_core_posts_independence_lines_cid="${core_posts_independence_parent_cid}"
        RESULT_core_posts_independence_lines_uri_list="${RESULT_core_posts_independence_lines_uri_list} ${RESULT_core_posts_single_uri}"
        #if [ -z "${core_posts_independence_lines_root_uri}" ]
        #then
        #  core_posts_independence_lines_root_uri="${core_posts_independence_lines_parent_uri}"
        #  RESULT_core_posts_independence_lines_root_uri="${core_posts_independence_lines_root_uri}"
        #fi
        # clear single post content
        lines=''
      else  # post failed
        status_core_posts_independence_lines=1
      fi
    fi
  else  # separator not specified : all lines as single content
    count=1
    text=`_p "${param_core_posts_independence_lines_text}" | sed -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\(\n\)*$//g; s/\n/\\\\n/g'`
    if core_posts_single "${text}" "${param_langs}" "${core_posts_independence_parent_uri}" "${core_posts_independence_parent_cid}"
    then  # post succeeded
      core_posts_independence_parent_uri=''
      core_posts_independence_parent_cid=''
      #RESULT_core_posts_independence_lines_uri="${core_posts_independence_parent_uri}"
      #RESULT_core_posts_independence_lines_cid="${core_posts_independence_parent_cid}"
      RESULT_core_posts_independence_lines_uri_list="${RESULT_core_posts_independence_lines_uri_list} ${RESULT_core_posts_single_uri}"
      #if [ -z "${core_posts_independence_lines_root_uri}" ]
      #then
      #  core_posts_independence_lines_root_uri="${core_posts_independence_lines_parent_uri}"
      #  RESULT_core_posts_independence_lines_root_uri="${core_posts_independence_lines_root_uri}"
      #fi
      # clear single post content
      lines=''
    else  # post failed
      status_core_posts_independence_lines=1
    fi
  fi
  #RESULT_core_posts_independence_lines_count="${count}"

  debug 'core_posts_independence_lines' 'END'

  return $status_core_posts_independence_lines
}

core_posts_independence()
{
  param_stdin_text="$1"
  param_specified_text="$2"
  param_text_files="$3"
  param_langs="$4"
  param_separator_prefix="$5"
  param_output_json="$6"

  debug 'core_posts_independence' 'START'
  debug 'core_posts_independence' "param_stdin_text:${param_stdin_text}"
  debug 'core_posts_independence' "param_specified_text:${param_specified_text}"
  debug 'core_posts_independence' "param_text_files:${param_text_files}"
  debug 'core_posts_independence' "param_langs:${param_langs}"
  debug 'core_posts_independence' "param_separator_prefix:${param_separator_prefix}"
  debug 'core_posts_independence' "param_output_json:${param_output_json}"

  parent_uri=''
  parent_cid=''
  thread_root_uri=''
  post_uri_list=''

  if [ -n "${param_stdin_text}" ]
  then  # standard input (pipe/redirect)
    if core_posts_independence_lines "${param_stdin_text}" "${param_langs}" '' '' "${param_separator_prefix}"
    then
      #parent_uri=''
      #parent_cid=''
      #thread_root_uri=''
      post_uri_list="${post_uri_list} ${RESULT_core_posts_independence_lines_uri_list}"
    else
      error 'Processing has been canceled'
    fi
  fi

  if [ -n "${param_specified_text}" ]
  then
    if core_posts_independence_lines "${param_specified_text}" "${param_langs}" '' '' "${param_separator_prefix}"
    then
      #parent_uri=''
      #parent_cid=''
      #thread_root_uri=''
      post_uri_list="${post_uri_list} ${RESULT_core_posts_independence_lines_uri_list}"
    else
      error 'Processing has been canceled'
    fi
  fi

  if [ -n "${param_text_files}" ]
  then
    _slice "${param_text_files}" "${BSKYSHCLI_PATH_DELIMITER}"
    files_count=$?
    files_index=1
    while [ $files_index -le $files_count ]
    do
      target_file=`eval _p \"\\$"RESULT_slice_${files_index}"\"`
      if [ -r "${target_file}" ]
      then
        file_content=`cat "${target_file}"`
      else
        check_comma=`_p "${target_file}" | sed 's/[^,]//g'`
        if [ -n "${check_comma}" ]
        then
          error_msg "commas(,) may be used to separate multiple paths"
        fi
        error_msg "Specified file is not readable: ${target_file}"
      fi
      if core_posts_independence_lines "${file_content}" "${param_langs}" '' '' "${param_separator_prefix}"
      then
        #parent_uri=''
        #parent_cid=''
        #thread_root_uri=''
        post_uri_list="${post_uri_list} ${RESULT_core_posts_independence_lines_uri_list}"
      else
        error 'Processing has been canceled'
      fi
      files_index=`expr "$files_index" + 1`
    done
  fi

  core_output_post "${post_uri_list}" '' '' "${param_output_json}"

  debug 'core_posts_independence' 'END'
}

core_posts()
{
  param_mode="$1"
  param_stdin_text="$2"
  param_specified_text="$3"
  param_text_files="$4"
  param_langs="$5"
  param_separator_prefix="$6"
  param_output_json="$7"

  debug 'core_posts' 'START'
  debug 'core_posts' "param_mode:${param_mode}"
  debug 'core_posts' "param_stdin_text:${param_stdin_text}"
  debug 'core_posts' "param_specified_text:${param_specified_text}"
  debug 'core_posts' "param_text_fies:${param_text_files}"
  debug 'core_posts' "param_langs:${param_langs}"
  debug 'core_posts' "param_separator_prefix:${param_separator_prefix}"
  debug 'core_posts' "param_output_json:${param_output_json}"

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.post'

  # size check
  core_verify_text_size_lines "${param_stdin_text}" "${param_specified_text}" "${param_text_files}" "${param_separator_prefix}"

  case $param_mode in
    sibling)
      core_posts_sibling "${param_stdin_text}" "${param_specified_text}" "${param_text_files}" "${param_langs}" "${param_separator_prefix}" "${param_output_json}"
      ;;
    independence)
      core_posts_independence "${param_stdin_text}" "${param_specified_text}" "${param_text_files}" "${param_langs}" "${param_separator_prefix}" "${param_output_json}"
      ;;
    thread|*)
      core_posts_thread "${param_stdin_text}" "${param_specified_text}" "${param_text_files}" "${param_langs}" "${param_separator_prefix}" "${param_output_json}"
      ;;
  esac

  debug 'core_posts' 'END'
}

core_reply()
{
  param_target_uri="$1"
  param_target_cid="$2"
  param_text="$3"
  param_linkcard_index="$4"
  param_langs="$5"
  param_output_json="$6"
  if [ $# -gt 6 ]
  then
    shift
    shift
    shift
    shift
    shift
    shift
  fi

  debug 'core_reply' 'START'
  debug 'core_reply' "param_target_uri:${param_target_uri}"
  debug 'core_reply' "param_target_cid:${param_target_cid}"
  debug 'core_reply' "param_text:${param_text}"
  debug 'core_reply' "param_linkcard_index:${param_linkcard_index}"
  debug 'core_reply' "param_langs:${param_langs}"
  debug 'core_reply' "param_output_json:${param_output_json}"
  debug 'core_reply' "param_image_alt:$*"

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.post'
  created_at=`get_ISO8601UTCbs`
  reply_fragment=`core_build_reply_fragment "${param_target_uri}" "${param_target_cid}"`
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  images_fragment=`core_build_images_fragment "$@"`
  actual_image_count=$?
  link_facets_fragment=`core_build_link_facets_fragment "${param_text}"`
  external_fragment=`core_build_external_fragment "${param_text}" "${param_linkcard_index}"`
  langs_fragment=`core_build_langs_fragment "${param_langs}"`
  case $actual_image_count in
    0|1|2|3|4)
      record="{\"text\":\"${param_text}\",\"createdAt\":\"${created_at}\",${reply_fragment}"
      # image and external (link card) are exclusive, prioritize image specification
      if [ $actual_image_count -gt 0 ]
      then
        record="${record},\"embed\":${images_fragment}"
      elif [ -n "${external_fragment}" ]
      then
        record="${record},\"embed\":${external_fragment}"
      fi
      if [ -n "${link_facets_fragment}" ]
      then
        record="${record},\"facets\":${link_facets_fragment}"
      fi
      if [ -n "${langs_fragment}" ]
      then
        record="${record},\"langs\":${langs_fragment}"
      fi
      if [ "${BSKYSHCLI_POST_VIA}" = 'ON' ]
      then
        record="${record},\"via\":\"${BSKYSHCLI_VIA_VALUE}\""
      fi
      record="${record}}"

      result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''`
      status=$?
      debug_single 'core_reply'
      _p "${result}" > "${BSKYSHCLI_DEBUG_SINGLE}"
      if [ $status -eq 0 ]
      then
        core_output_post "`_p "${result}" | jq -r '.uri'`" '' '' "${param_output_json}"
      else
        error 'reply command failed'
      fi
      ;;
  esac

  debug 'core_reply' 'END'
}

core_repost()
{
  param_target_uri="$1"
  param_target_cid="$2"
  param_output_json="$3"

  debug 'core_repost' 'START'
  debug 'core_repost' "param_target_uri:${param_target_uri}"
  debug 'core_repost' "param_target_cid:${param_target_cid}"
  debug 'core_repost' "param_output_json:${param_output_json}"

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.repost'
  created_at=`get_ISO8601UTCbs`
  subject_fragment=`core_build_subject_fragment "${param_target_uri}" "${param_target_cid}"`
  record="{\"createdAt\":\"${created_at}\",${subject_fragment}}"

  result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''`
  status=$?
  debug_single 'core_repost'
  _p "${result}" > "${BSKYSHCLI_DEBUG_SINGLE}"
  if [ $status -eq 0 ]
  then
    if [ -n "${param_output_json}" ]
    then
      _p "{\"repost\":${result},\"original\":"
    else
      _p "${result}" | jq -r '"[repost uri:\(.uri)]"'
    fi
    core_output_post "${param_target_uri}" '' '' "${param_output_json}"
    if [ -n "${param_output_json}" ]
    then
      _p "}"
    fi
  else
    error 'repost command failed'
  fi

  debug 'core_repost' 'END'
}

core_quote()
{
  param_target_uri="$1"
  param_target_cid="$2"
  param_text="$3"
  param_linkcard_index="$4"
  param_langs="$5"
  param_output_json="$6"
  if [ $# -gt 6 ]
  then
    shift
    shift
    shift
    shift
    shift
    shift
  fi

  debug 'core_quote' 'START'
  debug 'core_quote' "param_target_uri:${param_target_uri}"
  debug 'core_quote' "param_target_cid:${param_target_cid}"
  debug 'core_quote' "param_text:${param_text}"
  debug 'core_quote' "param_linkcard_index:${param_linkcard_index}"
  debug 'core_quote' "param_langs:${param_langs}"
  debug 'core_quote' "param_output_json:${param_output_json}"
  debug 'core_quote' "param_image_alt:$*"

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.post'
  created_at=`get_ISO8601UTCbs`
  quote_record_fragment=`core_build_quote_record_fragment "${param_target_uri}" "${param_target_cid}"`
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  images_fragment=`core_build_images_fragment "$@"`
  actual_image_count=$?
  link_facets_fragment=`core_build_link_facets_fragment "${param_text}"`
  external_fragment=`core_build_external_fragment "${param_text}" "${param_linkcard_index}"`
  langs_fragment=`core_build_langs_fragment "${param_langs}"`
  case $actual_image_count in
    0|1|2|3|4)
      record="{\"text\":\"${param_text}\",\"createdAt\":\"${created_at}\""
      # image and external (link card) are exclusive, prioritize image specification
      if [ $actual_image_count -eq 0 ]
      then
        if [ -n "${external_fragment}" ]
        then
          record="${record},\"embed\":{\"\$type\":\"app.bsky.embed.recordWithMedia\",\"media\":${external_fragment},\"record\":${quote_record_fragment}}"
        else
          record="${record},\"embed\":${quote_record_fragment}"
        fi
      else
        record="${record},\"embed\":{\"\$type\":\"app.bsky.embed.recordWithMedia\",\"media\":${images_fragment},\"record\":${quote_record_fragment}}"
      fi
      if [ -n "${link_facets_fragment}" ]
      then
        record="${record},\"facets\":${link_facets_fragment}"
      fi
      if [ -n "${langs_fragment}" ]
      then
        record="${record},\"langs\":${langs_fragment}"
      fi
      if [ "${BSKYSHCLI_POST_VIA}" = 'ON' ]
      then
        record="${record},\"via\":\"${BSKYSHCLI_VIA_VALUE}\""
      fi
      record="${record}}"

      result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''`
      status=$?
      debug_single 'core_quote'
      _p "${result}" > "${BSKYSHCLI_DEBUG_SINGLE}"
      if [ $status -eq 0 ]
      then
        core_output_post "`_p "${result}" | jq -r '.uri'`" '' '' "${param_output_json}"
      else
        error 'quote command failed'
      fi
      ;;
  esac

  debug 'core_quote' 'END'
}

core_like()
{
  param_target_uri="$1"
  param_target_cid="$2"
  param_output_json="$3"

  debug 'core_like' 'START'
  debug 'core_like' "param_target_uri:${param_target_uri}"
  debug 'core_like' "param_target_cid:${param_target_cid}"
  debug 'core_like' "param_output_json:${param_output_json}"

  subject_fragment=`core_build_subject_fragment "${param_target_uri}" "${param_target_cid}"`

  read_session_file
  repo="${SESSION_HANDLE}"
  collection='app.bsky.feed.like'
  created_at=`get_ISO8601UTCbs`
  record="{\"createdAt\":\"${created_at}\",${subject_fragment}}"

  result=`api com.atproto.repo.createRecord "${repo}" "${collection}" '' '' "${record}" ''`
  status=$?
  debug_single 'core_like'
  _p "${result}" > "${BSKYSHCLI_DEBUG_SINGLE}"
  if [ $status -eq 0 ]
  then
    if [ -n "${param_output_json}" ]
    then
      _p "{\"like\":${result},\"original\":"
    else
      _p "${result}" | jq -r '"[like uri:\(.uri)]"'
    fi
      core_output_post "${param_target_uri}" '' '' "${param_output_json}"
    if [ -n "${param_output_json}" ]
    then
      _p "}"
    fi
  else
    error 'quote command failed'
  fi

  debug 'core_like' 'END'
}

core_get_profile()
{
  param_did="$1"
  param_output_id="$2"
  param_dump="$3"
  param_output_json="$4"

  debug 'core_get_profile' 'START'
  debug 'core_get_profile' "param_did:${param_did}"
  debug 'core_get_profile' "param_output_id:${param_output_id}"
  debug 'core_get_profile' "param_dump:${param_dump}"
  debug 'core_get_profile' "param_output_json:${param_output_json}"

  result=`api app.bsky.actor.getProfile "${param_did}"`
  status=$?
  debug_single 'core_get_profile'
  _p "${result}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $status -eq 0 ]
  then
    if [ -n "${param_output_json}" ]
    then
      _p "${result}"
    elif [ -n "${param_dump}" ]
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
  param_output_json="$4"

  debug 'core_get_pref' 'START'
  debug 'core_get_pref' "param_group:${param_group}"
  debug 'core_get_pref' "param_item:${param_item}"
  debug 'core_get_pref' "param_dump:${param_dump}"
  debug 'core_get_pref' "param_output_json:${param_output_json}"

  result=`api app.bsky.actor.getPreferences`
  status=$?
  debug_single 'core_get_preferences'
  _p "${result}" > "$BSKYSHCLI_DEBUG_SINGLE"

  if [ $status -eq 0 ]
  then
    if [ -n "${param_output_json}" ]
    then
      _p "${result}"
    elif [ -n "${param_dump}" ]
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
  param_output_json="$1"

  debug 'core_info_session_which' 'START'
  debug 'core_info_session_which' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    _p "\"which\":\"`get_session_filepath`\""
  else
    _p "session file path: "
    _pn "`get_session_filepath`"
  fi

  debug 'core_info_session_which' 'END'
}

core_info_session_status()
{
  param_output_json="$1"

  debug 'core_info_session_status' 'START'
  debug 'core_info_session_status' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    _p "\"loginStatus\":"
    if is_session_exist
    then
      _p 'true'
    else
      _p 'false'
    fi
  else
    _p "login status: "
    if is_session_exist
    then
      _pn "login"
    else
      _pn "not login"
    fi
  fi

  debug 'core_info_session_status' 'END'
}

core_info_session_login()
{
  param_output_json="$1"

  debug 'core_info_session_login' 'START'
  debug 'core_info_session_login' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    _p "\"loginTimestamp\":\"${SESSION_LOGIN_TIMESTAMP}\""
  else
    _pn "login timestamp: ${SESSION_LOGIN_TIMESTAMP}"
  fi

  debug 'core_info_session_login' 'END'
}

core_info_session_refresh()
{
  param_output_json="$1"

  debug 'core_info_session_refresh' 'START'
  debug 'core_info_session_refresh' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    _p "\"refreshTimestamp\":\"${SESSION_REFRESH_TIMESTAMP}\""
  else
    _pn "session refresh timestamp: ${SESSION_REFRESH_TIMESTAMP}"
  fi

  debug 'core_info_session_refresh' 'END'
}

core_info_session_handle()
{
  param_output_json="$1"

  debug 'core_info_session_handle' 'START'
  debug 'core_info_session_handle' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    _p "\"handle\":\"${SESSION_HANDLE}\""
  else
    _pn "handle: ${SESSION_HANDLE}"
  fi

  debug 'core_info_session_handle' 'END'
}

core_info_session_did()
{
  param_output_json="$1"

  debug 'core_info_session_did' 'START'
  debug 'core_info_session_did' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    _p "\"did\":\"${SESSION_DID}\""
  else
    _pn "did: ${SESSION_DID}"
  fi

  debug 'core_info_session_did' 'END'
}

core_info_session_index()
{
  param_output_id="$1"
  param_output_json="$2"

  debug 'core_info_session_index' 'START'
  debug 'core_info_session_index' "param_output_id:${param_output_id}"
  debug 'core_info_session_index' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    _p "\"viewIndex\":["
  else
    _pn '[index]'
    if [ -n "${param_output_id}" ]
    then
      _pn '[[view indexes: <index> <uri> <cid>]]'
    else
      _pn '[[view indexes: <index>]]'
    fi
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
        
        if [ -n "${param_output_json}" ]
        then
          if [ $chunk_index -gt 1 ]
          then
            _p ','
          fi
          _p "{\"index\":${session_index},\"uri\":\"${session_uri}\",\"cid\":\"${session_cid}\"}"
        else
          if [ -n "${param_output_id}" ]
          then
            printf "%s\t%s\t%s\n" "${session_index}" "${session_uri}" "${session_cid}"
          else
            _pn "${session_index}"
          fi
        fi
      )
      chunk_index=`expr "${chunk_index}" + 1`
    done
  fi

  if [ -n "${param_output_json}" ]
  then
    _p "]"
  fi

  debug 'core_info_session_index' 'END'
}

core_info_session_cursor()
{
  param_output_json="$1"

  debug 'core_info_session_cursor' 'START'
  debug 'core_info_session_cursor' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    _p "\"cursor\":{\"timeline\":\"${SESSION_GETTIMELINE_CURSOR}\",\"feed\":\"${SESSION_GETFEED_CURSOR}\",\"authorFeed\":\"${SESSION_GETAUTHORFEED_CURSOR}\"}"
  else
    _pn '[cursor]'
    _pn "timeline cursor: ${SESSION_GETTIMELINE_CURSOR}"
    _pn "feed cursor: ${SESSION_GETFEED_CURSOR}"
    _pn "author-feed cursor: ${SESSION_GETAUTHORFEED_CURSOR}"
  fi

  debug 'core_info_session_cursor' 'END'
}

core_info_meta_path()
{
  param_output_json="$1"

  debug 'core_info_meta_path' 'START'
  debug 'core_info_meta_path' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    # TODO: escape double quote in value
    _p '"path":{'
    _p "\"BSKYSHCLI_RUN_COMMANDS_PATH\":\"${BSKYSHCLI_RUN_COMMANDS_PATH}\","
    _p "\"BSKYSHCLI_TOOLS_WORK_DIR\":\"${BSKYSHCLI_TOOLS_WORK_DIR}\","
    _p "\"BSKYSHCLI_LIB_PATH\":\"${BSKYSHCLI_LIB_PATH}\","
    _p "\"BSKYSHCLI_API_PATH\":\"${BSKYSHCLI_API_PATH}\""
    _p '}'
  else
    _pn "Run Commands (BSKYSHCLI_RUN_COMMANDS_PATH): ${BSKYSHCLI_RUN_COMMANDS_PATH}"
    _pn "work for session, debug log, etc. (BSKYSHCLI_TOOLS_WORK_DIR): ${BSKYSHCLI_TOOLS_WORK_DIR}"
    _pn "library (BSKYSHCLI_LIB_PATH): ${BSKYSHCLI_LIB_PATH}"
    _pn "api (BSKYSHCLI_API_PATH): ${BSKYSHCLI_API_PATH}"
  fi

  debug 'core_info_meta_path' 'END'
}

core_info_meta_config()
{
  param_output_json="$1"

  debug 'core_info_meta_config' 'START'
  debug 'core_info_meta_config' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    # TODO: escape double quote in value
    _p '"config":{'
    create_json_keyvalue_variable 'BSKYSHCLI_DEBUG'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_LIB_PATH'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_TZ'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_PROFILE'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_META'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_HEAD'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_BODY'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_SEPARATOR'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_OUTPUT_ID_PLACEHOLDER'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_QUOTE'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_OUTPUT_ID'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_META'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_HEAD'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_POST_FEED_GENERATOR_TAIL'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_IMAGE'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_PROFILE'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_PROFILE_OUTPUT_ID'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_COMMON'
    _p ','
    create_json_keyvalue_variable 'BSKYSHCLI_VIEW_TEMPLATE_PROFILE_NAVI_MYACCOUNT'
    _p '}'
  else
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
  fi

  debug 'core_info_meta_config' 'END'
}

core_info_meta_profile()
{
  param_output_json="$1"

  debug 'core_info_meta_profile' 'START'
  debug 'core_info_meta_profile' "param_output_json:${param_output_json}"

  if [ -n "${param_output_json}" ]
  then
    _p '"profile":['
    profile_stack=''
  else
    _pn '[profile (active session)]'
  fi
  session_files=`(cd "${SESSION_DIR}" && ls -- *"${SESSION_FILENAME_SUFFIX}" 2>/dev/null)`
  for session_file in $session_files
  do
    if [ "${session_file}" = "${SESSION_FILENAME_DEFAULT_PREFIX}${SESSION_FILENAME_SUFFIX}" ]
    then
      output_work='(default)'
    else
      output_work=`_p "${session_file}" | sed "s/${SESSION_FILENAME_SUFFIX}$//g"`
    fi
    if [ -n "${param_output_json}" ]
    then
      if [ -n "${profile_stack}" ]
      then
        profile_stack="${profile_stack},"
      fi
      profile_stack="${profile_stack}\"${output_work}\""
    else
      _pn "${output_work}"
    fi
  done
  if [ -n "${param_output_json}" ]
  then
    _p "${profile_stack}]"
  fi

  debug 'core_info_meta_profile' 'END'
}

core_size()
{
  param_stdin_text="$1"
  param_specified_text="$2"
  param_text_files="$3"
  param_separator_prefix="$4"
  param_count_only="$5"
  param_output_json="$6"

  debug 'core_size' 'START'
  debug 'core_post' "param_stdin_text:${param_stdin_text}"
  debug 'core_post' "param_specified_text:${param_specified_text}"
  debug 'core_post' "param_text_files:${param_text_files}"
  debug 'core_post' "param_separator_prefix:${param_separator_prefix}"
  debug 'core_post' "param_count_only:${param_count_only}"
  debug 'core_post' "param_output_json:${param_output_json}"

  json_stack=''
  status=0
  # standard input
  if [ -n "${param_stdin_text}" ]
  then
    core_text_size_lines "${param_stdin_text}" "${param_separator_prefix}"
    section_count=$?
    section_index=1
    if [ -n "${json_stack}" ]
    then
      json_stack="${json_stack},"
    fi
    json_stack="${json_stack}\"stdin\":["
    while [ $section_index -le $section_count ]
    do
      text_size=`eval _p \"\\$"RESULT_core_text_size_lines_${section_index}"\"`
      if [ "${text_size}" -le 300 ]
      then
        status=0
      else
        status=1
      fi
      if [ -n "${param_output_json}" ]
      then
        if [ $status -eq 0 ]
        then
          status_value='true'
        else
          status_value='false'
        fi
        if [ $section_index -gt 1 ]
        then
          json_stack="${json_stack},"
        fi
        json_stack="${json_stack}{\"size\":${text_size},\"status\":${status_value}}"
      else
        if [ -n "${param_count_only}" ]
        then
          _pn "${text_size}"
        else
          if [ $status -eq 0 ]
          then
            status_message='OK'
          else
            status_message='NG:over 300'
          fi
          if [ $section_count -eq 1 ]
          then
            _pn "standard input character count: ${text_size} [${status_message}]"
          else
            _pn "standard input character count (section #${section_index}): ${text_size} [${status_message}]"
          fi
        fi
      fi
      section_index=`expr "${section_index}" + 1`
    done
    json_stack="${json_stack}]"
  fi
  # parameter specified text
  if [ -n "${param_specified_text}" ]
  then
    # unescaped
    unescaped_text=`echo "${param_specified_text}" | sed 's/\\\\"/"/g'`
    core_text_size_lines "${unescaped_text}" "${param_separator_prefix}"
    section_count=$?
    section_index=1
    if [ -n "${json_stack}" ]
    then
      json_stack="${json_stack},"
    fi
    json_stack="${json_stack}\"text\":["
    while [ $section_index -le $section_count ]
    do
      text_size=`eval _p \"\\$"RESULT_core_text_size_lines_${section_index}"\"`
      if [ "${text_size}" -le 300 ]
      then
        status=0
      else
        status=1
      fi
      if [ -n "${param_output_json}" ]
      then
        if [ $status -eq 0 ]
        then
          status_value='true'
        else
          status_value='false'
        fi
        if [ $section_index -gt 1 ]
        then
          json_stack="${json_stack},"
        fi
        json_stack="${json_stack}{\"size\":${text_size},\"status\":${status_value}}"
      else
        if [ -n "${param_count_only}" ]
        then
          _pn "${text_size}"
        else
          if [ $status -eq 0 ]
          then
            status_message='OK'
          else
            status_message='NG:over 300'
          fi
          if [ $section_count -eq 1 ]
          then
            _pn "text character count: ${text_size} [${status_message}]"
          else
            _pn "text character count (section #${section_index}): ${text_size} [${status_message}]"
          fi
        fi
      fi
      section_index=`expr "${section_index}" + 1`
    done
    json_stack="${json_stack}]"
  fi
  # text files
  if [ -n "${param_text_files}" ]
  then
    if [ -n "${param_output_json}" ]
    then
      json_files=`core_process_files "${param_text_files}" 'core_output_text_file_size_lines' "${param_separator_prefix}" "${param_count_only}" "${param_output_json}"`
      json_files=`_p "${json_files}" | jq --slurp -c '.'`
      json_files="\"files\":${json_files}"
      if [ -n "${json_stack}" ]
      then
        json_stack="${json_stack},"
      fi
      json_stack="${json_stack}${json_files}"
    else
      core_process_files "${param_text_files}" 'core_output_text_file_size_lines' "${param_separator_prefix}" "${param_count_only}"
    fi
  fi
  json_stack="{${json_stack}}"
  if [ -n "${param_output_json}" ]
  then
    _p "${json_stack}"
  fi

  debug 'core_size' 'END'
}

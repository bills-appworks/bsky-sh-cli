#!/bin/sh -
# Bluesky in the shell
# A Bluesky CLI (Command Line Interface) implementation in shell script
# Author Bluesky:@bills-appworks.blue
# 
# Copyright (c) 2024-2025 bills-appworks
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php
IFS='
 	'
export IFS LC_ALL=C.UTF-8 LANG=C.UTF-8
umask 077
FILE_DIR=`dirname "$0"`
FILE_DIR=`(cd "${FILE_DIR}" && pwd)`

if [ -z "${BSKYSHCLI_DEFINE_PROXY}" ]; then
BSKYSHCLI_DEFINE_PROXY='defined'

# check if selfhosted AT server environment variable has been set
if [ -n "$BSKYSHCLI_SELFHOSTED_DOMAIN" ]
then
	ENDPOINT_BASE_URL="https://${BSKYSHCLI_SELFHOSTED_DOMAIN}/xrpc/"
else
	ENDPOINT_BASE_URL='https://bsky.social/xrpc/'
fi

if [ -n "${BSKYSHCLI_VIDEO_SERVICE_DOMAIN}" ]
then
  VIDEO_SERVICE_ENDPOINT_BASE_URL="https://${BSKYSHCLI_VIDEO_SERVICE_DOMAIN}/xrpc/"
else
  # variable use at API script
  # shellcheck disable=SC2034
  VIDEO_SERVICE_ENDPOINT_BASE_URL='https://video.bsky.app/xrpc/'
fi

HEADER_ACCEPT='Accept: application/json'
HEADER_AUTHORIZATION_PREFIX='Authorization: Bearer'
HEADER_CONTENT_TYPE='Content-Type: application/json'
HEADER_CONTENT_TYPE_KEY='Content-Type'

build_query_parameter()
{
  param_stack="$1"
  param_query_key="$2"
  param_query_value="$3"

  debug 'build_query_parameter' 'START'
  debug 'build_query_parameter' "param_stack:${param_stack}"
  debug 'build_query_parameter' "param_query_key:${param_query_key}"
  debug 'build_query_parameter' "param_query_value:${param_query_value}"

  query_value=`_p "${param_query_value}" | jq -Rr '@uri'`
  if [ -z "${param_stack}" ]
  then
    stack='?'
  else
    stack="${param_stack}&"
  fi
  stack="${stack}${param_query_key}=${query_value}"
  _p "${stack}"

  debug 'build_query_parameter' 'END'
}

build_array_parameters()
{
  param_stack="$1"
  param_query_key="$2"
  shift
  shift
  param_query_values="$@"

  debug 'build_array_parameters' 'START'
  debug 'build_array_parameters' "param_stack:${param_stack}"
  debug 'build_array_parameters' "param_query_key:${param_query_key}"
  debug 'build_array_parameters' "param_query_values:${param_query_values}"

  stack="${param_stack}"
  for query_value in $param_query_values
  do
    stack=`build_query_parameter "${stack}" "${param_query_key}" "${query_value}"`
  done
  _p "${stack}"

  debug 'build_array_parameters' 'END'
}

create_authorization_header()
{
  param_bearer="$1"

  debug 'create_authorization_header' 'START'

  _p "${HEADER_AUTHORIZATION_PREFIX} ${param_bearer}"

  debug 'create_authorization_header' 'END'
}

api_get_raw_queries()
{
  param_endpoint="$1"
  param_bearer="$2"
  param_raw_queries="$3"

  debug 'api_get_raw_queries' 'START'
  debug 'api_get_raw_queries' "param_endpoint:${param_endpoint}"
  debug 'api_get_raw_queries' "param_raw_queries:${param_raw_queries}"

  if [ -n "${param_bearer}" ]
  then
    bearer="${param_bearer}"
  else
    read_session_file
    bearer="${SESSION_ACCESS_JWT}"
  fi
  header_authorization=`create_authorization_header "${bearer}"`
  debug_single 'api_get_raw_queries'
  api_result=`curl -s -X GET "${ENDPOINT_BASE_URL}${param_endpoint}${param_raw_queries}" -H "${HEADER_ACCEPT}" -H "${header_authorization}" -w "\n%{response_code}" -i | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  result_header=`_p "${api_result}" | sed -n -e '1,/^\r*$/p'`
  debug 'HTTP header' "${result_header}"
  result_body=`_p "${api_result}" | sed -e '1,/^\r$/d' -e '$d'`
  result_status=`_p "${api_result}" | tail -n 1`
  debug 'HTTP status' "${result_status}"

  case "${result_status}" in
    301|302|307|308)
      header_location=`_p "${result_header}" | sed -n -E -e 's/^Location: *([^\r]+)\r$/\1/ip'`
      debug 'redirect header location' "${header_location}"
      if [ "${BSKYSHCLI_API_REDIRECT}" = 'OFF' ]
      then
        _p "{\"Location\":\"${header_location}\"}"
      else
        debug_single 'api_get_raw_queries_redirected'
        api_result=`curl -s -X GET "${header_location}" -H "${HEADER_ACCEPT}" -H "${header_authorization}" -w "\n%{response_code}" -i | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
        result_header=`_p "${api_result}" | sed -n -e '1,/^\r*$/p'`
        debug 'HTTP header' "${result_header}"
        result_body=`_p "${api_result}" | sed -e '1,/^\r$/d' -e '$d'`
        result_status=`_p "${api_result}" | tail -n 1`
        debug 'HTTP status' "${result_status}"
        _p "${result_body}"
      fi
      ;;
    *)
      _p "${result_body}"
      ;;
  esac

  debug 'api_get_raw_queries' 'END'
}

api_get()
{
  param_endpoint="$1"
  param_bearer="$2"
  shift
  shift

  debug 'api_get' 'START'
  debug 'api_get' "param_endpoint:${param_endpoint}"
  debug 'api_get' "QUERIES:$*"

  query_parameter=''
  while [ $# -gt 0 ]
  do
    if [ $# -lt 2 ]
    then
      error "query key $1 must have query value"
    fi
    if [ "$2" != '''' ] && [ -n "$2" ]
    then
      query_parameter=`build_query_parameter "${query_parameter}" "$1" "$2"`
    fi
    shift
    shift
  done

  api_get_raw_queries "${param_endpoint}" "${param_bearer}" "${query_parameter}"

  debug 'api_get' 'END'
}

api_get_nobearer_raw_queries()
{
  param_endpoint="$1"
  param_raw_queries="$2"

  debug 'api_get_nobearer_raw_queries' 'START'
  debug 'api_get_nobearer_raw_queries' "param_endpoint:${param_endpoint}"
  debug 'api_get_nobearer_raw_queries' "param_raw_queries:${param_raw_queries}"

  debug_single 'api_get_nobearer_raw_queries'
  api_result=`curl -s -X GET "${ENDPOINT_BASE_URL}${param_endpoint}${param_raw_queries}" -H "${HEADER_ACCEPT}" -w "\n%{response_code}" -i | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  result_header=`_p "${api_result}" | sed -n -e '1,/^\r*$/p'`
  debug 'HTTP header' "${result_header}"
  result_body=`_p "${api_result}" | sed -e '1,/^\r$/d' -e '$d'`
  result_status=`_p "${api_result}" | tail -n 1`
  debug 'HTTP status' "${result_status}"

  case "${result_status}" in
    301|302|307|308)
      header_location=`_p "${result_header}" | sed -n -E -e 's/^Location: *([^\r]+)\r$/\1/ip'`
      debug 'redirect header location' "${header_location}"
      if [ "${BSKYSHCLI_API_REDIRECT}" = 'OFF' ]
      then
        _p "{\"Location\":\"${header_location}\"}"
      else
        debug_single 'api_get_nobearer_raw_queries_redirected'
        api_result=`curl -s -X GET "${header_location}" -H "${HEADER_ACCEPT}" -H "${header_authorization}" -w "\n%{response_code}" -i | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
        result_header=`_p "${api_result}" | sed -n -e '1,/^\r*$/p'`
        debug 'HTTP header' "${result_header}"
        result_body=`_p "${api_result}" | sed -e '1,/^\r$/d' -e '$d'`
        result_status=`_p "${api_result}" | tail -n 1`
        debug 'HTTP status' "${result_status}"
        _p "${result_body}"
      fi
      ;;
    *)
      _p "${result_body}"
      ;;
  esac

  debug 'api_get_nobearer_raw_queries' 'END'
}

api_get_nobearer()
{
  param_endpoint="$1"
  shift

  debug 'api_get_nobearer' 'START'
  debug 'api_get_nobearer' "param_endpoint:${param_endpoint}"
  debug 'api_get_nobearer' "QUERIES:$*"

  query_parameter=''
  while [ $# -gt 0 ]
  do
    if [ $# -lt 2 ]
    then
      error "query key $1 must have query value"
    fi
    if [ "$2" != '''' ] && [ -n "$2" ]
    then
      query_parameter=`build_query_parameter "${query_parameter}" "$1" "$2"`
    fi
    shift
    shift
  done

  api_get_nobearer_raw_queries "${param_endpoint}" "${query_parameter}"

  debug 'api_get_nobearer' 'END'
}

api_post_nobearer()
{
  param_endpoint="$1"
  param_body="$2"

  debug 'api_post_nobearer' 'START'
  debug 'api_post_nobearer' "param_endpoint:${param_endpoint}"
# WARNING: parameters may contain sensitive information (e.g. passwords) and will remain in the debug log
#  debug_json 'api_post_nobearer' "param_body:${param_body}"
# WARNING: response may contain sensitive information (e.g. JWT) and will remain in the debug log
#  debug_single 'api_post_nobearer'
  api_result=`curl -s -X POST "${ENDPOINT_BASE_URL}${param_endpoint}" -H "${HEADER_CONTENT_TYPE}" -d "${param_body}" -w "\n%{response_code}" -i`
  result_header=`_p "${api_result}" | sed -n -e '1,/^\r*$/p'`
  debug 'HTTP header' "${result_header}"
  result_body=`_p "${api_result}" | sed -e '1,/^\r$/d' -e '$d'`
  result_status=`_p "${api_result}" | tail -n 1`
  debug 'HTTP status' "${result_status}"

  _p "${result_body}"

  debug 'api_post_nobearer' 'END'
}

api_post_bearer()
{
  param_endpoint="$1"
  param_bearer="$2"

  debug 'api_post_bearer' 'START'
  debug 'api_post_bearer' "param_endpoint:${param_endpoint}"

  header_authorization=`create_authorization_header "${param_bearer}"`
# WARNING: response may contain sensitive information (e.g. JWT) and will remain in the debug log
#  debug_single 'api_post_bearer'
  api_result=`curl -s -X POST "${ENDPOINT_BASE_URL}${param_endpoint}" -H "${HEADER_ACCEPT}" -H "${header_authorization}" -w "\n%{response_code}" -i | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  result_header=`_p "${api_result}" | sed -n -e '1,/^\r*$/p'`
  debug 'HTTP header' "${result_header}"
  result_body=`_p "${api_result}" | sed -e '1,/^\r$/d' -e '$d'`
  result_status=`_p "${api_result}" | tail -n 1`
  debug 'HTTP status' "${result_status}"

  _p "${result_body}"

  debug 'api_post_bearer' 'END'
}

api_post()
{
  param_endpoint="$1"
  param_body="$2"

  debug 'api_post' 'START'
  debug 'api_post' "param_endpoint:${param_endpoint}"
  debug 'api_post' "param_body:${param_body}"

  read_session_file
  bearer="${SESSION_ACCESS_JWT}"
  header_authorization=`create_authorization_header "${bearer}"`
  debug_single 'api_post'
  api_result=`curl -s -X POST "${ENDPOINT_BASE_URL}${param_endpoint}" -H "${HEADER_CONTENT_TYPE}" -H "${HEADER_ACCEPT}" -H "${header_authorization}" -d "${param_body}" -w "\n%{response_code}" -i | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  result_header=`_p "${api_result}" | sed -n -e '1,/^\r*$/p'`
  debug 'HTTP header' "${result_header}"
  result_body=`_p "${api_result}" | sed -e '1,/^\r$/d' -e '$d'`
  result_status=`_p "${api_result}" | tail -n 1`
  debug 'HTTP status' "${result_status}"

  _p "${result_body}"

  debug 'api_post' 'END'
}

api_post_content_type()
{
  param_endpoint="$1"
  param_content_type="$2"
  param_body="$3"

  debug 'api_post_content_type' 'START'
  debug 'api_post_content_type' "param_endpoint:${param_endpoint}"
  debug 'api_post_content_type' "param_content_type:${param_content_type}"
# omit log for big data
#  debug 'api_post_content_type' "param_body:${param_body}"

  read_session_file
  bearer="${SESSION_ACCESS_JWT}"
  header_authorization=`create_authorization_header "${bearer}"`
  header_content_type="${HEADER_CONTENT_TYPE_KEY}: ${param_content_type}"
  debug_single 'api_post_content_type'
  api_result=`curl -s -X POST "${ENDPOINT_BASE_URL}${param_endpoint}" -H "${header_content_type}" -H "${HEADER_ACCEPT}" -H "${header_authorization}" -d "${param_body}" -w "\n%{response_code}" -i | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  result_header=`_p "${api_result}" | sed -n -e '1,/^\r*$/p'`
  debug 'HTTP header' "${result_header}"
  result_body=`_p "${api_result}" | sed -e '1,/^\r$/d' -e '$d'`
  result_status=`_p "${api_result}" | tail -n 1`
  debug 'HTTP status' "${result_status}"

  _p "${result_body}"

  debug 'api_post_content_type' 'END'
}

api_post_content_type_binary_file()
{
  param_endpoint="$1"
  param_bearer="$2"
  param_content_type="$3"
  param_filename="$4"
  shift
  shift
  shift
  shift

  debug 'api_post_content_type_binary_file' 'START'
  debug 'api_post_content_type_binary_file' "param_endpoint:${param_endpoint}"
  debug 'api_post_content_type_binary_file' "param_content_type:${param_content_type}"
  debug 'api_post_content_type_binary_file' "param_filename:${param_filename}"
  debug 'api_get' "QUERIES:$*"

  query_parameter=''
  while [ $# -gt 0 ]
  do
    if [ $# -lt 2 ]
    then
      error "query key $1 must have query value"
    fi
    if [ "$2" != '''' ] && [ -n "$2" ]
    then
      query_parameter=`build_query_parameter "${query_parameter}" "$1" "$2"`
    fi
    shift
    shift
  done

  if [ -n "${param_bearer}" ]
  then
    bearer="${param_bearer}"
  else
    read_session_file
    bearer="${SESSION_ACCESS_JWT}"
  fi
  header_authorization=`create_authorization_header "${bearer}"`
  header_content_type="${HEADER_CONTENT_TYPE_KEY}: ${param_content_type}"
  debug_single 'api_post_content_type_binary_file'
  api_result=`curl -s -X POST "${ENDPOINT_BASE_URL}${param_endpoint}${query_parameter}" -H "${header_content_type}" -H "${HEADER_ACCEPT}" -H "${header_authorization}" -w "\n%{response_code}" -i --data-binary "@${param_filename}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  result_header=`_p "${api_result}" | sed -n -e '1,/^\r*$/p'`
  debug 'HTTP header' "${result_header}"
  result_body=`_p "${api_result}" | sed -e '1,/^\r$/d' -e '$d'`
  result_status=`_p "${api_result}" | tail -n 1`
  debug 'HTTP status' "${result_status}"

  _p "${result_body}"

  debug 'api_post_content_type_binary_file' 'END'
}

# ifndef BSKYSCHCLI_DEFINE_PROXY
fi

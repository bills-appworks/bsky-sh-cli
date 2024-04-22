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

if [ -z "${BSKYSHCLI_DEFINE_PROXY}" ]; then
BSKYSHCLI_DEFINE_PROXY='defined'

ENDPOINT_BASE_URL='https://bsky.social/xrpc/'
HEADER_ACCEPT='Accept: application/json'
HEADER_AUTHORIZATION_PREFIX='Authorization: Bearer'
HEADER_CONTENT_TYPE='Content-Type: application/json'

build_query_parameter()
{
  STACK="$1"
  QUERY_KEY="$2"
  QUERY_VALUE="$3"

  debug 'build_query_parameter' 'START'
  debug 'build_query_parameter' "STACK:${STACK}"
  debug 'build_query_parameter' "QUERY_KEY:${QUERY_KEY}"
  debug 'build_query_parameter' "QUERY_VALUE:${QUERY_VALUE}"

  QUERY_VALUE=`_p "${QUERY_VALUE}" | jq -Rr '@uri'`
  if [ -z "${STACK}" ]
  then
    STACK='?'
  else
    STACK="${STACK}&"
  fi
  STACK="${STACK}${QUERY_KEY}=${QUERY_VALUE}"
  _p "${STACK}"

  debug 'build_query_parameter' 'END'
}

build_array_parameters()
{
  STACK="$1"
  QUERY_KEY="$2"
  shift
  shift
  QUERY_VALUES="$@"

  debug 'build_array_parametres' 'START'
  debug 'build_array_parametres' "STACK:${STACK}"
  debug 'build_array_parametres' "QUERY_KEY:${QUERY_KEY}"
  debug 'build_array_parametres' "QUERY_VALUES:${QUERY_VALUES}"

  for QUERY_VALUE in $QUERY_VALUES
  do
    STACK=`build_query_parameter "${STACK}" "${QUERY_KEY}" "${QUERY_VALUE}"`
  done
  _p "${STACK}"

  debug 'build_array_parametres' 'END'
}

create_authorization_header()
{
  BEARER="$1"

  debug 'create_authorization_header' 'START'

  _p "${HEADER_AUTHORIZATION_PREFIX} ${BEARER}"

  debug 'create_authorization_header' 'END'
}

api_get_raw_queries()
{
  ENDPOINT="$1"
  BEARER="$2"
  RAW_QUERIES="$3"

  debug 'api_get_raw_queries' 'START'
  debug 'api_get_raw_queries' "ENDPOINT:${ENDPOINT}"
  debug 'api_get_raw_queries' "RAW_QUERIES:${RAW_QUERIES}"

  if [ -z "${BEARER}" ]
  then
    read_session_file
    BEARER="${SESSION_ACCESS_JWT}"
  fi
  HEADER_AUTHORIZATION=`create_authorization_header "${BEARER}"`
  debug_single 'api_get_raw_queries'
  curl -s -X GET "${ENDPOINT_BASE_URL}${ENDPOINT}${RAW_QUERIES}" -H "${HEADER_ACCEPT}" -H "${HEADER_AUTHORIZATION}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"

  debug 'api_get_raw_queries' 'END'
}

api_get()
{
  ENDPOINT="$1"
  BEARER="$2"
  shift
  shift

  debug 'api_get' 'START'
  debug 'api_get' "ENDPOINT:${ENDPOINT}"
  debug 'api_get' "QUERIES:$*"

  QUERY_PARAMETER=''
  while [ $# -gt 0 ]
  do
    if [ $# -lt 2 ]
    then
      error "query key $1 must have query value"
    fi
    if [ "$2" != '''' ] && [ -n "$2" ]
    then
      QUERY_PARAMETER=`build_query_parameter "${QUERY_PARAMETER}" "$1" "$2"`
    fi
    shift
    shift
  done

  api_get_raw_queries "${ENDPOINT}" "${BEARER}" "${QUERY_PARAMETER}"

  debug 'api_get' 'END'
}

api_post_nobearer()
{
  ENDPOINT="$1"
  BODY="$2"

  debug 'api_post_nobearer' 'START'
  debug 'api_post_nobearer' "ENDPOINT:${ENDPOINT}"
# WARNING: parameters may contain sensitive information (e.g. passwords) and will remain in the debug log
#  debug_json 'api_post_nobearer' "BODY:${BODY}"
  debug_single 'api_post_nobearer'
  curl -s -X POST "${ENDPOINT_BASE_URL}${ENDPOINT}" -H "${HEADER_CONTENT_TYPE}" -d "${BODY}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"

  debug 'api_post_nobearer' 'END'
}

api_post_bearer()
{
  ENDPOINT="$1"
  BEARER="$2"

  debug 'api_post_bearer' 'START'
  debug 'api_post_bearer' "ENDPOINT:${ENDPOINT}"

  HEADER_AUTHORIZATION=`create_authorization_header "${BEARER}"`
  debug_single 'api_post_bearer'
  curl -s -X POST "${ENDPOINT_BASE_URL}${ENDPOINT}" -H "${HEADER_ACCEPT}" -H "${HEADER_AUTHORIZATION}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"

  debug 'api_post_bearer' 'END'
}

api_post()
{
  ENDPOINT="$1"
  BODY="$2"

  debug 'api_post' 'START'
  debug 'api_post' "ENDPOINT:${ENDPOINT}"
  debug 'api_post' "BODY:${BODY}"

  read_session_file
  BEARER="${SESSION_ACCESS_JWT}"
  HEADER_AUTHORIZATION=`create_authorization_header "${BEARER}"`
  debug_single 'api_post'
  curl -s -X POST "${ENDPOINT_BASE_URL}${ENDPOINT}" -H "${HEADER_CONTENT_TYPE}" -H "${HEADER_ACCEPT}" -H "${HEADER_AUTHORIZATION}" -d "${BODY}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"

  debug 'api_post' 'END'
}

# ifndef BSKYSCHCLI_DEFINE_PROXY
fi

#!/bin/sh
FILE_DIR=`dirname "$0"`
FILE_DIR=`(cd "${FILE_DIR}" && pwd)`

ENDPOINT_BASE_URL='https://bsky.social/xrpc/'
HEADER_ACCEPT='Accept: application/json'
HEADER_AUTHORIZATION_PREFIX='Authorization: Bearer'
HEADER_CONTENT_TYPE='Content-Type: application/json'

create_authorization_header()
{
  BEARER="$1"

  echo "${HEADER_AUTHORIZATION_PREFIX} ${BEARER}"
}

api_get()
{
  ENDPOINT="$1"
  BEARER="$2"

  debug 'api_get' 'START'
  debug 'api_get' "ENDPOINT:${ENDPOINT}"

  if [ -z "${BEARER}" ]
  then
    read_session_file
    BEARER="${SESSION_ACCESS_JWT}"
  fi
  HEADER_AUTHORIZATION=`create_authorization_header "${BEARER}"`
  debug_single 'api_get'
  curl -s -X GET "${ENDPOINT_BASE_URL}${ENDPOINT}" -H "${HEADER_ACCEPT}" -H "${HEADER_AUTHORIZATION}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"

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

api_post()
{
  ENDPOINT="$1"
  BEARER="$2"
  BODY="$3"

  debug 'api_post' 'START'
  debug 'api_post' "ENDPOINT:${ENDPOINT}"

  if [ -z "${BEARER}" ]
  then
    read_session_file
    BEARER="${SESSION_ACCESS_JWT}"
  fi
  HEADER_AUTHORIZATION=`create_authorization_header "${BEARER}"`
  debug_single 'api_post'
  curl -s -X POST "${ENDPOINT_BASE_URL}${ENDPOINT}" -H "${HEADER_ACCEPT}" -H "${HEADER_AUTHORIZATION}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"

  debug 'api_post' 'END'
}

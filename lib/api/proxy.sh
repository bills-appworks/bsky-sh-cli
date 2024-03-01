#!/bin/sh
FILE_DIR=`dirname $0`
FILE_DIR=`(cd ${FILE_DIR} && pwd)`

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
  ESCAPE_MODE=1

  debug 'api_get' 'START'
  debug 'api_get' "ENDPOINT:${ENDPOINT}"

  read_session_file
  HEADER_AUTHORIZATION=`create_authorization_header "${SESSION_ACCESS_JWT}"`
  debug_single 'api_get'
  curl -s -X GET "${ENDPOINT_BASE_URL}${ENDPOINT}" -H "${HEADER_ACCEPT}" -H "${HEADER_AUTHORIZATION}" | $ESCAPE_DOUBLEBACKSLASH | tee $BSKYSHCLI_DEBUG_SINGLE
  # TODO: refresh session

  debug 'api_get' "RESULT:${RESULT}"
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

  RESULT=`curl -s -X POST "${ENDPOINT_BASE_URL}${ENDPOINT}" -H "${HEADER_CONTENT_TYPE}" -d "${BODY}"`

# WARNING: result value may contain sensitive information (e.g. session token) and will remain in the debug log
#  debug_json 'api_post_nobearer' "${RESULT}"
  debug 'api_post_nobearer' 'END'

  echo "${RESULT}"
}


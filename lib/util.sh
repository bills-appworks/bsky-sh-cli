#!/bin/sh
FILE_DIR=`dirname $0`
FILE_DIR=`(cd ${FILE_DIR} && pwd)`

BSKYSHCLI_DEBUG_ROOT_PATH="${TOOLS_WORK_DIR}"
BSKYSHCLI_DEBUG_LOG_FILEPATH="${TOOLS_WORK_DIR}/bsky-sh-cli_debug.log"
BSKYSHCLI_DEBUG_SINGLE=''

SESSION_DIR="${TOOLS_WORK_DIR}"
SESSION_FILENAME='bsky-sh-cli_session'
SESSION_KEY_HANDLE='SESSION_HANDLE'
SESSION_KEY_ACCESS_JWT='SESSION_ACCESS_JWT'
SESSION_KEY_REFRESH_JWT='SESSION_REFRESH_JWT'

## for restore (keeping) original JSON response 
##  in script expanded escape sequence at function/command return value
## strategy:
##   no calibration
##     caller(){VAR1=`callee`} calls callee(){...;echo "${VAR}"} and return to caller()
##       caller receive in $VAR1  <-  callee return in $VAR
##         \"                     <-    \"
##         \a                     <-    \\a
##         \n                     <-    \\n
##         (line break)           <-    \n
##         (line break)           <-    (line break)
##   do calibration
##     caller(){VAR1=`callee`} calls callee(){...;VAR=`echo "${VAR}" | $ESCAPE_BSKYSHCLI`;echo "${VAR}"} and return to caller()
##       caller receive in $VAR1  <-  callee return in $VAR (after process ESCAPE_DOUBLEBACKSLASH) <- callee original $VAR (before process ESCAPE_DOUBLEBACKSLASH)
##         \"                     <-    \"                                                         <-   \"
##         \\a                    <-    \\\\a                                                      <-   \\a
##         \\n                    <-    \\\\n                                                      <-   \\n
##         (line break)           <-    \n                                                         <-   \n
##         (line break)           <-    (line break)                                               <-   (line break)
##   doing calibration each function layers
##   this logic is original \n(non escaped newline escape sequence literally) lacks and mix together with line break (0x0A)
##   this code assuming there are no line breaks in the original JSON
##   in the top level function restore \n from line break by ESCPAE_NEWLINE
##
# (line break) -> \n(literally), \n(literally) at the end of line -> (remove)
# using GNU sed -z option
ESCAPE_NEWLINE_PATTERN='s/\n/\\n/g;s/\\n$//g'
ESCAPE_NEWLINE="sed -z ${ESCAPE_NEWLINE_PATTERN}"
# \\ -> \\\\ (literally in left variable of VAR=`echo "${VAR}" | $ESCAPE_DOUBLEBACKSLASH`)
ESCAPE_DOUBLEBACKSLASH_PATTERN='s/\\\\/\\\\\\\\/g'
ESCAPE_DOUBLEBACKSLASH="sed ${ESCAPE_DOUBLEBACKSLASH_PATTERN}"
# using GNU sed -z option
ESCAPE_BSKYSHCLI="sed -z ${ESCAPE_DOUBLEBACKSLASH_PATTERN};${ESCAPE_NEWLINE_PATTERN}"

debug_mode_suppress()
{
  EVACUATED_BSKYSHCLI_DEBUG="${BSKYSHCLI_DEBUG}"
  BSKYSHCLI_DEBUG=0
}

debug_mode_restore()
{
  BSKYSHCLI_DEBUG="${EVACUATED_BSKYSHCLI_DEBUG}"
}

debug()
{
  ID="$1"
  MESSAGE="$2"

  if [ "${BSKYSHCLI_DEBUG:=0}" -eq 1 ]
  then
    TIMESTAMP=`date '+%Y/%m/%d %H:%M:%S'`
    echo "${TIMESTAMP} ${ID}: ${MESSAGE}" >> "${BSKYSHCLI_DEBUG_LOG_FILEPATH}"
  fi
}

debug_single()
{
  FILE="$1"

  if [ "${BSKYSHCLI_DEBUG:=0}" -eq 1 ]
  then
    BSKYSHCLI_DEBUG_SINGLE="${BSKYSHCLI_DEBUG_ROOT_PATH}/${FILE}"
  else
    BSKYSHCLI_DEBUG_SINGLE=''
  fi
}

debug_json()
{
  ID="$1"
  JSON="$2"

  if [ "${BSKYSHCLI_DEBUG:=0}" -eq 1 ]
  then
    MESSAGE=`echo "${JSON}" | jq`
    debug "${ID}" "${MESSAGE}"
  fi
}

error()
{
  MESSAGE="$1"

  echo "ERROR: ${MESSAGE}" 1>&2
  exit 1
}

api()
{
  API="$1"

  debug 'api' 'START'
  debug 'api' "API:${API}"

  shift
  debug_single 'api'
  RESULT=`sh ${TOOLS_ROOT_DIR}/lib/api/${API} $@ | tee $BSKYSHCLI_DEBUG_SINGLE`
  ERROR=`echo "${RESULT}" | $ESCAPE_NEWLINE | jq -r '.error // empty'`
  if [ -n "$ERROR" ]
  then
    debug 'api' "ERROR:${ERROR}"
    case "${ERROR}" in
      ExpiredToken)
        # TODO: refresh session
        error 'Session expired (session auto refresh not yet implemented).'
        ;;
      *)
        error 'Unknown error.'
        ;;
    esac
  fi

  debug 'api' 'END'

  echo "${RESULT}"
  return 0
}

get_session_filepath()
{
  debug 'get_session_filepath' 'START'

  SESSION_FILEPATH="${SESSION_DIR}/${SESSION_FILENAME}"

  debug 'get_session_filepath' "SESSION_FILEPATH:${SESSION_FILEPATH}"
  debug 'get_session_filepath' 'END'

  echo "${SESSION_FILEPATH}"
}

create_session_file()
{
  HANDLE="$1"
  ACCESS_JWT="$2"
  REFRESH_JWT="$3"

  debug 'create_session_file' 'START'
  debug 'create_session_file' "HANDLE:${HANDLE}"
# WARNING: parameters may contain sensitive information (e.g. session token) and will remain in the debug log
#  debug 'create_session_file' "ACCESS_JWT:${ACCESS_JWT}"
#  debug 'create_session_file' "REFRESH_JWT:${REFRESH_JWT}"

  SESSION_FILEPATH=`get_session_filepath "${HANDLE}"`
  echo "${SESSION_KEY_HANDLE}=${HANDLE}" > "${SESSION_FILEPATH}"
  echo "${SESSION_KEY_ACCESS_JWT}=${ACCESS_JWT}" >> "${SESSION_FILEPATH}"
  echo "${SESSION_KEY_REFRESH_JWT}=${REFRESH_JWT}" >> "${SESSION_FILEPATH}"

  debug 'create_session_file' 'END'
}

read_session_file()
{
  debug 'read_session_file' 'START'

  SESSION_FILEPATH=`get_session_filepath "${HANDLE}"`
  if [ -e $SESSION_FILEPATH ]
  then
    . "${SESSION_FILEPATH}"
  fi

  debug 'read_session_file' 'END'
}

update_session_file()
{
  debug 'update_session_file' 'START'

  # TODO
  SESSION_FILEPATH=`get_session_filepath "${HANDLE}"`

  debug 'update_session_file' 'END'
}

clear_session_file()
{
  debug 'clear_session_file' 'START'

  SESSION_FILEPATH=`get_session_filepath "${HANDLE}"`
  if [ -e $SESSION_FILEPATH ]
  then
    rm -f "${SESSION_FILEPATH}"
  fi

  debug 'clear_session_file' 'END'
}


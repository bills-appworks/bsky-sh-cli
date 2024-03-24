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

if [ -z "${BSKYSHCLI_DEFINE_UTIL}" ]; then
BSKYSHCLI_DEFINE_UTIL='defined'

BSKYSHCLI_DEBUG_ROOT_PATH="${BSKYSHCLI_TOOLS_WORK_DIR}"
BSKYSHCLI_DEBUG_LOG_FILEPATH="${BSKYSHCLI_TOOLS_WORK_DIR}/bsky_sh_cli_debug.log"
BSKYSHCLI_DEBUG_SINGLE=''

# variable use at this file include(source) script
# shellcheck disable=SC2034
BSKYSHCLI_DEFAULT_DOMAIN='.bsky.social'

SESSION_FILENAME_DEFAULT_PREFIX='_bsky_sh_cli'
SESSION_FILENAME_SUFFIX='_session'
SESSION_DIR="${BSKYSHCLI_TOOLS_WORK_DIR}"
SESSION_KEY_HANDLE='SESSION_HANDLE'
SESSION_KEY_ACCESS_JWT='SESSION_ACCESS_JWT'
SESSION_KEY_REFRESH_JWT='SESSION_REFRESH_JWT'

### following escape process is unnecessary by changing from echo to _p
## for restore (keeping) original JSON response 
##  in script expanded escape sequence at function/command return value by echo to standard output
## strategy:
##   no calibration
##     caller(){VAR1=`callee`} calls callee(){...;echo "${VAR2}"} and return to caller()
##       caller receive in $VAR1  <-  callee return in $VAR2
##         \"                     <-    \"
##         \a                     <-    \\a
##         \n                     <-    \\n
##         (line break)           <-    \n
##         (line break)           <-    (line break)
##   do calibration
##     caller(){VAR1=`callee`} calls callee(){...;echo "${VAR2}" | $ESCAPE_BSKYSHCLI and return to caller()
##       caller receive in $VAR1  <-  callee return in $VAR2 (after process ESCAPE_BSKYSHCLI) <- callee original $VAR (before process ESCAPE_BSKYSHCLI)
##         \"                     <-    \"                                                    <-   \"
##         \\a                    <-    \\\\a                                                 <-   \\a
##         \\n                    <-    \\\\n                                                 <-   \\n
##         (line break)           <-    \n                                                    <-   \n
##         (line break)           <-    \n                                                    <-   (line break)
##   doing calibration each function layers
##   this logic is original \n(non escaped newline escape sequence literally) lacks and mix together with line break (0x0A)
##   this code assuming there are no line breaks in the original JSON
##
## however, this process is redundantly escaped when execute under VSCode bash debug.
##
# (line break) -> \n(literally), \n(literally) at the end of line -> (remove)
# using GNU sed -z option
ESCAPE_NEWLINE_PATTERN='s/\n/\\n/g;s/\\n$//g'
# obsolete definition
# shellcheck disable=SC2034
ESCAPE_NEWLINE="sed -z ${ESCAPE_NEWLINE_PATTERN}"
# \\ -> \\\\ (literally in left variable of VAR=`echo "${VAR}" | $ESCAPE_DOUBLEBACKSLASH`)
ESCAPE_DOUBLEBACKSLASH_PATTERN='s/\\\\/\\\\\\\\/g'
# obsolete definition
# shellcheck disable=SC2034
ESCAPE_DOUBLEBACKSLASH="sed ${ESCAPE_DOUBLEBACKSLASH_PATTERN}"
# using GNU sed -z option
# obsolete definition
# shellcheck disable=SC2034
ESCAPE_BSKYSHCLI="sed -z ${ESCAPE_DOUBLEBACKSLASH_PATTERN};${ESCAPE_NEWLINE_PATTERN}"

_p()
{
  printf '%s' "$*"
}

_pn()
{
  printf '%s\n' "$*"
}

_strlen()
{
  STRING=$1

  RESULT=`_p "${STRING}" | wc -c`
  return "${RESULT}"
}

_strleft()
{
  STRING=$1
  SEPARATOR=$2

  _p "${STRING}" | sed "s/\(^[^${SEPARATOR}]*\)${SEPARATOR}.*$/\1/"
}

_strright()
{
  STRING=$1
  SEPARATOR=$2

  SEPARATOR_IN_STRING=`_p "${STRING}" | sed "s/[^${SEPARATOR}]//g"`
  if [ -z "${SEPARATOR_IN_STRING}" ]
  then
    _p ''
  else
    _p "${STRING}" | sed "s/^.*${SEPARATOR}\([^${SEPARATOR}]*$\)/\1/"
  fi
}

_cut()
{
  STRING=$1
  shift

  _p "`_p "${STRING}" | cut "$@" | tr -d '\n'`"
}

set_timezone()
{
  if [ -n "${BSKYSHCLI_TZ}" ]
  then
    export TZ="${BSKYSHCLI_TZ}"
  fi
}

get_timestamp()
{
  date '+%Y/%m/%d %H:%M:%S'
}

get_ISO8601UTCbs()
{
  date -u '+%Y-%m-%dT%H:%M:%S.000Z'
}

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
    TIMESTAMP=`get_timestamp`
    _pn "${TIMESTAMP} ${ID}: ${MESSAGE}" >> "${BSKYSHCLI_DEBUG_LOG_FILEPATH}"
  fi
}

debug_single()
{
  FILE="$1"

  if [ "${BSKYSHCLI_DEBUG:=0}" -eq 1 ]
  then
    BSKYSHCLI_DEBUG_SINGLE="${BSKYSHCLI_DEBUG_ROOT_PATH}/${FILE}"
  else
    BSKYSHCLI_DEBUG_SINGLE='/dev/null'
  fi
}

debug_json()
{
  ID="$1"
  JSON="$2"

  if [ "${BSKYSHCLI_DEBUG:=0}" -eq 1 ]
  then
    MESSAGE=`_p "${JSON}" | jq`
    debug "${ID}" "${MESSAGE}"
  fi
}

error()
{
  MESSAGE="$1"

  _pn "ERROR: ${MESSAGE}" 1>&2
  exit 1
}

get_option_type()
{
  OPTION_TYPE_TARGET=$1

  case `_cut "${OPTION_TYPE_TARGET}" -c 1` in
    -)  # '-...'
      case `_cut "${OPTION_TYPE_TARGET}" -c 2` in
        -)
          _strlen "${OPTION_TYPE_TARGET}"
          if [ $? -eq 2 ]
          then  # '--'
            return 255
          fi
          return 2
          ;;
        *)  # '-<any>'
          return 1
          ;;
      esac
      ;;
    *)  # '<any>'
      return 0
      ;;
  esac
}

parse_parameter_element()
{
  EFFECTIVE_LIST=$1
  TARGET=$2
  TARGET_NEXT=$3

  debug 'parse_parameter_element' 'START'
  debug 'parse_parameter_element' "EFFECTIVE_LIST:${EFFECTIVE_LIST}"
  debug 'parse_parameter_element' "TARGET:${TARGET}"
  debug 'parse_parameter_element' "TARGET_NEXT:${TARGET_NEXT}"

  TARGET_LHS=`_strleft "${TARGET}" '='`
  TARGET_RHS=`_strright "${TARGET}" '='`

  debug 'parse_parameter_element' "TARGET_LHS:${TARGET_LHS}"
  debug 'parse_parameter_element' "TARGET_RHS:${TARGET_RHS}"

  SKIP_COUNT=''
  for LISTITEM in $EFFECTIVE_LIST
  do
    EFFECTIVE_NAME=`_strleft "${LISTITEM}" ':'`
    EFFECTIVE_VALUE=`_strright "${LISTITEM}" ':'`
    if [ "${EFFECTIVE_NAME}" = "${TARGET_LHS}" ]
    then  # target is effective option
      if [ "${EFFECTIVE_VALUE}" -eq 0 ]
      then  # target is no value required
        if [ -n "${TARGET_RHS}" ]
        then  # but value specified 'target=...'
          _p "parameter must not specify a value: ${TARGET}"
          SKIP_COUNT=255
        else  # no value specified by 'target=...'
          # next parameter is not check and delegate to next
          SKIP_COUNT=0
        fi
      else  # target is value required
        if [ -n "${TARGET_RHS}" ]
        then  # value specified 'target=...'
          _p "${TARGET_RHS}"
          SKIP_COUNT=0
        else  # value not specified by 'target=...'
          if [ -n "${TARGET_NEXT}" ]
          then  # check next parameter
            get_option_type "${TARGET_NEXT}"
            NEXT_OPTION_TYPE=$?
            case $NEXT_OPTION_TYPE in
              0)  # next parameter is not option ('<any>'), maybe value
                _p "${TARGET_NEXT}"
                SKIP_COUNT=1
                ;;
              1|2|255)  # next parameter is option ('-...' or '--...')  or '--'
                _p "parameter must specify value: ${TARGET}"
                SKIP_COUNT=255
                ;;
              *)
                _p 'internal error: parse_parameter_element'
                SKIP_COUNT=255
                ;;
            esac
          else  # next parameter is not exist
            _p "parameter must spcify value: ${TARGET}"
            SKIP_COUNT=255
          fi
        fi
      fi
      break
    fi
  done
  if [ -z "${SKIP_COUNT}" ]
  then
    _p "invalid parameter: ${TARGET}"
    SKIP_COUNT=255
  fi
  
  debug 'parse_parameter_element' 'END'

  return $SKIP_COUNT
}

parse_parameters()
{
  EFFECTIVE_LIST=$1
  shift

  debug 'parse_parameters' 'START'
  debug 'parse_parameters' "EFFECTIVE_LIST:${EFFECTIVE_LIST}"
  debug 'parse_parameters' "PARAMETERS:$*"

  COUNT_OPTIONS=0
  while [ $# -gt 0 ]
  do
    debug 'parse_parameters' "TARGET:$1"
    get_option_type "$1"
    OPTION_TYPE=$?
    debug 'parse_parameters' "OPTION_TYPE:${OPTION_TYPE}"
    case $OPTION_TYPE in
      0)  # maybe command or non optional value
        break
        ;;
      1|2)  # option '-...' or '--...'
        VALUE=`parse_parameter_element "${EFFECTIVE_LIST}" "$1" "$2"`
        SKIP_COUNT=$?
        debug 'parse_parameters' "SKIP_COUNT:${SKIP_COUNT}"
        if [ $SKIP_COUNT -eq 255 ]
        then
          error "${VALUE}"
        fi
        # -O or --opt -> O or opt
        CUT_START=`expr "${OPTION_TYPE}" + 1`
        CANONICAL_KEY=`_cut "$1" -c "${CUT_START}"-`
        # O or opt=value -> O or opt
        CANONICAL_KEY=`_strleft "${CANONICAL_KEY}" '='`
        # opt-foo -> opt_foo
        CANONICAL_KEY=`_p "${CANONICAL_KEY}" | sed 's/-/_/g'`
        # options value requirement is checked at parse_parameter_lement
        if [ -z "${VALUE}" ]
        then  # this parameter is single option
          EVALUATE="PARSED_PARAM_KEYONLY_${CANONICAL_KEY}='defined'"
        else  # this parameter is value specified option
          # escape \ -> \\, ' -> '\'', " -> \", (newline) -> \n
          # using GNU sed -z option
          VALUE=`_p "${VALUE}" | sed -z 's/\\\\/\\\\\\\\/g'";s/'/'\\\\\\\\''/g"';s/"/\\\\"/g;s/\n/\\\\n/g'`
          # quote for space character and others of shell separate
          VALUE="'${VALUE}'"
          EVALUATE="PARSED_PARAM_KEYVALUE_${CANONICAL_KEY}=${VALUE}"
        fi
        if [ $SKIP_COUNT -eq 1 ]
        then  # next parameter is current parameters value (non single option)
          COUNT_OPTIONS=`expr "${COUNT_OPTIONS}" + 1`
          shift
        fi
        eval "${EVALUATE}"
        debug 'parse_parameters' "EVALUATE:${EVALUATE}"
        ;;
      255)  # '--'
        COUNT_OPTIONS=`expr "${COUNT_OPTIONS}" + 1`
        shift
        break
        ;;
      *)
        error 'internal error: parse_parameters'
        ;;
    esac
    COUNT_OPTIONS=`expr "${COUNT_OPTIONS}" + 1`
    shift
  done
  return "${COUNT_OPTIONS}"
}

create_json_keyvalue()
{
  KEY=$1
  VALUE=$2
  QUOTE=$3

  debug 'create_json_keyvalue' 'START'
  debug 'create_json_keyvalue' "KEY:${KEY} VALUE:${VALUE} QUOTE:${QUOTE}"

  if [ -z "${KEY}" ]
  then
    error 'key must be specified'
  fi

  if [ "${QUOTE:=0}" -eq 0 ]
  then
    QUOTE='"'
  else
    QUOTE=''
  fi

  _p "\"${KEY}\":${QUOTE}${VALUE}${QUOTE}"

  debug 'create_json_keyvalue' 'END'
}

api_core()
{
  API="$1"
  # various API params continue

  debug 'api_core' 'START'
  debug 'api_core' "API:${API}"

  shift
  debug_single 'api_core-1'
  RESULT=`/bin/sh "${BSKYSHCLI_API_PATH}/${API}" "$@" | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  ERROR=`_p "${RESULT}" | jq -r '.error // empty'`
  if [ -n "$ERROR" ]
  then
    debug 'api_core' "ERROR:${ERROR}"
    case "${ERROR}" in
      ExpiredToken)
        return 2
        ;;
      *)
        MESSAGE=`_p "${RESULT}" | jq -r '.message // empty'`
        error "${ERROR} : ${MESSAGE}"
        ;;
    esac
  fi

  if [ -n "${RESULT}" ]
  then
    debug_single 'api_core-2'
    _p "${RESULT}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"
  fi

  debug 'api_core' 'END'
  return 0
}

api()
{
  # TODO: retry any time for api_core error
  API="$1"
  # various API params continue

  debug 'api' 'START'
  debug 'api' "API:${API}"

  RESULT=`api_core "$@"`
  STATUS_API_CORE=$?
  debug_single 'api-1'
  RESULT=`_p "${RESULT}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  debug 'api' "api_core status: ${STATUS_API_CORE}"
  case $STATUS_API_CORE in
    0)
      debug_single 'api-2'
      _p "${RESULT}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"
      API_STATUS=0
      ;;
    1)
      error "${ERROR}"
      ;;
    2)
      # session expired
      read_session_file
      api_core 'com.atproto.server.refreshSession' "${SESSION_REFRESH_JWT}" > /dev/null
      debug_single 'api-3'
      api_core "$@" | tee "${BSKYSHCLI_DEBUG_SINGLE}"
      API_STATUS=$?
      ;;
  esac

  debug 'api' 'END'

  return $API_STATUS
}

verify_profile_name()
{
  PROFILE="$1"

  debug 'verify_profile_name' 'START'
  debug 'verify_profile_name' "PROFILE:${PROFILE}"

  VERIFY=`_p "${PROFILE}" | sed 's/^[A-Za-z0-9][A-Za-z0-9._-]*//g'`
  if [ -n "${VERIFY}" ]
  then
    error "invalid profile name '${PROFILE}' : must be start with alphanumeric and continue alphanumeric or underscore or hyphen or period"
  fi

  debug 'verify_profile_name' 'END'
}

get_session_filepath()
{
  debug 'get_session_filepath' 'START'
  if [ -n "${BSKYSHCLI_GLOBAL_OPTION_PROFILE}" ]
  then
    SESSION_FILENAME="${BSKYSHCLI_GLOBAL_OPTION_PROFILE}${SESSION_FILENAME_SUFFIX}"
  else
    SESSION_FILENAME="${SESSION_FILENAME_DEFAULT_PREFIX}${SESSION_FILENAME_SUFFIX}"
  fi

  SESSION_FILEPATH="${SESSION_DIR}/${SESSION_FILENAME}"

  debug 'get_session_filepath' "SESSION_FILEPATH:${SESSION_FILEPATH}"
  debug 'get_session_filepath' 'END'

  _p "${SESSION_FILEPATH}"
}

create_session_info()
{
  OPS="$1"
  HANDLE="$2"
  ACCESS_JWT="$3"
  REFRESH_JWT="$4"

  debug 'create_session_info' 'START'

  debug 'create_session_info' "PROFILE: ${PROFILE}"
  debug 'create_session_info' "UPDATE_MODE: ${UPDATE_MODE}"
  debug 'create_session_info' "HANDLE: ${HANDLE}"
  if [ -n "${ACCESS_JWT}" ]
  then
    MESSAGE='(specified)'
  else
    MESSAGE='(empty)'
  fi
  debug 'create_session_info' "ACCESS_JWT: ${MESSAGE}"
  if [ -n "${REFRESH_JWT}" ]
  then
    MESSAGE='(specified)'
  else
    MESSAGE='(empty)'
  fi
  debug 'create_session_info' "REFRESH_JWT: ${MESSAGE}"

  TIMESTAMP=`get_timestamp`
  _pn "# session ${OPS} at ${TIMESTAMP}"
  _pn "${SESSION_KEY_HANDLE}=${HANDLE}"
  _pn "${SESSION_KEY_ACCESS_JWT}=${ACCESS_JWT}"
  _pn "${SESSION_KEY_REFRESH_JWT}=${REFRESH_JWT}"

  debug 'create_session_info' 'END'
}

create_session_file()
{
  HANDLE="$1"
  ACCESS_JWT="$2"
  REFRESH_JWT="$3"

  debug 'create_session_file' 'START'
  debug 'create_session_file' "HANDLE:${HANDLE}"
  if [ -n "${ACCESS_JWT}" ]
  then
    MESSAGE='(specified)'
  else
    MESSAGE='(empty)'
  fi
  debug 'create_session_info' "ACCESS_JWT: ${MESSAGE}"
  if [ -n "${REFRESH_JWT}" ]
  then
    MESSAGE='(specified)'
  else
    MESSAGE='(empty)'
  fi
  debug 'create_session_info' "REFRESH_JWT: ${MESSAGE}"

  SESSION_FILEPATH=`get_session_filepath`
  create_session_info 'create' "${HANDLE}" "${ACCESS_JWT}" "${REFRESH_JWT}" > "${SESSION_FILEPATH}"

  debug 'create_session_file' 'END'
}

read_session_file()
{
  debug 'read_session_file' 'START'

  SESSION_FILEPATH=`get_session_filepath`
  if [ -e "${SESSION_FILEPATH}" ]
  then
    # SC1090 disable for dynamical(variable) path source(.) using and generize on runtime
    # shellcheck source=/dev/null
    . "${SESSION_FILEPATH}"
  else
    error "session not found: ${SESSION_FILEPATH}"
  fi

  debug 'read_session_file' 'END'
}

update_session_file()
{
  HANDLE="$1"
  ACCESS_JWT="$2"
  REFRESH_JWT="$3"

  debug 'update_session_file' 'START'

  SESSION_FILEPATH=`get_session_filepath`
  case $BSKYSHCLI_SESSION_FILE_UPDATE in
    append)
      create_session_info 'update' "${HANDLE}" "${ACCESS_JWT}" "${REFRESH_JWT}" >> "${SESSION_FILEPATH}"
      ;;
    overwrite|*)
      create_session_info 'update' "${HANDLE}" "${ACCESS_JWT}" "${REFRESH_JWT}" > "${SESSION_FILEPATH}"
      ;;
  esac

  debug 'update_session_file' 'END'
}

clear_session_file()
{
  debug 'clear_session_file' 'START'

  SESSION_FILEPATH=`get_session_filepath`
  if [ -e "${SESSION_FILEPATH}" ]
  then
    rm -f "${SESSION_FILEPATH}"
  fi

  debug 'clear_session_file' 'END'
}

# ifndef BSKYSHCLI_DEFINE_UTIL
fi


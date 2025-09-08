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
FILE_DIR=`dirname "$0"`
FILE_DIR=`(cd "${FILE_DIR}" && pwd)`

if [ -z "${BSKYSHCLI_DEFINE_UTIL}" ]; then  # ifndef BSKYSCHCLI_DEFINE_UTIL
BSKYSHCLI_DEFINE_UTIL='defined'

BSKYSHCLI_DEBUG_LOG_FILEPATH="${BSKYSHCLI_DEBUG_DIR}/bsky_sh_cli_debug.log"
BSKYSHCLI_DEBUG_SINGLE=''

SESSION_FILENAME_DEFAULT_PREFIX='_bsky_sh_cli'
SESSION_FILENAME_SUFFIX='_session'
SESSION_DIR="${BSKYSHCLI_TOOLS_WORK_DIR}"
SESSION_KEY_RECORD_VERSION='SESSION_RECORD_VERSION'
SESSION_KEY_LOGIN_TIMESTAMP='SESSION_LOGIN_TIMESTAMP'
SESSION_KEY_REFRESH_TIMESTAMP='SESSION_REFRESH_TIMESTAMP'
SESSION_KEY_HANDLE='SESSION_HANDLE'
SESSION_KEY_DID='SESSION_DID'
SESSION_KEY_ACCESS_JWT='SESSION_ACCESS_JWT'
SESSION_KEY_REFRESH_JWT='SESSION_REFRESH_JWT'
SESSION_KEY_GETTIMELINE_CURSOR='SESSION_GETTIMELINE_CURSOR'
SESSION_KEY_GETFEED_CURSOR='SESSION_GETFEED_CURSOR'
SESSION_KEY_GETAUTHORFEED_CURSOR='SESSION_GETAUTHORFEED_CURSOR'
SESSION_KEY_FOLLOWS_CURSOR='SESSION_FOLLOWS_CURSOR'
SESSION_KEY_FOLLOWERS_CURSOR='SESSION_FOLLOWERS_CURSOR'
SESSION_KEY_KNOWN_FOLLOWERS_CURSOR='SESSION_KNOWN_FOLLOWERS_CURSOR'
SESSION_KEY_BOOKMARK_CURSOR='SESSION_BOOKMARK_CURSOR'
SESSION_KEY_FEED_VIEW_INDEX='SESSION_FEED_VIEW_INDEX'
BSKYSHCLI_SESSION_LIST="
${SESSION_KEY_LOGIN_TIMESTAMP}
${SESSION_KEY_REFRESH_TIMESTAMP}
${SESSION_KEY_HANDLE}
${SESSION_KEY_DID}
${SESSION_KEY_ACCESS_JWT}
${SESSION_KEY_REFRESH_JWT}
${SESSION_KEY_GETTIMELINE_CURSOR}
${SESSION_KEY_GETFEED_CURSOR}
${SESSION_KEY_GETAUTHORFEED_CURSOR}
${SESSION_KEY_FOLLOWS_CURSOR}
${SESSION_KEY_FOLLOWERS_CURSOR}
${SESSION_KEY_KNOWN_FOLLOWERS_CURSOR}
${SESSION_KEY_BOOKMARK_CURSOR}
${SESSION_KEY_FEED_VIEW_INDEX}
"

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
  param_strlen_string=$1

  result=`_p "${param_strlen_string}" | wc -c | sed 's/[^0-9]//g'`
  return "${result}"
}

_strleft()
{
  param_strleft_string=$1
  param_strleft_separator=$2

  _p "${param_strleft_string}" | sed "s/\(^[^${param_strleft_separator}]*\)${param_strleft_separator}.*$/\1/"
}

_strright()
{
  param_strright_string=$1
  param_strright_separator=$2

  separator_in_string=`_p "${param_strright_string}" | sed "s/[^${param_strright_separator}]//g"`
  if [ -z "${separator_in_string}" ]
  then
    _p ''
  else
    _p "${param_strright_string}" | sed "s/^.*${param_strright_separator}\([^${param_strright_separator}]*$\)/\1/"
  fi
}

_strchompleft()
{
  param_strchompleft_string=$1
  param_strchompleft_chomp=$2

  _p "${param_strchompleft_string}" | sed "s/^${param_strchompleft_chomp}\(.*$\)/\1/"
}

_isnumeric()
{
  param_isnumeric_string=$1

  not_numeric=`_p "${param_isnumeric_string}" | sed 's/[0-9]//g'`
  if [ -z "${not_numeric}" ]
  then
    status=0
  else
    status=1
  fi

  return "${status}"
}

_cut()
{
  param_cut_string=$1
  shift

  _p "`_p "${param_cut_string}" | cut "$@"`"
}

_slice()
{
  param_slice_string=$1
  param_slice_separator=$2

  separator_in_string=`_p "${param_slice_string}" | sed "s/[^${param_slice_separator}]//g"`
  _strlen "${separator_in_string}"
  separator_count=$?
  element_count=`expr "${separator_count}" + 1`
  element_index=1
  while [ "${element_index}" -le "${element_count}" ]
  do
    string_element=`_cut "${param_slice_string}" -d "${param_slice_separator}" -f "${element_index}"`
    eval "RESULT_slice_${element_index}='${string_element}'"
    element_index=`expr "${element_index}" + 1`
  done

  return "${element_count}"
}

_startswith()
{
  param_startswith_string=$1
  param_startswith_substring=$2

  _strlen "${param_startswith_substring}"
  substring_len=$?
  compare_string=`_cut "${param_startswith_string}" -b "1-${substring_len}"`
  if [ "${compare_string}" = "${param_startswith_substring}" ]
  then
    status=0
  else
    status=1
  fi

  return $status
}

_join()
{
  param_delimiter=$1
  shift

  result=''
  while [ $# -gt 0 ]
  do
    if [ -n "$1" ]
    then
      if [ -n "${result}" ]
      then
        result="${result}${param_delimiter}"
      fi
      result="${result}$1"
    fi
    shift
  done

  _p "${result}"
}

_tmpdir()
{
  if [ -n "${TMPDIR}" ]
  then
    result="${TMPDIR}"
  else
    result='/tmp'
  fi
  _p "${result}"
}

_mktemp_dir()
{
  _mktemp_dir_template="$1"

  tmpdir=`_tmpdir`
  mktemp -d "${tmpdir}/${_mktemp_dir_template}"
}

_mktemp_file()
{
  _mktemp_file_template="$1"

  tmpdir=`_tmpdir`
  mktemp "${tmpdir}/${_mktemp_file_template}"
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

get_timestamp_timezone()
{
  date '+%Y/%m/%d %H:%M:%S(%Z)'
}

get_ISO8601UTCbs()
{
  date -u '+%Y-%m-%dT%H:%M:%S.000Z'
}

extract_filename()
{
  param_filepath=$1

  _p "${param_filepath}" | sed -e 's_.*/__'
}

debug_mode_suppress()
{
  EVACUATED_BSKYSHCLI_DEBUG="${BSKYSHCLI_DEBUG}"
  BSKYSHCLI_DEBUG=''
}

debug_mode_restore()
{
  BSKYSHCLI_DEBUG="${EVACUATED_BSKYSHCLI_DEBUG}"
}

if [ "${BSKYSHCLI_DEBUG}" = 'ON' ]
then
debug()
{
  param_id="$1"
  param_message="$2"

  timestamp=`get_timestamp`
  _pn "${timestamp} ${param_id}: ${param_message}" >> "${BSKYSHCLI_DEBUG_LOG_FILEPATH}"
}
else
debug()
{
  :
}
fi

if [ "${BSKYSHCLI_DEBUG}" = 'ON' ]
then
debug_single()
{
  param_file="$1"

  BSKYSHCLI_DEBUG_SINGLE="${BSKYSHCLI_DEBUG_DIR}/${param_file}"
}
else
debug_single()
{
  BSKYSHCLI_DEBUG_SINGLE='/dev/null'
}
fi

debug_json()
{
  param_id="$1"
  param_json="$2"

  if [ "${BSKYSHCLI_DEBUG}" = 'ON' ]
  then
    message=`_p "${param_json}" | jq`
    debug "${param_id}" "${message}"
  fi
}

error_msg()
{
  param_message="$1"
  _pn "ERROR: ${param_message}" 1>&2
}

error()
{
  param_message="$1"

  error_msg "${param_message}"
  exit 1
}

check_required_command()
{
  status=0
  while [ $# -gt 0 ]
  do
    which "$1" > /dev/null
    which_result=$?
    if [ $which_result -ne 0 ]
    then
      error_msg "required command not found: $1"
      status=1
    fi
    shift
  done
  if [ $status -ne 0 ]
  then
    error_msg 'unable to start due to above reason'
  fi

  return $status
}

set_sed_command()
{
  result_sed=1
  if [ -n "${BSKYSHCLI_GNU_SED_PATH}" ]
  then
    # specified GNU sed path
    if [ -x "${BSKYSHCLI_GNU_SED_PATH}" ]
    then
      "${BSKYSHCLI_GNU_SED_PATH}" -z 's///' < /dev/null > /dev/null 2>&1
      result_sed=$?
      if [ $result_sed -eq 0 ]
      then
        BSKYSHCLI_SED="${BSKYSHCLI_GNU_SED_PATH}"
      else
        # try to sed
        :
      fi
    else
      # try to sed
      :
    fi
  else
    # try to sed
    :
  fi
  if [ $result_sed -ne 0 ]
  then
    # sed
    which sed > /dev/null
    result_sed=$?
    if [ $result_sed -eq 0 ]
    then
      # check GNU sed -z option
      sed -z 's///' < /dev/null > /dev/null 2>&1
      result_sed=$?
      if [ $result_sed -eq 0 ]
      then
        BSKYSHCLI_SED='sed'
      else
        # try to gsed
        :
      fi
    else
      # try to gsed
      :
    fi
    # gsed
    if [ $result_sed -ne 0 ]
    then
      which gsed > /dev/null
      result_sed=$?
      if [ $result_sed -eq 0 ]
      then
        gsed -z 's///' < /dev/null > /dev/null 2>&1
        result_sed=$?
        if [ $result_sed -eq 0 ]
        then
          BSKYSHCLI_SED='gsed'
        else
          :
        fi
      else
        :
      fi
    fi
  fi

  return $result_sed
}

escape_text_json_value()
{
  param_escape_json_value=$1

  # using GNU sed -z option
  _p "${param_escape_json_value}" | "${BSKYSHCLI_SED}" -z 's/\\/\\\\/g; s/"/\\"/g; s/\(\n\)*$//g; s/\n/\\n/g'
}

decode_keyvalue_list()
{
  param_keyvalue_list="$1"
  param_decoded_prefix="$2"
  param_encoded_separator="$3"

  debug 'decode_keyvalue_list' 'START'

  evaluated_IFS=$IFS
  # CAUTION: command substitution eliminates trailing newline
  IFS=`printf '\n\t'`
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $param_keyvalue_list
  IFS=$evaluated_IFS
  while [ $# -gt 0 ]
  do
    target_LHS=`_strleft "$1" "${param_encoded_separator}"`
    target_RHS=`_strchompleft "$1" "${target_LHS}${param_encoded_separator}"`
    eval "${param_decoded_prefix}${target_LHS}='${target_RHS}'"
    shift
  done

  debug 'decode_keyvalue_list' 'END'
}

verify_numeric_range()
{
  param_error_message_name="$1"
  param_number="$2"
  param_min="$3"
  param_max="$4"

  debug 'verify_numeric_range' 'START'

  _isnumeric "${param_min}"
  is_numeric_min=$?
  _isnumeric "${param_max}"
  is_numeric_max=$?
  if [ $is_numeric_min -ne 0 ] || [ $is_numeric_max -ne 0 ]
  then
    error "internal error: specified min(${param_min}) and/or max(${param_max}) is not numeric"
  fi

  _isnumeric "${param_number}"
  is_numeric=$?
  if [ $is_numeric -ne 0 ]
  then
    error "${param_error_message_name} parameter must be numeric value: ${param_number}"
  fi
  verify_number="${param_number}"
  if [ "${verify_number}" -lt "${param_min}" ] || [ "${verify_number}" -gt "${param_max}" ]
  then
    error "${param_error_message_name} parameter must be specify from 1 to 100: ${param_number}"
  fi

  debug 'verify_numeric_range' 'END'

  return "${verify_number}"
}

verify_exclusive()
{
  param_is_mandatory="$1"
  param_error_message_name="$2"
  shift
  shift

  debug 'verify_exclusive' 'START'
  debug 'verify_exclusive' "param_is_mandatory:${param_is_mandatory}"
  debug 'verify_exclusive' "param_error_message_name:${param_error_message_name}"
  debug 'verify_exclusive' "param_targets:$*"

  specified=1
  while [ $# -gt 0 ]
  do
    target="$1"
    if [ -n "${target}" ]
    then
      if [ "${specified}" -eq 0 ]
      then
        error "these are exclusive: ${param_error_message_name}"
      fi
      specified=0
    fi
    shift
  done
  if [ "${param_is_mandatory}" -eq 0 ] && [ "${specified}" -eq 1 ]
  then
    error "must be specified one: ${param_error_message_name}"
  fi

  debug 'verify_exclusive' 'end'

  return $specified
}

get_option_type()
{
  param_option_type_target=$1

  case `_cut "${param_option_type_target}" -b 1` in
    -)
      # '-...'
      case `_cut "${param_option_type_target}" -b 2` in
        -)
          _strlen "${param_option_type_target}"
          if [ $? -eq 2 ]
          then  # '--'
            return 255
          fi
          return 2
          ;;
        *)
          # '-<any>'
          option_remain=`_strright "${param_option_type_target}" '-'`
          if _strlen "${option_remain}"
          then
            :
          else
            option_remain=`_p "${option_remain}" | sed 's/[0-9]*//g'`
            if [ -z "${option_remain}" ]
            then  # '-[0-9]+' negative number
              return 0
            fi
          fi
          return 1
          ;;
      esac
      ;;
    *)
      # '<any>'
      return 0
      ;;
  esac
}

initialize_parameters_result()
{
  param_effective_list=$1

  debug 'initialize_parameters_result' 'START'
  debug 'initialize_parameters_result' "param_effective_list:${param_effective_list}"

  for listitem in $param_effective_list
  do
    get_option_type "${listitem}"
    option_type=$?
    effective_name=`_strleft "${listitem}" ':'`
    # -O or --opt -> O or opt
    cut_start=`expr "${option_type}" + 1`
    canonical_key=`_cut "${effective_name}" -b "${cut_start}"-`
    # O or opt=value -> O or opt
    canonical_key=`_strleft "${canonical_key}" '='`
    # opt-foo -> opt_foo
    canonical_key=`_p "${canonical_key}" | sed 's/-/_/g'`

    # initialize result variables
    unset "PARSED_PARAM_KEYONLY_${canonical_key}"
    unset "PARSED_PARAM_KEYVALUE_${canonical_key}"
  done

  debug 'initialize_parameters_result' 'END'
}

parse_parameter_element()
{
  param_value_varname=$1
  param_effective_list=$2
  param_target=$3
  param_target_next=$4

  debug 'parse_parameter_element' 'START'
  debug 'parse_parameter_element' "param_value_varname:${param_value_varname}"
  debug 'parse_parameter_element' "param_effective_list:${param_effective_list}"
  debug 'parse_parameter_element' "param_target:${param_target}"
  debug 'parse_parameter_element' "param_target_next:${param_target_next}"

  target_LHS=`_strleft "${param_target}" '='`
  target_RHS=`_strright "${param_target}" '='`

  debug 'parse_parameter_element' "target_LHS:${target_LHS}"
  debug 'parse_parameter_element' "target_RHS:${target_RHS}"

  value=''
  skip_count=''
  for listitem in $param_effective_list
  do
    effective_name=`_strleft "${listitem}" ':'`
    effective_value=`_strright "${listitem}" ':'`
    if [ "${effective_name}" = "${target_LHS}" ]
    then  # target is effective option
      if [ "${effective_value}" -eq 0 ]
      then  # target is no value required
        if [ -n "${target_RHS}" ]
        then  # but value specified 'target=...'
          error "parameter must not specify a value: ${param_target}"
        else  # no value specified by 'target=...'
          # next parameter is not check and delegate to next
          skip_count=0
        fi
      else  # target is value required
        if [ -n "${target_RHS}" ]
        then  # value specified 'target=...'
          value="${target_RHS}"
          skip_count=0
        else  # value not specified by 'target=...'
          if [ -n "${param_target_next}" ]
          then  # check next parameter
            get_option_type "${param_target_next}"
            next_option_type=$?
            case $next_option_type in
              0)
                # next parameter is not option ('<any>'), maybe value
                # variable use at eval
                # shellcheck disable=SC2034
                value="${param_target_next}"
                skip_count=1
                ;;
              1|2|255)
                # next parameter is option ('-...' or '--...')  or '--'
                error "parameter must specify value: ${param_target}"
                ;;
              *)
                error 'internal error: parse_parameter_element'
                ;;
            esac
          else  # next parameter is not exist
            error "parameter must specify value: ${param_target}"
          fi
        fi
      fi
      break
    fi
  done
  if [ -z "${skip_count}" ]
  then
    error "invalid parameter: ${param_target}"
  fi

  eval "${param_value_varname}=\${value}"

  debug 'parse_parameter_element' 'END'

  return $skip_count
}

parse_parameters()
{
  effective_list=$1
  shift

  debug 'parse_parameters' 'START'
  debug 'parse_parameters' "effective_list:${effective_list}"
  debug 'parse_parameters' "parameters:$*"

  initialize_parameters_result "${effective_list}"

  count_options=0
  while [ $# -gt 0 ]
  do
    debug 'parse_parameters' "target:$1"
    get_option_type "$1"
    option_type=$?
    debug 'parse_parameters' "option_type:${option_type}"
    case $option_type in
      0)
        # maybe command or non optional value
        break
        ;;
      1|2)
        # option '-...' or '--...'
        parse_parameter_element PARSED_VALUE "${effective_list}" "$1" "$2"
        skip_count=$?
        debug 'parse_parameters' "skip_count:${skip_count}"
        if [ $skip_count -eq 255 ]
        then
          error "${PARSED_VALUE}"
        fi
        # -O or --opt -> O or opt
        cut_start=`expr "${option_type}" + 1`
        canonical_key=`_cut "$1" -b "${cut_start}"-`
        # O or opt=value -> O or opt
        canonical_key=`_strleft "${canonical_key}" '='`
        # opt-foo -> opt_foo
        canonical_key=`_p "${canonical_key}" | sed 's/-/_/g'`
        # options value requirement is checked at parse_parameter_element
        if [ -z "${PARSED_VALUE}" ]
        then  # this parameter is single option
          evaluate="PARSED_PARAM_KEYONLY_${canonical_key}='defined'"
        else  # this parameter is value specified option
          # escape ' -> '\''
          escaped_value=`_p "${PARSED_VALUE}" | sed "s/'/'\\\\\\\\''/g"`
          evaluate="PARSED_PARAM_KEYVALUE_${canonical_key}='${escaped_value}'"
        fi
        if [ $skip_count -eq 1 ]
        then  # next parameter is current parameters value (non single option)
          count_options=`expr "${count_options}" + 1`
          shift
        fi
        eval "${evaluate}"
        debug 'parse_parameters' "evaluate:${evaluate}"
        ;;
      255)
        # '--'
        count_options=`expr "${count_options}" + 1`
        shift
        break
        ;;
      *)
        error 'internal error: parse_parameters'
        ;;
    esac
    count_options=`expr "${count_options}" + 1`
    shift
  done
  return "${count_options}"
}

create_json_keyvalue()
{
  param_key=$1
  param_value=$2
  param_quote=$3

  debug 'create_json_keyvalue' 'START'
  debug 'create_json_keyvalue' "param_key:${param_key} param_value:${param_value} param_quote:${param_quote}"

  if [ -z "${param_key}" ]
  then
    error 'key must be specified'
  fi

  if [ "${param_quote:=0}" -eq 0 ]
  then
    quote='"'
  else
    quote=''
  fi

  _p "\"${param_key}\":${quote}${param_value}${quote}"

  debug 'create_json_keyvalue' 'END'
}

create_json_keyvalue_variable()
{
  param_variable=$1
  param_quote=$2

  debug 'create_json_keyvalue_variable' 'START'
  debug 'create_json_keyvalue_variable' "param_key:${param_variable} param_quote:${param_quote}"

  value=`eval _p \"\\$"${param_variable}"\"`
  value=`_p "${value}" | "${BSKYSHCLI_SED}" -z 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\n/\\\\n/g'`
  create_json_keyvalue "${param_variable}" "${value}" "${param_quote}"

  debug 'create_json_keyvalue_variable' 'END'
}

create_json_array()
{
  param_array_elements="$@"

  debug 'create_json_array' 'START'

  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $param_array_elements
  if [ $# -gt 0 ]
  then
    json_array=''
    while [ $# -gt 0 ]
    do
      element="$1"
      if [ -n "${element}" ]
      then
        if [ -n "${json_array}" ]
        then
          json_array="${json_array},"
        fi
        json_array="${json_array}${element}"
      fi
      shift
    done
    if [ -n "${json_array}" ]
    then
      _p "[${json_array}]"
    fi
  fi

  debug 'create_json_array' 'START'
}

api_core()
{
  param_api="$1"
  # various API params continue

  debug 'api_core' 'START'
  debug 'api_core' "param_api:${param_api}"

  shift
  api_core_status=0
  debug_single 'api_core-1'
  result=`/bin/sh "${BSKYSHCLI_API_PATH}/${param_api}" "$@" | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
  error_element=`_p "${result}" | jq -r '.error // empty'`
  api_error_message=`_p "${result}" | jq -r '.message // empty'`
  if [ -n "${error_element}" ]
  then
    debug 'api_core' "error_element:${error_element} / ${api_error_message}"
    case "${error_element}" in
      ExpiredToken)
        api_core_status=2
        ;;
      AuthFactorTokenRequired)
        api_core_status=3
        ;;
      *)
        #error_msg "${api_error} / ${api_error_message}"
        api_core_status=1
        ;;
    esac
  fi

  if [ -n "${result}" ]
  then
    debug_single 'api_core-2'
    _p "${result}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"
  fi

  debug 'api_core' 'END'

  return $api_core_status
}

api()
{
  # TODO: retry any time for api_core error
  param_api="$1"
  # various API params continue

  debug 'api' 'START'
  debug 'api' "param_api:${param_api}"

  if [ -n "${BSKYSHCLI_GLOBAL_OPTION_SESSION_REFRESH}" ]
  then
    # force session refresh
    api_core_status=2
  else
    result=`api_core "$@"`
    api_core_status=$?
    debug_single 'api-1'
    result=`_p "${result}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
    debug 'api' "api_core status: ${api_core_status}"
  fi
  case $api_core_status in
    0)
      debug_single 'api-2'
      _p "${result}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"
      api_status=0
      ;;
    1)
      debug_single 'api-4'
      _p "${result}" | tee "${BSKYSHCLI_DEBUG_SINGLE}"
      api_status=1
      ;;
    2)
      # session expired
      read_session_file
      api_core 'com.atproto.server.refreshSession' "${SESSION_REFRESH_JWT}" > /dev/null
      api_status=$?
      if [ "${api_status}" -eq 0 ]
      then
        # refresh runtime information
        read_session_file
        debug_single 'api-3'
        api_core "$@" | tee "${BSKYSHCLI_DEBUG_SINGLE}"
        api_status=$?
      else
        error_msg 'session expired and failed to refresh session. please login again.'
        api_status=1
      fi
      ;;
    3)
      # 2FA token required
      api_status=3
      ;;
  esac

  debug 'api' 'END'

  return "${api_status}"
}

verify_profile_name()
{
  param_profile="$1"

  debug 'verify_profile_name' 'START'
  debug 'verify_profile_name' "param_profile:${param_profile}"

  verify=`_p "${param_profile}" | sed 's/^[A-Za-z0-9][A-Za-z0-9._-]*//g'`
  if [ -n "${verify}" ]
  then
    error "invalid profile name '${param_profile}' : must be start with alphanumeric and continue alphanumeric or underscore or hyphen or period"
  fi

  debug 'verify_profile_name' 'END'
}

get_profile_run_commands_filepath()
{
  debug 'get_profile_run_commands_filepath' 'START'
  if [ -n "${BSKYSHCLI_PROFILE}" ]
  then
    profile_run_commands_filename="${BSKYSHCLI_DEFAULT_PROFILE_RUN_COMMANDS_FILENAME_PREFIX}${BSKYSHCLI_PROFILE}${BSKYSHCLI_DEFAULT_PROFILE_RUN_COMMANDS_FILENAME_SUFFIX}"
  else
    profile_run_commands_filename=''
  fi
  # overwrite with global profile option
  if [ -n "${BSKYSHCLI_GLOBAL_OPTION_PROFILE}" ]
  then
    profile_run_commands_filename="${BSKYSHCLI_DEFAULT_PROFILE_RUN_COMMANDS_FILENAME_PREFIX}${BSKYSHCLI_GLOBAL_OPTION_PROFILE}${BSKYSHCLI_DEFAULT_PROFILE_RUN_COMMANDS_FILENAME_SUFFIX}"
  fi

  profile_run_commands_filepath=''
  if [ -n "${profile_run_commands_filename}" ]
  then
    profile_run_commands_filepath="${HOME}/${profile_run_commands_filename}"
  fi

  debug 'get_profile_run_commands_filepath' "profile_run_commands_filepath:${profile_run_commands_filepath}"
  debug 'get_profile_run_commands_filepath' 'END'

  _p "${profile_run_commands_filepath}"
}

get_session_filepath()
{
  debug 'get_session_filepath' 'START'
  if [ -n "${BSKYSHCLI_PROFILE}" ]
  then
    session_filename="${BSKYSHCLI_PROFILE}${SESSION_FILENAME_SUFFIX}"
  else
    session_filename="${SESSION_FILENAME_DEFAULT_PREFIX}${SESSION_FILENAME_SUFFIX}"
  fi
  # overwrite with global profile option
  if [ -n "${BSKYSHCLI_GLOBAL_OPTION_PROFILE}" ]
  then
    session_filename="${BSKYSHCLI_GLOBAL_OPTION_PROFILE}${SESSION_FILENAME_SUFFIX}"
  fi

  session_filepath="${SESSION_DIR}/${session_filename}"

  debug 'get_session_filepath' "session_filepath:${session_filepath}"
  debug 'get_session_filepath' 'END'

  _p "${session_filepath}"
}

init_session_info()
{
  param_ops="$1"
  param_handle="$2"
  param_access_JWT="$3"
  param_refresh_JWT="$4"
  param_did="$5"

  debug 'init_session_info' 'START'

  debug 'init_session_info' "param_ops: ${param_ops}"
  debug 'init_session_info' "param_handle: ${param_handle}"
  if [ -n "${param_access_JWT}" ]
  then
    message='(specified)'
  else
    message='(empty)'
  fi
  debug 'init_session_info' "param_access_JWT: ${message}"
  if [ -n "${param_refresh_JWT}" ]
  then
    message='(specified)'
  else
    message='(empty)'
  fi
  debug 'init_session_info' "param_refresh_JWT: ${message}"
  if [ -n "${param_did}" ]
  then
    message='(specified)'
  else
    message='(empty)'
  fi
  debug 'init_session_info' "param_did: ${message}"

  timestamp=`get_timestamp_timezone`
  _pn "# session ${param_ops} at ${timestamp}"
  _pn "${SESSION_KEY_LOGIN_TIMESTAMP}='${timestamp}'"
  _pn "${SESSION_KEY_HANDLE}='${param_handle}'"
  _pn "${SESSION_KEY_DID}='${param_did}'"
  _pn "${SESSION_KEY_ACCESS_JWT}='${param_access_JWT}'"
  _pn "${SESSION_KEY_REFRESH_JWT}='${param_refresh_JWT}'"

  debug 'init_session_info' 'END'
}

create_session_file()
{
  param_handle="$1"
  param_access_JWT="$2"
  param_refresh_JWT="$3"
  param_did="$4"

  debug 'create_session_file' 'START'
  debug 'create_session_file' "param_handle:${param_handle}"
  if [ -n "${param_access_JWT}" ]
  then
    message='(specified)'
  else
    message='(empty)'
  fi
  debug 'create_session_file' "param_access_JWT: ${message}"
  if [ -n "${param_refresh_JWT}" ]
  then
    message='(specified)'
  else
    message='(empty)'
  fi
  debug 'create_session_file' "param_refresh_JWT: ${message}"
  if [ -n "${param_did}" ]
  then
    message='(specified)'
  else
    message='(empty)'
  fi
  debug 'create_session_file' "param_did: ${message}"

  session_filepath=`get_session_filepath`
  init_session_info 'create' "${param_handle}" "${param_access_JWT}" "${param_refresh_JWT}" "${param_did}" > "${session_filepath}"

  debug 'create_session_file' 'END'
}

read_session_file()
{
  debug 'read_session_file' 'START'

  session_filepath=`get_session_filepath`
  if [ -e "${session_filepath}" ]
  then
    # SC1090 disable for dynamical(variable) path source(.) using and generate on runtime
    # shellcheck source=/dev/null
    . "${session_filepath}"
    export SESSION_DID
    status=0
  else
    status=1
  fi

  debug 'read_session_file' 'END'

  return $status
}

create_session_info()
{
  param_ops="$1"
  # CAUTION: key=value pairs are separated by tab characters
  param_session_keyvalue_list="$2"

  debug 'create_session_info' 'START'

  read_session_file
  timestamp=`get_timestamp_timezone`
  _pn "# session ${param_ops} at ${timestamp}"
  _pn "${SESSION_KEY_RECORD_VERSION}='${BSKYSHCLI_CLI_VERSION}'"
  decoded_prefix='DECODED_'
  decode_keyvalue_list "${param_session_keyvalue_list}" "${decoded_prefix}" '='
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $BSKYSHCLI_SESSION_LIST
  while [ $# -gt 0 ]
  do
    session_key="$1"
    current_session_value=`eval _p \"\\$"${session_key}"\"`
    specified_session_value=`eval _p \"\\$"${decoded_prefix}${session_key}"\"`
    if [ -n "${specified_session_value}" ]
    then
      _pn "${session_key}='${specified_session_value}'"
    else
      _pn "${session_key}='${current_session_value}'"
    fi
    shift
  done

  debug 'create_session_info' 'END'
}

update_session_file()
{
  # CAUTION: key=value pairs are separated by tab characters
  param_session_keyvalue_list="$1"

  debug 'update_session_file' 'START'

  session_filepath=`get_session_filepath`
  case $BSKYSHCLI_SESSION_FILE_UPDATE in
    append)
      create_session_info 'update' "${param_session_keyvalue_list}" >> "${session_filepath}"
      ;;
    overwrite|*)
      create_session_info 'update' "${param_session_keyvalue_list}" > "${session_filepath}"
      ;;
  esac

  debug 'update_session_file' 'END'
}

delete_session_info()
{
  param_ops="$1"
  param_session_key="$2"

  debug 'delete_session_info' 'START'

  read_session_file
  timestamp=`get_timestamp_timezone`
  _pn "# session ${param_ops} at ${timestamp}"
  _pn "${SESSION_KEY_RECORD_VERSION}='${BSKYSHCLI_CLI_VERSION}'"
  # no double quote for use word splitting
  # shellcheck disable=SC2086
  set -- $BSKYSHCLI_SESSION_LIST
  while [ $# -gt 0 ]
  do
    session_key="$1"
    current_session_value=`eval _p \"\\$"${session_key}"\"`
    if [ "${session_key}" = "${param_session_key}" ]
    then
      _pn "${session_key}=''"
    else
      _pn "${session_key}='${current_session_value}'"
    fi
    shift
  done

  debug 'delete_session_info' 'END'
}

update_delete_session_file()
{
  # CAUTION: key=value pairs are separated by tab characters
  param_session_key="$1"

  debug 'update_delete_session_file' 'START'

  session_filepath=`get_session_filepath`
  case $BSKYSHCLI_SESSION_FILE_UPDATE in
    append)
      delete_session_info 'delete' "${param_session_key}" >> "${session_filepath}"
      ;;
    overwrite|*)
      delete_session_info 'delete' "${param_session_key}" > "${session_filepath}"
      ;;
  esac

  debug 'update_delete_session_file' 'END'
}

clear_session_file()
{
  debug 'clear_session_file' 'START'

  session_filepath=`get_session_filepath`
  if [ -e "${session_filepath}" ]
  then
    rm -f "${session_filepath}"
  fi

  debug 'clear_session_file' 'END'
}

is_session_exist()
{
  debug 'is_session_exist' 'START'

  session_filepath=`get_session_filepath`
  if [ -e "${session_filepath}" ]
  then
    status=0
  else
    status=1
  fi

  debug 'is_session_exist' 'END'

  return $status
}

is_stdin_exist()
{
  debug 'is_stdin_exist' 'START'

  if [ -p /dev/stdin ] || [ -f /dev/stdin ]
  then
    status=0
  else
    status=1
  fi

  debug 'is_stdin_exist' 'END'

  return $status
}

interactive_input_post_lines()
{
  param_interactive_input_post_lines_progress=$1

  debug 'interactive_input_post_lines' 'START'
  debug 'interactive_input_post_lines' "param_interactive_input_post_lines_progress:${param_interactive_input_post_lines_progress}"

  progress='Posting...'
  if [ -n "${param_interactive_input_post_lines_progress}" ]
  then
    progress="${param_interactive_input_post_lines_progress}"
  fi

  # interactive input
  _pn '[Input post text (Ctrl-D to post, Ctrl-C to interruption)]' 1>&2
  cat -
  _pn "[${progress}]" 1>&2

  debug 'interactive_input_post_lines' 'END'
}

standard_input_lines()
{
  param_standard_input_lines_text=$1
  param_standard_input_lines_text_file=$2
  param_standard_input_lines_progress=$3

  debug 'standard_input_lines' 'START'
  debug 'standard_input_lines' "param_standard_input_lines_text:${param_standard_input_lines_text}"
  debug 'standard_input_lines' "param_standard_input_lines_text_file:${param_standard_input_lines_text_file}"

  if is_stdin_exist
  then
    # standard input (pipe or redirect)
    cat -
  elif [ -z "${param_standard_input_lines_text}" ] && [ -z "${param_standard_input_lines_text_file}" ]
  then
    # interactive input
    interactive_input_post_lines "${param_standard_input_lines_progress}"
  else
    # --text or --text-file(s) parameter
    :
  fi

  debug 'standard_input_lines' 'END'
}

resolve_post_text()
{
  param_resolve_post_text=$1
  param_resolve_post_text_file=$2

  debug 'resolve_post_text' 'START'
  debug 'resolve_post_text' "param_resolve_post_text:${param_resolve_post_text}"
  debug 'resolve_post_text' "param_resolve_post_text_file:${param_resolve_post_text_file}"

  status_resolve_post_text=0
  if is_stdin_exist
  then
    # standard input (pipe or redirect)
    cat -
  elif [ -n "${param_resolve_post_text}" ]
  then
    # --text parameter
    _p "${param_resolve_post_text}"
  elif [ -n "${param_resolve_post_text_file}" ]
  then
    # --text-file parameter
    if [ -r "${param_resolve_post_text_file}" ]
    then
      cat "${param_resolve_post_text_file}"
    else
      error_msg "specified text file is not readable: ${param_resolve_post_text_file}"
      status_resolve_post_text=1
    fi
  else
    # interactive input
    interactive_input_post_lines
  fi

  debug 'resolve_post_text' 'END'

  return $status_resolve_post_text
}

inputYn()
{
  read prompt_input
  if [ -n "${prompt_input}" ]
  then
    case $prompt_input in
      Y|y|YES|yes|Yes)
        status=0
        ;;
      *)
        status=1
        ;;
    esac
  else
    status=0
  fi
  return $status
}

inputyn()
{
  param_prompt="$1"

  status=255
  while [ $status -eq 255 ]
  do
    _p "${param_prompt}"
    read prompt_input
    if [ -n "${prompt_input}" ]
    then
      case $prompt_input in
        Y|y|YES|yes|Yes)
          status=0
          ;;
        N|n|NO|no|No)
          status=1
          ;;
        *)
          ;;
      esac
    fi
  done
  return $status
}

get_did_document()
{
  param_did="$1"
  param_path="$2"

  debug 'get_did_document' 'START'
  debug 'get_did_document' "param_did:${param_did}"
  debug 'get_did_document' "param_path:${param_path}"

  debug_single 'get_did_document'
  api_result=`curl -s -X GET "https://plc.directory/${param_did}${param_path}" -H "${HEADER_ACCEPT}" -w "\n%{response_code}" -i | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
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
        debug_single 'get_did_document_redirected'
        api_result=`curl -s -X GET "${header_location}" -H "${HEADER_ACCEPT}" -w "\n%{response_code}" -i | tee "${BSKYSHCLI_DEBUG_SINGLE}"`
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

  debug 'get_did_document' 'END'
}

# ifndef BSKYSHCLI_DEFINE_UTIL
fi


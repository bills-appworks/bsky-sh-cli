#!/bin/sh -
# Bluesky in the shell
# A Bluesky CLI (Command Line Interface) implementation in shell script
# Author Bluesky:@billsbs.bills-appworks.net
# 
# Copyright (c) 2024 bills-appworks
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php
IFS='
 	'
FILE_DIR=`dirname "$0"`
FILE_DIR=`(cd "${FILE_DIR}" && pwd)`

BSKYSHCLI_INSTALLER_VERSION='0.1.0'

rcfile_name='.bsky_sh_cli_rc'

install_fail()
{
  param_reason="$1"
  error "Install failed : ${param_reason}"
}

verify_file()
{
  param_filepath="$1"

  if [ -r "${param_filepath}" ]
  then
    :
  else
    install_fail "${param_filepath} is not readable. please check file organization."
  fi
}

verify_file_organization()
{
  _p '... '
  verify_file "${FILE_DIR}/bin/bsky"
  verify_file "${FILE_DIR}/lib/bsky_core.sh"
  _pn '[OK]'
}

verify_required_tool()
{
  param_tool="$1"

  _p "${param_tool} ... "
  which "${param_tool}" > /dev/null
  tool_exist=$?
  if [ ${tool_exist} -eq 0 ]
  then
    _pn '[OK]'
  else
    _pn "[NG] Command ${param_tool} not found."
    STATUS_TOOLS=1
  fi
  return $tool_exist
}

verify_required_tools()
{
  STATUS_TOOLS=0
  verify_required_tool 'curl'
  verify_required_tool 'jq'
  # GNU sed
  _p 'GNU sed ... '
  which sed > /dev/null
  result_sed=$?
  if [ $result_sed -eq 0 ]
  then
    # check GNU sed -z option
    sed -z 's///' < /dev/null 2>&1 /dev/null
    result_sed=$?
    if [ $result_sed -eq 0 ]
    then
      _pn '[OK]'
    else
      _pn '[NG] : Command GNU sed not found (-z option is disabled).'
      STATUS_TOOLS=1
    fi
  else
    _pn '[NG] : Command "sed" not found.'
    STATUS_TOOLS=1
  fi
  # file (libmagic)
  _p 'file (libmagic) ... ' 
  which find > /dev/null
  result_find=$?
  if [ $result_find -eq 0 ]
  then
    _pn '[OK]'
  else
    _pn '[WARNING] : Command find (libmagic) not found. Images and link cards cannot be used.'
  fi

  if [ $STATUS_TOOLS -ne 0 ]
  then
    install_fail 'Lack of required tool.'
  fi
}

is_super_user()
{
  user=`whoami`
  if [ "${user}" = 'root' ]
  then
    status=0
  else
    status=1
  fi

  return $status
}

get_candidate_user_config()
{
  config=''
  case $SHELL in
    /bin/bash)
      if [ -f "${HOME}/.bashrc" ]
      then
        config="${HOME}/.bashrc"
      elif [ -f "${HOME}/.bash_profile" ]
      then
        config="${HOME}/.bash_profile"
      elif [ -f "${HOME}/.bash_login" ]
      then
        config="${HOME}/.bash_login"
      fi
      ;;
    *)
      ;;
  esac
  if [ -z "${config}" ]
  then
    config="${HOME}/.profile"
  fi
  echo "${config}"
}

is_already_set_path()
{
  param_install_dir="$1"
  detect=`echo "${PATH}" | grep -o -E '(^|\:)'"${param_install_dir}"/bin'(\:|$)'`
  if [ -n "${detect}" ]
  then
    status=0
  else
    status=1
  fi
  return $status
}

add_path_config()
{
  param_config_file="$1"
  param_install_dir="$2"
  {
    echo "# Configuration add by bsky-sh-cli (Bluesky in the shell) installer (install.sh) version ${BSKYSHCLI_INSTALLER_VERSION}"
    # '$PATH' use literally
    # shellcheck disable=SC2016
    echo 'PATH=$PATH:'"${param_install_dir}/bin"
    echo 'export PATH'
  } >> "${param_config_file}"
  return $?
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

# entry point

echo "bsky-sh-cli (Bluesky in the shell) installer version ${BSKYSHCLI_INSTALLER_VERSION}"
echo ''
echo 'If the message "(Question)? [Y/n]:" is displayed, enter "y" for yes, "n" for no, and press the enter key.'
echo 'If you press the enter key without entering anything, it is assumed that you have specified the uppercase option ("Y" (yes) in the above case).'

lib_util_path="${FILE_DIR}/lib/util.sh"
if [ -r "${lib_util_path}" ]
then
  :
else
  echo "ERROR: ${lib_util_path} is not readable. please check file organization."
  exit 1
fi
# SC1090
# shellcheck source=SCRIPTDIR/lib/util.sh
. "${lib_util_path}"

# parameter parse & check
parse_parameters '--install-dir:1 --config-path-file:1 --skip-config-path:0 --skip-rcfile-copy:0 --config-langs:1 --skip-confirm:0' "$@"

# install source files verification
_pn '>>>> Verify file part of organization'
verify_file_organization

# required tools verification
_pn '>>>> Verify required tools'
verify_required_tools

# change behavior by executor is super user or not
if is_super_user
then
  install_dir='/opt/bsky_sh_cli'
  config_path_file='/etc/profile.d/bsky_sh_cli.sh'
else
  install_dir="${HOME}/.local/bsky_sh_cli"
  config_path_file=`get_candidate_user_config`
fi
# override path by parameter
if [ -n "${PARSED_PARAM_KEYVALUE_install_dir}" ]
then
  install_dir="${PARSED_PARAM_KEYVALUE_install_dir}"
fi
if [ -n "${PARSED_PARAM_KEYVALUE_config_path_file}" ]
then
  config_path_file="${PARSED_PARAM_KEYVALUE_config_path_file}"
fi

# configure install destination directory
_pn '>>>> Configure install destination directory'
if [ -n "${PARSED_PARAM_KEYONLY_skip_confirm}" ] || [ -n "${PARSED_PARAM_KEYVALUE_install_dir}" ]
then
  _pn "Install to '${install_dir}'"
else
  _pn "Suggests '${install_dir}' as a install destination directory."
  _p 'Are you sure you want to install to this directory? [Y/n]: '
  if inputYn
  then
    _pn "Install to '${install_dir}'"
  else
    _pn 'Please specify the directory path of the path to install, and press the enter key.'
    _p 'Install directory path: '
    read install_dir
  fi
fi

# remove tail '/'
# '$' is not variable use
# shellcheck disable=SC2016
install_dir=`_p "${install_dir}" | sed -E 's_^(.+)/$_\1_'`

if [ -f "${install_dir}" ]
then
  install_fail "A file with the same name already exists in specified directory '${install_dir}'."
fi

if [ -d "${install_dir}" ]
then
  _pn "A directory with the same name already exists in specified directory '${install_dir}'."
  if [ -n "${PARSED_PARAM_KEYONLY_skip_confirm}" ]
  then
    _pn "Overwrite directory '${install_dir}'."
    overwrite_directory=0
  else
    _p 'Do you want to overwrite and continue? [Y/n]: '
    if inputYn
    then
      _pn "Overwrite directory '${install_dir}'."
      overwrite_directory=0
    else
      install_fail 'Installation canceled.'
    fi
  fi
else
  overwrite_directory=1
fi

# configure PATH environment variable
_pn '>>>> Configure PATH environment variable'
if [ -n "${PARSED_PARAM_KEYONLY_skip_config_path}" ]
then
  _pn 'Skip configure the environment variable PATH.'
  config_path=1
else
  if is_already_set_path "${install_dir}/bin"
  then
    _pn "Directory '${install_dir}/bin' is already set in the environment variable PATH. Skip configuring the environment variable PATH."
    config_path=1
  else
    if [ -n "${PARSED_PARAM_KEYONLY_skip_confirm}" ]
    then
      _pn 'Configure the environment variable PATH.'
      config_path=0
    else
      _p 'Do you want to configure the environment variable PATH? [Y/n]: '
      if inputYn
      then
        _pn 'Configure the environment variable PATH.'
        config_path=0
      else
        _pn 'Skip configure the environment variable PATH.'
        config_path=1
      fi
    fi
  fi

  if [ $config_path -eq 0 ]
  then
    if [ -n "${PARSED_PARAM_KEYONLY_skip_confirm}" ]
    then
      _pn "Configure login script_file: ${config_path_file}"
    else
      if [ -n "${PARSED_PARAM_KEYVALUE_config_path_file}" ]
      then
        _pn "Login script file path is specified: '${PARSED_PARAM_KEYVALUE_config_path_file}'"
      else
        _pn "Suggests '${config_path_file}' as a login script file in the environment variable PATH."
        _p 'Are you sure you want to crate or make changes to this file? [Y/n]: '
        if inputYn
        then
          _pn "Configure login script file: ${config_path_file}"
        else
          _pn 'Please specify the path of the file to set the environment variable PATH, and press the enter key.'
          _p 'file path: '
          read config_path_file
        fi
      fi
      _pn "NOTE: Please confirm that the login script file is read and the PATH is set when login in again."
    fi
  fi
fi

# Run Commands file copy
_pn '>>>> Configure Run Commands file'
if [ -n "${PARSED_PARAM_KEYONLY_skip_rcfile_copy}" ]
then
  _pn "Skip put the Run Commands file."
  rcfile_copy=1
else
  if [ -n "${PARSED_PARAM_KEYONLY_skip_confirm}" ]
  then
    if [ -f "${HOME}/${rcfile_name}" ]
    then
      _pn "'${HOME}/${rcfile_name}' is already exists. Skip to put the Run Commands file."
      rcfile_copy=1
    else
      _pn "Put the Run Commands file: '${HOME}/${rcfile_name}'"
      rcfile_copy=0
    fi
  else
    _p "Do you want to put the Run Commands file in '${HOME}/${rcfile_name}'? [Y/n]: "
    if inputYn
    then
      if [ -f "${HOME}/${rcfile_name}" ]
      then
        _pn "'${HOME}/${rcfile_name}' is already exists."
        _p 'Do you want to skip and continue? [Y/n]: '
        if inputYn
        then
          _pn "Skip to overwrite Run Commands file."
          rcfile_copy=1
        else
          _pn "Overwrite '${HOME}/${rcfile_name}'"
          rcfile_copy=0
        fi
      else
        _pn "Put the Run Commands file in '${HOME}/${rcfile_name}'."
        rcfile_copy=0
      fi
    else
      _pn 'Skip put the Run Commands file.'
      rcfile_copy=1
    fi
  fi
fi

# post default languages
_pn '>>>> Configure post default languages'
if [ -n "${PARSED_PARAM_KEYONLY_skip_confirm}" ]
then
  if [ $rcfile_copy -eq 0 ]
  then
    if [ -n "${PARSED_PARAM_KEYVALUE_config_langs}" ]
    then
      _pn "Configure post default languages: ${PARSED_PARAM_KEYVALUE_config_langs}"
      config_langs_value="${PARSED_PARAM_KEYVALUE_config_langs}"
      config_langs=0
    else
      _pn "Skip to configure post default languages."
      config_langs=1
    fi
  else
    _pn "Skip to configure post default languages."
    config_langs=1
  fi
else
  if [ $rcfile_copy -eq 0 ]
  then
    if [ -n "${PARSED_PARAM_KEYVALUE_config_langs}" ]
    then
      _pn "Configure post default languages: ${PARSED_PARAM_KEYVALUE_config_langs}"
      config_langs_value="${PARSED_PARAM_KEYVALUE_config_langs}"
      config_langs=0
    else
      _p "Configure post default languages? [Y/n]: "
      if inputYn
      then
        _p "Input languages (comma separated: e.g. en,ja). : "
        read config_langs_value
        _pn "Configure post default languages: ${config_langs_value}"
        config_langs=0
      else
        _pn "Skip to configure post default languages."
        config_langs=1
      fi
    fi
  else
    _pn "Skip to configure post default languages."
    config_langs=1
  fi
fi

# output configuration of install
_pn ''
_pn '[Configuration of install]'
_pn "Install directory: ${install_dir}"
_p  'Directory overwrite: '
if [ $overwrite_directory -eq 0 ]
then
  _pn 'Yes'
else
  _pn 'No'
fi
_p  'Configure the environment variable PATH: '
if [ $config_path -eq 0 ]
then
  _pn 'Yes'
  _pn "  Path of the file to set the environment variable PATH: ${config_path_file}"
  _pn '  Add following lines:'
  _pn "  # Configuration add by bsky-sh-cli (Bluesky in the shell) installer (install.sh) version ${BSKYSHCLI_INSTALLER_VERSION}"
  # '$PATH' use literally
  # shellcheck disable=SC2016
  _pn '  PATH=$PATH:'"${install_dir}/bin"
  _pn '  export PATH'
else
  _pn 'No'
fi
_p  "Put the Run Commands file in '${HOME}/${rcfile_name}: "
if [ $rcfile_copy -eq 0 ]
then
  _pn 'Yes'
else
  _pn 'No'
fi
_p "Configure post default languages: "
if [ $config_langs -eq 0 ]
then
  _pn 'Yes'
  _pn "  Add following line in '${HOME}/${rcfile_name}'"
  _pn "  # Configuration add by installer (install.sh) version ${BSKYSHCLI_INSTALLER_VERSION}"
  _pn "  BSKYSHCLI_POST_DEFAULT_LANGUAGES='${config_langs_value}'"
else
  _pn 'No'
fi

# final confirm

if [ -z "${PARSED_PARAM_KEYONLY_skip_confirm}" ]
then
  if inputyn 'Are you sure you want to install with the above configuration? [y/n]: '
  then
    :
  else
    _pn 'Installation canceled.'
    exit 1
  fi
fi

# install execution

status=0
_p "Create installation directories if necessary '${install_dir}' ... "
if mkdir -p "${install_dir}"
then
  _pn 'Complete'
else
  _pn 'Failed'
  exit 1
fi
_p "Copying files to '${install_dir}' ... "
if cp -rp "${FILE_DIR}/bin" "${FILE_DIR}/lib" "${install_dir}/"
then
  _pn 'Complete'
else
  _pn 'Failed'
  exit 1
fi
if [ $config_path -eq 0 ]
then
  _p "Add the environment variable PATH set lines in '${config_path_file}' ... "
  if add_path_config "${config_path_file}" "${install_dir}"
  then
    _pn 'Complete'
  else
    _pn 'Failed'
    exit 1
  fi
fi
if [ $rcfile_copy -eq 0 ]
then
  _p "Copying Run Commands file to '${HOME}/${rcfile_name}' ... "
  if cp "${rcfile_name}.sample" "${HOME}/${rcfile_name}"
  then
    _pn 'Complete'
  else
    _pn 'Failed'
    exit 1
  fi
fi
if [ $config_langs -eq 0 ]
then
  _p "Add post default languages in '${HOME}/${rcfile_name}' ... "
  {
    echo "# Configuration add by installer (install.sh) version ${BSKYSHCLI_INSTALLER_VERSION}"
    echo "BSKYSHCLI_POST_DEFAULT_LANGUAGES='${config_langs_value}'"
  } >> "${HOME}/${rcfile_name}"
  echo 'Complete'
fi

_pn 'Installation complete.'

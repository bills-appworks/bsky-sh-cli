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
FILE_DIR=`dirname "$0"`
FILE_DIR=`(cd "${FILE_DIR}" && pwd)`

BSKYSHCLI_INSTALLER_VERSION='0.5.0'

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

verify_specified_GNU_sed()
{
  param_specified_target="$1"
  param_specified_path="$2"

  result_verify_specified_GNU_sed=0
  if [ -n "${param_specified_path}" ]
  then
    # specified GNU sed path
    if [ -x "${param_specified_path}" ]
    then
      "${param_specified_path}" -z 's///' < /dev/null > /dev/null 2>&1
      result_specified_sed=$?
      if [ $result_specified_sed -eq 0 ]
      then
        _pn "[OK] : ${param_specified_path}"
      else
        _pn "[NG] : Specified sed(${param_specified_target}=${param_specified_path}) -z option is disabled)."
        result_verify_specified_GNU_sed=1
      fi
    else
      _pn "[NG] : Specified sed(${param_specified_target}=${param_specified_path}) is not executable)."
      result_verify_specified_GNU_sed=1
    fi
  fi

  return $result_verify_specified_GNU_sed
}

verify_required_tools()
{
  STATUS_TOOLS=0
  verify_required_tool 'curl'
  verify_required_tool 'jq'
  # GNU sed
  _p 'GNU sed ... '
  result_sed=1
  if [ -n "${PARSED_PARAM_KEYVALUE_config_gsed_path}" ]
  then
    verify_specified_GNU_sed '--config-gsed-path' "${PARSED_PARAM_KEYVALUE_config_gsed_path}"
    STATUS_TOOLS=$?
  else
    if [ -n "${BSKYSHCLI_GNU_SED_PATH}" ]
    then
      verify_specified_GNU_sed 'BSKYSHCLI_GNU_SED_PATH' "${BSKYSHCLI_GNU_SED_PATH}"
      STATUS_TOOLS=$?
    else
      which sed > /dev/null
      result_sed=$?
      if [ $result_sed -eq 0 ]
      then
        # check GNU sed -z option
        sed -z 's///' < /dev/null > /dev/null 2>&1
        result_sed=$?
        if [ $result_sed -eq 0 ]
        then
          _pn '[OK] : sed'
        else
          # try to gsed
          #_pn '[NG] : Command GNU sed not found (sed -z option is disabled).'
          #STATUS_TOOLS=1
          :
        fi
      else
        # try to gsed
        #_pn '[NG] : Command "sed" not found.'
        #STATUS_TOOLS=1
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
            _pn '[OK] : gsed'
          else
            _pn '[NG] : Command GNU sed not found (gsed -z option is disabled).'
            STATUS_TOOLS=1
          fi
        else
          _pn '[NG] : Command GNU sed not found.'
          STATUS_TOOLS=1
        fi
      fi
    fi
  fi
  # file (libmagic)
  _p 'file (libmagic) ... ' 
  which file > /dev/null
  result_file=$?
  if [ $result_file -eq 0 ]
  then
    _pn '[OK]'
  else
    _pn '[WARNING] : Command file (libmagic) not found. Images and link cards cannot be used.'
  fi
  # convert (imagemagick)
  _p '/usr/bin/convert (imagemagick) ... ' 
  which /usr/bin/convert > /dev/null
  result_convert=$?
  if [ $result_convert -eq 0 ]
  then
    _pn '[OK]'
  else
    _pn '[WARNING] : Command /usr/bin/convert (imagemagick) not found. Images and link card some functions cannot be used.'
  fi
  # ffprobe (ffmpeg)
  _p 'ffprobe (ffmpeg) ... ' 
  which ffprobe > /dev/null
  result_ffprobe=$?
  if [ $result_ffprobe -eq 0 ]
  then
    _pn '[OK]'
  else
    _pn '[WARNING] : Command ffprobe (ffmpeg) not found. Video some functions cannot be used.'
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
    /bin/zsh)
      if [ -f "${HOME}/.zshrc" ]
      then
        config="${HOME}/.zshrc"
      elif [ -f "${HOME}/.zlogin" ]
      then
        config="${HOME}/.zlogin"
      fi
      ;;
    /bin/csh|/bin/tcsh)
      if [ -f "${HOME}/.cshrc" ]
      then
        config="${HOME}/.cshrc"
      elif [ -f "${HOME}/.login" ]
      then
        config="${HOME}/.login"
      fi
      ;;
    *)
      ;;
  esac
  if [ -z "${config}" ]
  then
    case $SHELL in
      /bin/zsh)
        config="${HOME}/.zprofile"
        ;;
      /bin/csh|/bin/tcsh)
        config="${HOME}/.login"
        ;;
      *)
        config="${HOME}/.profile"
        ;;
    esac
  fi
  echo "${config}"
}

is_already_set_path()
{
  param_install_dir="$1"
  detect=`echo "${PATH}" | grep -o -E '(^|:)'"${param_install_dir}"/bin'(:|$)'`
  if [ -n "${detect}" ]
  then
    status=0
  else
    status=1
  fi
  return $status
}

add_path_config_single()
{
  param_config_file_single="$1"
  param_install_dir_single="$2"

  echo "# Configuration add by bsky-sh-cli (Bluesky in the shell) installer (install.sh) version ${BSKYSHCLI_INSTALLER_VERSION}" >> "${param_config_file_single}"
  ext_check=`echo "${param_config_file_single}" | sed -E -e 's/.+\.csh$//'`
  ext_check2=`echo "${param_config_file_single}" | sed -E -e 's/.+\.cshrc$//'`
  ext_check3=`echo "${param_config_file_single}" | sed -E -e 's/.+\.login$//'`
  if [ "${param_config_file_single}" != "${ext_check}" ] || [ "${param_config_file_single}" != "${ext_check2}" ] || [ "${param_config_file_single}" != "${ext_check3}" ]
  then  # *.csh *.cshrc *.login
    # '$path' use literally
    # shellcheck disable=SC2016
    echo 'set path = ($path '"${param_install_dir_single}/bin"')' >> "${param_config_file_single}"
    # refer to echo result
    # shellcheck disable=SC2320
    result=$?
  else  # Other
    {
      # '$PATH' use literally
      # shellcheck disable=SC2016
      echo 'PATH=$PATH:'"${param_install_dir_single}/bin"
      echo 'export PATH'
    } >> "${param_config_file_single}"
    # refer to echo result
    # shellcheck disable=SC2320
    result=$?
  fi

  return $result
}

add_path_config()
{
  param_config_file="$1"
  param_install_dir="$2"

  config_file_work="${param_config_file}"
  while [ -n "${config_file_work}" ]
  do
    extract_config_file=`echo "${config_file_work}" | sed -E -e 's/:.*//'`
    if add_path_config_single "${extract_config_file}" "${param_install_dir}"
    then
      echo "configured: ${extract_config_file}"
    else
      echo "config failed: ${extract_config_file}"
      return 1
    fi
    config_file_work=`echo "${config_file_work}" | sed -E -e "s|^${extract_config_file}:*||"`
  done
  return 0
}

add_bskyshcli_path_config_single()
{
  param_config_file_single="$1"
  param_variable_name_single="$2"
  param_variable_value_single="$3"

  echo "# Configuration add by bsky-sh-cli (Bluesky in the shell) installer (install.sh) version ${BSKYSHCLI_INSTALLER_VERSION}" >> "${param_config_file_single}"
  ext_check=`echo "${param_config_file_single}" | sed -E -e 's/.+\.csh$//'`
  ext_check2=`echo "${param_config_file_single}" | sed -E -e 's/.+\.cshrc$//'`
  ext_check3=`echo "${param_config_file_single}" | sed -E -e 's/.+\.login$//'`
  if [ "${param_config_file_single}" != "${ext_check}" ] || [ "${param_config_file_single}" != "${ext_check2}" ] || [ "${param_config_file_single}" != "${ext_check3}" ]
  then  # *.csh *.cshrc *.login
    echo "setenv ${param_variable_name_single} ${param_variable_value_single}" >> "${param_config_file_single}"
    # refer to echo result
    # shellcheck disable=SC2320
    result=$?
  else  # Other
    {
      echo "${param_variable_name_single}=${param_variable_value_single}"
      echo "export ${param_variable_name_single}"
    } >> "${param_config_file_single}"
    # refer to echo result
    # shellcheck disable=SC2320
    result=$?
  fi

  return $result
}

add_bskyshcli_path_config()
{
  param_config_file="$1"
  param_variable_name="$2"
  param_variable_value="$3"

  config_file_work="${param_config_file}"
  while [ -n "${config_file_work}" ]
  do
    extract_config_file=`echo "${config_file_work}" | sed -E -e 's/:.*//'`
    if add_bskyshcli_path_config_single "${extract_config_file}" "${param_variable_name}" "${param_variable_value}"
    then
      echo "configured: ${extract_config_file}"
    else
      echo "config failed: ${extract_config_file}"
      return 1
    fi
    config_file_work=`echo "${config_file_work}" | sed -E -e "s|^${extract_config_file}:*||"`
  done
  return 0
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
parse_parameters '--install-dir:1 --config-path-file:1 --skip-config-path:0 --skip-rcfile-copy:0 --config-langs:1 --skip-confirm:0 --config-gsed-path:1' "$@"

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
# all known login shell pattern
#  case $SHELL in
#    /bin/zsh)
#      config_path_file='/etc/zprofile'
#      ;;
#    /bin/csh|/bin/tcsh)
#      config_path_file='/etc/profile.d/bsky_sh_cli.csh'
#      ;;
#    *)
#      config_path_file='/etc/profile.d/bsky_sh_cli.sh'
#      ;;
#  esac
  config_path_file='/etc/zprofile'
  config_path_file="${config_path_file}:"'/etc/csh.cshrc'
  if [ -d /etc/profile.d ]
  then
    config_path_file="${config_path_file}:"'/etc/profile.d/bsky_sh_cli.csh'
    config_path_file="${config_path_file}:"'/etc/profile.d/bsky_sh_cli.sh'
  fi
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
  if is_already_set_path "${install_dir}"
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
        _p 'Are you sure you want to create or make changes to above file? [Y/n]: '
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

# configure BSKYSHCLI_GNU_SED_PATH environment variable
_pn '>>>> Configure BSKYSHCLI_GNU_SED_PATH environment variable'
config_gnu_sed_path_file="${config_path_file}"
if [ -n "${PARSED_PARAM_KEYONLY_skip_config_path}" ]
then
  _pn 'Skip configure the environment variable BSKYSHCLI_GNU_SED_PATH.'
  config_gnu_sed_path=1
else
  if [ -n "${PARSED_PARAM_KEYVALUE_config_gsed_path}" ]
  then
    if [ "${PARSED_PARAM_KEYVALUE_config_gsed_path}" = "${BSKYSHCLI_GNU_SED_PATH}" ]
    then
      _pn "Specified GNU sed '${PARSED_PARAM_KEYVALUE_config_gsed_path}' is already set in the environment variable BSKYSHCLI_GNU_SED_PATH. Skip configuring the environment variable BSKYSHCLI_GNU_SED_PATH."
      config_gnu_sed_path=1
    else
      if [ -n "${PARSED_PARAM_KEYONLY_skip_confirm}" ]
      then
        _pn 'Configure the environment variable BSKYSHCLI_GNU_SED_PATH.'
        config_gnu_sed_path=0
      else
        _p 'Do you want to configure the environment variable BSKYSHCLI_GNU_SED_PATH? [Y/n]: '
        if inputYn
        then
          _pn 'Configure the environment variable BSKYSHCLI_GNU_SED_PATH.'
          config_gnu_sed_path=0
        else
          _pn 'Skip configure the environment variable BSKYSHCLI_GNU_SED_PATH.'
          config_gnu_sed_path=1
        fi
      fi
    fi

    if [ $config_gnu_sed_path -eq 0 ]
    then
      if [ -n "${PARSED_PARAM_KEYONLY_skip_confirm}" ]
      then
        _pn "Configure login script_file: ${config_gnu_sed_path_file}"
      else
        if [ -n "${PARSED_PARAM_KEYVALUE_config_path_file}" ]
        then
          _pn "Login script file path is specified: '${PARSED_PARAM_KEYVALUE_config_path_file}'"
        else
          _pn "Suggests '${config_gnu_sed_path_file}' as a login script file in the environment variable BSKYSHCLI_GNU_SED_PATH."
          _p 'Are you sure you want to create or make changes to above file? [Y/n]: '
          if inputYn
          then
            _pn "Configure login script file: ${config_gnu_sed_path_file}"
          else
            _pn 'Please specify the path of the file to set the environment variable BSKYSHCLI_GNU_SED_PATH, and press the enter key.'
            _p 'file path: '
            read config_gnu_sed_path_file
          fi
        fi
        _pn "NOTE: Please confirm that the login script file is read and the BSKYSHCLI_GNU_SED_PATH is set when login in again."
      fi
    fi
  else  # PARSED_PARAM_KEYVALUE_config_gsed_path not specified
    _pn 'Skip configure the environment variable BSKYSHCLI_GNU_SED_PATH.'
    config_gnu_sed_path=1
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
if [ "${overwrite_directory}" -eq 0 ]
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
  _pn '  (Other than csh/tcsh)'
  # '$PATH' use literally
  # shellcheck disable=SC2016
  _pn '  PATH=$PATH:'"${install_dir}/bin"
  _pn '  export PATH'
  _pn '  (csh/tcsh)'
  # '$PATH' use literally
  # shellcheck disable=SC2016
  _pn '  set path = ($path '"${install_dir}/bin"')'
else
  _pn 'No'
fi
_p  'Configure the environment variable BSKYSHCLI_GNU_SED_PATH: '
if [ $config_gnu_sed_path -eq 0 ]
then
  _pn 'Yes'
  _pn "  Path of the file to set the environment variable BSKYSHCLI_GNU_SED_PATH: ${config_gnu_sed_path_file}"
  _pn '  Add following lines:'
  _pn "  # Configuration add by bsky-sh-cli (Bluesky in the shell) installer (install.sh) version ${BSKYSHCLI_INSTALLER_VERSION}"
  _pn '  (Other than csh/tcsh)'
  # '$BSKYSHCLI_GNU_SED_PATH' use literally
  # shellcheck disable=SC2016
  _pn '  BSKYSHCLI_GNU_SED_PATH='"${PARSED_PARAM_KEYVALUE_config_gsed_path}"
  _pn '  export BSKYSHCLI_GNU_SED_PATH'
  _pn '  (csh/tcsh)'
  # '$BSKYSHCLI_GNU_SED_PATH' use literally
  # shellcheck disable=SC2016
  _pn '  setenv BSKYSHCLI_GNU_SED_PATH '"${PARSED_PARAM_KEYVALUE_config_gsed_path}"
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
if [ $config_gnu_sed_path -eq 0 ]
then
  _p "Add the environment variable BSKYSHCLI_GNU_SED_PATH set lines in '${config_gnu_sed_path_file}' ... "
  if add_bskyshcli_path_config "${config_gnu_sed_path_file}" 'BSKYSHCLI_GNU_SED_PATH' "${PARSED_PARAM_KEYVALUE_config_gsed_path}"
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
  if cp "${FILE_DIR}/${rcfile_name}.sample" "${HOME}/${rcfile_name}"
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

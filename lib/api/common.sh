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

if [ -z "${BSKYSHCLI_DEFINE_API_COMMON}" ]; then  # ifndef BSKYSHCLI_DEFINE_API_COMMON
BSKYSHCLI_DEFINE_API_COMMON='defined'

BSKYSHCLI_DEFAULT_RESOURCE_CONFIG_PATH="${HOME}/.bsky_sh_cli_rc"
BSKYSHCLI_DEFAULT_TOOLS_WORK_DIR="${HOME}/.bsky_sh_cli"
BSKYSHCLI_DEFAULT_TOOLS_ROOT_DIR="${FILE_DIR}/../.."
BSKYSHCLI_DEFAULT_TOOLS_ROOT_DIR=`(cd "${BSKYSHCLI_DEFAULT_TOOLS_ROOT_DIR}" && pwd)`
BSKYSHCLI_DEFAULT_LIB_PATH="${BSKYSHCLI_DEFAULT_TOOLS_ROOT_DIR}/lib"

# read resource config
if [ -z "${BSKYSHCLI_RESOURCE_CONFIG_PATH}" ]
then
  BSKYSHCLI_RESOURCE_CONFIG_PATH="${BSKYSHCLI_DEFAULT_RESOURCE_CONFIG_PATH}"
elif [ -r "${BSKYSHCLI_RESOURCE_CONFIG_PATH}" ]
then
  :
else
  echo "specified resource config path (BSKYSHCLI_RESOURCE_CONFIG_PATH) is not readable: ${BSKYSHCLI_RESOURCE_CONFIG_PATH}"
  exit 1
fi
if [ -r "${BSKYSHCLI_RESOURCE_CONFIG_PATH}" ]
then
  # SC1090 disable for resource config file generize on runtime
  # shellcheck source=/dev/null
  . "${BSKYSHCLI_RESOURCE_CONFIG_PATH}"
fi

if [ -z "${BSKYSHCLI_TOOLS_WORK_DIR}" ]
then
  BSKYSHCLI_TOOLS_WORK_DIR="${BSKYSHCLI_DEFAULT_TOOLS_WORK_DIR}"
fi
export BSKYSHCLI_TOOLS_WORK_DIR
if [ -z "${BSKYSHCLI_TOOLS_ROOT_DIR}" ]
then
  BSKYSHCLI_TOOLS_ROOT_DIR="${BSKYSHCLI_DEFAULT_TOOLS_ROOT_DIR}"
fi
export BSKYSHCLI_TOOLS_ROOT_DIR
if [ -z "${BSKYSHCLI_LIB_PATH}" ]
then
  BSKYSHCLI_LIB_PATH="${BSKYSHCLI_DEFAULT_LIB_PATH}"
fi
export BSKYSHCLI_LIB_PATH
if [ -z "${BSKYSHCLI_API_PATH}" ]
then
  BSKYSHCLI_API_PATH="${BSKYSHCLI_LIB_PATH}/api"
fi
export BSKYSHCLI_API_PATH

UTILITY_PATH="${BSKYSHCLI_LIB_PATH}/util.sh"
if [ -r "${UTILITY_PATH}" ]
then
  # SC1090
  # shellcheck source=SCRIPTDIR/../util.sh
  . "${UTILITY_PATH}"
else
  echo "tools internal configured file util.sh is not readable: ${UTILITY_PATH}"
  exit 1
fi
PROXY_PATH="${BSKYSHCLI_API_PATH}/proxy.sh"
if [ -r "${PROXY_PATH}" ]
then
  # SC1090
  # shellcheck source=SCRIPTDIR/proxy.sh
  . "${PROXY_PATH}"
else
  echo "tools internal configured file proxy.sh is not readable: ${PROXY_PATH}"
  exit 1
fi

# ifndef BSKYSHCLI_DEFINE_API_COMMON
fi


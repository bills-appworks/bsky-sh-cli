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

BSKYSHCLI_DOWNLOAD_INSTALLER_VERSION='0.1.0'

github_latest_url='https://api.github.com/repos/bills-appworks/bsky-sh-cli/releases/latest'
github_tarball_url_prefix='https://github.com/bills-appworks/bsky-sh-cli/tarball/refs/heads'
tarball_filename='bsky-sh-cli.tar.gz'

echo "bsky-sh-cli (Bluesky in the shell) download & installer (download-install.sh) version ${BSKYSHCLI_DOWNLOAD_INSTALLER_VERSION}"

# download latest version
if github_latest=`curl -s -X GET "${github_latest_url}"`
then
  :
else
  echo "GitHub latest version query error: ${github_latest_url}"
  exit 1
fi
release_tag=`printf "%s" "${github_latest}" | jq -r '.tag_name'`
if install_temporary_path=`mktemp --tmpdir -d bsky_sh_cli.XXXXXXXXXX`
then
  :
else
  echo 'Failed to make temporary directory'
  exit 1
fi
echo "Install temporary directory: ${install_temporary_path}"
echo "Installer download source: ${github_tarball_url_prefix}/${release_tag}"
printf "%s" "Download latest version..."
if curl -s -L "${github_tarball_url_prefix}/${release_tag}" -o "${install_temporary_path}/${tarball_filename}"
then
  :
else
  echo "Failed to download latest asset: ${github_tarball_url_prefix}/${release_tag}"
  exit 1
fi
echo "Done"

# expand tarball
# tar root directory (bills-appworks-bsky-sh-cli-<commit ID>/) skip (--strip-components 1) 
printf "%s" "Expand latest version assets..."
if tar zxf "${install_temporary_path}/${tarball_filename}" --strip-components 1 -C "${install_temporary_path}"
then
  :
else
  echo "Failed to expand latest asset: ${install_temporary_path}/${tarball_filename}"
  exit 1
fi
echo "Done"

# install execution
echo ">>>>>>>> ${install_temporary_path}/install.sh START"
/bin/sh "${install_temporary_path}/install.sh" "$@"
status=$?
echo ">>>>>>>> ${install_temporary_path}/install.sh END"

# remove installer files
printf "%s" 'Remove installer files...'
if rm -rf "${install_temporary_path}"
then
  :
else
  echo "Failed to remove installer: ${install_temporary_path}"
  exit 1
fi
echo "Done"

# output result
if [ "${status}" -eq 0 ]
then
  echo 'Install complete.'
else
  echo "Failed to install. install.sh status code:${status}"
  exit 1
fi

# About installation

This document explains how to install and update after installation.

- How to install
  - [Run download installer](#run-download-installer)
  - [Run installer in release archive](#run-installer-in-release-archive)
  - [Manual installation](#manual-installation)
  - [Self hosted AT server (PDS)](#self-hosted-at-server-pds)
- How to update
  - [Execute update command](#execute-update-command)


# How To Install

## Run download installer

### Overview
By downloading and running one file in the GitHub repository, the following installation-related processes will be performed.
1. Download the latest release archive to a temporary directory
2. Extract the downloaded release archive in a temporary directory
3. Run the installer (`install.sh`) in the release archive
4. Delete temporary directory

### How to run
- Run the following command. This will save the download installer in the current directory to download and install.
```
curl https://raw.githubusercontent.com/bills-appworks/bsky-sh-cli/main/download-install.sh -O
```
- Run the download installer with the following command. If you want all users to use it, run it as super user.

For super user:
```
sudo sh download-install.sh
```
For general users:
```
sh download-install.sh
```

> [!WARNING]
> Direct execution like below is not recommended.
> ```
> curl https://raw.githubusercontent.com/bills-appworks/bsky-sh-cli/main/download-install.sh | sh
> ```
> Input waiting within the installer is disabled. As a result, the installation method cannot be selected, and the final confirmation waiting process loops endlessly, making installation impossible.
> ```
> sudo sh <(https://raw.githubusercontent.com/bills-appworks/bsky-sh-cli/main/download-install.sh)
> ```
> If you run the downloaded file as a super user using standard input, execution may fail depending on the environment for security reasons.

- When executed, the processing described in the overview above will be performed. For information on executing the installer in the release archive, please refer to [next section](#run-installer-in-release-archive). When the installation is complete, the files extracted to the temporary directory will be deleted. If you cancel it, it will remain so please delete it manually. The temporary directory can be confirmed by the "Install temporary directory:" line displayed during installation.

- If you specify an option parameter, it will be passed as is as an option parameter to the installer in the release archive.

## Run installer in release archive

### Overview
You can install this tool in your environment by running the simple installer: `install.sh` included in the latest release archive.

The following describes what to do. If it does not meet your needs, please refer to [Manual installation](#manual-installation).

If necessary, you will be asked to confirm execution or input during installation (confirmation or input may not be required depending on the [install.sh command option](#installsh-command-options) specification).

If you create or modify (add) a login script that sets the environment variable `PATH` during the installation process, the environment variable `PATH` will not be set immediately after the installation is completed. To execute the `bsky` command without specifying a path, log in to the shell again.

### How to run
- In the directory where you extracted the release archive, execute the installer with the following command. If you want all users to use it, run it as super user.

For super user:
```
sudo ./install.sh
```
For general users:
```
./install.sh
```

### What `install.sh` does
1. Check the existence of some files under the subdirectories `bin` and `lib`. It is assumed that the directory and file structure is the same as provided.
2. Check the existence of the commands required when running this tool. If it does not exist, please install the necessary tools in advance. The following commands are checked (subject to change depending on version):
   - Required
     - `curl`
     - `jq`
     - `sed` : Requires GNU sed. Check for errors when specifying the `-z` option.
   - Recommendation
     - `convert` (imagemagick): If it does not exist, display a warning that some image posting and link card functions cannot be used and continue the installation.
     - `file` (libmagic): If it does not exist, display a warning that image posting and link cards cannot be used and continue the installation.
3. Copy the subdirectories `bin` and `lib` and the files under them to the specified installation directory.
   - The copy destination installation directory is specified in [Startup options](#installsh-command-options), or if not specified, the following is suggested: If the proposal is not what you want, you can change it.
     - The installation execution user is a super user (when executed with sudo or root):
       - `/opt/bsky_sh_cli`
     - If the installation execution user is a general user:
       - `$HOME/.local/bsky_sh_cli`
4. Check the setting status of the environment variable `PATH` to the `bin` subdirectory under the installation directory, and if it is not set, we will suggest creating or modifying (adding) a login script. If the proposal is not what you want, you can change it.
   - The installation execution user is a super user (when executed with sudo or root):
     - `/etc/profile.d/bsky_sh_cli.sh`
   - If the installation execution user is a general user:
     - Files found by checking the following sequentially
       - If the execution shell is `/bin/bash`:
         1. `$HOME/.bashrc`
         2. `$HOME/.bash_profile`
         3. `$HOME/.bash_login`
       - If the execution shell is other than `/bin/bash` or the file is not found above:
         - `$HOME/.profile`
   - Add the following line (create the file if it doesn't exist):
     ````
     PATH=$PATH:<specified installation directory>/bin
     export PATH
     ````
5. Suggests the installation of a Run Commands file that provides customization settings for this tool. You can skip it if you don't need it.
   - The installation location of the Run Commands file is as follows.
     - `$HOME/.bsky_sh_cli_rc`
   - If a file with the same name already exists, you will be asked to confirm whether to skip it. Please note that if you overwrite without skipping, the existing settings will be erased.
     - If you want to keep the existing settings and check the settings file in the new version, please refer to the provided file `.bsky_sh_cli_rc.sample` without overwriting it.
6. The contents specified above will be displayed in a list and you will be asked to confirm execution. If there is no problem with the content, please continue.
7. Executes the specified processing.

### `install.sh` command options
You can change the behavior by specifying the following options when running `install.sh`.
- `--install-dir <directory path>`
  - Specify the path specified by `<directory path>` as the installation destination directory.
- `--config-path-file <login script file path>`
  - Specify the path of the login script file for setting processing regarding the environment variable `PATH`.
- `--skip-config-path`
  - Skips the login script setting process regarding the environment variable `PATH`.
  - The specification of the `--config-path-file` option is ignored.
- `--skip-rcfile-copy`
  - Skips the Run Commands file installation process.
- `--config-langs '<language code>[,...]'`
  - Specify the default language code to be set when posting (e.g. 'en' for English, 'ja' for Japanese).
  - Multiple languages can be specified separated by commas (e.g. en,ja).
  - Even if you do not set it here, you can specify it individually in the options when posting. The setting here will be the default language code if you do not specify it individually in the options when posting.
  - It will be ignored if the `--skip-config-path` option is specified or if the installation of the Run Commands file is skipped during the confirmation during installation.
- `--skip-confirm`
  - Skip various confirmations. Confirmations that are skipped and operations when skipped are as follows.
    - Confirm overwriting if a directory with the same name as the specified installation directory exists:
      - This will be an overwriting operation.
    - Confirm execution of login script creation or modification process regarding environment variable `PATH`:
      - If the subdirectory `bin` of the installation directory is already set in the environment variable `PATH`:
        - Processing will not be executed.
      - If the subdirectory `bin` of the installation directory is not set in the environment variable `PATH`:
        - When specifying the `--skip-config-path` option:
          - Processing will not be executed.
        - When `--skip-config-path` option is not specified:
          - This is an action that executes a process.
          - The target login script file is as follows.
            - When specifying the `--config-path-file` option:
              - This will be the file path specified in the `--config-path-file` option.
            - When `--config-path-file` option is not specified:
              - This will be the file suggested by the installer. For suggested files, see [What `install.sh` does](#what-installsh-does).
    - Install Run Commands file (`$HOME/.bsky_sh_cli_rc`):
      - When specifying the `--skip-rcfile-copy` option:
        - Processing will not be executed.
      - When the `--skip-rcfile-copy` option is not specified:
        - If the Run Commands file already exists, the process will not be executed. The Run Commands file will be installed if it does not exist.
    - Setting the post default language code:
      - When specifying the `--config-langs` option:
        - The configuration is executed (changes the Run Commands file) with the value specified in the `--config-langs` option (only if the Run Commands file is installed).
      - When `--config-langs` option is not specified:
        - Processing will not be executed.

## Manual installation
If this installer does not cover your preferred installation method (or you do not trust it), you can install by manually locating directories and files.

Please copy the following directories and files included in the provided files to the corresponding location.

- `bin` directory and `lib` directory
  - -> Directly under the same arbitrary directory
  - Currently, the two directories must exist under the same directory. A method of specifying the `lib` directory path with an environment variable has been implemented, but its operation has not been confirmed.
- `.bsky_sh_cli_rc.sample` file
  - -> Directly under $HOME (user home directory) as file name `.bsky_sh_cli_rc` with the extension `.sample` removed.
  - In the initial state, it is only a comment without changing any settings, so please edit it as appropriate (there is no documentation on how to set it up at the moment).
    - For post default language code settings, add the following line (or uncomment the existing commented out line and set the value).
       `BSKYSHCLI_POST_DEFAULT_LANGUAGES=<language code>[,...]`
      - For information on how to write `<language code>`, see [`install.sh` command options](#installsh-command-options), see the description of the `--config-langs` option.

To run the `bsky` command without specifying a path, edit the login script according to your environment and add the full path of the `bin` directory to the environment variable `PATH`.

## Self hosted AT server (PDS)

If you are self-hosting the AT server (PDS), you can easily point the program at your server through the 
use of an exported environment variable. 

If you are [self-hosting the AT server (PDS)](https://rafaeleyng.github.io/self-hosting-a-bluesky-pds-and-using-your-domain-as-your-handle), then add this line, replacing `sky.example.com` with the url to your AT server, to either your `.profile` or `.bashrc` as applicable:

`export BSKYSHCLI_SELFHOSTED_DOMAIN=sky.example.com`

The script will then query your AT server (PDS) instead of bsky.social.

# How To Update

## Execute update command

If it has already been installed, you can update the tool itself to the latest version using the installed bsky command (`bsky update`).

If you installed as a super user:
```
sudo -i bsky update
```
If you installed as a general user:
```
bsky update
```

See the [command line reference](https://github.com/bills-appworks/bsky-sh-cli/wiki/Command-Line-Reference#tool-update-update) for details.

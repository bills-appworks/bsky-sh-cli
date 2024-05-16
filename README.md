# Bluesky in the shell
Bluesky CLI (Command Line Interface) implementation in shell script

<img src="https://github.com/bills-appworks/bsky-sh-cli/wiki/images/README-sample.png" width="100%">

## Summary
This is a tool for using Bluesky (bsky.social/bsky.app) from the command line in a Unix-like environment shell.

The goal of this tool is to be able to run it using a shell script execution environment similar to the sh:Bourne Shell family and some dependent tools.

It is currently under development and will be enriched with functionality in the future.

## How to use
You can install (copy files, edit the login script to set the environment variable PATH) by running `install.sh` included in the provided file. When you run `install.sh`, the installation destination etc. will be confirmed. 

If you install it as a super user (sudo or root user), it will be configured for use by all users. If you install it as a general user, it will be set so that it can only be used by the user who installed it.

Execution example:
```
# Install as super user
sudo ./install.sh
```
```
# Installation as a general user
./install.sh
```

For details, please refer to [Installation document](INSTALL.md).

There is a file called `bsky` under the `bin` subdirectory of the installation destination, and this is the startup command.

Launch the bsky command from the shell by specifying the path, just like any common command or shell script.

Unless otherwise configured, it is assumed that the `bin` and `lib` directories of the provided files exist under the same directory.

Additionally, the tools listed in [Required tools](#required-tools) below must be executable.

## Tutorial
### Login (Sign in)
First, log in (sign in) to Bluesky.

```bsky login --handle <handle> --password <password>```

For `<handle>`, specify the username of the Bluesky account you are using. The at sign at the beginning of the username is not required. Login using email address is not possible at this time.

`<password>` specifies the password corresponding to the handle (user name).
If you omit `--handle` and/or `--password`, an on-screen prompt will appear allowing you to enter what you omitted.

### Timeline display
When you run the command line below, a timeline of up to 50 posts will be displayed.

```bsky timeline```

One post will be displayed in the following format.
```
[ViewIndex:<number>]
<Poster's user display name>  @<Poster's handle>  <Post date and time>
<Post content>
Reply:<Number of replies> Repost:<Number of reposts> Like:<Number of Likes>
```
The number displayed in the first `ViewIndex` is used to specify the target post as a parameter for commands that like or reply to posts.

### Post
You can post by running the command line below.

```bsky post --text '<Post content text>'```

The image can be specified as a local file using the `--image` option. Only the URL of the image will be displayed on the timeline etc.

### Reply
You can reply to the displayed post by executing the command line below.

```bsky reply --index <number> --text '<Reply content text>'```

As the value of the `--index` option, specify the ViewIndex number of the post displayed by the timeline command earlier as the reply destination.

### Other features
This tool is still under development, but several other features have been implemented.

The general command line format for this tool is as follows:

```bsky <options> <command> <parameters>```

In the tutorials so far, we have not specified `<options>`, but have specified `<command>` such as `login`/`timeline`/`post` and some `<parameters>`.

You can display help for the `<command>` list using the command line below.

```bsky help```

Help for each `<command>` can be displayed with the command line below.

```bsky <command> help```

For example, to get help for the `post` command, run it as follows:

```bsky post help```

Please also refer to the [Command Line Reference](https://github.com/bills-appworks/bsky-sh-cli/wiki/Command-Line-Reference) on [Wiki](https://github.com/bills-appworks/bsky-sh-cli/wiki).

## Summary of what you can (and cannot) do at the moment
- What you can do
  - Login/logout (creation/deletion of session information (login connection information))
    - It supports 2FA
  - Display of timeline and custom feed (feed generator)
  - Post
  - Reply to post/Reost/Quoted Repost/Like
  - Specified user profile display and feed display
- Things impossible
  - Displaying images (only display URL)
  - Hide mute and block targets
  - Execution of commands and APIs that do not require authentication when not logged in
  - Many other functions

## Profile
Multiple pieces of session information can be held at the same time. In other words, when using multiple accounts, you can connect to other accounts (login and other operations) without logging out of the currently connected account.

To specify the connection, specify the `--profile` or `-P` option in the command.

```bsky --profile <profile name> <command> <parameters>```

Session information is managed in units of `<profile name>`, so you can switch operations for multiple accounts by switching the profile specification.

## Files other than the provided file group
In addition to the provided files to be deployed, generate and use the following files. If you no longer need this tool, you can delete it.
- `$HOME/.bsky_sh_cli/` directory
  - When you run this tool, it will generate this directory and some files under it. Files such as the session information management file and debug information file (when the debug function is enabled) are stored.
- `$HOME/.bsky_sh_cli_rc` file
  - A file that describes settings to customize this tool. Not created by default. The `.bsky_sh_cli_rc.sample` file included in the provided files is a sample. If you want to customize this tool, rename this file, deploy it to your `$HOME` directory, and configure it.
- Create a file under the `/tmp/` directory
  - Use the /tmp/ directory (depend on system configuration) as a temporary file creation directory for attaching image files, etc.

## Required tools
This tool uses the following tools in addition to general Unix-like tools used in shell scripts.

We would like to thank everyone who provides and maintains the execution environment and tools.

- curl
- file (libmagic)
  - Only when using images
- jq
- sed (GNU sed)

## API wrapper script
In the `lib/api/` directory of the provided files, there are files with names starting with `app.`, `com.`, etc. This is a wrapper script that calls Bluesky and AT Protocol APIs.

By running these files, you can directly call Bluesky and AT Protocol APIs and get the response as standard output.

Execution permission is not given by default, so start it with `sh <API file name>` or give execution permission to the file.

Connection information (authentication information/session information) is saved in the same session management file as the bsky command and is automatically shared between APIs.

It is currently under development, and we will expand the compatible API in the future.

> [!NOTE]
> - The API file `com.atproto.server.createSession` saves the JWT returned after successful authentication in the session management file, and most other APIs retrieve the JWT from the session management file and use it for authentication. The session management file is `$HOME/.bsky_sh_cli/_bsky_sh_cli_session` by default, and `$HOME/.bsky_sh_cli/<profile name>_session` when a profile is specified.
> - Session will not be updated automatically. If the API execution result output is an `ExpiredToken` error, please update the session using the following method.
>   - Specify the value of `SESSION_REFRESH_JWT` in the session management file as a parameter of the API file `com.atproto.server.refreshSession` and execute.
>   - Execute any bsky command
> - There is no API file parameter that specifies the profile. Please specify it using the shell variable `BSKYSHCLI_PROFILE` during execution.
>    - ```BSKYSHCLI_PROFILE=<profile name> sh <API file name>```

## License
This software is released under the MIT license. Please refer to [LICENSE](https://github.com/bills-appworks/bsky-sh-cli/blob/main/LICENSE).

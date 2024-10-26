# v0.12.0
## Add
- Follows/followers display function (social command)
- Add to API wrapper script
  - app.bsky.graph.getFollowers
  - app.bsky.graph.getFollows
  - app.bsky.graph.getKnowFollowers
## Fix
- Other minor fixes

# v0.11.1
## Modify
- Fixed an issue where users other than root could not use tools when installing for the first time using the installer as the root user (or sudo) (reduced excessive permission restrictions)
- Improved documentation for installation and updates
- Implemented a check for required tools for the download installer
- Adjusted permissions for deploying the .bsky_sh_cli_rc file during installation
- (When running in debug mode) Reduced excessive debug information output
- (For developers) Supported ShellCheck version 0.9.0

# v0.11.0
## Add
- Display of quoted numbers
- Support display message of detached quotation
- Support thread mute hidden target
## Modify
- Improved display message for blocked accounts
## Fix
- Other minor fixes

# v0.10.0
## Add
- Display of post supplementary information of reply recipient and reposter
- download installer
## Modify
- Improved timeline and thread display
## Fix
- Other minor fixes

# v0.9.0
## Add
- Specifying individual post options in the thread posting function (delimited section option directive function in the posts command)
- Self-update function (update command)
## Fix
- Other minor fixes

# v0.8.0
## Add
- Preview function support for posting functions (posts/posts/reply/quote command) (--preview option)
- Mention support in post text [#1](https://github.com/bills-appworks/bsky-sh-cli/issues/1)
- Added output option to specify language when posting (--output-langs option)
- Supports hashtag extraction display when displaying posts
## Modify
- Improved display of posting results
## Fix
- Other minor fixes

# v0.7.0
## Add
- URL shortening support in post text
- Hashtag support in post text
## Modify
- Changed post display date and time field from createdAt to indexedAt
## Fix
- Removed JWT tokens that were output as part of the log in debug mode
- Other minor fixes

# v0.6.0
## Add
- Standard input (pipe, redirect, interactive) support (post/posts/reply/quote/size commands)
- Added JSON output option to most commands (--output-json option)
- Thread posting function (posts command) supports multiple posts in one file by specifying a separator string (--separator-prefix option)
- Single posting function (post/reply/quote commands) supports specifying a text file (--text-file option)
## Fix
- Minor fixes

# v0.5.0
## Add
- Multiple post function such as thread posting (posts command)
- Function to check number of characters in post text (size command)
- Support for via (unofficial field for posting client name)
- "app.bsky.feed.getPosts" add to API wrapper script
## Modify
- Improved execution result display for posting commands
- Minor modifies

# v0.4.0
## Add
- Specify langs (language code) when posting
- Simple installer
## Modify
- Change the debug related file output directory
- Minor modifies

# v0.3.1
## Fix
- OGP image file work directory was the current directory instead of the temporary directory

# v0.3.0
## Add
- Support for posts with link URLs
  - Link card generation in text posts containing link URLs
  - Display link card
  - Display the link URL included in the text at the end of the post (if it is shortened, display the full name)

# v0.2.0
## Add
- Image post support (command: post/reply/quote)
  - Images in post displays such as timelines are only URLs as before.
- command "file" (libmagic) add to required tools
  - Only when using images
- "com.atproto.repo.uploadBlob" add to API wrapper script
- CHANGELOG file
## Modify
- Image view index "image-" literal string move from index value to template 
## Fix
-  Minor fixes

# v0.1.0
- Initial release
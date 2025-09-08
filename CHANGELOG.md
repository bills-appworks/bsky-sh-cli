# v0.20.0
## Add
- Added support for adding, listing, and removing bookmarks (bookmark)
- Added indicators in post view to show bookmark count and whether the post is bookmarked (BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL_INDICATOR_OWN_REACTION, BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL)
## Modify
- Updated info to include bookmark-related details (info)
- Added explanation to the video upload command that animated GIFs will be converted to video (post --video)
## Fix
- Other minor fixes

# v0.19.0
## Add
- Support for canceling posts, reposts, and likes (cancel)
- Added an indicator to show whether you have reacted (repost/like) next to the count in post display (BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL_INDICATOR_OWN_REACTION, BSKYSHCLI_VIEW_TEMPLATE_POST_TAIL)
## Fix
- Other minor fixes

# v0.18.0
## Add
- Support for notifications to reposters when liking/reposting a repost (like/repost)
- Added option to suppress notifications to reposters (--notify-origin-only)
- Added repost URI/CID specification options for URI/CID specification format in like/repost commands (like/repost --via-uri/--via-cid)
## Modify
- Support for repost URI/CID output in ID output mode (--output-id)
## Fix
- Fixed JSON session information output to output feed index as string type instead of invalid numeric type when it contains hyphens in reply relationships etc. (info session --output-json)

# v0.17.0
## Add
- Supports profile-specific customization configuration files (`$HOME/.bsky_sh_cli_<profile name>_rc`)
- Supports GNU sed path specification (environment variable `BSKYSHCLI_GNU_SED_PATH`)
- Supports GNU sed path specification in the installer (`install.sh --config-gsed-path`)
- Added GNU sed path specification information to configuration information output (`info meta --path (BSKYSHCLI_GNU_SED_PATH)`)
## Fix
- Other minor fixes

# v0.16.0
## Add
- Supports text link posting (`[text](URL)`)
- Support for the link card output target specification option (--linkcard-index) in the thread posting function (posts) (command line option and delimited section option directive)
- Supports csh/tcsh login shell (installer PATH setting)
- Platform tuning (FreeBSD)
- Listed environments where work has been confirmed in README
## Modify
- Changed ImageMagick convert resize parameter from `800x512!` to `800x812` when link card OGP image size is large (changed to keep aspect ratio) (BSKYSHCLI_LINKCARD_RESIZE_CONVERT_PARAM)
- Compatible with `mktemp` command in environments where the `--tmpdir(-p)` option cannot be used
- Changed to update initial setting files for all types of login shells (bash/zsh/csh/tcsh) that have been supported during installation with administrator privileges
## Fix
- Fixed a case where the delimited section option directive for thread posts was applied to the previous section
- Other minor fixes

# v0.15.0
## Add
- Video posting function supported (post --video)
- Video support when viewing posts (only text output of related information)
- command "ffprobe" (ffmpeg) add to required tools
  - Required to set the aspect ratio when posting videos (if there is no tool, post without specifying the aspect ratio)
- Add to API wrapper script
  - app.bsky.video.getJobStatus
  - app.bsky.video.getUploadLimits
  - app.bsky.video.uploadVideo
  - com.atproto.server.describeServer
  - com.atproto.server.getServiceAuth
  - com.atproto.sync.getBlob
  - com.atproto.sync.listBlobs
## Modify
- Supports redirection in GET APIs
## Fix
- Other minor fixes

# v0.14.0
## Add
- Platform tuning
  - macOS
  - cloud shell (SAKURA internet)
  - Amazon Web Services CloudShell
## Fix
- Corrected output configuration information (info meta)
- Other minor fixes

# v0.13.0
## Add
- Support for self-hosted PDS (BSKYSHCLI_SELFHOSTED_DOMAIN) #5
- Added API wrapper script (searchPosts/listRecords)
- command "/usr/bin/convert" (imagemagick) add to required tools
  - Required for resizing link card OGP image files (no resizing without the tool)
## Modify
- Link card OGP image file size is resized if it exceeds 2MB (imagemagick convert) #5
## Fix
- Other minor fixes

# v0.12.1
## Fix
- Fixed some errors in the help

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
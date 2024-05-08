# v0.3.1
## Fix
- OGP image file work directry was the current directoy instead of the temporary directory

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
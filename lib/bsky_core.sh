#!/bin/sh
FILE_DIR=`dirname $0`
FILE_DIR=`(cd ${FILE_DIR} && pwd)`
. "${TOOLS_ROOT_DIR}/lib/util.sh"

core_create_session()
{
  HANDLE="$1"
  PASSWORD="$2"

  debug 'core_create_session' 'START'
  debug 'core_create_session' "HANDLE:${HANDLE}"
# WARNING: parameters may contain sensitive information (e.g. passwords) and will remain in the debug log
#  debug 'core_create_session' "PASSWORD:${PASSWORD}"

  `api com.atproto.server.createSession ${HANDLE} ${PASSWORD}`

  debug 'core_create_session' 'END'
}

core_get_timeline()
{
  debug 'core_get_timeline' 'START'

  debug_single 'core_get_timeline'
  RESULT=`api app.bsky.feed.getTimeline | $ESCAPE_BSKYSHCLI | tee $BSKYSHCLI_DEBUG_SINGLE`
  RETURN_CODE=$?

  if [ $RETURN_CODE -ne 0 ]
  then
    debug 'core_get_timeline' 'END'
    return $RETURN_CODE
  fi

  FEED_COUNT=`echo ${RESULT} | $ESCAPE_NEWLINE | jq '.feed | length'`
  echo "${RESULT}" | $ESCAPE_NEWLINE | jq -r 'foreach .feed[] as $feed (0; 0; 
"\($feed.post.author.displayName) @\($feed.post.author.handle) \($feed.post.record.createdAt)
\($feed.post.record.text)
Reply:\($feed.post.replyCount) Repost:\($feed.post.repostCount) Like:\($feed.post.likeCount)
")'

  debug 'core_get_timeline' 'END'
}


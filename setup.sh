#!/bin/bash

set -e
set -x

# install tmate or grab the pre-compiled linux binary from a docker image
if [[ "$(uname)" = "Darwin" ]]; then
  brew install tmate
else
  cid=$(docker create tmate/tmate)
  sudo docker cp $cid:/build/tmate /usr/local/bin/tmate
fi

# set up ssh authorized_keys if it does not exist
[[ ! -d ~/.ssh ]] && {
  mkdir ~/.ssh
  chmod 700 ~/.ssh
}
[[ ! -f ~/.ssh/authorized_keys || $TMATE_AUTHORIZED_KEYS_URL ]] && {
  curl -vLo ~/.ssh/authorized_keys "$TMATE_AUTHORIZED_KEYS_URL"
  chmod 600 ~/.ssh/authorized_keys
}

if [[ -f ~/.ssh/authorized_keys ]]; then
  tmate -a ~/.ssh/authorized_keys -S /tmp/tmate.sock new-session -d
else
  tmate -S /tmp/tmate.sock new-session -d
fi
tmate -S /tmp/tmate.sock wait tmate-ready
cd "$GITHUB_WORKSPACE" || exit
commit_msg="$(git log -1 --pretty=%B)"
# look for slack username on GH user's profile with format: [a|slack_username]
slack_user="$(curl -s "https://github.com/$GITHUB_ACTOR" | perl -ne '/\[a\|([^ \]]+)\]/ and print \1 and last')"
ssh_url="$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')"
text="<@${slack_user:-$GITHUB_ACTOR}> use `$ssh_url` to access the env for run https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID from commit:\n$commit_msg\nhttps://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$text\"}" "$SLACK_WEBHOOK_URL_FOR_TMATE_FROM_GITHUB_WORKFLOW"

sleep 14400 # 4 hours

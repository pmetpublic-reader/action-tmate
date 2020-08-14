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

# get last commit msg if it exists
if [[ -d "$GITHUB_WORKSPACE/.git" ]]; then
  cd "$GITHUB_WORKSPACE" || exit
  commit_msg="$(git log -1 --pretty=%B | LC_ALL=C tr -dc 'a-z0-9 \_\-\[\]' | head -c 50)"
  [[ -n "$commit_msg" ]] && commit_msg=":\n*$commit_msg*"
else
  commit_msg="$(
    curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA" |
    perl -ne 's/^\s*"message"\s*:\s*"(.*)"\s*$/\1/ and print and last' |
    LC_ALL=C tr -dc 'a-z0-9 \_\-\[\]' |
    head -c 50
  )"
fi

# look for slack username on GH user's profile with format: [a|slack_username]
slack_user="$(curl -s "https://github.com/$GITHUB_ACTOR" | perl -0777 -ne '/.*content="[^"]*~([^ ]+)/s and print $1 and last')"
slack_user="${slack_user%.}" # sometimes a mysterious trailing period exists in the html?
ssh_url="$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')"
text="<@${slack_user:-$GITHUB_ACTOR}> use \`$ssh_url\` to access <https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID|this run> of <https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA|this $GITHUB_REPOSITORY commit>$commit_msg"
curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$text\"}" "$SLACK_WEBHOOK_URL_FOR_TMATE_FROM_GITHUB_WORKFLOW"

sleep 7200 # 2 hours

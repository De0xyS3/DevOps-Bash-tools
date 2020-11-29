#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2020-03-27 19:16:35 +0000 (Fri, 27 Mar 2020)
#
#  https://github.com/harisekhon/bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(dirname "$0")"

# shellcheck disable=SC1090
. "$srcdir/lib/utils.sh"

# shellcheck disable=SC2034,SC2154
usage_description="
Boots a GoCD CI cluster with server and agent(s) in Docker, and builds the current repo

- boots GoCD server and agent(s) (one by default) in Docker
- loads the config repo for the current git project (setup/gocd_config_repo.json)
- authorizes the agent(s) to begin building
- opens the GoCD web UI (on Mac only)

    ${0##*/} [up]

    ${0##*/} down

    ${0##*/} ui     - prints the GoCD Server URL and on Mac automatically opens browser

Idempotent, you can re-run this and continue from any stage

See Also:

    gocd_api.sh - this script makes use of it to handle API calls as part of the setup
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[up|down|ui]"

help_usage "$@"

export GOCD_URL="http://${GOCD_HOST:-localhost}:${GOCD_PORT:-8153}"
url="$GOCD_URL/go/pipelines#!/"

export COMPOSE_FILE="$srcdir/setup/gocd-docker-compose.yml"

if [ -f setup/gocd_config_repo.json ]; then
    repo_config=setup/gocd_config_repo.json
else
    repo_config="$srcdir/setup/gocd_config_repo.json"
fi

if ! type docker-compose &>/dev/null; then
    "$srcdir/install_docker_compose.sh"
fi

action="${1:-up}"
shift || :

#git_repo="$(git remote -v | grep github.com | sed 's/.*github.com/https:\/\/github.com/; s/ .*//')"
#repo="${git_repo##*/}"

# load .gocd.yaml from this github location
# doesn't work - see https://github.com/gocd/gocd/issues/7930
# also, caused gocd-server to be recreated from different repos due to this differing environment variable each time
# which is not ideal as we want to boot GoCD from any repo and then incrementally add any builds from other repos, or load all via:
#
# git_foreach_repo.sh gocd.sh
#
#if [ -n "$git_repo" ]; then
#    export CONFIG_GIT_REPO="$git_repo"
#fi

if [ "$action" = up ]; then
    timestamp "Booting GoCD cluster:"
    # starting agents later they won't be connected in time to become authorized
    # only start the server, don't wait for the agent to download before triggering the URL to prompt user for initialization so it can progress while agent is downloading
    #docker-compose up -d teamcity-server "$@"
    docker-compose up -d "$@"
elif [ "$action" = ui ]; then
    echo "GoCD Server URL:  $GOCD_URL"
    if is_mac; then
        open "$GOCD_URL"
    fi
    exit 0
else
    docker-compose "$action" "$@"
    echo >&2
    exit 0
fi

when_url_content "$GOCD_URL" '(?i:gocd)'
echo >&2

SECONDS=0
max_secs=300
# don't use --fail here, it'll exit the loop prematurely
while curl -sS "$GOCD_URL" | grep -q 'GoCD server is starting'; do
    timestamp 'waiting for server to finish starting up and remove message "GoCD server is starting"'
    if [ $SECONDS -gt $max_secs ]; then
        die "GoCD server failed to start within $max_secs seconds"
    fi
    sleep 3
done
echo >&2

timestamp "(re)creating config repo:"
echo >&2

config_repo="$(jq -r '.id' "$repo_config")"

# XXX: these config_repo endpoints don't work unless v3 is set
timestamp "deleting config repo if already existing:"
"$srcdir/gocd_api.sh" "/admin/config_repos/$config_repo" \
     -H 'Accept:application/vnd.go.cd.v3+json' \
     -X DELETE || :
echo >&2
echo >&2

# XXX: these config_repo endpoints don't work unless v3 is set
timestamp "creating config repo:"
"$srcdir/gocd_api.sh" "/admin/config_repos" \
     -H 'Accept:application/vnd.go.cd.v3+json' \
     -X POST -d @"$repo_config"
echo >&2
echo >&2

# needs this header, otherwise gets 404
get_agents(){
    "$srcdir/gocd_api.sh" "/agents"
}
# TODO: refine this to only connected agents
get_agent_count(){
    get_agents |
    jq '._embedded.agents | length'
}

timestamp "getting list of expected agents"
expected_agents="$(docker-compose config | awk '/^[[:space:]]+gocd-agent.*:[[:space:]]*$/ {print $1}' | sed 's/://g; s/[[:space:]]//g; /^[[:space:]]*$/d')"
num_expected_agents="$(grep -c . <<< "$expected_agents" || :)"

SECONDS=0
timestamp "Waiting for $num_expected_agents expected agent(s) connect before authorizing them:"
while true; do
    num_connected_agents="$(get_agent_count)"
    #if get_agents | grep -q hostname; then
    if [ "$num_connected_agents" -ge "$num_expected_agents" ]; then
        break
    fi
    if [ $SECONDS -gt $max_secs ]; then
        timestamp "giving up waiting for connect agents after $max_secs"
        break
    fi
    timestamp "connected agents: $num_connected_agents"
    sleep 3
done
echo

echo "Enabling agent(s):"
echo
get_agents |
jq -r '._embedded.agents[] | [.hostname, .uuid] | @tsv' |
while read -r hostname uuid; do
    for expected_agent in $expected_agents; do
        # grep -f would be easier but don't want to depend on have the GNU version installed and then remapped via func
        #if [[ "$hostname" =~ ^$expected_agent(-[[:digit:]]+)?$ ]]; then
        if [[ "$hostname" =~ ^$expected_agent$ ]]; then
            timestamp "enabling expected agent '$hostname' with uuid '$uuid'"
            "$srcdir/gocd_api.sh" "/agents/$uuid" -X PATCH -d '{ "agent_config_state": "Enabled" }' || :  # don't stop, try enabling all agents
            echo
            continue 2
        fi
    done
    timestamp "WARNING: unauthorized agent '$hostname' was not expected, not automatically enabling"
done

echo
echo "GoCD Server URL:  $url"
echo
if is_mac; then
    open "$url"
fi

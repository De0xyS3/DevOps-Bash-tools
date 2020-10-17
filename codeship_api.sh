#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2020-10-13 19:49:17 +0100 (Tue, 13 Oct 2020)
#
#  https://codeship.com/harisekhon/bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(dirname "${BASH_SOURCE[0]}")"

# shellcheck disable=SC1090
. "$srcdir/lib/utils.sh"

# shellcheck disable=SC1090
. "$srcdir/lib/git.sh"

# shellcheck disable=SC2034,SC2154
usage_description="
Queries the CodeShip.com API with authentication

Required:

    \$CODESHIP_TOKEN
        or
    \$CODESHIP_USERNAME / \$CODESHIP_USER and \$CODESHIP_PASSWORD

    \$CODESHIP_ORGANIZATION_UUID

See codeship_api_token.sh for more details


Can specify \$CURL_OPTS for options to pass to curl or provide them as arguments


API Reference:

https://apidocs.codeship.com/v2


Examples:

The CodeShip API is pretty rudimentary compared to other systems APIs found in adjacent scripts

# List projects:

    ${0##*/} /organizations/{organization_uuid}/projects | jq .

# List builds for a project:

    ${0##*/} /organizations/{organization_uuid}/projects/{project_uuid}/builds

# Get pipelines for a build:

    ${0##*/} /organizations/{organization_uuid}/projects/{project_uuid}/builds/{build_uuid}/pipelines


Placeholders replaced by \$CODESHIP_ORGANIZATION_UUID:                     {organization}, {organization_uuid}, <organization>, <organization_uuid>, :organization, :organization_uuid
Placeholders replaced by \$CODESHIP_USERNAME / \$CODESHIP_USER:             :owner, :user, :username, <user>, <username>
Placeholders replaced by the local repo name of the current directory:    :repo, <repo>

"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="/path [<curl_options>]"

url_base="https://api.codeship.com/v2"

CURL_OPTS="-sS --fail --connect-timeout 3 ${CURL_OPTS:-}"

help_usage "$@"

min_args 1 "$@"

token="${CODESHIP_TOKEN:-}"
organization_uuid="${CODESHIP_ORGANIZATION_UUID:-}"

if [ -z "$token" ] || [ -z "$organization_uuid" ]; then
    output="$(GET_ORGANIZATION=1 "$srcdir/codeship_api_token.sh")"
    token="${output%%[[:space:]]*}"
    organization_uuid="${output##*[[:space:]]}"
fi

export TOKEN="$token"

url_path="${1:-}"
shift

#url_path="${url_path//https:\/\/api.codeship.com/v2}"
url_path="${url_path##$url_base}"
url_path="${url_path##/}"

# for convenience of straight copying and pasting out of documentation pages

url_path="${url_path/:organization/$organization_uuid}"
url_path="${url_path/<organization>/$organization_uuid}"
url_path="${url_path/\{organization\}/$organization_uuid}"

url_path="${url_path/:organization_uuid/$organization_uuid}"
url_path="${url_path/<organization_uuid>/$organization_uuid}"
url_path="${url_path/\{organization_uuid\}/$organization_uuid}"

url_path="${url_path/:uuid/$organization_uuid}"
url_path="${url_path/<uuid>/$organization_uuid}"
url_path="${url_path/\{uuid\}/$organization_uuid}"

repo=$(git_repo | sed 's/.*\///')

user="${CODESHIP_USERNAME:-${CODESHIP_USER:-}}"
if [ -n "$user" ]; then
    url_path="${url_path/:owner/$user}"
    url_path="${url_path/:username/$user}"
    url_path="${url_path/:user/$user}"
    url_path="${url_path/<username>/$user}"
    url_path="${url_path/<user>/$user}"
fi
if [ -n "${repo:-}" ]; then
    url_path="${url_path/:repo/$repo}"
    url_path="${url_path/<repo>/$repo}"
fi

# need CURL_OPTS splitting, safer than eval
# shellcheck disable=SC2086
"$srcdir/curl_auth.sh" "$url_base/$url_path" -H "Content-Type: application/json" -H "Accept: application/json" "$@" $CURL_OPTS

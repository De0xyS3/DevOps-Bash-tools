#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2022-10-24 15:11:14 +0100 (Mon, 24 Oct 2022)
#
#  https://github.com/HariSekhon/DevOps-Bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090,SC1091
. "$srcdir/lib/utils.sh"

# shellcheck disable=SC2034,SC2154
usage_description="
Parses Terraform Plan for aws_iam_group additions and imports each one into Terraform state

If \$TERRAFORM_PRINT_ONLY is set to any value, prints the commands to stdout to collect so you can check, collect into a text file or pipe to a shell or further manipulate, ignore errors etc.


Requires Terraform to be installed and configured
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<dir>]"

help_usage "$@"

dir="${1:-.}"

cd "$dir"

#group_arn_mapping="$(aws iam list-groups | jq -r '.Groups[] | [.GroupName, .Arn] | @tsv' | column -t)"

terraform plan -no-color |
sed -n '/# aws_iam_group\..* will be created/,/}/ p' |
awk '/# aws_iam_group/ {print $2};
     /name/ {print $4}' |
sed 's/^"//; s/"$//' |
xargs -n2 echo |
sed 's/\[/["/; s/\]/"]/' |
while read -r group name; do
    [ -n "$name" ] || continue
    timestamp "Importing group: $name"
    #arn="$(awk "/^${name}[[:space:]]/{print \$2}" <<< "$group_arn_mapping")"
    #if is_blank "$arn"; then
    #    die "Failed to determine group ARN"
    #fi
    cmd="terraform import '$group' '$name'"
    echo "$cmd"
    if [ -z "${TERRAFORM_PRINT_ONLY:-}" ]; then
        eval "$cmd"
    fi
    echo >&2
done

#!/bin/zsh
 
# Usage: ./github2bitbucket.sh githubusername [bitbucketusername]
#
# Requires: curl, resty, spidermonkey, jsawk, git

# Utility function array_contains
function array_contains # array value
{
    [[ -n "$1" && -n "$2" ]] || {
        echo "usage: array_contains <array> <value>"
        echo "Returns 0 if array contains value, 1 otherwise"
        return 2
    }

    eval 'local values=("${'$1'[@]}")'

    local element
    for element in "${values[@]}"; do
        [[ "$element" == "$2" ]] && return 0
    done
    return 1
}

# Main script
if [ "$#" -lt 1 ]; then
        echo "Usage: ./github2bitbucket.sh <github username> [ <bitbucket username> ]\n\nIf only one argument is provided, it will be used as the username\nfor both services."
        exit 0
fi

if [ "$#" -gt 1 ]; then
        github_username="$1"
        bitbucket_username="$2"
else
        github_username="$1"
        bitbucket_username="$1"
fi
echo "GitHub user: $github_username"
echo "BitBucket user: $bitbucket_username"

echo "Enter your BitBucket password for user $bitbucket_username:"
read -s bitbucket_password
# Just for testing!
# echo "$bitbucket_password"

# Existing BitBucket repos
bitbucket_repolist=("${(@f)$(curl https://api.bitbucket.org/1.0/users/NihonjinRXS | jsawk 'return this.repositories' | jsawk -n 'out(this.name)')}")

echo "Mirroring repos..."
. resty
resty https://api.github.com/users/$github_username
repolist=("${(@f)$(GET /repos | jsawk -n 'if (!this.private) out(this.name)')}")

for repo in $repolist
do
        echo "###"
        echo "Processing $repo"
        git clone --bare https://github.com/$github_username/$repo $repo
        cd $repo
        echo "Checking if repo exists in Bitbucket"
        if (!$(array_contains bitbucket_repolist $repo)); then
                echo "  Repo doesn't exist in BitBucket: Creating"
                curl --user $bitbucket_username:$bitbucket_password https://api.bitbucket.org/1.0/repositories/ --data name=$repo --data is_private=false --data owner=$bitbucket_username
        else
                echo "  Repo already exists in BitBucket"
        fi
        echo "Pushing mirror to bitbucket"
        git push --mirror https://$bitbucket_username@bitbucket.org/$bitbucket_username/$repo.git
        cd ..
        echo "Removing $repo"
        rm -rf "$repo"
        echo "Waiting 1 second"
        echo "###"
        sleep 1;
done
 
exit
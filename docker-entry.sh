#!/bin/bash

set -e

# Usage instructions
usage () {
    echo "Usage: $0 OPTION..." 
    echo "-t, --token             TOKEN           GitHub access token used for cloning and pushing"
    echo "-o, --organization      ORGANIZATION    organization name"
    echo "-r, --repository        REPOSITORY      repository"
    echo "-b, --branch            BRANCH          branch within the repository"
    echo "-c, --commit            SHA             commit to check out"
    echo "-s, --style50                           whether to use style50"
    echo "-cb, --callback-url     URL             callback URL"
    echo "-h, --help                              display help message"
    exit 1
}

# Get command-line args
while [ $# -gt 0 ]; do
    case $1 in
        -t|--token)
            shift
            TOKEN="$1"
            ;;
        -r|--repository)
            shift
            REPO="$1"
            ;;
        -b|--branch)
            shift
            BRANCH="$1"
            SLUG="$1"
            ;;
        -c|--commit)
            shift
            COMMIT="$1"
            ;;
        -s|--style50)
            STYLE=1
            ;;
        -o|--organization)
            shift
            ORG="$1"
            ;;
        -cb|--callback-url)
            shift
            CALLBACK_URL="$1"
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage
            ;;
    esac

    shift
done

# Clone repo
echo "Cloning $ORG/$REPO@$BRANCH..."
git clone --branch $BRANCH --single-branch "https://$TOKEN:x-oauth-basic@github.com/$ORG/$REPO.git"

# Checkout commit to be tested
echo "Changing directory to $REPO..."
cd $REPO

echo "Checking out $COMMIT..."
git checkout $COMMIT

# Construct tag name (note assumes system timezone is utc)
echo "Constructing tag name..."
TAG_NAME="$REPO-$BRANCH@$(date '+%Y%m%dT%H%M%S.%NZ')"
echo "Tag name is $TAG_NAME..."

# Squash commit
echo "Squashing commit..."
TAG_HASH=$(git commit-tree HEAD^{tree} -m "$TAG_NAME")
echo "Tag hash is $TAG_HASH"

# Push tag
echo "Pushing tag $TAG_NAME ($TAG_HASH)..."
git push origin $TAG_HASH:refs/tags/$TAG_NAME

# Remove remote origin
echo "Removing remote origin..."
git remote remove origin

function sandbox() {
    eval "CHECK50_PRIVATE_KEY= TOKEN= $@"
}

# Get style50 result
STYLE50_RESULT_DEFAULT="null"
STYLE50_RESULT="$STYLE50_RESULT_DEFAULT"
if [ "$STYLE" == "1" ]; then
    echo "Running style50..."
    STYLE50_RESULT=$(sandbox 'style50 --verbose --ignore \*/.\* --output=json $PWD')
    if [ $? -ne 0 ]; then
        STYLE50_RESULT="$STYLE50_RESULT_DEFAULT"
    fi

    echo "style50 result is $STYLE50_RESULT"
else
    echo "STYLE is $STYLE. Skipping style50..."
fi

# Get check50 result
CHECK50_OUT=$(mktemp)
echo -n "null" > $CHECK50_OUT

if [ -n "$SLUG" ]; then
    echo "Cloning checks at $SLUG..."
    python3 -c "import lib50, os, sys; lib50.set_local_path(os.getenv('CHECK50_PATH')); lib50.local(sys.argv[1], github_token=sys.argv[2], remove_origin=True)" "$SLUG" "$TOKEN"

    echo "Running check50..."
    sandbox "check50 --local --no-download-checks --verbose --output=json --output-file='$CHECK50_OUT' '$SLUG'" || true
else
    echo "SLUG is $SLUG. Skipping check50..."
fi

CHECK50_RESULT=$(cat $CHECK50_OUT)
echo "check50 result is $CHECK50_RESULT"

# Construct payload
PAYLOAD="{ \
    \"id\": \"$CHECK50_ID\", \
    \"org\": \"$ORG\", \
    \"repo\": \"$REPO\", \
    \"slug\": \"$BRANCH\", \
    \"commit_hash\": \"$COMMIT\", \
    \"style50\": $STYLE50_RESULT, \
    \"check50\": $CHECK50_RESULT, \
    \"tag_hash\": \"$TAG_HASH\", \
    \"pushed_at\": \"$CHECK50_PUSHED_AT\"
}"

echo "Payload is $PAYLOAD"
echo "Compacting payload..."
PAYLOAD="$(jq -c . <<<"$PAYLOAD")"
echo "Compact payload is $PAYLOAD"

echo "Signing payload..."
SIGNATURE="$(openssl dgst -sha512 -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:-2 -sign /keys/private.pem <(echo -n "$PAYLOAD") | openssl base64 -A)"

# Send payload to callback URL
echo "Sending payload to $CALLBACK_URL..."
echo -n "$PAYLOAD" | curl --fail --header "Content-Type: application/json" --header "X-Payload-Signature: $SIGNATURE" --data @- "$CALLBACK_URL"

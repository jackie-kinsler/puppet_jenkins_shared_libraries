#!/bin/sh
PE_VERSION=$1
REPO='ci-job-configs'
TEMP_BRANCH="auto/master/${PE_VERSION}-release_teardown"
rm -rf ./${REPO}
git clone git@github.com:puppetlabs/${REPO} ./${REPO}
cd ${REPO}
git checkout -b $TEMP_BRANCH

# Search through git logs for the release version
# Then we only care about the commit SHA
for i in $(git log --grep="Installer team pipelines for ${PE_VERSION}-release" --oneline --no-merges | sed "s/\([[:alpha:]]\?[[:digit:]]*\) .*/\1/")
do
    git revert $i --no-edit
done

git push origin $TEMP_BRANCH
PULL_REQUEST="$(git show -s --pretty='format:%s%n%n%b' | hub pull-request -b master -F -)"
echo "Opened PR for $(pwd): ${PULL_REQUEST}"

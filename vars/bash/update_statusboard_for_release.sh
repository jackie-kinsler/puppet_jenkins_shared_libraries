#!/bin/sh
# sed version is: gsed (GNU sed) 4.8
VIEW_URL='http://cinext-jenkinsmaster-enterprise-prod-1.delivery.puppetlabs.net:8080/view/pe-integration/view/pe'
PE_VERSION=$1
SETTINGS_FILEPATH=config/settings.rb
FAMILY=`echo $PE_VERSION | sed "s/\(.*\..*\)\..*/\1/"`
REPO='peteam-statusboard'
JOB_NAME='update_statusboard_for_release'
TEMP_BRANCH="auto/${JOB_NAME}/${PE_VERSION}-release"

rm -rf ./${REPO}
git clone git@github.com:puppetlabs/${REPO} ./${REPO}
cd ${REPO}
git pull
git checkout -b $TEMP_BRANCH


#Comment out the non-release branch and add release branch to top of array
sed -i "s/^.*$FAMILY.x/#&/" $SETTINGS_FILEPATH
sed -i "2i '$VIEW_URL-$PE_VERSION-release'," $SETTINGS_FILEPATH

## create a PR and push it
git add $SETTINGS_FILEPATH
git commit -m "${JOB_NAME} for ${PE_VERSION}-release"
git push origin $TEMP_BRANCH
PULL_REQUEST="$(git show -s --pretty='format:%s%n%n%b' | hub pull-request -b main -F -)"
echo "Opened PR for $(pwd): ${PULL_REQUEST}"

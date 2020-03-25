#!/bin/sh
PE_VERSION=$1
REPO='ci-job-configs'
FAMILY=`echo $PE_VERSION | sed "s/\(.*\..*\)\..*/\1/"`
X_FAMILY=`echo $FAMILY | sed "s/\(.*\)\..*/\1/"`
Y_FAMILY=`echo $FAMILY | sed "s/.*\.\(.*\)/\1/"`
JOB_NAME='jar_jar_release_job_creation'
YAML_FILEPATH=./jenkii/enterprise/projects/pe-installer-shim.yaml
TEMP_BRANCH="auto/${JOB_NAME}/${PE_VERSION}-release"

rm -rf ./${REPO}
git clone git@github.com:puppetlabs/${REPO} ./${REPO}
cd ${REPO}
git pull
git checkout -b $TEMP_BRANCH

echo "
        - 'pe-installer-shim':
            scm_branch: '${PE_VERSION}-release' # pe-installer-shim branch to trigger from
            promote_branch: '${PE_VERSION}-release' # enterprise-dist branch to promote into
            qualifier: '${PE_VERSION}-release'" >> $YAML_FILEPATH

## create a PR and push it
git add $YAML_FILEPATH
git commit -m "${JOB_NAME} for ${PE_VERSION}-release"
git push origin $TEMP_BRANCH
PULL_REQUEST="$(git show -s --pretty='format:%s%n%n%b' | hub pull-request -b master -F -)"
echo "Opened PR for $(pwd): ${PULL_REQUEST}"

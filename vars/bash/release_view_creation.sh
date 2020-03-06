#!/bin/sh
PE_VERSION=$1
REPO='ci-job-configs'
FAMILY=`echo $PE_VERSION | sed "s/\(.*\..*\)\..*/\1/"`
X_FAMILY=`echo $FAMILY | sed "s/\(.*\)\..*/\1/"`
Y_FAMILY=`echo $FAMILY | sed "s/.*\.\(.*\)/\1/"`
JOB_NAME='integration_release_job_creation'
YAML_FILEPATH=./jenkii/enterprise/projects/pe-integration.yaml
TEMP_BRANCH="auto/${JOB_NAME}/${PE_VERSION}-release"

rm -rf ./${REPO}
git clone git@github.com:puppetlabs/${REPO} ./${REPO}
cd ${REPO}
git pull
git checkout -b $TEMP_BRANCH

# supported_upgrade_defaults logic
# incase we are basing the release branch off of master
upgrade_default_name="p_${X_FAMILY}_${Y_FAMILY}_supported_upgrade_defaults"
grep_output=`grep ${upgrade_default_name} $YAML_FILEPATH`
FAMILY_SETTING="${X_FAMILY}_${Y_FAMILY}"
if [ -z "$grep_output" ]; then
    FAMILY_SETTING="master"
fi

echo "
- view:
    name: '${PE_VERSION}-release'
    view-type: 'list'
    regex: 'enterprise_pe-acceptance-tests_integration-system_(pe|skip_workspace|opsworks).*nightly.*${PE_VERSION}-release'
    job-filters:
        regex-job:
            regex: 'enterprise_(pe-acceptance-tests_(?:integration-system_pe_smoke|integration-system_pe_split-smoke|integration-system_pe.*(?:nightly|non-standard)|packaging_promotion|workspace-creation).*)${PE_VERSION}-release|(?!.*init-cinext.*)'
            match-type: 'includeMatched'
        job-status:
            disabled: true
            match-type: 'excludeMatched'
    columns:
        - 'status'
        - 'weather'
        - 'job'
        - 'last-success'
        - 'last-failure'
        - 'last-duration'
        - 'build-button'
" >> $YAML_FILEPATH


## create a PR and push it
git add $YAML_FILEPATH
git commit -m "${JOB_NAME} for ${PE_VERSION}-release"
git push origin $TEMP_BRANCH
PULL_REQUEST="$(git show -s --pretty='format:%s%n%n%b' | hub pull-request -b master -F -)"
echo "Opened PR for $(pwd): ${PULL_REQUEST}"

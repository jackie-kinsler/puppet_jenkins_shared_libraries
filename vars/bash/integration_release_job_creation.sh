#!/bin/sh
PE_VERSION=$1
CODENAME=$2
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

# Renames the usual p_scm_alt_code_name, which is used by pe-backup-tools, in order to avoid duplicate job declerations
`sed -i "s/p_scm_alt_code_name: '${CODENAME}'/p_scm_alt_code_name: '${CODENAME}_replacement'/" $YAML_FILEPATH`

sed -i "/${FAMILY_SETTING} integration release anchor point/a \
\        - '{value_stream}_{name}_workspace-creation_{qualifier}':\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            qualifier: '{scm_branch}'\n\
\n\
\        - 'pe-integration-smoke-upgrade-release':\n\
\            pe_family: ${FAMILY}\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            cinext_preserve_resources: 'true'\n\
\            beaker_helper: 'lib/beaker_helper.rb'\n\
\            beaker_tag: 'risk:high,risk:medium'\n\
\            upgrader_smoke_platform_axis_flatten_split:\n\
\              - centos6-64mcd-64agent%2Cpe_postgres.\n\
\            <<: *p_${FAMILY_SETTING}_supported_upgrade_defaults\n\
\n\
\        - 'pe-integration-non-standard-agents-release':\n\
\            pe_family: ${FAMILY}\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            pipeline_scm_branch: ${PE_VERSION}-release\n\
\            <<: *p_${FAMILY_SETTING}_non_standard_settings\n\
\n\
\        - 'pe-integration-full-release':\n\
\            pe_family: ${FAMILY}\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            p_scm_alt_code_name: '${CODENAME}'\n\
\            <<: *p_${FAMILY_SETTING}_settings\n\
\            p_proxy_genconfig_extra: '--pe_dir=https://artifactory.delivery.puppetlabs.net/artifactory/generic_enterprise__local/${FAMILY}/release/ci-ready/'" $YAML_FILEPATH


## create a PR and push it
git add $YAML_FILEPATH
git commit -m "${JOB_NAME} for ${PE_VERSION}-release"
git push origin $TEMP_BRANCH
PULL_REQUEST="$(git show -s --pretty='format:%s%n%n%b' | hub pull-request -b master -F -)"
echo "Opened PR for $(pwd): ${PULL_REQUEST}"

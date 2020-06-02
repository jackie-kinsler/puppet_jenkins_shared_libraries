#!/bin/sh
readonly PE_VERSION=$1
readonly CODENAME=$2
readonly FAMILY=`echo $PE_VERSION | sed "s/\(.*\..*\)\..*/\1/"`
readonly X_FAMILY=`echo $FAMILY | sed "s/\(.*\)\..*/\1/"`
readonly Y_FAMILY=`echo $FAMILY | sed "s/.*\.\(.*\)/\1/"`
readonly PE_FAMILY="${X_FAMILY}_${Y_FAMILY}"

readonly REPO='ci-job-configs'
readonly JOB_NAME='installer_team_release_creation_job'
readonly TEMP_BRANCH="auto/${JOB_NAME}/${PE_VERSION}-release"

##Modify init.yaml file for updating PE compose job
init_release_job_creation() {
  echo 'Updating init.yaml...'
  sed -i "/init release anchor point/a \
\        - pm_conditional-step:\n\
\            m_scm_branch: '${PE_VERSION}-release'\n\
\            m_name: '{name}'\n\
\            m_value_stream: '{value_stream}'\n\
\            m_projects: '{value_stream}_pe-acceptance-tests_packaging_promotion_${PE_VERSION}-release,{value_stream}_{name}_init-cinext_smoke-upgrade_${PE_VERSION}-release,{value_stream}_{name}_init-cinext_split-smoke-upgrade_${PE_VERSION}-release,{value_stream}_jar-jar_component-update_${PE_VERSION}-release'" resources/job-templates/init.yaml
  git add ./resources/job-templates/init.yaml
  git commit -m "${FUNCNAME[0]} for ${PE_VERSION}-release"
}

##Modify jar-jar.yaml file for updating PE compose job
jar_jar_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/jar-jar.yaml

  echo 'Updating jar-jar.yaml...'
  echo "
        # ---- ${PE_VERSION}-release ----
        # this is triggered by the PE compose hook and is not part of the normal pipeline
        - '{value_stream}_jar-jar_component-update_{qualifier}':
            scm_branch: '${PE_VERSION}-release'
            pe_family: '${FAMILY}'
            pgdb_user: 'jar_jar'
            pgdb_password: 'how_wude'
            tpb_projects:
                - '{value_stream}_{name}_release-clj_{scm_branch}'
            tpb_property_file: release.props
        - '{value_stream}_{name}_release-clj_{qualifier}':
            slnotifier_notify_success: True
            scm_branch: '${PE_VERSION}-release'" >> $yaml_filepath


  git add $yaml_filepath
  git commit -m "${FUNCNAME[0]} for ${PE_VERSION}-release"
}

##Create integration pe_acceptance_tests release pipeline
integration_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-integration.yaml
  local settings_default="p_${PE_FAMILY}_supported_upgrade_defaults"
  local settings_default_exists=$(grep ${settings_default} $yaml_filepath)
  local family_setting=$PE_FAMILY
  if [ -z "$settings_default_exists" ]; then
      family_setting="master"
  fi

  echo 'Updating pe-integration.yaml...'
  # Renames the usual p_scm_alt_code_name, which is used by pe-backup-tools, in order to avoid duplicate job declerations
  (sed -i "s/p_scm_alt_code_name: '${CODENAME}'/p_scm_alt_code_name: '${CODENAME}_replacement'/" $yaml_filepath)

  sed -i "/${family_setting} integration release anchor point/a \
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
\            <<: *p_${family_setting}_supported_upgrade_defaults\n\
\n\
\        - 'pe-integration-non-standard-agents-release':\n\
\            pe_family: ${FAMILY}\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            pipeline_scm_branch: ${PE_VERSION}-release\n\
\            <<: *p_${family_setting}_non_standard_settings\n\
\n\
\        - 'pe-integration-full-release':\n\
\            pe_family: ${FAMILY}\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            p_scm_alt_code_name: '${CODENAME}'\n\
\            <<: *p_${family_setting}_settings\n\
\            p_proxy_genconfig_extra: '--pe_dir=https://artifactory.delivery.puppetlabs.net/artifactory/generic_enterprise__local/${FAMILY}/release/ci-ready/'" $yaml_filepath

  git add $yaml_filepath
  git commit -m "${FUNCNAME[0]} for ${PE_VERSION}-release"
}

##Create pe-installer-vanagon release pipeline
installer_vanagon_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-installer-vanagon.yaml
  local settings_default="p_${PE_FAMILY}_installer_vanagon_settings"
  local settings_default_exists=$(grep ${settings_default} jenkii/enterprise/projects/pe-installer-vanagon.yaml)
  local family_setting=$PE_FAMILY
  if [ -z "$settings_default_exists" ]; then
      family_setting="master"
  fi

  echo 'Updating pe-installer-vanagon.yaml...'
  echo "
        - 'pe-installer-vanagon-with-pez-and-ui-acceptance':
            component_scm_branch: '${PE_VERSION}-release'
            vanagon_scm_branch: '${PE_VERSION}-release'
            promote_branch: '${PE_VERSION}-release'
            <<: *p_${family_setting}_installer_vanagon_settings" >> $yaml_filepath

  git add $yaml_filepath
  git commit -m "${FUNCNAME[0]} for ${PE_VERSION}-release"
}

##Create pe-modules-vanagon release pipeline
modules_vanagon_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-modules-vanagon.yaml
  local settings_default="p_${PE_FAMILY}_pe_modules_vanagon"
  local settings_default_exists=$(grep ${settings_default} $yaml_filepath)
  local family_setting=$PE_FAMILY
  if [ -z "$settings_default_exists" ]; then
    family_setting="master"
  fi

  echo 'Updating pe-modules-vanagon.yaml...'
  echo "
        - 'pe-modules-vanagon-suite-pipeline-daily':
            qualifier: '${PE_VERSION}-release'
            scm_branch: '${PE_VERSION}-release'
            component_scm_branch: '${PE_VERSION}-release'
            promote_branch: '${PE_VERSION}-release'
            promote_into: '${PE_VERSION}-release'
            <<: *p_${family_setting}_pe_modules_vanagon" >> $yaml_filepath

  git add $yaml_filepath
  git commit -m "${FUNCNAME[0]} for ${PE_VERSION}-release"
}

##Create pe-installer-shim release pipeline
pe_installer_shim_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-installer-shim.yaml

  echo 'Updating pe-installer-shim.yaml...'
  echo "
        - 'pe-installer-shim':
            scm_branch: '${PE_VERSION}-release' # pe-installer-shim branch to trigger from
            promote_branch: '${PE_VERSION}-release' # enterprise-dist branch to promote into
            qualifier: '${PE_VERSION}-release'" >> $yaml_filepath

  git add $yaml_filepath
  git commit -m "${FUNCNAME[0]} for ${PE_VERSION}-release"
}

##Create monorepo promotion release pipeline
monorepo_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/monorepo-promote.yaml

  echo 'Updating monorepo-promote.yaml...'
  echo "
        - 'monorepo-component-pipeline':
            unit_ruby_versions:
              - ruby-2.5.1
            p_component_branch: '${PE_VERSION}-release'
            qualifier: '${PE_VERSION}-release'
            next_branch: ''
            p_vanagon_repo_branch: '${PE_VERSION}-release'
            component_scm_branch: '${PE_VERSION}-release'
            vanagon_scm_branch: '${PE_VERSION}-release'
            promote_branch: '${PE_VERSION}-release'
            pe_promotion: 'FALSE'" >> $yaml_filepath

  git add $yaml_filepath
  git commit -m "${FUNCNAME[0]} for ${PE_VERSION}-release"
}

error_exit() {
  local msg=$1
  echo $msg
  exit 1
}

main() {
  rm -rf ./${REPO}
  git clone git@github.com:puppetlabs/${REPO} ./${REPO}
  cd ${REPO}
  git checkout -b $TEMP_BRANCH
  init_release_job_creation || error_exit 'Updating init.yaml failed'
  jar_jar_release_job_creation || error_exit 'Updating jar-jar.yaml failed'
  integration_release_job_creation || error_exit 'Updating pe-integration.yaml failed'
  installer_vanagon_release_job_creation || error_exit 'Updating pe-installer-vanagon.yaml failed'
  modules_vanagon_release_job_creation || error_exit 'Updating pe-modules-vanagon.yaml failed'
  pe_installer_shim_job_creation || error_exit 'Updating pe-installer-shim.yaml failed'
  monorepo_release_job_creation || error_exit 'Updating monorepo-promote.yaml failed'
  # push changes to upstream and create a PR
  echo 'Pushing changes to upstream...'
  git push origin $TEMP_BRANCH
  echo 'Creating PR...'
  PULL_REQUEST="$(git show -s --pretty='format:%s%n%n%b' | hub pull-request -b master -F -)"
}
main || error_exit 'Release job creation failed'
echo "Successfully Opened PR for $(pwd): ${PULL_REQUEST}"

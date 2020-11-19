#!/bin/sh
readonly PE_VERSION=$1 # Release version, e.g. 2019.8.4
readonly MAINLINE_BRANCH=$2 # The mainline pe_acceptance_tests branch (special cased to 'irving' where needed, but otherwise p_a_t branch matches component repo branches)
readonly KICKOFF_HOUR=$3 # Hour (in 24-hour notation) to kick off CI for release branch
readonly FAMILY=`echo $PE_VERSION | sed "s/\(.*\..*\)\..*/\1/"` # e.g. 2019.8
readonly X_FAMILY=`echo $FAMILY | sed "s/\(.*\)\..*/\1/"` # e.g. 2019
readonly Y_FAMILY=`echo $FAMILY | sed "s/.*\.\(.*\)/\1/"` # e.g. 8
readonly X_Y="${X_FAMILY}_${Y_FAMILY}" # e.g. 2019_8, used for settings variable names

readonly REPO='ci-job-configs'
readonly JOB_NAME='installer_team_release_creation_job'
readonly TEMP_BRANCH="auto/${JOB_NAME}/${PE_VERSION}-release"

##Modify init.yaml file for updating PE compose job
init_release_job_creation() {
  local yaml_filepath=./resources/job-templates/init.yaml

  echo 'Updating init.yaml...'
  sed -i "/init release anchor point/a \
\        # ---- ${PE_VERSION}-release ----\n\
\        - pm_conditional-step:\n\
\            m_scm_branch: '${PE_VERSION}-release'\n\
\            m_name: '{name}'\n\
\            m_value_stream: '{value_stream}'\n\
\            m_projects: '{value_stream}_pe-acceptance-tests_packaging_promotion_${PE_VERSION}-release,{value_stream}_{name}_init-cinext_smoke-upgrade_${PE_VERSION}-release,{value_stream}_{name}_init-cinext_split-smoke-upgrade_${PE_VERSION}-release,{value_stream}_jar-jar_component-update_${PE_VERSION}-release'" $yaml_filepath
  
  git add $yaml_filepath
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
}

##Create integration pe_acceptance_tests release pipeline
integration_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-integration.yaml
  local settings_default="p_${X_Y}_settings"
  local settings_default_exists=$(grep ${settings_default} $yaml_filepath)
  local family_setting=$X_Y
  # If it isn't something like 2019_8, then it should be 'main'
  if [ -z "$settings_default_exists" ]; then
      family_setting=$MAINLINE_BRANCH
  fi
  local p_scm_alt_code_name=$MAINLINE_BRANCH
  if [[ "${MAINLINE_BRANCH}" = "2018.1.x" ]]; then
      p_scm_alt_code_name='irving'
  fi

  echo 'Updating pe-integration.yaml...'
  # Renames the usual p_scm_alt_code_name, which is used by pe-backup-tools, in order to avoid duplicate job declarations
  (sed -i "s/p_scm_alt_code_name: '${p_scm_alt_code_name}'/p_scm_alt_code_name: '${p_scm_alt_code_name}_replacement'/" $yaml_filepath)

  sed -i "/${family_setting} integration release anchor point/a \
\        # ---- ${PE_VERSION}-release ----\n\
\        - '{value_stream}_{name}_workspace-creation_{qualifier}':\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            qualifier: '{scm_branch}'\n\
\n\
\        - 'pe-integration-smoke-upgrade-release':\n\
\            kickoff_disabled: False\n\
\            pe_family: ${FAMILY}\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            cinext_preserve_resources: 'true'\n\
\            beaker_helper: 'lib/beaker_helper.rb'\n\
\            beaker_tag: 'risk:high,risk:medium'\n\
\            <<: *p_upgrade_axes_${family_setting}\n\
\n\
\        - 'pe-integration-non-standard-agents-release':\n\
\            kickoff_disabled: False\n\
\            timed_trigger_cron: '00 ${KICKOFF_HOUR} * * *'\n\
\            pe_family: ${FAMILY}\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            pipeline_scm_branch: ${PE_VERSION}-release\n\
\            <<: *p_${family_setting}_non_standard_settings\n\
\n\
\        - 'pe-integration-full-release':\n\
\            kickoff_disabled: False\n\
\            timed_trigger_cron: '00 ${KICKOFF_HOUR} * * *'\n\
\            pe_family: ${FAMILY}\n\
\            scm_branch: ${PE_VERSION}-release\n\
\            p_scm_alt_code_name: '${p_scm_alt_code_name}'\n\
\            <<: *p_${family_setting}_settings\n\
\            <<: *p_upgrade_axes_${family_setting}\n\
\            p_proxy_genconfig_extra: '--pe_dir=https://artifactory.delivery.puppetlabs.net/artifactory/generic_enterprise__local/${FAMILY}/release/ci-ready/'" $yaml_filepath

  # We probably won't want to disable the 'main' CI pipeline since people will still be landing changes there,
  # but we'll want to disable the LTS mainline pipelines. However, 'main' anchor points are there in case
  # we decide differently later.
  if [[ "${MAINLINE_BRANCH}" != "main" ]]; then
    sed -i "/${family_setting} pe-integration-non-standard-agents disable anchor/{n;s/False/True/}" $yaml_filepath
    sed -i "/${family_setting} pe-integration-full disable anchor/{n;s/False/True/}" $yaml_filepath
  fi

  git add $yaml_filepath
}

##Create pe-installer-vanagon release pipeline
installer_vanagon_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-installer-vanagon.yaml
  local settings_default="p_${X_Y}_installer_vanagon_settings"
  local settings_default_exists=$(grep ${settings_default} jenkii/enterprise/projects/pe-installer-vanagon.yaml)
  local family_setting=$X_Y
  if [ -z "$settings_default_exists" ]; then
      family_setting=$MAINLINE_BRANCH
  fi

  echo 'Updating pe-installer-vanagon.yaml...'
  echo "
        # ---- ${PE_VERSION}-release ----
        - 'pe-installer-vanagon-with-pez-and-ui-acceptance':
            component_scm_branch: '${PE_VERSION}-release'
            vanagon_scm_branch: '${PE_VERSION}-release'
            promote_branch: '${PE_VERSION}-release'
            <<: *p_${family_setting}_installer_vanagon_settings" >> $yaml_filepath

  git add $yaml_filepath
}

##Create pe-modules-vanagon release pipeline
modules_vanagon_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-modules-vanagon.yaml
  local settings_default="p_${X_Y}_pe_modules_vanagon"
  local settings_default_exists=$(grep ${settings_default} $yaml_filepath)
  local family_setting=$X_Y
  if [ -z "$settings_default_exists" ]; then
    family_setting=$MAINLINE_BRANCH
  fi

  echo 'Updating pe-modules-vanagon.yaml...'
  echo "
        # ---- ${PE_VERSION}-release ----
        - 'pe-modules-vanagon-suite-pipeline-daily':
            qualifier: '${PE_VERSION}-release'
            scm_branch: '${PE_VERSION}-release'
            component_scm_branch: '${PE_VERSION}-release'
            promote_branch: '${PE_VERSION}-release'
            promote_into: '${PE_VERSION}-release'
            <<: *p_${family_setting}_pe_modules_vanagon" >> $yaml_filepath

  git add $yaml_filepath
}

##Create pe-installer-shim release pipeline
pe_installer_shim_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-installer-shim.yaml

  echo 'Updating pe-installer-shim.yaml...'
  echo "
        # ---- ${PE_VERSION}-release ----
        - 'pe-installer-shim':
            scm_branch: '${PE_VERSION}-release' # pe-installer-shim branch to trigger from
            promote_branch: '${PE_VERSION}-release' # enterprise-dist branch to promote into
            p_run_pez: False
            qualifier: '${PE_VERSION}-release'" >> $yaml_filepath

  git add $yaml_filepath
}

##Create monorepo promotion release pipeline
pe_modules_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-modules.yaml

  echo 'Updating pe-modules.yaml...'
  echo "
        # ---- ${PE_VERSION}-release ----
        - 'puppet-enterprise-modules-component-pipeline':
            p_component_branch: '${PE_VERSION}-release'
            qualifier: '${PE_VERSION}-release'
            next_branch: ''
            p_vanagon_repo_branch: '${PE_VERSION}-release'
            component_scm_branch: '${PE_VERSION}-release'
            vanagon_scm_branch: '${PE_VERSION}-release'
            promote_branch: '${PE_VERSION}-release'
            pe_promotion: 'FALSE'" >> $yaml_filepath
  # These secondary pipelines are just for 2019.8+
  # I think they're probably only for pe-admin, but not entirely sure,
  # so we'll keep promoting p-e-m into pe-installer-vanagon anyway.
  if (($X_FAMILY > 2018)); then
    echo "
        - 'puppet-enterprise-modules-secondary-component-pipeline':
            p_component_branch: '${PE_VERSION}-release'
            qualifier: '${PE_VERSION}-release_pe-installer'
            next_branch: ''
            p_components_to_prep: 'pe-installer-vanagon'
            p_vanagon_repo: 'pe-installer-vanagon'
            p_vanagon_project_name: 'pe-installer-vanagon'
            p_vanagon_repo_branch: '${PE_VERSION}-release'
            component_scm_branch: '${PE_VERSION}-release'
            vanagon_scm_branch: '${PE_VERSION}-release'
            promote_branch: '${PE_VERSION}-release'
            pe_promotion: 'FALSE'
        - 'pe-integration-module-pr':
            cinext_enabled: 'false'
            scm_branch: '${PE_VERSION}-release'
            pe_family: ${FAMILY}
            p_split_topology: 'pe-postgres'
            upgrade_from: '2019.4.0'" >> $yaml_filepath
  fi

  git add $yaml_filepath
}

pe_installer_promote_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe_installer-promote.yaml
  echo 'Updating pe_installer-promote.yaml...'
  echo "
        # ---- ${PE_VERSION}-release ----
        - 'ruby-vanagon-component-pipeline':
            p_rvm_ruby_version: 'ruby-2.5.1'
            p_component_branch: '${PE_VERSION}-release'
            component_scm_branch: '${PE_VERSION}-release'
            qualifier: '${PE_VERSION}-release'
            next_branch: ''
            p_vanagon_repo_branch: '${PE_VERSION}-release'
            vanagon_scm_branch: '${PE_VERSION}-release'
            pe_promotion: 'TRUE'" >> $yaml_filepath

  git add $yaml_filepath
}

pe_backup_tools_release_job_creation() {
  local yaml_filepath=./jenkii/enterprise/projects/pe-backup-tools.yaml
  local settings_default="p_${X_Y}_pe_backup_tools_settings"
  local settings_default_exists=$(grep ${settings_default} $yaml_filepath)
  local family_setting=$X_Y
  if [ -z "$settings_default_exists" ]; then
    family_setting=$MAINLINE_BRANCH
  fi

  echo 'Updating pe-backup-tools.yaml...'
  sed -i "/pe-backup-tools release anchor point/a \
\        # ---- ${PE_VERSION}-release ----\n\
\        - 'pe-etc-vanagon-pipeline':\n\
\            component_scm_branch: '${PE_VERSION}-release'\n\
\            vanagon_scm_branch: '${PE_VERSION}-release'\n\
\            promote_branch: '${PE_VERSION}-release'\n\
\            p_optional_path: '${FAMILY}\/'\n\
\            env_command: |\n\
\              source \/usr\/local\/rvm\/scripts\/rvm\n\
\              rvm use {rvm_ruby_version}\n\
\              export pe_ver=\\\"\$(redis-cli -h redis.delivery.puppetlabs.net get ${FAMILY}_release_pe_version)\\\"\n\
\              export PE_FAMILY=${FAMILY}\n\
\              export BUNDLE_PATH=.bundle\/gems BUNDLE_BIN=.bundle\/bin SHA=\$SUITE_COMMIT CONFIG=config\/nodes\/\$TEST_TARGET.yaml\n\
\              eval \"\$(ssh-agent -t 24h -s)\"\n\
\              ssh-add \"\${{HOME}}\/.ssh\/id_rsa\"\n\
\              ssh-add \"\${{HOME}}\/.ssh\/id_rsa-acceptance\"\n\
\            <<: *p_${family_setting}_pe_backup_tools_settings\n\
\        - 'pe-ruby-vanagon-pr':\n\
\            component_scm_branch: '${PE_VERSION}-release'\n\
\            vanagon_scm_branch: '${PE_VERSION}-release'\n\
\            env_command: |\n\
\              source \/usr\/local\/rvm\/scripts\/rvm\n\
\              rvm use {rvm_ruby_version}\n\
\              export pe_ver=\"\$(redis-cli -h redis.delivery.puppetlabs.net get ${FAMILY}_release_pe_version)\"\n\
\              export PE_FAMILY=${FAMILY}\n\
\              export BUNDLE_PATH=.bundle\/gems BUNDLE_BIN=.bundle\/bin SHA=\$SUITE_COMMIT CONFIG=config\/nodes\/\$TEST_TARGET.yaml\n\
\              eval \"\$(ssh-agent -t 24h -s)\"\n\
\              ssh-add \"\${{HOME}}\/.ssh\/id_rsa\"\n\
\              ssh-add \"\${{HOME}}\/.ssh\/id_rsa-acceptance\"\n\
\            <<: *p_${family_setting}_pe_backup_tools_settings\n" $yaml_filepath


  echo "
        # ---- ${PE_VERSION}-release ----
        - 'pe-etc-vanagon-suite-pipeline-daily':
            scm_branch: '${PE_VERSION}-release'
            pe_family: '${FAMILY}' #needed for PEZ
            promote_into: '${PE_VERSION}-release'
            p_pkg-int-sys-testing_env-command: |
              export pe_dist_dir=https://artifactory.delivery.puppetlabs.net/artifactory/generic_enterprise__local/${FAMILY}/release/ci-ready
              export PE_FAMILY=${FAMILY}
              eval \"\$(ssh-agent -t 24h -s)\"
              ssh-add \$HOME/.ssh/id_rsa
              ssh-add \$HOME/.ssh/id_rsa-acceptance
            <<: *p_${family_setting}_pe_backup_tools_vanagon_settings" >> $yaml_filepath

  git add $yaml_filepath
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
  pe_modules_release_job_creation || error_exit 'Updating pe-modules.yaml failed'
  pe_installer_promote_release_job_creation || error_exit 'Updating pe_installer-promote.yaml failed'
  pe_backup_tools_release_job_creation || error_exit 'Updating pe-backup-tools.yaml failed'

  git commit -m "Installer team pipelines for ${PE_VERSION}-release"
  # push changes to upstream and create a PR
  echo 'Pushing changes to upstream...'
  git push origin $TEMP_BRANCH
  echo 'Creating PR...'
  PULL_REQUEST="$(git show -s --pretty='format:%s%n%n%b' | hub pull-request -b master -F -)"
}
main || error_exit 'Release job creation failed'
echo "Successfully Opened PR for $(pwd): ${PULL_REQUEST}"

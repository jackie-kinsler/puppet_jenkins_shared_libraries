#!/bin/sh

# Moves PE integration pipeline kickoff time. If HOUR == -1, disables the pipeline instead.
readonly BRANCH=$1
readonly HOUR=$2
readonly CJC_BRANCH="master"
readonly TEMP_BRANCH="auto/${CJC_BRANCH}/change_PE_CI_time_${BRANCH}"

# Find CI status of the merge PR
# If hub ci-status returns 2 (status: pending), wait  for another 10 seconds
# Returns 0 on success
function is_ci_status_success() {
  ci_branch=$1
  # seconds between ci-status checks
  check_interval=30
  # seconds to wait before giving up
  maximum_wait=1800
  waited=0

  SHA=`git rev-parse $ci_branch`
  if [ "${?}" -eq "0" ]; then
    echo "${ci_branch} HEAD is at ${SHA}"
    hub ci-status "${SHA}"
    RET=$?
    while [[ $waited -le $maximum_wait ]] && [[ $RET -ne 0 ]] && [[ $RET -ne 1 ]]; do
      echo "hub ci-status returned ${RET}."
      echo "Waiting ${check_interval} for a conclusive 0 or 1 status."
      sleep $check_interval
      waited=$((waited + check_interval))
      hub ci-status "${SHA}"
      RET=$?
    done
  else
    echo "failed to get the HEAD of branch ${ci_branch}"
    RET=1
  fi
  return ${RET}
}


# Validate input
if (( $HOUR > 23 || $HOUR < -1 )); then
  echo "Hour must be between 0 and 23."
  exit 1
fi

rm -rf ./ci-job-configs
git clone git@github.com:puppetlabs/ci-job-configs ./ci-job-configs
cd ci-job-configs
readonly yaml_filepath=./jenkii/enterprise/projects/pe-integration.yaml
git checkout -b "${TEMP_BRANCH}" origin/${CJC_BRANCH}
if (( $HOUR == -1 )); then
  sed -i "/${BRANCH} pe-integration-non-standard-agents disable anchor/{n;s/False/True/}" $yaml_filepath
  sed -i "/${BRANCH} pe-integration-full disable anchor/{n;s/False/True/}" $yaml_filepath
  commit_message="Disable ${BRANCH} CI pipeline"
else
  sed -i "/${BRANCH} pe-integration-non-standard-agents disable anchor/{n;s/True/False/}" $yaml_filepath
  sed -i "/${BRANCH} pe-integration-full disable anchor/{n;s/True/False/}" $yaml_filepath
  sed -i "/${BRANCH} pe-integration-non-standard-agents timed_trigger_cron anchor/{n;s/timed_trigger_cron: '.*'/timed_trigger_cron: '00 ${HOUR} * * *'/}" $yaml_filepath
  sed -i "/${BRANCH} pe-integration-full timed_trigger_cron anchor/{n;s/timed_trigger_cron: '.*'/timed_trigger_cron: '00 ${HOUR} * * *'/}" $yaml_filepath
  commit_message="Change ${BRANCH} CI pipeline kickoff to ${HOUR}:00"
fi
git add $yaml_filepath
uncommitted=$(git status --porcelain=v1 --untracked-files=no 2>/dev/null | wc -l)
if [[ "${uncommitted}" == "0" ]]; then
  echo "No changes to ${yaml_filepath} detected. Check that ${BRANCH} is the correct branch and that the timed_trigger_cron anchor for this branch exists. If so, you may be trying to set the time to the value it is already set to."
  exit 1
fi
git commit -m "${commit_message}"
echo "Pushing ${TEMP_BRANCH}..."
git push -f origin "${TEMP_BRANCH}"
echo "Creating PR..."
PULL_REQUEST="$(git show -s --pretty='%s' | hub pull-request -b ${CJC_BRANCH} -h ${TEMP_BRANCH} -F -)"
PR_NUM="$(hub pr list -h ${TEMP_BRANCH} -f '%I')"
echo "Opened PR: ${PULL_REQUEST}"
is_ci_status_success ${TEMP_BRANCH}
CI_STATUS=$?
if [[ "${CI_STATUS}" -eq "0" ]]; then
  echo "PR CI status is green. Merging PR. You can probably ignore the error that shows up just after this message."
  hub api -XPUT "repos/puppetlabs/ci-job-configs/pulls/${PR_NUM}/merge"
  MERGE_STATUS=$?
  # At the moment, hub sometimes thinks the merge failed (exit code 22) due to needing a review on the PR,
  # but it actually merges it just fine, so we'll check that there are no open PRs after the merge.
  if [[ "${MERGE_STATUS}" -eq "0" ]] || [[ "${MERGE_STATUS}" -eq "22" ]] ; then
    pr="$(hub pr list -h ${TEMP_BRANCH} -f '%I')"
    echo ""
    if [[ -z "${pr}" ]]; then
      echo "PR merge successful. Deleting ${TEMP_BRANCH}."
      # There's a weird timing issue here, I think. But if the remote doesn't
      # have the branch (maybe it gets auto-deleted on merge?), then don't try
      # to delete it ourselves.
      sleep 5
      git fetch origin
      git show-branch "origin/${TEMP_BRANCH}" 2>/dev/null
      if [[ "${?}" -eq "0" ]]; then
        git push origin --delete "${TEMP_BRANCH}"
        if [[ "${?}" -ne "0" ]]; then
          echo "Failed to delete ${TEMP_BRANCH} from origin. Please delete manually."
          exit 0
        fi
      else
        echo "Branch already deleted on origin."
      fi
    else
      echo "PR ${pr} still appears to be open."
      exit 1
    fi
  else
    echo "PR merge failed!"
    exit ${MERGE_STATUS}
  fi
else
  echo "PR CI status check exited with ${CI_STATUS}. PR will not be merged automatically. Please manage the PR manually at ${PULL_REQUEST}."
  exit ${CI_STATUS}
fi

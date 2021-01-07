#!/bin/bash
#USAGE: ./tag_enterprise_dist_next_rc.sh <version> <branch_from>

export BUNDLE_BIN=.bundle/bin
export BUNDLE_PATH=.bundle/gems
export PATH=/opt/puppetlabs/puppet/bin:$PATH

set +x
source /usr/local/rvm/scripts/rvm
rvm use 2.5.1
set -x

version=${1:-invalid}
branch_from=${2:-invalid}
next_pe_version=${3:-not_specified}

# make sure our params are set to something reasonable
if [[ $version == invalid ]]; then
  : === Error: looks like param VERSION was set incorrectly, it must be set to a PE version in x.y.z format
  exit 1
fi

if [[ $branch_from == invalid ]]; then
  : === Error: looks like param BRANCH_FROM was set incorrectly, it must be set to a valid enterprise-dist branch
  exit 1
fi

if [[ $next_pe_version == not_specified ]]; then
  : === Info: No value set for NEXT_PE_VERSION... calculating based on x.y value
fi

# Calculate tagging actions based on user input
if [[ ! -z $next_pe_version ]] ; then
  : === You specified the version $next_pe_version to tag $branch_from at...
  tagging_task=new_release:create_and_push_new_pe_tag
  export PE_BRANCH_NAME=$branch_from
  export NEXT_PE_VERSION=$next_pe_version
elif [[ $branch_from == master ]] ; then
  : === Next PE version not specified, incrementing Y value and pushing new tag
  tagging_task=new_release:create_and_push_new_y_tag
  export PE_BRANCH_NAME=$branch_from
else
  : === Next PE version not specified, incrementing Z value and pushing new tag
  tagging_task=new_release:create_and_push_new_z_tag
  export PE_BRANCH_NAME=$branch_from
fi

rm -rf ./$GITHUB_PROJECT
git clone git@github.com:jackie-kinsler/$GITHUB_PROJECT ./$GITHUB_PROJECT

cd $GITHUB_PROJECT

bundle install --path $BUNDLE_PATH --retry 3

: === Checking out release branch $version-release
git checkout $version-release

: === Pushing empty commit to $version-release and tagging next rc
bundle exec rake new_release:push_empty_commit PE_BRANCH_NAME=$version-release
bundle exec rake new_release:create_and_push_rc_tag PE_BRANCH_NAME=$version-release

: === Populating release repos on Artifactory
bundle exec rake ship:prepare_release_repos ARTIFACTORY_USERNAME=jenkins ARTIFACTORY_API_KEY=$ARTIFACTORY_API_KEY

: === Checking out mainline branch $branch_from
git checkout $branch_from

: === Pushing empty commit to $branch_from
bundle exec rake new_release:push_empty_commit PE_BRANCH_NAME=$branch_from

: === Tagging next rc tag on $branch_from
bundle exec rake $tagging_task

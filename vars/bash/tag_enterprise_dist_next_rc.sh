#!/usr/bin/env bash --login -e

#USAGE: ./tag_enterprise_dist_next_rc.sh <version> <branch_from>
set +x
source /usr/local/rvm/scripts/rvm
rvm use 2.5.1
set -x

version=${1:-invalid}
branch_from=${2:-invalid}
next_pe_version=${3:-not_specified}

# make sure our params are set to something reasonable
if [[ $version == invalid ]]; then
  echo "Error...looks like param VERSION was set incorrectly, it must be set to a PE version in x.y.z format"
  exit 1
fi

if [[ $branch_from == invalid ]]; then
  echo "Error...looks like param BRANCH_FROM was set incorrectly, it must be set to a valid enterprise-dist branch"
  exit 1
fi

if [[ $next_pe_version == not_specified ]]; then
  echo "No value set for NEXT_PE_VERSION...guessing"
fi

export BUNDLE_BIN=.bundle/bin
export BUNDLE_PATH=.bundle/gems
export PATH=/opt/puppetlabs/puppet/bin:$PATH

rm -rf ./$GITHUB_PROJECT
git clone git@github.com:puppetlabs/$GITHUB_PROJECT ./$GITHUB_PROJECT

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

# If the user specifies what tag to use, use that tag
# Otherwise if branch_from is master we tag next release with next Y (2019.4.0 -> 2019.5.0-rc0)
# Finally, if we're branching from an LTS branch tag next Z (2018.1.11 -> 2018.1.12-rc0)
: === Tagging next rc tag on $branch_from
if [[ ! -z "$next_pe_version" ]] ; then
    : === You specified the version $next_pe_version to tag $branch_from at...tagging now...
    bundle exec rake new_release:create_and_push_new_pe_tag PE_BRANCH_NAME=$branch_from NEXT_PE_VERSION=$next_pe_version
elif [[ $branch_from == "master" ]] ; then
    puts "Next PE version not specified, incrementing Y value and pushing new tag"
    bundle exec rake new_release:create_and_push_new_y_tag PE_BRANCH_NAME=$branch_from
else
    puts "Next PE version not specified, incrementing Z value and pushing new tag"
    bundle exec rake new_release:create_and_push_new_z_tag PE_BRANCH_NAME=$branch_from
fi

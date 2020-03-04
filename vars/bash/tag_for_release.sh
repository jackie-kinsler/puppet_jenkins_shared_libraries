#USAGE: ./tag_for_release.sh <pe_version>

PE_VERSION=$1
rm -rf ./${GITHUB_PROJECT}
git clone git@github.com:puppetlabs/${GITHUB_PROJECT} ./${GITHUB_PROJECT}
cd ${GITHUB_PROJECT}

RELEASE_X_NUMBER=`echo $PE_VERSION | sed "s/\([[:digit:]]\+\)\.[[:digit:]]\+\.[[:digit:]]\+/\1/"`
RELEASE_Y_NUMBER=`echo $PE_VERSION | sed "s/[[:digit:]]\+\.\([[:digit:]]\+\)\.[[:digit:]]\+/\1/"`
RELEASE_Z_NUMBER=`echo $PE_VERSION | sed "s/[[:digit:]]\+\.[[:digit:]]\+\.\([[:digit:]]\+\)/\1/"`
CURRENT_TAG=`git describe`
TAG_X_NUMBER=`echo $CURRENT_TAG | sed 's/\([[:digit:]]\+\)\.[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+-\?.*/\1/'`
TAG_Y_NUMBER=`echo $CURRENT_TAG | sed 's/[[:digit:]]\+\.\([[:digit:]]\+\)\.[[:digit:]]\+\.[[:digit:]]\+-\?.*/\1/'`
TAG_Z_NUMBER=`echo $CURRENT_TAG | sed 's/[[:digit:]]\+\.[[:digit:]]\+\.\([[:digit:]]\+\)\.[[:digit:]]\+-\?.*/\1/'`
TAG_FOURTH_DIGIT=`echo $CURRENT_TAG | sed 's/[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\.\([[:digit:]]\+\)-\?.*/\1/'`
RELEASE_BRANCH=`git ls-remote | grep $PE_VERSION-release`

verify_digits() {
    re='^[0-9]+$'
    input=$1
    if ! [[ $input =~ $re ]] ; then
        echo "error: Something went wrong validating version or current tag. VERSION should be in 2019.3.1 style format, current tag should be in 2019.3.1.0(-sha) format" >&2; exit 1
    fi
}

# Input validation
num_ary=($RELEASE_X_NUMBER $RELEASE_Y_NUMBER $RELEASE_Z_NUMBER $TAG_X_NUMBER $TAG_Y_NUMBER $TAG_Z_NUMBER)
for i in "${num_ary[@]}"
do
    verify_digits $i
done
# Until we automate cutting release branches, need this check
if [ -z "$RELEASE_BRANCH" ]; then
    echo $TAG_X_NUMBER $TAG_Y_NUMBER
    git checkout $TAG_X_NUMBER.$TAG_Y_NUMBER.x
else
    git checkout $PE_VERSION-release
    CURRENT_TAG=`git describe`
    TAG_X_NUMBER=`echo $CURRENT_TAG | sed 's/\([[:digit:]]\+\)\.[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+-\?.*/\1/'`
    TAG_Y_NUMBER=`echo $CURRENT_TAG | sed 's/[[:digit:]]\+\.\([[:digit:]]\+\)\.[[:digit:]]\+\.[[:digit:]]\+-\?.*/\1/'`
    TAG_Z_NUMBER=`echo $CURRENT_TAG | sed 's/[[:digit:]]\+\.[[:digit:]]\+\.\([[:digit:]]\+\)\.[[:digit:]]\+-\?.*/\1/'`
    TAG_FOURTH_DIGIT=`echo $CURRENT_TAG | sed 's/[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\.\([[:digit:]]\+\)-\?.*/\1/'`
fi

if [ $RELEASE_X_NUMBER != $TAG_X_NUMBER ]; then
    if [ "$RELEASE_X_NUMBER" -lt "$TAG_X_NUMBER" ]; then
        echo "$PE_VERSION is less then current tag $CURRENT_TAG"
        cd ..
	rm -rf ${GITHUB_PROJECT}
        exit 1
    fi
    TAG=$PE_VERSION.0
    git tag -a $TAG -m "$TAG"
else
    if [ $RELEASE_Y_NUMBER != $TAG_Y_NUMBER ]; then
        if [ "$RELEASE_Y_NUMBER" -lt "$TAG_Y_NUMBER" ]; then
            echo "$PE_VERSION is less then current tag $CURRENT_TAG"
            cd ..
	    rm -rf ${GITHUB_PROJECT}
            exit 1
        fi
        TAG=$PE_VERSION.0
        git tag -a $TAG -m "$TAG"
    else
        if [ $RELEASE_Z_NUMBER != $TAG_Z_NUMBER ]; then
            if [ "$RELEASE_Z_NUMBER" -lt "$TAG_Z_NUMBER" ]; then
                echo "$PE_VERSION is less then current tag $CURRENT_TAG"
                cd ..
		rm -rf ${GITHUB_PROJECT}
                exit 1
            fi
                TAG=$PE_VERSION.0
                    git tag -a $TAG -m "$TAG"
                    else
                TAG_FOURTH_DIGIT=$(( TAG_FOURTH_DIGIT + 1 ))
                    TAG=$PE_VERSION.$TAG_FOURTH_DIGIT
                        git tag -a $TAG -m "$TAG"
                        fi
    fi
fi
git push git@github.com:puppetlabs/${GITHUB_PROJECT}.git $TAG
cd ..
rm -rf ${GITHUB_PROJECT}

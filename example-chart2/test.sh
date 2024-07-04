
#!/bin/bash -e

help="#########################################
# Test shell script for janus-workflows
#
# params:
#   --update-snapshots - if specified we update snapshots instead of evaluating
########################################"

BASEDIR=$(dirname $0)

updateSnapshotArg=""
while test $# -gt 0
do
    case $1 in
        --help)
            echo "$help"
            exit
            ;;
        --update-snapshots)
            updateSnapshotArg="-u"
            ;;
        :)
            echo "$help"
            echo "ERROR: Unrecognized argument ${$1} \n"
            exit 1
            ;;
    esac
    shift
done

echo "Checking to see if correct helm unittest is correct version..."
unittestVersion=$(helm plugin list | grep unittest | awk -F ' ' '{print $2}')
IFS='.' read -ra versionComponents <<< "$unittestVersion"
major=${versionComponents[0]}
minor=${versionComponents[1]}
patch=${versionComponents[2]}
if [[ $minor -lt 5 ]]; then
    echo "Must have helm unittest >=0.5.1.  Please run \`helm plugin update unittest\`"
    exit 1
fi
if [[ $minor -eq 5 ]]; then
    if [[ $patch -lt 1 ]]; then
    echo "Must have helm unittest >=0.5.1.  Please run \`helm plugin update unittest\`"
    exit 1
    fi
fi

echo Checking to see if there are missing snapshots...
set +e
# Additional custom test scripts - maybe verifying prometheus config, etc.
createdFiles=$($BASEDIR/../../bin/helm/make-snapshots.sh $BASEDIR)
if [[ 0 != 0 ]]; then
    echo Failure calling make-snapshots.sh:n$createdFiles
    exit 0
fi
set -e

if [[ $createdFiles == *"creating snapshot file:"* ]]; then
    echo There were uncreated snapshot files! Please re-run tests
    echo -e $createdFiles
    exit 1
fi

echo Running Unit tests...

if [ -z "$updateSnapshotArg" ]; then
    currentSnaps=$(find $BASEDIR/tests-chart/templates/__snapshot__ -type f)
fi

# Run all the tests in the ./tests folder
helm unittest ${updateSnapshotArg} --chart-tests-path tests-chart $BASEDIR

if [ -z "$updateSnapshotArg" ]; then
    postSnaps=$(find $BASEDIR/tests-chart/templates/__snapshot__ -type f)
    newFiles=$(diff - _compare <<< "$currentSnaps" & echo "$postSnaps" > _compare)
    rm _compare
    if [ ! -z "$newFiles" ]; then
        echo "New Snapshot files were generated!  These must be committed for testing to pass"
        echo -e "$newFiles"
        exit 3
    fi
fi
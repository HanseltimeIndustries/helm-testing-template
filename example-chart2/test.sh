
#!/bin/bash -e

BASEDIR=$(dirname $0)

help="#########################################
# Test shell script for 
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

echo Checking to see if there are missing snapshots...
set +e
# Additional custom test scripts - maybe verifying prometheus config, etc.
createdFiles=$($BASEDIR/../bin/helm/make-snapshots.sh $BASEDIR)
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

# Run all the tests in the ./tests folder
helm unittest ${updateSnapshotArg} --chart-tests-path tests-chart $BASEDIR


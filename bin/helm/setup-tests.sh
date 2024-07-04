#!/bin/bash -e

help="#########################################################
#
# setup-tests.sh <helm folder|pwd>
#
# This script will scan the entire helm folder and update the
# standared tests/snapshot_test.yaml file with all of the files
# that are .yaml.
#
###########################################################"
BASEDIR=$(dirname $0)

workingDir=${1:-$PWD}

if [ "$1" == "--help" ]; then
  echo -e $help
  exit
fi

if [ ! -f "$workingDir/Chart.yaml" ]; then
    echo "Could not find Chart.yaml.  Must run in a helm chart folder."
    exit 1
fi


absDirName="$(cd $workingDir >/dev/null; pwd -P)"
dirName=$(basename $workingDir)

# TODO: we want replace this when there is an init command in helm-unittest
# START - Creating helm tests folder
testChartsFolder=$workingDir/tests-chart
if [ ! -d $testChartsFolder ]; then
  mkdir $testChartsFolder
fi

# Add the yaml schema just for IDE support
if [ ! -f $workingDir/tests-chart/helm-testsuite.json ]; then
    cp $BASEDIR/helm-testsuite.json $workingDir/tests-chart/
fi

if [ ! -f $testChartsFolder/Chart.yaml ]; then
  echo "
apiVersion: v2
name: ${dirName}-unittests
description: |
  This helm chart is used for building unit test yaml and running them for the encompassing
  helm chart.

type: application

# This is the chart version. This version number should be incremented each time you make changes
# to the chart and its templates, including the app version.
# Versions are expected to follow Semantic Versioning (https://semver.org/)
version: 0.1.0
" > $testChartsFolder/Chart.yaml
fi

if [ ! -f $testChartsFolder/.helmignore ]; then
  echo "
*/__snapshot__/*"> $testChartsFolder/.helmignore
fi

if [ ! -f $testChartsFolder/values.yaml ]; then
  touch $testChartsFolder/values.yaml
  echo "
# Example of multiple environment names
envs:
  - dev
  - staging
  - prod

noDocTemplates:
  - hpa
  - ingress
" > $testChartsFolder/values.yaml
fi

if [ ! -f $testChartsFolder/templates ]; then
  mkdir $testChartsFolder/templates
fi
# END - Creating helm tests folder

# Get the releative path
IFS='/' read -ra pathParts <<< "$workingDir"
relPath=""
# Print each part
for part in "${pathParts[@]}"; do
  if [ ! -z "$part" ]; then
    relPath="$relPath../"
  fi
done

if [ ! -f $workingDir/test.sh ]; then
    echo "
#!/bin/bash -e

BASEDIR=\$(dirname \$0)

help=\"#########################################
# Test shell script for ${dirname}
#
# params:
#   --update-snapshots - if specified we update snapshots instead of evaluating
########################################\"

BASEDIR=\$(dirname \$0)

updateSnapshotArg=\"\"
while test \$# -gt 0
do
    case \$1 in
        --help)
            echo \"\$help\"
            exit
            ;;
        --update-snapshots)
            updateSnapshotArg=\"-u\"
            ;;
        :)
            echo \"\$help\"
            echo \"ERROR: Unrecognized argument \${\$1} \n\"
            exit 1
            ;;
    esac
    shift
done

echo \"Checking to see if helm unittest is correct version...\"
unittestVersion=\$(helm plugin list | grep unittest | awk -F ' ' '{print \$2}')
IFS='.' read -ra versionComponents <<< "\$unittestVersion"
major=\${versionComponents[0]}
minor=\${versionComponents[1]}
patch=\${versionComponents[2]}
if [[ \$minor -lt 5 ]]; then
    echo \"Must have helm unittest >=0.5.1.  Please run \`helm plugin update unittest\`\"
    exit 1
fi
if [[ \$minor -eq 5 ]]; then
    if [[ \$patch -lt 1 ]]; then
    echo \"Must have helm unittest >=0.5.1.  Please run \`helm plugin update unittest\`\"
    exit 1
    fi
fi

echo \"Checking to see if there are missing snapshots...\"
set +e
# Additional custom test scripts - maybe verifying prometheus config, etc.
createdFiles=\$(\$BASEDIR/$relPath${BASEDIR/.\//}/make-snapshots.sh \$BASEDIR)
if [[ \"\$?\" != \"0\" ]]; then
    echo \"Failure calling make-snapshots.sh:\n\$createdFiles\"
    exit $?
fi
set -e

if [[ \"\$createdFiles\" == *\"creating snapshot file:\"* ]]; then
    echo \"There were uncreated snapshot files!  Please re-run tests\"
    echo -e "\$createdFiles"
    exit 1
fi

if [[ \$createdFiles == *\"creating snapshot file:\"* ]]; then
    echo \"There were uncreated snapshot files! Please re-run tests\"
    echo -e \"\$createdFiles\"
    exit 1
fi

echo \"Running Unit tests...\"

if [ -z \"\$updateSnapshotArg\" ]; then
    currentSnaps=\$(find \$BASEDIR/tests-chart/templates/__snapshot__ -type f)
fi

# Run all the tests in the ./tests folder
helm unittest \${updateSnapshotArg} --chart-tests-path tests-chart \$BASEDIR

if [ -z \"\$updateSnapshotArg\" ]; then
    postSnaps=\$(find \$BASEDIR/tests-chart/templates/__snapshot__ -type f)
    newFiles=\$(diff - _compare <<< \"\$currentSnaps\" & echo \"\$postSnaps\" > _compare)
    rm _compare
    if [ ! -z \"\$newFiles\" ]; then
        echo \"New Snapshot files were generated!  These must be committed for testing to pass\"
        echo -e \"\$newFiles\"
        exit 3
    fi
fi
" > $workingDir/test.sh
chmod 755 $workingDir/test.sh
else
    echo "test.sh already exists.  Skipping making."
fi

# Always use the tests-chart repo
$BASEDIR/make-snapshots.sh $workingDir

#!/bin/bash -e

BASEDIR=$(dirname $0)

help="#########################################################
#
# make-snapshots.sh <helm folder|pwd>
#
# This script will fill in the helm repo with all of the basic
# minimum tests to get started via helm unittest.
#
###########################################################"

workingDir=${1:-$PWD}

if [ "$1" == "--help" ]; then
  echo -e $help
  exit
fi

yamlFiles=$(find $workingDir/templates -type f -name '*.yaml' -o -name '*.yml')

# Get all templates in the test directory - for validation
# yq '.templates[]' $1/tests/snapshot_test.yaml

if [ ! -f "$workingDir/Chart.yaml" ]; then
    echo "Could not find Chart.yaml.  Must run in a helm chart folder."
    exit 1
fi

testChartsFolder="$workingDir/tests-chart/templates"

if [ ! -d "$testChartsFolder" ]; then
  echo "make snapshots requires test-charts helm tests.  Attempting to run setup in directory"
  $BASEDIR/setup-tests.sh "$workingDir"
fi

snapshotTemplate=
if [ -f "$workingDir/snapshot-template.yaml" ]; then
  echo "Using snapshot-template.yaml"
  snapshotTemplate=$(cat "$workingDir/snapshot-template.yaml")
else 
  snapshotTemplate="
{{- /*
# Helm unit testing
#
# TODO: parameterize this as needed by with values from your values.yaml
# 
# This folder is sorely lacking.  Please update anything that you change to
# ensure that we are proving any helm chart functionality that you've added.
# yaml-language-server: \$schema=../helm-testsuite.json
*/}}
{{- range \$idx, \$env := $.Values.envs }}
suite: YAML_NAME snapshot {{ \$env }} test
snapshotId: {{ \$env }}
templates:
  - YAML_PATH
tests:
  - it: manifest should match snapshot
    set:
      env: {{ \$env }}
    asserts:
      - matchSnapshot: {}
---
{{- end }}
"
fi

while IFS= read -r fileName; do
    # Create a snapshot per file for better git diff experience
    relPath="${fileName/${workingDir}\/templates\//}"
    snaked=${relPath//\//_}
    noYaml=${snaked/".yaml"/}
    filebase=${noYaml/".yml"/}
    # Legacy Snapshot location
    snapshotFile="$testChartsFolder/snapshot_${filebase}_test.yaml"

    if [ ! -f $snapshotFile ]; then
      echo "creating snapshot file: ${snapshotFile}"
      # Substitute the agreed on values
      snapshotTestTemplate="${snapshotTemplate//YAML_NAME/$filebase}"
      snapshotTestTemplate="${snapshotTestTemplate//YAML_PATH/$relPath}"

      if [ ! -d $workingDir/tests ]; then
          mkdir $workingDir/tests
      fi
      printf "$snapshotTestTemplate" > $snapshotFile
    fi
done <<< "$yamlFiles"

#!/bin/bash -e

help="################################################################
#
# test-all-charts.sh [--allow-no-tests] [--update-snapshots]
#
# Attempts to run the test.sh in all folders that are helm charts.  
# Allows charts with no test.sh if "--allow-no-tests" is set
#
###############################################################"

# Cli parsing
allowNoTests=false
updateSnapshots=false
while test $# -gt 0
do
    case $1 in
        --help)
            echo "$help"
            exit
            ;;
        --allow-no-tests)
            allowNoTests=true
            ;;
        --update-snapshots)
            updateSnapshots=true
            ;;
        :)
            echo "$help"
            echo "ERROR: Unrecognized argument ${$1} \n"
            exit 1
            ;;
    esac
    shift
done

charts=$(find . -type f -name "Chart.yaml" -exec dirname {} \;)

while IFS= read -r chart; do
    chartFolder=$(basename $chart)
    if [[ "$chartFolder" == "tests-chart" ]]; then
        echo "skipping $chart helm chart - Expected Test Chart"
        continue
    fi
    echo "Testing $chart..."
    if [ ! -f $chart/test.sh ]; then
        if [ "$allowNoTests" != "true" ]; then
            echo "No test.sh found in $chart, and therefore chart is untested!  Please run bin/helm/setup-tests.sh $chart"
            exit 1
        fi
    else
        snapshotArg=""
        if [ "$updateSnapshots" == "true" ]; then
            snapshotArg="--update-snapshots"
        fi
        $chart/test.sh $snapshotArg
    fi

done <<< "$charts"

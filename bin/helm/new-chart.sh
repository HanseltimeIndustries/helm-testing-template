#!/bin/bash -e

BASEDIR=$(dirname $0)

#########################################
# Simple wrapper shell script that calls helm create and test setup in one go
# 
# Use it the same way you would use helm create
########################################\

createOutput=$(helm create "$@")
echo -e "$createOutput"

chartPath=${createOutput/Creating /}

echo "Creating test setup..."
$BASEDIR/setup-tests.sh "$chartPath"
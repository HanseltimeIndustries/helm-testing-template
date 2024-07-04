# Helm Testing Template

This repo shows a set of scripts that augment the very useful `helm-unittest` plugin for helm.  The
target of this pattern is to be able to enforce snapshots with every helm change so that git reviewers
can be certain of the manifest changes.  The use of snapshots also helps developers to test trickier
helm syntax by run tests multiple times and reviewing the diff.

- [Helm Testing Template](#helm-testing-template)
- [Tools:](#tools)
- [Creating a new helm repo](#creating-a-new-helm-repo)
  - [Using new-chart.sh](#using-new-chartsh)
  - [Doing it via manual commands](#doing-it-via-manual-commands)
  - [End Result](#end-result)
    - [test.sh](#testsh)
      - [Updating snapshots](#updating-snapshots)
    - [tests-chart](#tests-chart)
  - [Snapshots-template.yaml](#snapshots-templateyaml)
    - [Default Snapshots-template.yaml](#default-snapshots-templateyaml)
      - [Environment based document skips](#environment-based-document-skips)
- [Running all tests](#running-all-tests)

*Created with Markdown All In One VsCode Extension*

# Tools:

1. [Install helm](https://helm.sh/docs/intro/install/)
2. [Install unittest plugin](https://github.com/helm-unittest/helm-unittest?tab=readme-ov-file#install)
   
# Creating a new helm repo

The [bin/helm/new-chart.sh](./bin/helm/new-chart.sh) file is a quick attempt at wrapping `helm create` so that users
do not have to call multiple commands.

## Using new-chart.sh

```shell
./bin/helm/new-chart.sh <args for helm create> example-chart
```

## Doing it via manual commands

```shell
helm create <args for helm create> example-chart
./bin/helm/setup-tests.sh example-chart
```

## End Result

The end result of the above commands is a helm chart with a nested helm test chart and some additional scripts.

### test.sh

This is the script that sets up calling your unit-tests. It performs some additional abstractions that are hard to police
via Github PRs.  The main thing that is does is call the standard make-snapshots.sh script to see if there are new files
that don't have a snapshot test.

#### Updating snapshots

All the test scripts come with a `--update-snapshots` flag that will run tests and update the snapshots (it just triggers this
on the helm unittest command).  Because of this, when changing charts, you can use this to get snapshots to store new expected
snapshots.

### tests-chart

This is a helm-unittest chart that is parameterized via the values.yaml file in it's folder repo.  Why is this valuable?

Example:

Let's say that you have 3 environments: dev, staging, and prod, and this chart is configured to use separate values per environment
or even skip whole configurations (for instance, not bothering to set up additional tools in dev due to cost).

While you could create multiple copy-paste snapshot tests, that will quickly become the pain point that developers either
skip or becomes very out of date.  Instead, you can create a snapshot per yaml, and then configure a loop on env values, so that
you can get multiple snapshots and even new ones, by just adding a new environment in that values.yaml!


## Snapshots-template.yaml

The [make-snapshots.sh](./bin/helm/make-snapshots.sh) script will try to add a very simple best guess example set of 
snapshot tests per .yaml.  However, you may know what the standard patterns are that you want for each test (per the environments, etc.)
becuause of this, if you put a snapshots-template.yaml file in the root of your chart, make-snapshots will use that
for new tests.

It will also perform rudimentary substitution on the following values:

* YAML_NAME - the name of the template file
* YAML_PATH - the relative path from the tests-chart to the actual template file

### Default Snapshots-template.yaml

The default snapshot template is:

```yaml
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
    {{- /*
      If we have no documents snapshot doesn't handle that well
    */}}
    {{- if has \"YAML_NAME\" $.Values.noDocTemplates }}
      - hasDocuments:
        count: 0 
    {{- else }}
      - matchSnapshot: {}
    {{- end }}
---
{{- end }}
```

This template make a test-suite per env that you list in .envs and set the `env` value to the same.
It also provides a rudimentary way for us to handle yaml files that actually don't render (for instance,
the hpa.yaml that is not enabled in the helm values.yaml).  Because helm unit-test cannot snapshot a file
that does not exist, we actually need to specify that the test returns 0 documents.

We do some by controlling this with the `tests-chart/value.yaml` list:

```yaml

noDocTemplates:
  - hpa
```

#### Environment based document skips

**This is deprecated now with >0.5.0 helm unittest you will want to update your test.sh scripts to ensure that no new snap files are created instead**

More commonly, you might find yourself wanting to say that certain environments are probably missing templates.  This
could happen because you have a cost cutting measure in some environments over others, or different tooling.  This type of
thing is up to you to ultimately pattern (and probably add to your `snapshots-template.yaml`), but the following is a naive
example of how to do that:

```yaml
# values.yaml
envs:
  - dev
  - prod

noDocTemplates:
  hpa:
    - dev
  ingress:
    - all
```

```yaml
# test
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
    {{- /*
      If we have no documents snapshot doesn't handle that well
    */}}
    {{- $noSnapshot := false }}
    {{- if eq (default .Values.noDocTemplates.YAML_NAME false) true }}
        {{- $noSnapshot = true }}
        {{- if or (has $env $.Values.noDocTemplates.YAML_NAME) (has "all" $.Values.noDocTemplates.YAML_NAME) }}
      - hasDocuments:
        count: 0
        {{- end }}
    {{- end }}
    {{- if not $noSnapshot }}
      - matchSnapshot: {}
    {{- end }}
---
{{- end }}
```

The above setup will only expect no documents if we added "all" for all environments or the current environment
has an entry for the yaml name.

# Running all tests

This repository also houses a simple shell script for running all tests within the repo and also throwing an error if a helm chart is setup without tests.

It will equally allow you to run snapshot updates in all folders as well.

```shell
./bin/helm/test-all-charts.sh --update-snapshots --allow-no-tests
```

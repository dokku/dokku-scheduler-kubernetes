#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create $TEST_APP
  dokku config:set $TEST_APP DOKKU_SCHEDULER=kubernetes
  dokku registry:set $TEST_APP server docker.io
  dokku registry:set $TEST_APP image-repo dokkutestapps/$TEST_APP
  dokku scheduler-kubernetes:set $TEST_APP imagePullSecrets registry-credential
}

teardown() {
  dokku --force apps:destroy $TEST_APP
}

@test "(scheduler-kubernetes) help" {
  dokku scheduler-kubernetes:help
}

@test "(scheduler-kubernetes) deploy dockerfile" {
  run deploy_app dockerfile-procfile
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:show-manifest $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_failure
}

@test "(scheduler-kubernetes) deploy herokuish" {
  run deploy_app python
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:show-manifest $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success
}

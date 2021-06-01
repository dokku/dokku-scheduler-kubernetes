#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create "$TEST_APP"
}

teardown() {
  dokku --force apps:destroy "$TEST_APP"
}

@test "($PLUGIN_COMMAND_PREFIX:hook:set) cert-manager-enabled" {
  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-cert-manager-enabled"
  echo "output: $output"
  echo "status: $status"
  assert_success ""

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP cert-manager-enabled true"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-cert-manager-enabled"
  echo "output: $output"
  echo "status: $status"
  assert_success "true"

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP cert-manager-enabled"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-cert-manager-enabled"
  echo "output: $output"
  echo "status: $status"
  assert_success ""
}

@test "($PLUGIN_COMMAND_PREFIX:hook:set) imagePullSecrets" {
  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-imagePullSecrets"
  echo "output: $output"
  echo "status: $status"
  assert_success ""

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP imagePullSecrets registry-credential"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-imagePullSecrets"
  echo "output: $output"
  echo "status: $status"
  assert_success "registry-credential"

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP imagePullSecrets"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-imagePullSecrets"
  echo "output: $output"
  echo "status: $status"
  assert_success ""
}

@test "($PLUGIN_COMMAND_PREFIX:hook:set) ingress-enabled" {
  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-ingress-enabled"
  echo "output: $output"
  echo "status: $status"
  assert_success "false"

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP ingress-enabled true"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-ingress-enabled"
  echo "output: $output"
  echo "status: $status"
  assert_success "true"

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP ingress-enabled"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-ingress-enabled"
  echo "output: $output"
  echo "status: $status"
  assert_success "false"
}

@test "($PLUGIN_COMMAND_PREFIX:hook:set) namespace" {
  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-namespace"
  echo "output: $output"
  echo "status: $status"
  assert_success ""

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP namespace some-namespace"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-namespace"
  echo "output: $output"
  echo "status: $status"
  assert_success "some-namespace"

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP namespace"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-namespace"
  echo "output: $output"
  echo "status: $status"
  assert_success ""
}

@test "($PLUGIN_COMMAND_PREFIX:hook:set) pod-max-unavailable" {
  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-pod-max-unavailable"
  echo "output: $output"
  echo "status: $status"
  assert_success ""

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP pod-max-unavailable 1"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-pod-max-unavailable"
  echo "output: $output"
  echo "status: $status"
  assert_success "1"

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP pod-max-unavailable"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-pod-max-unavailable"
  echo "output: $output"
  echo "status: $status"
  assert_success ""
}

@test "($PLUGIN_COMMAND_PREFIX:hook:set) pod-min-available" {
  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-pod-min-available"
  echo "output: $output"
  echo "status: $status"
  assert_success ""

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP pod-min-available 1"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-pod-min-available"
  echo "output: $output"
  echo "status: $status"
  assert_success "1"

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP pod-min-available"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-pod-min-available"
  echo "output: $output"
  echo "status: $status"
  assert_success ""
}

@test "($PLUGIN_COMMAND_PREFIX:hook:set) service-process-types" {
  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-service-process-types"
  echo "output: $output"
  echo "status: $status"
  assert_success ""

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP service-process-types http,worker"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-service-process-types"
  echo "output: $output"
  echo "status: $status"
  assert_success "http,worker"

  run /bin/bash -c "dokku scheduler-kubernetes:set $TEST_APP service-process-types"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku scheduler-kubernetes:report $TEST_APP --scheduler-kubernetes-service-process-types"
  echo "output: $output"
  echo "status: $status"
  assert_success ""
}

#!/usr/bin/env bash
export DOKKU_LIB_ROOT="/var/lib/dokku"
source "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/config"

UUID=$(uuidgen)
TEST_APP="rdmtestapp-${UUID}"

flunk() {
  {
    if [ "$#" -eq 0 ]; then
      cat -
    else
      echo "$*"
    fi
  }
  return 1
}

assert_equal() {
  if [ "$1" != "$2" ]; then
    {
      echo "expected: $1"
      echo "actual:   $2"
    } | flunk
  fi
}

# ShellCheck doesn't know about $status from Bats
# shellcheck disable=SC2154
assert_exit_status() {
  assert_equal "$1" "$status"
}

# ShellCheck doesn't know about $status from Bats
# shellcheck disable=SC2154
# shellcheck disable=SC2120
assert_success() {
  if [ "$status" -ne 0 ]; then
    flunk "command failed with exit status $status"
  elif [ "$#" -gt 0 ]; then
    assert_output "$1"
  fi
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    flunk "expected failed exit status"
  elif [[ "$#" -gt 0 ]]; then
    assert_output "$1"
  fi
}

assert_exists() {
  if [ ! -f "$1" ]; then
    flunk "expected file to exist: $1"
  fi
}

assert_contains() {
  if [[ "$1" != *"$2"* ]]; then
    flunk "expected $2 to be in: $1"
  fi
}

# ShellCheck doesn't know about $output from Bats
# shellcheck disable=SC2154
assert_output() {
  local expected
  if [ $# -eq 0 ]; then
    expected="$(cat -)"
  else
    expected="$1"
  fi
  assert_equal "$expected" "$output"
}

deploy_app() {
  declare APP_TYPE="$1" GIT_REMOTE="$2" CUSTOM_TEMPLATE="$3" CUSTOM_PATH="$4"
  local APP_TYPE=${APP_TYPE:="python"}
  local GIT_REMOTE=${GIT_REMOTE:="dokku@dokku.me:$TEST_APP"}
  local GIT_REMOTE_BRANCH=${GIT_REMOTE_BRANCH:="master"}
  local TMP=${CUSTOM_TMP:=$(mktemp -d "/tmp/dokku.me.XXXXX")}

  rmdir "$TMP" && cp -r "${BATS_TEST_DIRNAME}/../tests/apps/$APP_TYPE" "$TMP"

  # shellcheck disable=SC2086
  [[ -n "$CUSTOM_TEMPLATE" ]] && $CUSTOM_TEMPLATE $TEST_APP $TMP/$CUSTOM_PATH

  pushd "$TMP" &>/dev/null || exit 1
  [[ -z "$CUSTOM_TMP" ]] && trap 'popd &>/dev/null || true; rm -rf "$TMP"' RETURN INT TERM

  git init
  git config user.email "robot@example.com"
  git config user.name "Test Robot"
  echo "setting up remote: $GIT_REMOTE"
  git remote add target "$GIT_REMOTE"

  [[ -f gitignore ]] && mv gitignore .gitignore
  git add .
  git commit -m 'initial commit'
  git push target "master:${GIT_REMOTE_BRANCH}" || destroy_app $?
}

destroy_app() {
  local RC="$1"
  local RC=${RC:=0}
  local APP="$2"
  local TEST_APP=${APP:=$TEST_APP}
  dokku --force apps:destroy "$TEST_APP"
  return "$RC"
}

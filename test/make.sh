#!/usr/bin/env bash

# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This function checks to make sure that every
# shebang has a '- e' flag, which causes it
# to exit on error
function check_bash() {
find . -name "*.sh" -not -path "./planter/*" | while IFS= read -d '' -r file;
do
  if [[ "$file" != *"bash -e"* ]];
  then
    echo "$file is missing shebang with -e";
    exit 1;
  fi;
done;
}

# This function makes sure that the required files for
# releasing to OSS are present
function basefiles() {
  echo "Checking for required files"
  test -f CONTRIBUTING.md || echo "Missing CONTRIBUTING.md"
  test -f LICENSE || echo "Missing LICENSE"
  test -f README.md || echo "Missing README.md"
}

# This function runs the hadolint linter on
# every file named 'Dockerfile'
function docker() {
  echo "Running hadolint on Dockerfiles"
  find . -name "Dockerfile" -not -path "./planter/*" -exec hadolint {} \;
}

# This function runs 'terraform validate' against all
# files ending in '.tf'
function check_terraform() {
  echo "Running terraform validate"
  #shellcheck disable=SC2156
  find . -name "*.tf" -not -path "./planter/*" -exec bash -c 'terraform validate --check-variables=false $(dirname "{}")' \;
}

# This function runs 'go fmt' and 'go vet' on eery file
# that ends in '.go'
function golang() {
  echo "Running go fmt and go vet"
  find . -name "*.go" -not -path "./planter/*" -exec go fmt {} \;
  find . -name "*.go" -not -path "./planter/*" -exec go vet {} \;
}

# This function runs the flake8 linter on every file
# ending in '.py'
# Install flake8 with `python -m pip install flake8 --user`
function check_python() {
  echo "Running flake8"
  find . -name "*.py" -not -path "./planter/*" -not -path "./js-client/node_modules/*" -exec flake8 {} \;
}

# This function runs the shellcheck linter on every
# file ending in '.sh'
function check_shell() {
  echo "Running shellcheck"
  find . -name "*.sh" -not -path "./planter/*" -not -path "./js-client/node_modules/*" -exec shellcheck -x {} \;
}

# This function runs the java formatter on every
# file ending in '.java'
# Download from https://github.com/checkstyle/checkstyle/releases/download/checkstyle-8.15/checkstyle-8.15-all.jar
function check_java() {
  echo "Formatting Java"
  find . -name "*.java" -not -path "./planter/*" -exec sh -c \
    'java -jar ~/Downloads/checkstyle-8.15-all.jar -c /google_checks.xml "$1"'\
		-x {} \;
}

# This function runs the `yarn buildifier` command.
function check_angular() {
  echo "Formatting Angular"
  cd js-client && yarn bazel:format && yarn bazel:lint
  find src -name "*.ts" -not -path "./node_modules/*" -exec sh -c \
    '"$(npm bin)"/clang-format -style="Google" -i "$1"' \
		-x {} \;
}

# This function makes sure that there is no trailing whitespace
# in any files in the project.
# There are some exclusions
function check_trailing_whitespace() {
  echo "The following lines have trailing whitespace"
  grep -r '[[:blank:]]$' \
    --exclude-dir=".terraform" --exclude-dir="dist"\
    --exclude-dir="bazel-out" --exclude-dir="planter"\
    --exclude-dir="node_modules" --exclude=".DS_Store"\
    --exclude="*.class"\
    --exclude="*.png" --exclude-dir=".git" --exclude="*.pyc" .
  rc=$?
  if [ $rc = 0 ]; then
    exit 1
  fi
}

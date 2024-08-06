#!/bin/bash

# echo '{"source_path": "example/my-lambda", "output_path": "example/my-lambda/my-lambda.zip", "install_dependencies": true}' | scripts//go_lambda_packer.sh

function error_exit() {
  echo "$1" 1>&2
  exit 1
}

function check_deps() {
  test -f "$(which go)" || error_exit "$(go) command not detected in path, please install it"
  test -f "$(which jq)" || error_exit "$(jq) command not detected in path, please install it"
}

function parse_input() {
  eval "$(jq -r '@sh "export architecture=\(.architecture) export source_path=\(.source_path) output_path=\(.output_path) install_dependencies=\(.install_dependencies)"')"
  if [[ -z "${architecture}" ]]; then export architecture=none; fi
  if [[ -z "${source_path}" ]]; then export source_path=none; fi
  if [[ -z "${output_path}" ]]; then export output_path=none; fi
  if [[ -z "${install_dependencies}" ]]; then export install_dependencies=none; fi
} &> /dev/null

function build_executable() {
  cd "${source_path}" || exit

  if $install_dependencies; then
    go mod verify
    go mod tidy
  fi

  GOOS=linux GOARCH=$architecture CGO_ENABLED=0 go build -o bootstrap .

  cd - || exit # go back to previous directory
} &> /dev/null

function produce_output() {
  # Construct the binary path
  binary_path="${source_path}/bootstrap"

  echo $output_path > outputpath.txt
  echo $binary_path > binarypath.txt

  # Output the JSON with both output_path and binary_path
  jq -n \
    --arg output_path "$output_path" \
    --arg binary_path "$binary_path" \
    '{"output_path":$output_path,"binary_path":$binary_path}'
}

check_deps
parse_input
build_executable
produce_output

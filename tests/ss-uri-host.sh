#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source <(sed '$d' "${SCRIPT_DIR}/../ss-2022.sh")

[[ "$(format_uri_host 212.135.37.238)" == "212.135.37.238" ]] || exit 1
[[ "$(format_uri_host 2a06:a005:ad:fffd::5)" == "[2a06:a005:ad:fffd::5]" ]] || exit 1

echo "SS URI host formatting tests passed"

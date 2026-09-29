#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source <(sed '$d' "${SCRIPT_DIR}/../ss-2022.sh")

generate_random_port() { echo 60776; }
port_in_use() { return 1; }
check_firewall() { :; }
close_firewall_port() { :; }

assert_port() {
    local input=$1 expected=$2
    SS_PORT=""
    set_port <<< "${input}" >/dev/null
    if [[ "${SS_PORT}" != "${expected}" ]]; then
        echo "expected port ${expected}, got ${SS_PORT}" >&2
        exit 1
    fi
}

assert_port $'30123\n' 30123
assert_port $'2\n30123\n' 30123
assert_port $'\n' 60776
assert_port $'99999\n2\n30123\n' 30123

echo "port selection tests passed"

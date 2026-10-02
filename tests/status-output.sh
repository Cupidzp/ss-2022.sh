#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source <(sed '$d' "${SCRIPT_DIR}/../ss-2022.sh")

CONFIG_PATH="/tmp/ss-2022-status-config.json"
check_installed_status() { return 0; }
service_active() { [[ "$1" == "ss-rust" ]]; }
service_show_logs() { echo "test log for $1"; }
jq() {
    case "$*" in
        *server_port*) echo 30123 ;;
        *method*) echo 2022-blake3-aes-256-gcm ;;
    esac
}
ss() {
    printf '%s\n' \
        'Netid State Recv-Q Send-Q Local Address:Port Peer Address:Port Process' \
        'tcp LISTEN 0 1024 *:30123 *:* users:("ss-rust",pid=42,fd=9)' \
        'udp UNCONN 0 0 *:30123 *:* users:("ss-rust",pid=42,fd=10)'
}
command() {
    if [[ "$1" == "-v" && "$2" == "ss" ]]; then
        return 0
    fi
    builtin command "$@"
}

output=$(Status <<< "")
for expected in "运行中" "30123" "监听情况" "test log for ss-rust"; do
    if [[ "${output}" != *"${expected}"* ]]; then
        echo "missing status output: ${expected}" >&2
        exit 1
    fi
done

echo "status output test passed"

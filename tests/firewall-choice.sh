#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source <(sed '$d' "${SCRIPT_DIR}/../ss-2022.sh")

INSTALL_DIR=$(mktemp -d)
FIREWALL_SKIP_FILE="${INSTALL_DIR}/firewall-disabled"
unset SS_SKIP_FIREWALL
firewall_add_calls=0
alpine_firewall_add_port() { firewall_add_calls=$((firewall_add_calls + 1)); }

configure_firewall_preference <<< "1" >/dev/null
if firewall_is_disabled || [[ -f "${FIREWALL_SKIP_FILE}" ]]; then
    echo "firewall management should be enabled for choice 1" >&2
    exit 1
fi
check_firewall 30123 >/dev/null
if [[ ${firewall_add_calls} -ne 1 ]]; then
    echo "choice 1 should add the selected port to firewall management" >&2
    exit 1
fi

firewall_add_calls=0
configure_firewall_preference <<< $'invalid\n2' >/dev/null
if ! firewall_is_disabled || [[ ! -f "${FIREWALL_SKIP_FILE}" ]]; then
    echo "firewall management should be disabled for choice 2" >&2
    exit 1
fi
check_firewall 30123 >/dev/null
if [[ ${firewall_add_calls} -ne 0 ]]; then
    echo "choice 2 should not add firewall rules" >&2
    exit 1
fi

SS_SKIP_FIREWALL=0 configure_firewall_preference >/dev/null
if firewall_is_disabled || [[ -f "${FIREWALL_SKIP_FILE}" ]]; then
    echo "SS_SKIP_FIREWALL=0 should re-enable firewall management" >&2
    exit 1
fi

SS_SKIP_FIREWALL=1 configure_firewall_preference >/dev/null
if ! firewall_is_disabled || [[ ! -f "${FIREWALL_SKIP_FILE}" ]]; then
    echo "SS_SKIP_FIREWALL=1 should persistently disable firewall management" >&2
    exit 1
fi

rm -rf "${INSTALL_DIR}"
echo "firewall choice tests passed"

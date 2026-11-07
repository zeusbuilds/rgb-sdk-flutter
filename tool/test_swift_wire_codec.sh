#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rgb-wire-codec.XXXXXX")"
trap 'rm -rf "${WORK_DIR}"' EXIT
swiftc -warnings-as-errors \
  "${REPO_DIR}/ios/Classes/RlnWireCodec.swift" \
  "${REPO_DIR}/test/native/wire_codec_main.swift" \
  -o "${WORK_DIR}/wire-codec-test"
"${WORK_DIR}/wire-codec-test"
swiftc -warnings-as-errors \
  "${REPO_DIR}/ios/Classes/RgbLibOperationPolicy.swift" \
  "${REPO_DIR}/test/native/rgb_lib_operation_policy_main.swift" \
  -o "${WORK_DIR}/rgb-lib-operation-policy-test"
"${WORK_DIR}/rgb-lib-operation-policy-test"

swiftc -warnings-as-errors \
  "${REPO_DIR}/ios/Classes/RgbLibNetworkPolicy.swift" \
  "${REPO_DIR}/test/native/rgb_lib_network_policy_main.swift" \
  -o "${WORK_DIR}/rgb-lib-network-policy-test"
"${WORK_DIR}/rgb-lib-network-policy-test"
swiftc -warnings-as-errors \
  "${REPO_DIR}/ios/Classes/RgbLibSessionAddress.swift" \
  "${REPO_DIR}/test/native/rgb_lib_session_address_main.swift" \
  -o "${WORK_DIR}/rgb-lib-session-address-test"
"${WORK_DIR}/rgb-lib-session-address-test"

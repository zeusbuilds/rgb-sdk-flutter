#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DART_BIN="${DART_BIN:-dart}"
export DART_BIN FLUTTER_BIN
source "${SCRIPT_DIR}/evidence_shell.sh"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/consumer-matrix}"
mkdir -p "${REPORT_DIR}"
REPORT_DIR="$(cd "${REPORT_DIR}" && pwd)"
RUN_ID="${RELEASE_RUN_ID:-${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)}}"
REPORT_FILE="${REPORT_DIR}/clean-consumer-matrix-${RUN_ID}.json"
LOG_FILE="${REPORT_DIR}/clean-consumer-matrix-${RUN_ID}.log"
WORK_DIR="${CONSUMER_WORK_DIR:-${REPO_DIR}/build/clean-consumer-matrix/${RUN_ID}}"
PACKAGE_DIR="${WORK_DIR}/package"
RUN_ARCHIVES="${RUN_CONSUMER_ARCHIVES:-1}"
ZIPALIGN_BIN="${ZIPALIGN_BIN:-${ANDROID_SDK_ROOT:-${ANDROID_HOME:-${HOME}/Library/Android/sdk}}/build-tools/36.0.0/zipalign}"

mkdir -p "${REPORT_DIR}"

STEP_NAMES=()
STEP_CODES=()
STEP_DURATIONS=()
STEP_NOTES=()
FAILED=0
FULL_COMMIT="$(git -C "${REPO_DIR}" rev-parse HEAD)"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

run_step() {
  local name="$1"
  shift
  local start
  local finish
  local code

  echo
  echo "==> ${name}"
  start="$(date +%s)"
  set +e
  ( set -euo pipefail; "$@" )
  code="$?"
  set -e
  finish="$(date +%s)"

  STEP_NAMES+=("${name}")
  STEP_CODES+=("${code}")
  STEP_DURATIONS+=("$((finish - start))")
  STEP_NOTES+=("")

  if [[ "${code}" -ne 0 ]]; then
    FAILED=1
    echo "!! ${name} failed with exit code ${code}"
  fi
}

write_report() {
  local status="passed"
  if [[ "${FAILED}" -ne 0 ]]; then
    status="failed"
  fi
  mkdir -p "${REPORT_DIR}"
  local report_file="${REPORT_DIR}/clean-consumer-matrix-${RUN_ID}.json"
  {
    echo "{"
    echo "  \"suite\": \"clean-consumer-matrix\","
    echo "  \"status\": \"${status}\","
    echo "  \"repository\": {\"commit\": \"${FULL_COMMIT}\"},"
    echo "  \"releaseEligible\": false,"
    echo "  \"runId\": \"$(json_escape "${RUN_ID}")\","
    echo "  \"workDir\": \"$(json_escape "${WORK_DIR}")\","
    echo "  \"packageDir\": \"$(json_escape "${PACKAGE_DIR}")\","
    echo "  \"archivesEnabled\": \"$(json_escape "${RUN_ARCHIVES}")\","
    echo "  \"steps\": ["
    for index in "${!STEP_NAMES[@]}"; do
      local comma=","
      if [[ "${index}" -eq $((${#STEP_NAMES[@]} - 1)) ]]; then
        comma=""
      fi
      echo "    {\"name\": \"$(json_escape "${STEP_NAMES[${index}]}")\", \"exitCode\": ${STEP_CODES[${index}]}, \"durationSeconds\": ${STEP_DURATIONS[${index}]}, \"note\": \"$(json_escape "${STEP_NOTES[${index}]}")\"}${comma}"
    done
    echo "  ]"
    echo "}"
  } >"${report_file}"
  echo
  echo "clean consumer matrix report: ${report_file}"
}

copy_candidate_snapshot() {
  cd "${REPO_DIR}"
  [[ -z "$(git status --porcelain)" ]] || {
    echo "Clean consumer qualification requires a committed clean candidate." >&2
    return 1
  }
  if [[ -e "${WORK_DIR}" ]]; then
    echo "Consumer work directory already exists; choose a new run directory." >&2
    return 1
  fi
  mkdir -p "${PACKAGE_DIR}"
  git archive "${FULL_COMMIT}" | tar -xf - -C "${PACKAGE_DIR}"
}

prepare_package_git_ref() {
  cd "${PACKAGE_DIR}"
  git init -q
  # Keep the candidate checkout's scoped identity in the temporary fixture.
  git config user.name "$(git -C "${REPO_DIR}" config user.name)"
  git config user.email "$(git -C "${REPO_DIR}" config user.email)"
  git add .
  git commit -q -m "candidate snapshot"
  git branch -M consumer-candidate
}

create_consumer() {
  local consumer_dir="$1"
  local dependency_yaml="$2"
  local ios_minimum
  ios_minimum="$(python3 - "${REPO_DIR}/tool/release_baseline.json" <<'PY'
import json
import sys
from pathlib import Path

baseline = json.loads(Path(sys.argv[1]).read_text())
print(baseline["buildRequirements"]["ios"]["minimumOsVersion"], end="")
PY
)"

  mkdir -p "${consumer_dir}"
  cd "${consumer_dir}"
  "${FLUTTER_BIN}" create --platforms android,ios --org com.utexo.consumer --project-name rgb_sdk_consumer .
  python3 - "${consumer_dir}/android/app/build.gradle.kts" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
marker = "    defaultConfig {\n"
if text.count(marker) != 1 or "abiFilters" in text:
    raise SystemExit("Cannot safely locate one unfiltered consumer Android defaultConfig block")
# Flutter's target-platform selects its engine binaries, but does not filter
# the plugin AAR's other ABIs. Keep this arm64 fixture complete for every ABI
# the resulting APK advertises.
text = text.replace(marker, marker + '        ndk.abiFilters.add("arm64-v8a")\n', 1)
path.write_text(text)
PY
  python3 - "${consumer_dir}/ios/Podfile" "${ios_minimum}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
minimum = sys.argv[2]
if path.exists():
    text = path.read_text()
else:
    text = """\
platform :ios, '__IOS_MINIMUM__'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      if current.nil? || Gem::Version.new(current) < Gem::Version.new('__IOS_MINIMUM__')
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '__IOS_MINIMUM__'
      end
    end
  end
end
""".replace("__IOS_MINIMUM__", minimum)
platform = f"platform :ios, '{minimum}'"
hook = """
    target.build_configurations.each do |config|
      current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      if current.nil? || Gem::Version.new(current) < Gem::Version.new('__IOS_MINIMUM__')
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '__IOS_MINIMUM__'
      end
    end
""".replace("__IOS_MINIMUM__", minimum)
if "Gem::Version.new(current)" not in text:
    marker = "    flutter_additional_ios_build_settings(target)\n"
    if marker not in text:
        raise SystemExit("Cannot locate consumer iOS build settings hook")
    text = text.replace(marker, marker + hook, 1)
if re.search(r"^#?\s*platform :ios,", text, re.M):
    text = re.sub(r"^#?\s*platform :ios,.*$", platform, text, count=1, flags=re.M)
else:
    text = f"{platform}\n{text}"
path.write_text(text)
PY
  python3 - "${consumer_dir}/pubspec.yaml" "${dependency_yaml}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
dependency = sys.argv[2].replace("\\n", "\n")
text = path.read_text()
marker = "dependencies:\n"
replacement = f"dependencies:\n  rgb_sdk_flutter:\n{dependency}\n"
if marker not in text:
    raise SystemExit("dependencies section not found")
path.write_text(text.replace(marker, replacement, 1))
PY
  python3 - "${consumer_dir}/pubspec.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
marker = "\nflutter:\n"
replacement = "\nflutter:\n  config:\n    enable-swift-package-manager: false\n"
if marker not in text:
    raise SystemExit("Flutter configuration section not found")
path.write_text(text.replace(marker, replacement, 1))
PY
cat >lib/main.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
  final version = RgbSdkFlutter.rlnVersion;
  final network = getNetworkDefaults('regtest')?.proxyEndpoint ?? 'missing';
    return MaterialApp(home: Text('$version $network'));
  }
}
DART
}

verify_consumer_apk_inventory() {
  python3 - "$1" "$2" <<'PY'
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

apk = Path(sys.argv[1])
report_path = Path(sys.argv[2])
required = {
    "lib/arm64-v8a/libapp.so",
    "lib/arm64-v8a/libflutter.so",
    "lib/arm64-v8a/libjnidispatch.so",
    "lib/arm64-v8a/librgb_lightning_node.so",
    "lib/arm64-v8a/librgblibuniffi.so",
}
failures = []
native_entries = []
digest = hashlib.sha256()
try:
    with apk.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    with zipfile.ZipFile(apk) as archive:
        native_entries = [entry.filename for entry in archive.infolist() if entry.filename.endswith(".so")]
    if len(native_entries) != len(set(native_entries)):
        failures.append("Duplicate native APK entries")
    if any(not re.fullmatch(r"lib/arm64-v8a/[A-Za-z0-9_.+-]+\.so", name) for name in native_entries):
        failures.append("Arm64 consumer APK contains an unexpected native path or ABI")
    missing = sorted(required - set(native_entries))
    if missing:
        failures.append("Missing required Flutter/RLN/RGB Lib/JNA libraries: " + ", ".join(missing))
except (OSError, zipfile.BadZipFile) as error:
    failures.append("Cannot inspect consumer APK: " + str(error))

report = {
    "schemaVersion": 1,
    "scope": "consumer-android-arm64-runtime-inventory",
    "apk": str(apk),
    "apkSha256": digest.hexdigest(),
    "expectedAbis": ["arm64-v8a"],
    "requiredLibraries": sorted(required),
    "nativeEntries": sorted(native_entries),
    "compatible": not failures,
    "failures": failures,
}
report_path.parent.mkdir(parents=True, exist_ok=True)
report_path.write_text(json.dumps(report, indent=2) + "\n")
for failure in failures:
    print(failure, file=sys.stderr)
if failures:
    raise SystemExit(1)
PY
}

build_consumer() {
  local consumer_dir="$1"
  cd "${consumer_dir}"
  "${FLUTTER_BIN}" pub get
  "${FLUTTER_BIN}" analyze --fatal-infos
  if [[ "${RUN_ARCHIVES}" == "1" ]]; then
    # Flutter 3.47's default filtering overwrites defaultConfig ABI filters.
    # Preserve this fixture's explicit arm64 filter; verify the final ZIP below.
    "${FLUTTER_BIN}" build apk --release --target-platform android-arm64 \
      --android-project-arg=disable-abi-filtering=true
    local apk="${consumer_dir}/build/app/outputs/flutter-apk/app-release.apk"
    local report_prefix="${REPORT_DIR}/android-${consumer_dir##*/}-${RUN_ID}"
    verify_consumer_apk_inventory "${apk}" "${report_prefix}-inventory.json"
    "${DART_BIN}" "${SCRIPT_DIR}/verify_android_elf.dart" \
      --archive "${apk}" --kind apk --expected-abis arm64-v8a \
      --zipalign "${ZIPALIGN_BIN}" --report "${report_prefix}-elf-zip.json"
    if [[ "$(uname -s)" == "Darwin" ]]; then
      "${FLUTTER_BIN}" build ios --release --no-codesign
      test -d "ios/.symlinks/plugins/rgb_sdk_flutter/ios/RGBLightningNode.xcframework" ||
        {
          echo "iOS consumer did not prepare the RLN xcframework." >&2
          exit 1
        }
      test -f "ios/.symlinks/plugins/rgb_sdk_flutter/ios/RGBLightningNodeFFI.h" ||
        {
          echo "iOS consumer did not prepare the RLN FFI header." >&2
          exit 1
        }
      local app="build/ios/iphoneos/Runner.app/Frameworks"
      for framework in RGBLib rgb_libFFI; do
        test -f "${app}/${framework}.framework/${framework}" || {
          echo "iOS consumer did not embed ${framework}.framework." >&2
          exit 1
        }
      done
      (
        cd ios
        pod install --deployment --no-repo-update
      )
    fi
  fi
}

main() {

  if [[ "${RUN_ARCHIVES}" != 1 || "$(uname -s)" != Darwin ]]; then
    echo "Both Android and iOS consumer archives are mandatory." >&2
    FAILED=1
    return 125
  fi
  if [[ ! -x "${ZIPALIGN_BIN}" ]]; then
    echo "Set ZIPALIGN_BIN to the reviewed Android build-tools 36.0.0 zipalign executable: ${ZIPALIGN_BIN}" >&2
    FAILED=1
    return 1
  fi

  run_step "snapshot package from candidate files" copy_candidate_snapshot
  [[ "${FAILED}" -eq 0 ]] || return 1
  run_step "prepare local git dependency ref" prepare_package_git_ref
  run_step "package tarball content dry-run" bash -lc "cd '${PACKAGE_DIR}' && '${DART_BIN}' pub publish --dry-run"

  local path_consumer="${WORK_DIR}/consumer-path"
  local git_consumer="${WORK_DIR}/consumer-git"
  run_step "create path consumer" create_consumer "${path_consumer}" "    path: ${PACKAGE_DIR}"
  run_step "build path consumer archives" build_consumer "${path_consumer}"
  run_step "create git consumer" create_consumer "${git_consumer}" "    git:\n      url: file://${PACKAGE_DIR}\n      ref: consumer-candidate"
  run_step "build git consumer archives" build_consumer "${git_consumer}"

  if [[ "$(git -C "${REPO_DIR}" rev-parse HEAD)" != "${FULL_COMMIT}" ||
        -n "$(git -C "${REPO_DIR}" status --porcelain)" ]]; then
    echo "Candidate changed during consumer qualification." >&2
    FAILED=1
  fi

  if [[ "${FAILED}" -ne 0 ]]; then
    exit 1
  fi
}

finalize_consumer() {
  local result=$?
  trap - EXIT
  set +e
  if [[ "${result}" -ne 0 ]]; then FAILED=1; fi
  end_evidence_log || { FAILED=1; result=1; }
  write_report || result=1
  finish_evidence "${REPORT_FILE}" || result=1
  exit "${result}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  start_evidence "${REPORT_FILE}"
  begin_evidence_log
  trap finalize_consumer EXIT
  main "$@"
fi

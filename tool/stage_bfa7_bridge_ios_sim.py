#!/usr/bin/env python3
"""Stage a verified Dev Bridge SDK for an arm64 iOS simulator only."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
import build_rgb_lib_bfa7 as native
import install_rgb_lib_ios as installer
from build_durable_onchain_ios_sim import admitted_output

TARGET = "aarch64-apple-ios-sim"
SLICE = ("ios-arm64-simulator", "iphonesimulator", ("arm64",), "-simulator")
SCOPE = "local-bfa7-dev-bridge-ios-arm64-simulator-only"
RUNTIME_KEYS = {
    "expectedVersion": "version", "expectedSourceRevision": "source_commit",
    "expectedBridgeVersion": "bridge_version", "expectedIntegrationTree": "integration_tree",
    "expectedOverlayPatchSha256": "overlay_patch_sha256",
    "expectedSourceLockSha256": "source_lock_sha256",
    "expectedSourceManifestSha256": "source_manifest_sha256",
}
BASELINE_KEYS = {
    "version": "version", "sourceRevision": "source_commit", "bridgeVersion": "bridge_version",
    "integrationTree": "integration_tree", "sourceOverlaySha256": "overlay_patch_sha256",
    "sourceLockSha256": "source_lock_sha256", "sourceManifestSha256": "source_manifest_sha256",
    "nativeOverlay": "native_overlay",
}

VERIFIER = '''
import hashlib
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parent
manifest = json.loads((root / "fixture-native-manifest.json").read_text())
if manifest.get("scope") != "local-bfa7-dev-bridge-ios-arm64-simulator-only" or manifest.get("releaseArtifact") is not False:
    raise SystemExit("Invalid local Dev Bridge fixture")
for name, expected in manifest["files"].items():
    path = root / name
    if path.resolve() != path or not path.is_file() or not path.is_relative_to(root):
        raise SystemExit("Unsafe local fixture file: " + name)
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(block)
    if digest.hexdigest() != expected:
        raise SystemExit("Changed local fixture file: " + name)
print("[rgb-lib] Verified local Dev Bridge arm64 simulator fixture.", file=sys.stderr)
'''


def clone(src, dst):
    subprocess.run(["cp", "-cR", str(src), str(dst)], check=True)


def file_hashes(root, relative):
    return {str(path.relative_to(root)): native.digest(path)
            for path in sorted((root / relative).rglob("*")) if path.is_file()}


def stage(output):
    native.use_bridge_candidate()
    manifest = json.loads(native.MANIFEST.read_text())
    native.verify_source(manifest)
    native.verify_dependencies(manifest)
    native.verify_generated(manifest)
    binary = native.target_binary(TARGET)
    stamp_path = native.WORK / "built-targets" / (TARGET + ".json")
    stamp = json.loads(stamp_path.read_text())
    if (stamp["identity"] != native.target_identity(manifest, TARGET)
            or stamp["sha256"] != native.digest(binary) or stamp["sizeBytes"] != binary.stat().st_size
            or installer.run("xcrun", "lipo", "-archs", binary) != "arm64"):
        raise ValueError("Simulator binary does not match its immutable build receipt.")
    provenance = native.metadata(manifest, "apple")
    provenance.update(targets=[TARGET], fixture_scope=SCOPE, release_artifact=False)
    if not provenance["durable_hosted_bridge"] or provenance["bridge_version"] != 6:
        raise ValueError("Not a durable Dev Bridge candidate.")
    expected_inputs = {**file_hashes(native.ROOT, "lib"), **file_hashes(native.ROOT, "ios/Classes")}
    expected_inputs.update({rel: native.digest(native.ROOT / rel) for rel in (
        "pubspec.yaml", "ios/rgb_sdk_flutter.podspec", "tool/rgb_lib_native_baseline.json",
    )})

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".stage-bfa7-bridge-", dir=output.parent) as temp:
        work = Path(temp)
        sdk = work / "sdk"
        sdk.mkdir(mode=0o700)
        # Copy only paths required by the Flutter plugin. Do not copy local
        # dependency overrides, build caches, other SDK or wallet data.
        for name in ("lib", "android", "tool", "licenses", "pubspec.yaml", "LICENSE"):
            clone(native.ROOT / name, sdk / name)
        for name in ("build", ".gradle"):
            directory = sdk / "android" / name
            if directory.is_dir():
                shutil.rmtree(directory)
        ios = sdk / "ios"
        ios.mkdir()
        for name in ("Classes", "Resources", "rgb_sdk_flutter.podspec", "RGBLightningNode.xcframework",
                     "RGBLightningNode.swift", "RGBLightningNodeFFI.h", "RGBLightningNodeFFI.modulemap"):
            clone(native.ROOT / "ios" / name, ios / name)
        for relative, digest in expected_inputs.items():
            if native.digest(native.ROOT / relative) != digest or native.digest(sdk / relative) != digest:
                raise ValueError("SDK wrapper changed during fixture staging: " + relative)

        release = work / "release"
        sources = release / "Sources/RgbLib"
        sources.mkdir(parents=True)
        shutil.copyfile(native.GENERATED / "swift/rgb_lib.swift", sources / "RgbLib.swift")
        headers = release / "rgb_libFFI.xcframework" / SLICE[0] / "Headers"
        headers.mkdir(parents=True)
        shutil.copyfile(native.GENERATED / "swift/rgb_libFFI.h", headers / "rgb_libFFI.h")
        os.link(binary, headers.parent / binary.name)
        for name, contents in native.release_attribution(manifest).items():
            (release / name).write_bytes(contents)
        (release / "version.json").write_text(json.dumps(provenance, sort_keys=True) + "\n")
        ffi, swift = installer.build_slice(release, work, *SLICE)
        bindings = ios / "RgbLibBindings"
        bindings.mkdir()
        for name, framework in (("RGBLib", swift), ("rgb_libFFI", ffi)):
            installer.run("xcodebuild", "-create-xcframework", "-framework", framework,
                          "-output", bindings / (name + ".xcframework"))
        if native.digest(binary) != stamp["sha256"]:
            raise ValueError("Simulator static library changed during staging.")

        pin_file = sdk / "tool/rgb_lib_native_baseline.json"
        pin = json.loads(pin_file.read_text())
        pin.update({key: provenance[value] for key, value in BASELINE_KEYS.items()})
        pin["features"]["durableHostedBridge"] = True
        pin["fixtureScope"] = SCOPE
        pin_file.write_text(json.dumps(pin, indent=2) + "\n")
        wire = sdk / "lib/src/wallet/rgb_lib/wire.dart"
        dart = wire.read_text()
        for dart_key, key in RUNTIME_KEYS.items():
            expression = r"(?m)(static const " + dart_key + r"\s*=\s*)(?:'[^']+'|\d+);"
            raw = provenance[key]
            dart, n = re.subn(expression, lambda m: m[1] + repr(raw) + ";", dart)
            if n != 1:
                raise ValueError("SDK native runtime admission changed: " + dart_key)
        wire.write_text(dart)

        spec = ios / "rgb_sdk_flutter.podspec"
        old = "File.expand_path('../tool/install_rgb_lib_ios.py', __dir__)"
        text = spec.read_text()
        if text.count(old) != 1:
            raise ValueError("SDK iOS install boundary changed.")
        spec.write_text(text.replace(old, "File.expand_path('../verify_local_bridge_native.py', __dir__)")
                        .replace("'i386',", "'i386 x86_64',"))
        (sdk / "verify_local_bridge_native.py").write_text(VERIFIER)
        files = {**file_hashes(sdk, "lib"), **file_hashes(sdk, "ios/Classes"),
                 **file_hashes(sdk, "ios/RgbLibBindings")}
        files.update({rel: native.digest(sdk / rel) for rel in (
            "pubspec.yaml", "ios/rgb_sdk_flutter.podspec", "tool/rgb_lib_native_baseline.json",
            "verify_local_bridge_native.py",
        )})
        record = {"scope": SCOPE, "releaseArtifact": False, "files": files,
                  "staticBuild": stamp, "provenance": provenance}
        (sdk / "fixture-native-manifest.json").write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
        subprocess.run([sys.executable, str(sdk / "verify_local_bridge_native.py")], check=True)
        sdk.rename(output)
    print("Staged local iOS Dev Bridge fixture: " + str(output))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    output = parser.parse_args().output.resolve()
    admitted_output(output)
    stage(output)


if __name__ == "__main__":
    main()

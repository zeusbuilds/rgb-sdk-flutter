#!/usr/bin/env python3
"""Stage a private, hash-verified arm64 Simulator SDK without official-file edits."""
import argparse
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
from build_durable_onchain_ios_sim import SDK, SCOPE, admitted_output, sha, source_snapshot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True, type=Path,
                        help="Successful build_durable_onchain_ios_sim.py evidence directory")
    parser.add_argument("--output", required=True, type=Path,
                        help="New separate fixture directory; never the official SDK")
    args = parser.parse_args()
    build, fixture = args.build.resolve(), args.output.resolve()
    if (build / "HOLD_STAGING").exists():
        raise RuntimeError("Staging is explicitly held; preserve this build and qualify a fresh candidate")
    admitted_output(fixture)
    inputs = json.loads((build / "build-inputs.json").read_text())
    result = json.loads((build / "build-result.json").read_text())
    if (inputs.get("scope") != SCOPE or inputs.get("releaseArtifact") is not False
            or result.get("scope") != SCOPE or result.get("releaseArtifact") is not False
            or result.get("exitCode") != 0 or result.get("sourceUnchanged") is not True
            or inputs.get("target") != "aarch64-apple-ios-sim"):
        raise RuntimeError("A successful unchanged-source arm64 Simulator build is required")
    if (sha(SDK / "native/durable_onchain_manifest.json") != inputs["overlayManifestSha256"]
            or any(sha(SDK / name) != digest for name, digest in {
                **inputs["overlayPatchFiles"], **inputs["toolFiles"]}.items())
            or source_snapshot(Path(inputs["source"]), inputs["overlayManifest"]) != inputs["sourceSnapshot"]):
        raise RuntimeError("Source overlay changed since compilation")
    library = Path(result["archive"])
    for name, expected in result["artifacts"].items():
        path = Path(name)
        if path.is_symlink() or not path.is_file() or sha(path) != expected["sha256"]:
            raise RuntimeError("Native binary changed since compilation")
    generated = build / "generated-swift"
    required = ("RGBLightningNode.swift", "RGBLightningNodeFFI.h", "RGBLightningNodeFFI.modulemap")
    if set(result["generatedFiles"]) != set(required):
        raise RuntimeError("Generated binding file set is not exact")
    for name in required:
        if sha(generated / name) != result["generatedFiles"][name]:
            raise RuntimeError("Generated bindings changed since compilation")
    if fixture == SDK or fixture in SDK.parents or fixture == Path(inputs["source"]):
        raise RuntimeError("Fixture must not replace an SDK or native source checkout")

    wrappers = [SDK / "pubspec.yaml"]
    for directory, pattern in (("lib", "*.dart"), ("ios/Classes", "*.swift"), ("pigeons", "*.dart")):
        wrappers.extend((SDK / directory).rglob(pattern))
    wrapper_hashes = {str(path.relative_to(SDK)): sha(path) for path in wrappers}

    def ignore(directory, names):
        ignored = {".git", ".buildlog", ".references", ".dart_tool", "build", "coverage",
                   ".gradle", ".idea", ".pub-cache", "__pycache__"} & set(names)
        if Path(directory) == SDK / "ios":
            ignored |= {"RGBLightningNode.xcframework", "RGBLightningNode.swift",
                        "RGBLightningNodeFFI.h", "RGBLightningNodeFFI.modulemap"} & set(names)
        return ignored

    shutil.copytree(SDK, fixture, ignore=ignore, symlinks=True)
    for name, digest in wrapper_hashes.items():
        if sha(fixture / name) != digest or sha(SDK / name) != digest:
            raise RuntimeError("SDK wrapper changed while staging")
    ios = fixture / "ios"
    framework = ios / "RGBLightningNode.xcframework"
    slice_dir = framework / "ios-arm64-simulator"
    headers = slice_dir / "Headers"
    headers.mkdir(parents=True)
    shutil.copy2(library, slice_dir / library.name)
    for name in required:
        shutil.copy2(generated / name, ios / name)
    shutil.copy2(generated / "RGBLightningNodeFFI.h", headers / "RGBLightningNodeFFI.h")
    shutil.copy2(generated / "RGBLightningNodeFFI.modulemap", headers / "module.modulemap")
    (framework / "Info.plist").write_bytes(plistlib.dumps({
        "CFBundlePackageType": "XFWK", "XCFrameworkFormatVersion": "1.0",
        "AvailableLibraries": [{"LibraryIdentifier": "ios-arm64-simulator", "LibraryPath": library.name,
                                "HeadersPath": "Headers", "SupportedArchitectures": ["arm64"],
                                "SupportedPlatform": "ios", "SupportedPlatformVariant": "simulator"}],
    }))
    podspec = ios / "rgb_sdk_flutter.podspec"
    original = podspec.read_text()
    start = "  artifact_script = File.expand_path('../tool/download_rln_ios.sh', __dir__)"
    finish = "    raise 'Failed to prepare verified iOS RLN artifacts. See the artifact diagnostics above.'\n  end"
    before, found, rest = original.partition(start)
    _, found_end, after = rest.partition(finish)
    if not found or not found_end or original.count(start) != 1:
        raise RuntimeError("Official artifact preparation block changed; inspect before staging")
    replacement = """  # Private arm64 Simulator fixture; official SDK artifact preparation is unchanged.
  fixture_verifier = File.expand_path('../verify_local_recovery_native.py', __dir__)
  unless system('python3', fixture_verifier, :out => $stderr, :err => $stderr)
    raise 'Local recovery Simulator fixture verification failed.'
  end"""
    staged = (before + replacement + after).replace("ios-arm64_x86_64-simulator", "ios-arm64-simulator")
    old = "'DEFINES_MODULE' => 'YES',"
    if staged.count(old) != 1:
        raise RuntimeError("Podspec compilation settings changed; inspect before staging")
    staged = staged.replace(old, old + "\n    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) RGB_RECOVERABLE_ONCHAIN_SEND',\n    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',")
    staged = staged.replace("    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',\n", "")
    podspec.write_text(staged)
    verifier = fixture / "verify_local_recovery_native.py"
    verifier.write_text('''#!/usr/bin/env python3
import hashlib,json,pathlib,sys
root=pathlib.Path(__file__).resolve().parent
manifest=json.loads((root/'fixture-native-manifest.json').read_text())
if (manifest.get('scope')!='local-ios-arm64-simulator-qualification-only'
    or manifest.get('releaseArtifact') is not False
    or manifest.get('architectures')!=['arm64'] or manifest.get('platform')!='ios-simulator'):
    raise SystemExit('Invalid local fixture scope')
for relative,digest in manifest['verifiedFiles'].items():
    key=pathlib.PurePosixPath(relative)
    if key.is_absolute() or not key.parts or any(p in ('.','..') for p in key.parts):
        raise SystemExit('Invalid local fixture path')
    path=root/relative
    parents=[root.joinpath(*key.parts[:i]) for i in range(1,len(key.parts)+1)]
    if any(p.is_symlink() for p in parents) or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:
        raise SystemExit('Local recovery fixture hash mismatch: '+relative)
print('[rln] Verified LOCAL arm64 Simulator recovery fixture; not a published release artifact.',file=sys.stderr)
''')
    verified = [
        "ios/RGBLightningNode.swift", "ios/RGBLightningNodeFFI.h", "ios/RGBLightningNodeFFI.modulemap",
        "ios/RGBLightningNode.xcframework/Info.plist",
        "ios/RGBLightningNode.xcframework/ios-arm64-simulator/librgb_lightning_node.a",
        "ios/RGBLightningNode.xcframework/ios-arm64-simulator/Headers/RGBLightningNodeFFI.h",
        "ios/RGBLightningNode.xcframework/ios-arm64-simulator/Headers/module.modulemap",
        "ios/rgb_sdk_flutter.podspec", "verify_local_recovery_native.py",
        "native/durable_onchain_manifest.json", *inputs["overlayPatchFiles"], *inputs["toolFiles"], *wrapper_hashes,
    ]
    manifest = {
        "schemaVersion": 1, "scope": SCOPE, "releaseArtifact": False,
        "overlayManifestSha256": inputs["overlayManifestSha256"],
        "overlayPatchFiles": inputs["overlayPatchFiles"],
        "buildInputsSha256": sha(build / "build-inputs.json"),
        "buildResultSha256": sha(build / "build-result.json"),
        "verifiedFiles": {name: sha(fixture / name) for name in sorted(set(verified))},
        "officialSdkNativeFilesModified": False, "architectures": ["arm64"], "platform": "ios-simulator",
        "notQualified": ["ios-device", "ios-simulator-x86_64", "android", "public-dependency-restore",
                         "published-native-provenance", "signed-distribution", "production-mainnet"],
    }
    (fixture / "fixture-native-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    subprocess.run([sys.executable, str(verifier)], check=True)
    print("Fixture manifest SHA-256: " + sha(fixture / "fixture-native-manifest.json"))


if __name__ == "__main__":
    main()

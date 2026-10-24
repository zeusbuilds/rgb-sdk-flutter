#!/usr/bin/env python3
"""Build and stage an explicitly local, arm64 iOS Simulator recovery candidate.

Requires the installed Rust 1.94.0 toolchain, Apple Xcode command-line tools and
bindgen. It never installs tools or replaces the official SDK native artifacts.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys

SDK = Path(__file__).resolve().parent.parent
SCOPE = "local-ios-arm64-simulator-qualification-only"
TARGET = "aarch64-apple-ios-sim"
RUST = "1.94.0"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, *, cwd=None, env=None):
    return subprocess.check_output(command, cwd=cwd, env=env, text=True).strip()


def git(root, *arguments):
    return run(["git", "-C", str(root), *arguments])


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def patch_paths(path):
    return set(re.findall(r"^\+\+\+ b/(.+)$", path.read_text(), re.M))


def source_snapshot(source, manifest):
    """Reject extra source edits, and bind all three effective source trees."""
    roots = {
        "rln": (source, manifest["rln"]["commit"]),
        "rgbLib": (source / manifest["rgbLib"]["checkoutPath"],
                   manifest["rgbLib"]["commit"]),
        "lightning": (source / "rust-lightning", manifest["lightningCommit"]),
    }
    snapshot = {}
    for name, (root, expected) in roots.items():
        if git(root, "rev-parse", "HEAD") != expected:
            raise RuntimeError(f"{name}: source commit does not match the manifest")
        if git(root, "diff", "--cached", "--name-only", "HEAD"):
            raise RuntimeError(f"{name}: staged source edits are unsupported; apply the reviewed patch to the worktree")
        changed = set(filter(None, git(root, "diff", "--name-only", "HEAD").splitlines()))
        if name == "lightning":
            if changed or git(root, "ls-files", "--others", "--exclude-standard"):
                raise RuntimeError("Lightning source must be clean at its pinned commit")
            allowed = set()
        else:
            allowed = patch_paths(SDK / "native" / manifest[name]["patch"])
            if not changed.issubset(allowed):
                raise RuntimeError(f"{name}: edits outside the reviewed source patch")
        untracked = set(filter(None, git(root, "ls-files", "--others", "--exclude-standard").splitlines()))
        extra = untracked - allowed
        if name == "rln":
            extra.discard(manifest["rgbLib"]["checkoutPath"].rstrip("/") + "/")
        if name == "rgbLib":
            # Cargo's cached-source admission marker is not compiler input.
            extra.discard(".cargo-ok")
        if extra:
            raise RuntimeError(f"{name}: unexpected untracked input: {sorted(extra)}")
        names = set(git(root, "ls-files").splitlines()) | (untracked & allowed)
        files = {}
        for relative in sorted(names):
            path = root / relative
            if path.is_file():
                files[relative] = sha(path)
            elif path.is_symlink():
                raise RuntimeError(f"{name}: broken source symlink: {relative}")
        snapshot[name] = {"commit": expected, "files": files}
    return snapshot


def admitted_output(path):
    if path.exists() or path.is_symlink():
        raise RuntimeError("Output must be a new directory; previous evidence is preserved")
    path = path.resolve()
    parent = path.parent
    while not parent.exists() and parent != parent.parent:
        parent = parent.parent
    repository = subprocess.run(["git", "-C", str(parent), "rev-parse", "--show-toplevel"],
                                capture_output=True, text=True, check=False)
    if repository.returncode == 0:
        root = Path(repository.stdout.strip()).resolve()
        relative = path.relative_to(root)
        result = subprocess.run(["git", "check-ignore", "--quiet", str(relative / "candidate")],
                                cwd=root, check=False)
        if result.returncode:
            raise RuntimeError("Output inside a Git repository must be ignored (for example build/)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path,
                        help="Existing exact-pin checkout with the reviewed source patches applied")
    parser.add_argument("--output", required=True, type=Path,
                        help="New, separate evidence and fixture directory; use an ignored location")
    parser.add_argument("--target-dir", type=Path,
                        help="Optional existing Cargo cache; defaults to OUTPUT/cargo-target")
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise RuntimeError("This candidate builder supports arm64 macOS hosts only")
    source, output = args.source.resolve(), args.output.resolve()
    admitted_output(output)
    if source == output or source in output.parents or output in source.parents:
        raise RuntimeError("Source and output must be separate trees")
    target_dir = args.target_dir.resolve() if args.target_dir else output / "cargo-target"
    if (target_dir == SDK or target_dir == source or source in target_dir.parents
            or target_dir in source.parents or target_dir in SDK.parents
            or any(path == target_dir or path in target_dir.parents for path in (SDK / "ios", SDK / "android"))):
        raise RuntimeError("Cargo target directory cannot replace a source tree")
    check = [sys.executable, str(SDK / "tool/refresh_durable_onchain_patches.py"),
             "--source", str(source), "--check"]
    subprocess.run(check, check=True)
    manifest_path = SDK / "native/durable_onchain_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    before = source_snapshot(source, manifest)
    patch_hashes = {str(Path("native") / manifest[key]["patch"]):
                    sha(SDK / "native" / manifest[key]["patch"]) for key in ("rln", "rgbLib")}
    tool_hashes = {"tool/" + name: sha(SDK / "tool" / name) for name in (
        "build_durable_onchain_ios_sim.py", "stage_durable_onchain_ios_sim.py",
        "test_durable_onchain_ios_sim.py", "refresh_durable_onchain_patches.py")}
    for key in ("rln", "rgbLib"):
        if sha(SDK / "native" / manifest[key]["patch"]) != manifest[key]["patchSha256"]:
            raise RuntimeError("Source patch hash does not match the manifest")
    env = os.environ.copy()
    for name in ("RUSTFLAGS", "CARGO_ENCODED_RUSTFLAGS"):
        env.pop(name, None)
    sim_sdk = run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"])
    env.update({
        "CARGO_TARGET_DIR": str(target_dir), "CARGO_NET_GIT_FETCH_WITH_CLI": "true",
        "CARGO_BUILD_JOBS": "2", "CARGO_INCREMENTAL": "0",
        "CARGO_PROFILE_RELEASE_DEBUG": "0", "CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG": "0",
        "AWS_LC_SYS_EXTERNAL_BINDGEN": "1", "IPHONEOS_DEPLOYMENT_TARGET": "18.5",
        "CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS": "-C link-arg=-mios-simulator-version-min=18.5",
        "BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim": "--sysroot=" + sim_sdk,
    })
    inputs = {
        "schemaVersion": 1, "scope": SCOPE, "releaseArtifact": False,
        "source": str(source), "sourceSnapshot": before,
        "overlayManifest": manifest, "overlayManifestSha256": sha(manifest_path),
        "overlayPatchFiles": patch_hashes, "toolFiles": tool_hashes,
        "target": TARGET, "profile": "release",
        "features": ["uniffi", "vls", "vss"], "targetDir": str(target_dir),
        "rust": run(["rustc", "+" + RUST, "-Vv"]),
        "cargo": run(["cargo", "+" + RUST, "-V"]),
        "bindgen": run(["bindgen", "--version"]),
        "xcode": run(["xcodebuild", "-version"]), "sdkPath": sim_sdk,
        "sdkVersion": run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]),
        "environment": {key: value for key, value in env.items()
                        if key.startswith("CARGO_PROFILE_") or key in (
                            "DEVELOPER_DIR", "CARGO_TARGET_DIR", "CARGO_NET_GIT_FETCH_WITH_CLI",
                            "CARGO_BUILD_JOBS", "CARGO_INCREMENTAL", "AWS_LC_SYS_EXTERNAL_BINDGEN",
                            "IPHONEOS_DEPLOYMENT_TARGET", "CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS",
                            "BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim")},
        "startedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    output.mkdir(parents=True)
    write_json(output / "build-inputs.json", inputs)
    commands = [
        ["cargo", "+" + RUST, "build", "--locked", "--release", "--features", "uniffi,vls,vss",
         "--lib", "--target", TARGET],
        ["cargo", "+" + RUST, "build", "--locked", "--release", "--manifest-path",
         str(source / "bindings/uniffi-bindgen/Cargo.toml")],
    ]
    result = {"scope": SCOPE, "releaseArtifact": False, "commands": commands,
              "exitCode": None, "sourceUnchanged": False}
    try:
        for index, command in enumerate(commands):
            with (output / f"build-{index + 1}.log").open("w") as log:
                subprocess.run(command, cwd=source, env=env, stdout=log,
                               stderr=subprocess.STDOUT, check=True)
        subprocess.run(check, check=True)
        if (source_snapshot(source, manifest) != before or sha(manifest_path) != inputs["overlayManifestSha256"]
                or any(sha(SDK / name) != digest for name, digest in {**patch_hashes, **tool_hashes}.items())):
            raise RuntimeError("Native source, checked-in overlay or build tooling changed during compilation")
        archive = target_dir / TARGET / "release/librgb_lightning_node.a"
        dylib = target_dir / TARGET / "release/librgb_lightning_node.dylib"
        generator = target_dir / "release/uniffi-bindgen"
        generated = output / "generated-swift"
        command = [str(generator), "generate", str(source / "bindings/rgb_lightning_node.udl"),
                   "--lib-file", str(archive), "--crate", "rgb_lightning_node", "--language", "swift",
                   "--no-format", "--config", str(source / "uniffi.toml"), "--out-dir", str(generated)]
        with (output / "generate-swift.log").open("w") as log:
            subprocess.run(command, cwd=source, env=env, stdout=log,
                           stderr=subprocess.STDOUT, check=True)
        swift = (generated / "RGBLightningNode.swift").read_text()
        for name in ("prepareOnchainSend", "commitOnchainSend", "onchainSendStatus", "cancelOnchainSend"):
            if name + "(requestJson:" not in swift:
                raise RuntimeError("Generated binding is missing full-request method: " + name)
        result.update({"exitCode": 0, "sourceUnchanged": True, "generationCommand": command,
                       "generatorSha256": sha(generator),
                       "artifacts": {str(path): {"sha256": sha(path), "sizeBytes": path.stat().st_size}
                                     for path in (archive, dylib)}, "archive": str(archive),
                       "generatedFiles": {path.name: sha(path) for path in generated.iterdir() if path.is_file()}})
    except Exception as error:
        result["exitCode"] = getattr(error, "returncode", 1)
        result["failure"] = type(error).__name__
        raise
    finally:
        result["finishedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write_json(output / "build-result.json", result)
    subprocess.run([sys.executable, str(SDK / "tool/stage_durable_onchain_ios_sim.py"),
                    "--build", str(output), "--output", str(output / "fixture-sdk")], check=True)
    print("Local simulator fixture ready: " + str(output / "fixture-sdk"))
    print("This is not a published or production-qualified native artifact.")


if __name__ == "__main__":
    main()

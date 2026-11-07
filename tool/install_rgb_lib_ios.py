#!/usr/bin/env python3
"""Install the pinned RGB Lib iOS artifact, with isolated UniFFI symbols."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile
import plistlib


ROOT = Path(__file__).resolve().parent.parent
IOS = ROOT / "ios"
PIN = json.loads((ROOT / "tool/rgb_lib_native_baseline.json").read_text())
TARGET = IOS / "RgbLibBindings"
MIN_IOS = PIN["ios"]["minIosVersion"]
SLICES = (
    ("ios-arm64", "iphoneos", ("arm64",), ""),
    ("ios-arm64_x86_64-simulator", "iphonesimulator", ("arm64", "x86_64"), "-simulator"),
)
ATTRIBUTION_FILES = (
    "LICENSE.rgb-lib.txt", "LICENSE.MPL-2.0.txt", "NOTICE.txt", "source-manifest.json",
)


def run(*args):
    env = os.environ.copy()
    xcode = Path("/Applications/Xcode.app/Contents/Developer")
    if xcode.is_dir():
        env.setdefault("DEVELOPER_DIR", str(xcode))
    return subprocess.check_output(args, text=True, env=env).strip()


def sha256(path):
    checksum = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(block)
    return checksum.hexdigest()


def verify_archive(archive):
    if archive.stat().st_size != PIN["ios"]["sizeBytes"] or sha256(archive) != PIN["ios"]["sha256"]:
        raise ValueError("RGB Lib iOS archive does not match the verified release pin.")


def verify_provenance(provenance):
    fields = {
        "version": "version", "bridge_version": "bridgeVersion",
        "source_commit": "sourceRevision", "source_lock_sha256": "sourceLockSha256",
        "integration_tree": "integrationTree", "overlay_patch_sha256": "sourceOverlaySha256",
        "source_manifest_sha256": "sourceManifestSha256", "native_overlay": "nativeOverlay",
    }
    for archive_key, pin_key in fields.items():
        expected = PIN.get(pin_key)
        if expected is None or provenance.get(archive_key) != expected:
            raise ValueError("RGB Lib iOS provenance does not match the release pin: " + archive_key)


def build_identity():
    return {"pin": PIN, "xcode": run("xcodebuild", "-version"), "installer": sha256(Path(__file__))}


def framework_hashes(directory):
    files = {}
    for name in ("RGBLib", "rgb_libFFI"):
        xcframework = directory / f"{name}.xcframework"
        if not (xcframework / "Info.plist").is_file():
            raise ValueError("RGB Lib xcframework is missing.")
        for slice_id, _, _, _ in SLICES:
            if not (xcframework / slice_id / f"{name}.framework" / name).is_file():
                raise ValueError("RGB Lib framework slice is missing.")
        files.update({str(file.relative_to(directory)): sha256(file)
                      for file in xcframework.rglob("*") if file.is_file()})
    return files


def installed_matches(identity):
    try:
        manifest = json.loads((TARGET / "manifest.json").read_text())
        return manifest == {"identity": identity, "files": framework_hashes(TARGET)}
    except (OSError, ValueError):
        return False


def prepare_framework(directory, name):
    framework = directory / f"{name}.framework"
    bundle_suffix = name.replace("_", "-").lower()
    framework.mkdir(parents=True)
    (framework / "Info.plist").write_bytes(plistlib.dumps({
        "CFBundleDevelopmentRegion": "en",
        "CFBundleExecutable": name,
        "CFBundleIdentifier": f"org.utexo.rgb-lib-bfa.{bundle_suffix}",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": name,
        "CFBundlePackageType": "FMWK",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1",
        "MinimumOSVersion": MIN_IOS,
    }))
    return framework


def copy_attribution(release, framework):
    for filename in ATTRIBUTION_FILES:
        shutil.copyfile(release / filename, framework / filename)


def build_slice(release, work, slice_id, sdk, architectures, suffix):
    sdk_path = run("xcrun", "--sdk", sdk, "--show-sdk-path")
    compiler_help = run("xcrun", "swiftc", "-help")
    language_flag = "-language-mode" if "-language-mode " in compiler_help else "-swift-version"
    native = release / "rgb_libFFI.xcframework" / slice_id
    source = release / "Sources/RgbLib/RgbLib.swift"
    directory = work / slice_id
    ffi = prepare_framework(directory, "rgb_libFFI")
    swift = prepare_framework(directory, "RGBLib")
    copy_attribution(release, ffi)
    copy_attribution(release, swift)
    modules = swift / "Modules/RGBLib.swiftmodule"
    modules.mkdir(parents=True)
    (ffi / "Headers").mkdir()
    shutil.copyfile(native / "Headers/rgb_libFFI.h", ffi / "Headers/rgb_libFFI.h")
    (ffi / "Modules").mkdir()
    (ffi / "Modules/module.modulemap").write_text(
        'framework module rgb_libFFI { umbrella header "rgb_libFFI.h" export * }\n'
    )
    shutil.copyfile(release / "version.json", swift / "rgb-lib-bfa-version.json")

    ffi_binaries = []
    swift_binaries = []
    for arch in architectures:
        arch_dir = directory / arch
        arch_dir.mkdir()
        arch_ffi = arch_dir / ffi.name
        shutil.copytree(ffi, arch_ffi)
        static_lib = native / "librgblibuniffi.a"
        if len(architectures) > 1:
            thin_lib = arch_dir / static_lib.name
            run("xcrun", "lipo", static_lib, "-thin", arch, "-output", thin_lib)
            static_lib = thin_lib
        target = f"{arch}-apple-ios{MIN_IOS}{suffix}"
        binary = arch_ffi / "rgb_libFFI"
        # Export only UniFFI entry points. This keeps the Rust/RGB/crypto
        # symbols private so an app can link its existing static RLN as well.
        run("xcrun", "--sdk", sdk, "clang", "-target", target, "-isysroot", sdk_path,
            "-dynamiclib", "-Wl,-force_load," + str(static_lib),
            "-Wl,-exported_symbol,_uniffi_rgblibuniffi_*",
            "-Wl,-exported_symbol,_ffi_rgblibuniffi_*", "-Wl,-dead_strip",
            "-install_name", "@rpath/rgb_libFFI.framework/rgb_libFFI",
            "-framework", "Security", "-framework", "SystemConfiguration",
            "-framework", "CoreFoundation", "-lc++", "-lresolv", "-lsqlite3",
            "-lz", "-liconv", "-o", binary)
        ffi_binaries.append(binary)
        module = modules / f"{arch}-apple-ios{suffix}"
        swift_binary = arch_dir / "RGBLib"
        run("xcrun", "--sdk", sdk, "swiftc", "-target", target, "-sdk", sdk_path,
            "-module-name", "RGBLib", language_flag, "5", "-parse-as-library", "-emit-library", "-O",
            "-wmo", "-enable-library-evolution",
            "-emit-module-interface-path", str(module) + ".swiftinterface",
            "-emit-private-module-interface-path", str(module) + ".private.swiftinterface",
            "-emit-module-path", str(module) + ".swiftmodule",
            "-module-cache-path", work / "module-cache",
            "-F", arch_dir, "-framework", "rgb_libFFI",
            "-Xlinker", "-install_name", "-Xlinker", "@rpath/RGBLib.framework/RGBLib",
            "-o", swift_binary, source)
        swift_binaries.append(swift_binary)

    run("xcrun", "lipo", "-create", *ffi_binaries, "-output", ffi / "rgb_libFFI")
    run("xcrun", "lipo", "-create", *swift_binaries, "-output", swift / "RGBLib")
    return ffi, swift


def install(work, identity):
    archive_override = os.environ.get("RGB_LIB_IOS_ARCHIVE_PATH")
    cache = Path(os.environ.get("RGB_LIB_IOS_CACHE_DIR",
                               Path.home() / ".cache/rgb-sdk-flutter/rgb-lib-ios"))
    cached_archive = cache / f'{PIN["version"]}.zip'
    archive = work / "release.zip"
    if archive_override:
        shutil.copyfile(archive_override, archive)
    elif cached_archive.is_file():
        shutil.copyfile(cached_archive, archive)
    elif os.environ.get("RGB_LIB_IOS_OFFLINE") == "1":
        raise ValueError("RGB Lib iOS archive is unavailable in offline mode.")
    else:
        subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error",
                        "--retry", "2", "--connect-timeout", "15", "--max-time", "600",
                        PIN["ios"]["url"], "--output", archive], check=True)
    verify_archive(archive)
    if not archive_override and not cached_archive.is_file():
        cache.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=cache, delete=False) as temporary:
            pending = Path(temporary.name)
        try:
            shutil.copyfile(archive, pending)
            pending.replace(cached_archive)
        finally:
            pending.unlink(missing_ok=True)

    release = work / "release"
    with zipfile.ZipFile(archive) as source:
        source.extract("version.json", release)
        for filename in ATTRIBUTION_FILES:
            source.extract(filename, release)
        source.extract("Sources/RgbLib/RgbLib.swift", release)
        for slice_id, _, _, _ in SLICES:
            for file in ("librgblibuniffi.a", "Headers/rgb_libFFI.h"):
                source.extract(f"rgb_libFFI.xcframework/{slice_id}/{file}", release)
    provenance = json.loads((release / "version.json").read_text())
    verify_provenance(provenance)

    print("[rgb-lib] Building verified iOS and simulator frameworks.", flush=True)
    slices = [build_slice(release, work, *slice_info) for slice_info in SLICES]
    stage = work / "install"
    stage.mkdir()
    for index, name in enumerate(("rgb_libFFI", "RGBLib")):
        frameworks = [arg for slice_files in slices for arg in ("-framework", slice_files[index])]
        run("xcodebuild", "-create-xcframework", *frameworks,
            "-output", stage / f"{name}.xcframework")
    (stage / "manifest.json").write_text(json.dumps({
        "identity": identity, "files": framework_hashes(stage),
    }, sort_keys=True) + "\n")
    previous = work / "previous"
    if TARGET.exists():
        TARGET.rename(previous)
    try:
        stage.rename(TARGET)
    except OSError:
        if previous.exists():
            previous.rename(TARGET)
        raise


def main():
    if sys.platform != "darwin":
        return
    identity = build_identity()
    with (IOS / ".rgb-lib-install.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not installed_matches(identity):
            with tempfile.TemporaryDirectory(prefix=".rgb-lib-install.", dir=IOS) as temp:
                install(Path(temp), identity)
    print(f'[rgb-lib] Verified iOS bindings {PIN["version"]}.')


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(f"[rgb-lib] Native preparation command failed with status {error.returncode}.")
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        sys.exit(f"[rgb-lib] {error}")

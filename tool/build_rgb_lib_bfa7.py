#!/usr/bin/env python3
"""Build the immutable Flutter BFA.7 overlay without operating any wallet/stack.

The tracked source manifest and overlay are the admission boundary. Existing
source/build directories are verified, never reset or silently overwritten.
Run ``seal`` only after reviewing changes to the disposable source checkout.
Every normal preparation/build uses the sealed patch and Cargo --locked.
"""

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / "native/rgb_l1"
MANIFEST = NATIVE / "source-manifest.json"
WORK = ROOT / ".buildlog/bfa7-finalize"
SOURCE = WORK / "source"
ESPLORA = WORK / "esplora-client"
SQLITE = WORK / "sqlite3-sys"
TARGET = WORK / "target"
GENERATED = WORK / "generated"
ARTIFACTS = WORK / "artifacts"


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def read_manifest():
    manifest = json.loads(MANIFEST.read_text())
    if manifest["source"]["revision"] != "9ec49c08be2e68f08521281e3efbd760ec989cb9":
        raise ValueError("BFA.7 source revision requires an explicit tooling review.")
    return manifest


def run(*args, cwd=None, env=None):
    if env is None:
        env = os.environ.copy()
        xcode = Path("/Applications/Xcode.app/Contents/Developer")
        if xcode.is_dir():
            env.setdefault("DEVELOPER_DIR", str(xcode))
    return subprocess.check_output(
        [str(arg) for arg in args], cwd=cwd, env=env, text=True
    ).strip()


def git(directory, *args):
    return run("git", "-c", "core.hooksPath=/dev/null", "-C", directory, *args)


def checked_patch(entry):
    path = (NATIVE / entry["path"]).resolve(strict=True)
    if not path.is_relative_to(NATIVE.resolve()) or digest(path) != entry["sha256"]:
        raise ValueError("Native patch digest/path differs from the admitted source manifest.")
    return path


def verify_source(manifest, *, base_only=False):
    source = manifest["source"]
    if (git(SOURCE, "rev-parse", "HEAD") != source["revision"] or
            git(SOURCE, "rev-parse", "HEAD^{tree}") != source["tree"]):
        raise ValueError("Prepared BFA.7 source is not the pinned commit/tree.")
    expected = source["coreOverlayTree"] if base_only else manifest["integration"]["tree"]
    if not expected:
        raise ValueError("The Flutter integration overlay has not been sealed.")
    if (git(SOURCE, "write-tree") != expected or
            git(SOURCE, "diff", "--name-only") or
            git(SOURCE, "ls-files", "--others", "--exclude-standard")):
        raise ValueError("Prepared BFA.7 source has unadmitted changes; preserve it for review.")
    if not base_only:
        lock = SOURCE / "bindings/uniffi/Cargo.lock"
        if digest(lock) != manifest["integration"]["uniffiLockSha256"]:
            raise ValueError("Prepared UniFFI lockfile differs from its sealed digest.")


def extract_crate(package, destination, prefix):
    with tarfile.open(fileobj=io.BytesIO(package), mode="r:gz") as archive:
        entries = archive.getmembers()
        for entry in entries:
            parts = Path(entry.name).parts
            if (not parts or parts[0] != prefix or ".." in parts or
                    ".git" in parts or not (entry.isfile() or entry.isdir())):
                raise ValueError("Unsafe entry in the pinned Esplora crate.")
        # Every member was restricted to regular files/directories under one
        # trusted prefix above. Support the repository's Python 3.9 baseline.
        archive.extractall(destination, members=entries)


def prepare_esplora(manifest):
    pin = manifest["esplora"]
    patch = checked_patch(pin["patch"])
    if not ESPLORA.exists():
        package_name = "esplora-client-" + pin["version"]
        cargo_home = Path(os.environ.get("CARGO_HOME", Path.home() / ".cargo"))
        cached = next((cargo_home / "registry/cache").glob("*/" + package_name + ".crate"), None)
        package = cached.read_bytes() if cached else download(
            "https://static.crates.io/crates/esplora-client/" + package_name + ".crate",
            maximum=2 * 1024 * 1024,
        )
        if hashlib.sha256(package).hexdigest() != pin["crateSha256"]:
            raise ValueError("Esplora crate checksum mismatch.")
        WORK.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=WORK) as temporary:
            extract_crate(package, temporary, package_name)
            staged = Path(temporary) / package_name
            git(staged, "init", "--quiet")
            git(staged, "add", "--force", "--all")
            git(staged, "apply", "--check", "--index", patch)
            git(staged, "apply", "--index", patch)
            if git(staged, "write-tree") != pin["overlayTree"]:
                raise ValueError("Esplora overlay tree mismatch.")
            staged.rename(ESPLORA)
    if (git(ESPLORA, "write-tree") != pin["overlayTree"] or
            git(ESPLORA, "diff", "--name-only") or
            git(ESPLORA, "ls-files", "--others", "--exclude-standard")):
        raise ValueError("Existing guarded Esplora source differs from its admitted tree.")


def prepare_sqlite(manifest):
    pin = manifest.get("sqlite3")
    if pin is None:
        return
    patch = checked_patch(pin["patch"])
    if not SQLITE.exists():
        package_name = "libsqlite3-sys-" + pin["version"]
        cargo_home = Path(os.environ.get("CARGO_HOME", Path.home() / ".cargo"))
        cached = next((cargo_home / "registry/cache").glob("*/" + package_name + ".crate"), None)
        package = cached.read_bytes() if cached else download(
            "https://static.crates.io/crates/libsqlite3-sys/" + package_name + ".crate",
            maximum=20 * 1024 * 1024,
        )
        if hashlib.sha256(package).hexdigest() != pin["crateSha256"]:
            raise ValueError("SQLite crate checksum mismatch.")
        WORK.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=WORK) as temporary:
            extract_crate(package, temporary, package_name)
            staged = Path(temporary) / package_name
            git(staged, "init", "--quiet")
            git(staged, "add", "--force", "--all")
            git(staged, "apply", "--check", "--index", patch)
            git(staged, "apply", "--index", patch)
            if git(staged, "write-tree") != pin["overlayTree"]:
                raise ValueError("SQLite overlay tree mismatch.")
            staged.rename(SQLITE)
    if (git(SQLITE, "write-tree") != pin["overlayTree"] or
            git(SQLITE, "diff", "--name-only") or
            git(SQLITE, "ls-files", "--others", "--exclude-standard")):
        raise ValueError("Existing SQLite source differs from its admitted tree.")


def prepare(manifest, source_override=None):
    integration = manifest["integration"]
    overlay = checked_patch({"path": integration["patch"], "sha256": integration["patchSha256"]})
    prepare_esplora(manifest)
    prepare_sqlite(manifest)
    if SOURCE.exists():
        verify_source(manifest)
        return
    WORK.mkdir(parents=True, exist_ok=True)
    source = str(Path(source_override).resolve(strict=True)) if source_override else manifest["source"]["repository"]
    with tempfile.TemporaryDirectory(dir=WORK) as temporary:
        staged = Path(temporary) / "source"
        staged.mkdir()
        git(staged, "init", "--quiet")
        git(staged, "-c", "http.followRedirects=false", "fetch", "--quiet", "--depth=1",
            "--no-tags", source, manifest["source"]["revision"])
        git(staged, "checkout", "--quiet", "--detach", "FETCH_HEAD")
        if git(staged, "rev-parse", "HEAD^{tree}") != manifest["source"]["tree"]:
            raise ValueError("Fetched source tree mismatch.")
        for entry in manifest["corePatches"]:
            patch = checked_patch(entry)
            git(staged, "apply", "--check", "--index", patch)
            git(staged, "apply", "--index", patch)
        if git(staged, "write-tree") != manifest["source"]["coreOverlayTree"]:
            raise ValueError("BFA.7 core safeguard overlay tree mismatch.")
        git(staged, "apply", "--check", "--index", overlay)
        git(staged, "apply", "--index", overlay)
        if git(staged, "write-tree") != integration["tree"]:
            raise ValueError("Flutter integration overlay tree mismatch.")
        staged.rename(SOURCE)
    verify_source(manifest)


def seal(manifest):
    """Explicit developer operation; never used by consumer acquisition/build."""
    source = manifest["source"]
    if (git(SOURCE, "rev-parse", "HEAD") != source["revision"] or
            git(SOURCE, "write-tree") != source["coreOverlayTree"]):
        raise ValueError("Seal requires the exact safeguard overlay in the index.")
    git(SOURCE, "add", "--intent-to-add", "--all")
    patch = subprocess.check_output(["git", "-C", str(SOURCE), "diff", "--binary"])
    if not patch:
        raise ValueError("No integration changes to seal.")
    integration = manifest["integration"]
    destination = NATIVE / integration["patch"]
    destination.write_bytes(patch)
    git(SOURCE, "add", "--all")
    integration.update(
        patchSha256=digest(destination), tree=git(SOURCE, "write-tree"),
        uniffiLockSha256=digest(SOURCE / "bindings/uniffi/Cargo.lock"),
    )
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    verify_source(manifest)


def download(url, maximum=128 * 1024 * 1024):
    if not url.startswith("https://"):
        raise ValueError("Native build inputs require HTTPS.")
    with urllib.request.urlopen(url, timeout=60) as response:
        value = response.read(maximum + 1)
    if len(value) > maximum:
        raise ValueError("Native build download exceeds its size bound.")
    return value


def build_env(manifest, target=None):
    env = os.environ.copy()
    env.pop("LIBSQLITE3_FLAGS", None)
    xcode = Path("/Applications/Xcode.app/Contents/Developer")
    if xcode.is_dir():
        env.setdefault("DEVELOPER_DIR", str(xcode))
    env.update(CARGO_TARGET_DIR=str(TARGET), CARGO_BUILD_JOBS="2", CARGO_INCREMENTAL="0",
               CARGO_PROFILE_RELEASE_DEBUG="0", CARGO_PROFILE_RELEASE_STRIP="debuginfo",
               IPHONEOS_DEPLOYMENT_TARGET=manifest["build"]["minIosVersion"])
    if target and "apple-ios" in target:
        sdk = "iphoneos" if target == "aarch64-apple-ios" else "iphonesimulator"
        # Codex/Xcode shells can inherit the CLT macOS SDK. DEVELOPER_DIR alone
        # does not supersede SDKROOT in cc-rs or bindgen.
        env["SDKROOT"] = run("xcrun", "--sdk", sdk, "--show-sdk-path", env=env)
        # AWS-LC's supported cc builder also works when a project path contains
        # '<' or '>', which CMake rejects in custom output names.
        env["AWS_LC_SYS_CMAKE_BUILDER"] = "0"
        sqlite = manifest.get("sqlite3")
        if sqlite is not None:
            flags = sqlite["iosCompileFlags"]
            if flags != ["SQLITE_ENABLE_LOCKING_STYLE=0", "RGB_SQLITE_IOS_CONTAINER_ONLY=1"]:
                raise ValueError("Unreviewed iOS SQLite compile flags.")
            # Preserve Apple's full-fsync support. Only the sealed container VFS
            # exception and POSIX locking selection are admitted here.
            env["LIBSQLITE3_FLAGS"] = " ".join("-D" + flag for flag in flags)
    if target and target.endswith("-linux-android"):
        sdk = Path(env.get("ANDROID_HOME", env.get("ANDROID_SDK_ROOT", Path.home() / "Library/Android/sdk")))
        ndk = sdk / "ndk" / manifest["build"]["androidNdk"]
        llvm = ndk / "toolchains/llvm/prebuilt/darwin-x86_64/bin"
        api = manifest["build"]["minAndroidApi"]
        prefix = "aarch64-linux-android" if target.startswith("aarch64-") else "x86_64-linux-android"
        cc = llvm / f"{prefix}{api}-clang"
        if not cc.is_file() or f'Pkg.Revision = {manifest["build"]["androidNdk"]}' not in (ndk / "source.properties").read_text():
            raise ValueError("The exact pinned Android NDK is unavailable.")
        key = target.replace("-", "_")
        sysroot = llvm.parent / "sysroot"
        env.update({f"CARGO_TARGET_{key.upper()}_LINKER": str(cc), f"CC_{key}": str(cc),
                    f"CXX_{key}": str(cc) + "++", f"AR_{key}": str(llvm / "llvm-ar"),
                    f"RANLIB_{key}": str(llvm / "llvm-ranlib"),
                    f"BINDGEN_EXTRA_CLANG_ARGS_{key}":
                    f'--target={prefix}{api} --sysroot="{sysroot}" -isystem "{sysroot / "usr/include" / prefix}"',
                    "ANDROID_NDK_ROOT": str(ndk), "AWS_LC_SYS_CMAKE_BUILDER": "0",
                    f"CARGO_TARGET_{key.upper()}_RUSTFLAGS":
                    "-C link-arg=-Wl,-z,max-page-size=16384 -C link-arg=-Wl,-z,common-page-size=16384 "
                    "-C link-arg=-Wl,-z,relro -C link-arg=-Wl,-z,now -C link-arg=-Wl,-z,noexecstack"})
    return env


def cargo(manifest, *args, target=None):
    return run("cargo", "+" + manifest["build"]["rust"], *args,
               "--manifest-path", SOURCE / "bindings/uniffi/Cargo.toml", env=build_env(manifest, target))


def verify_dependencies(manifest):
    for entry in manifest["corePatches"]:
        checked_patch(entry)
    integration = manifest["integration"]
    checked_patch({"path": integration["patch"], "sha256": integration["patchSha256"]})
    # The path-patched dependency is outside SOURCE; its clean tree must be
    # checked independently before and after builds, including cached builds.
    prepare_esplora(manifest)
    prepare_sqlite(manifest)


def generate(manifest):
    verify_source(manifest)
    verify_dependencies(manifest)
    for relative, expected in manifest["build"]["bindgenFiles"].items():
        if digest(NATIVE / relative) != expected:
            raise ValueError("UniFFI generator input differs from its admitted digest.")
    if GENERATED.exists():
        shutil.rmtree(GENERATED)
    GENERATED.mkdir(parents=True)
    config = WORK / "uniffi.toml"
    config.write_text('[defaults.bindings.kotlin]\npackage_name = "com.utexo"\ncdylib_name = "rgblibuniffi"\n'
                      '[defaults.bindings.swift]\nmodule_name = "rgb_lib"\nffi_module_name = "rgb_libFFI"\n')
    run("cargo", "+" + manifest["build"]["rust"], "build", "--locked", "--release",
        "--manifest-path", NATIVE / "bindgen-tool/Cargo.toml", env=build_env(manifest))
    bindgen = TARGET / "release/flutter-rgb-lib-bindgen"
    for language in ("kotlin", "swift"):
        run(bindgen, "generate", SOURCE / "bindings/uniffi/src/rgb-lib.udl", "--language", language,
            "--config", config, "--out-dir", GENERATED / language, "--no-format")
    generated = {str(path.relative_to(GENERATED)): digest(path)
                 for language in ("kotlin", "swift")
                 for path in (GENERATED / language).rglob("*") if path.is_file()}
    (GENERATED / "manifest.json").write_text(json.dumps({
        "integrationTree": manifest["integration"]["tree"],
        "bindgenFiles": manifest["build"]["bindgenFiles"], "files": generated,
    }, indent=2, sort_keys=True) + "\n")


def verify_generated(manifest):
    recorded = json.loads((GENERATED / "manifest.json").read_text())
    if (recorded["integrationTree"] != manifest["integration"]["tree"] or
            recorded["bindgenFiles"] != manifest["build"]["bindgenFiles"]):
        raise ValueError("Generated binding source identity is stale.")
    actual = {str(path.relative_to(GENERATED)): digest(path)
              for language in ("kotlin", "swift")
              for path in (GENERATED / language).rglob("*") if path.is_file()}
    if recorded["files"] != actual:
        raise ValueError("Generated binding content differs from its recorded source.")


def build(manifest, selected):
    verify_source(manifest)
    verify_dependencies(manifest)
    admitted = manifest["build"]["targets"]
    targets = admitted if not selected else selected
    for target in targets:
        verify_source(manifest)
        if target not in admitted:
            raise ValueError("Unadmitted native build target: " + target)
        if shutil.disk_usage(WORK).free < 6 * 1024**3:
            raise ValueError("Fewer than 6 GiB free; preserve artifacts and recover space before building.")
        identity = target_identity(manifest, target)
        cargo(manifest, "build", "--locked", "--release", "--lib", "--target", target, target=target)
        verify_source(manifest)
        verify_dependencies(manifest)
        if target_identity(manifest, target) != identity:
            raise ValueError("Native source/tool inputs changed during compilation.")
        binary = target_binary(target)
        stamps = WORK / "built-targets"
        stamps.mkdir(exist_ok=True)
        (stamps / (target + ".json")).write_text(json.dumps({
            "identity": identity, "sha256": digest(binary), "sizeBytes": binary.stat().st_size,
        }, indent=2, sort_keys=True) + "\n")
        print("Built " + target, flush=True)


def target_binary(target):
    return TARGET / target / "release" / (
        "librgblibuniffi.so" if target.endswith("-linux-android") else "librgblibuniffi.a"
    )


def target_identity(manifest, target):
    return {"manifestSha256": digest(MANIFEST), "integrationTree": manifest["integration"]["tree"],
            "lockSha256": manifest["integration"]["uniffiLockSha256"],
            "buildScriptSha256": digest(Path(__file__)), "target": target,
            "distributionInputs": distribution_inputs(),
            "rustVersion": run("rustc", "+" + manifest["build"]["rust"], "--version"),
            "xcode": run("xcodebuild", "-version")}


def verify_built_targets(manifest, platform):
    for target in manifest["build"]["targets"]:
        if platform == "android" and not target.endswith("-linux-android"):
            continue
        if platform == "ios" and "apple-ios" not in target:
            continue
        stamp = json.loads((WORK / "built-targets" / (target + ".json")).read_text())
        binary = target_binary(target)
        if (stamp["identity"] != target_identity(manifest, target) or
                stamp["sha256"] != digest(binary) or stamp["sizeBytes"] != binary.stat().st_size):
            raise ValueError("Native target artifact is stale or has changed: " + target)


def zip_entries(output, entries, modes=None):
    """Stable order/timestamps and permissions for reproducible packaging."""
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, value in sorted(entries.items()):
            info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (modes or {}).get(name, 0o100644) << 16
            archive.writestr(info, value)


def release_attribution(manifest):
    return {
        "LICENSE.rgb-lib.txt": (SOURCE / "LICENSE").read_bytes(),
        "LICENSE.MPL-2.0.txt": (NATIVE / "LICENSE-MPL-2.0.txt").read_bytes(),
        "NOTICE.txt": (NATIVE / "NOTICE.txt").read_bytes(),
        "source-manifest.json": MANIFEST.read_bytes(),
    }


def distribution_inputs():
    return {name: digest(NATIVE / name) for name in ("NOTICE.txt", "LICENSE-MPL-2.0.txt")}


def dependency_inventory(manifest):
    data = json.loads(cargo(manifest, "metadata", "--locked", "--offline", "--format-version", "1"))
    components = []
    texts = {}
    missing = []
    for package in sorted(data["packages"], key=lambda item: (item["name"], item["version"], item.get("source") or "")):
        name = package["name"] + "-" + package["version"]
        directory = Path(package["manifest_path"]).parent.resolve()
        candidates = {p for p in directory.iterdir() if p.is_file() and
                      p.name.lower().startswith(("license", "licence", "copying", "notice", "copyright"))}
        if package.get("license_file"):
            candidates.add(directory / package["license_file"])
        licenses = []
        for candidate in sorted(candidates):
            resolved = candidate.resolve()
            if (not resolved.is_relative_to(directory) or not resolved.is_file() or
                    resolved.stat().st_size > 2 * 1024 * 1024):
                continue
            relative = resolved.relative_to(directory).as_posix()
            key = "third-party-licenses/" + name + "/" + relative
            content = resolved.read_bytes()
            texts[key] = content
            licenses.append({"path": key, "sha256": hashlib.sha256(content).hexdigest()})
        if not licenses:
            missing.append(name)
        components.append({"name": package["name"], "version": package["version"],
                           "source": package.get("source") or "included-local-source",
                           "repository": package.get("repository"),
                           "declaredLicenseExpression": package.get("license"), "availableLicenseTexts": licenses})
    inventory = {
        "schemaVersion": 1, "kind": "Cargo dependency inventory; not a complete SBOM/license approval",
        "integrationTree": manifest["integration"]["tree"],
        "sourceLockSha256": manifest["integration"]["uniffiLockSha256"],
        "scope": "Locked Cargo metadata including build/target packages; overinclusive of final linked code.",
        "components": components, "packagesWithoutBundledLicenseText": missing,
        "publicationDisposition": "Review unresolved license texts/expressions, source availability and final linked obligations before publication.",
    }
    return json.dumps(inventory, indent=2, sort_keys=True).encode() + b"\n", texts


def package_source(manifest, inventory, license_texts):
    entries = {"source-manifest.json": MANIFEST.read_bytes(), "dependency-inventory.json": inventory,
               **release_attribution(manifest), **license_texts}
    modes = {}
    source_roots = [("rgb-lib-bfa", SOURCE), ("esplora-client", ESPLORA)]
    if manifest.get("sqlite3") is not None:
        source_roots.append(("sqlite3-sys", SQLITE))
    for prefix, directory in source_roots:
        for line in git(directory, "ls-files", "--stage").splitlines():
            record, name = line.split("\t", 1)
            mode, _, stage = record.split()
            if stage != "0" or mode not in ("100644", "100755"):
                raise ValueError("Source bundle admits only resolved regular tracked files.")
            key = prefix + "/" + name
            entries[key] = (directory / name).read_bytes()
            modes[key] = int(mode, 8)
    for path in NATIVE.rglob("*"):
        if path.is_file():
            entries["native/rgb_l1/" + path.relative_to(NATIVE).as_posix()] = path.read_bytes()
    for name in ("build_rgb_lib_bfa7.py", "test_build_rgb_lib_bfa7.py", "install_rgb_lib_ios.py"):
        entries["tool/" + name] = (ROOT / "tool" / name).read_bytes()
    for language in ("kotlin", "swift"):
        for path in (GENERATED / language).rglob("*"):
            if path.is_file():
                entries["generated/" + path.relative_to(GENERATED).as_posix()] = path.read_bytes()
    output = ARTIFACTS / f'rgb-lib-bfa-source-{manifest["version"]}.zip'
    zip_entries(output, entries, modes)
    return output


def metadata(manifest, platform):
    return {"schema_version": 2, "version": manifest["version"], "bridge_version": manifest["bridgeVersion"],
            "native_overlay": manifest["nativeOverlay"],
            "source_repository": "UTEXO-Protocol/rgb-lib-bfa", "source_commit": manifest["source"]["revision"],
            "source_lock_sha256": manifest["integration"]["uniffiLockSha256"],
            "core_overlay_tree": manifest["source"]["coreOverlayTree"],
            "integration_tree": manifest["integration"]["tree"],
            "overlay_patch_sha256": manifest["integration"]["patchSha256"],
            "source_manifest_sha256": digest(MANIFEST), "build_script_sha256": digest(Path(__file__)),
            "dispatched_rgb_revocation": manifest.get("features", {}).get("dispatchedRgbRevocation", False),
            "sqlite_overlay_tree": manifest.get("sqlite3", {}).get("overlayTree"),
            "ios_sqlite_compile_flags": manifest.get("sqlite3", {}).get("iosCompileFlags", []),
            "distribution_inputs": distribution_inputs(),
            "rust_version": run("rustc", "+" + manifest["build"]["rust"], "--version"),
            "xcode": run("xcodebuild", "-version"),
            "android_ndk": manifest["build"]["androidNdk"],
            "min_android_api": manifest["build"]["minAndroidApi"],
            "min_ios_version": manifest["build"]["minIosVersion"],
            "targets": [target for target in manifest["build"]["targets"]
                        if platform == "cross-platform" or
                        (platform == "android" and target.endswith("-linux-android")) or
                        (platform == "apple" and "apple-ios" in target)],
            "kotlin_version": manifest["build"]["kotlinVersion"],
            "build_profile": "release", "platform": platform, "local_candidate": True}


def kotlin_jars(manifest):
    directory = WORK / "build-jars"
    directory.mkdir(parents=True, exist_ok=True)
    files = []
    for pin in manifest["build"]["kotlinJars"]:
        path = directory / (pin["name"] + "-" + pin["version"] + ".jar")
        if not path.exists():
            path.write_bytes(download(pin["url"]))
        if path.stat().st_size != pin["sizeBytes"] or digest(path) != pin["sha256"]:
            raise ValueError("Kotlin build dependency checksum mismatch: " + path.name)
        files.append(path)
    return files


def package_android(manifest):
    jars = kotlin_jars(manifest)
    kotlin = GENERATED / "kotlin/com/utexo/rgb_lib.kt"
    if not kotlin.is_file():
        raise ValueError("Generated com.utexo Kotlin binding is missing.")
    java_home = Path(os.environ.get("JAVA_HOME", "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"))
    java = java_home / "bin/java"
    if not run(java, "-version").startswith("openjdk version \"17"):
        # java -version writes stderr, so verify release metadata instead.
        if 'JAVA_VERSION="17.' not in (java_home / "release").read_text():
            raise ValueError("Pinned Android binding compile requires JDK 17.")
    classes = WORK / "kotlin-classes"
    if classes.exists():
        shutil.rmtree(classes)
    classes.mkdir()
    classpath = os.pathsep.join(str(path) for path in jars)
    run(java, "-Xmx1536m", "-cp", classpath, "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler", "-no-stdlib", "-no-reflect",
        "-jvm-target", "17", "-classpath", classpath, "-d", classes, kotlin)
    jar = io.BytesIO()
    with zipfile.ZipFile(jar, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(classes.rglob("*")):
            if path.is_file():
                info = zipfile.ZipInfo(path.relative_to(classes).as_posix(), (2026, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, path.read_bytes())
    android_manifest = ('<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
                        'package="com.utexo.rgb_lib_bfa"><uses-sdk android:minSdkVersion="'
                        + str(manifest["build"]["minAndroidApi"]) + '"/></manifest>')
    entries = {"AndroidManifest.xml": android_manifest.encode(),
               "classes.jar": jar.getvalue(), "assets/rgb-lib-bfa-version.json": json.dumps(metadata(manifest, "android"), sort_keys=True).encode(),
               "proguard.txt": b'-keep class com.utexo.** { *; }\n-keep class com.sun.jna.** { *; }\n'}
    entries.update({"META-INF/" + name: content for name, content in release_attribution(manifest).items()})
    # AAR root metadata is not an Android asset. Preserve the notices in the
    # consuming APK too, rather than relying on an AAR transform to copy them.
    entries.update({"assets/rgb-lib-bfa-notices/" + name: content
                    for name, content in release_attribution(manifest).items()})
    for target, abi in (("aarch64-linux-android", "arm64-v8a"), ("x86_64-linux-android", "x86_64")):
        entries[f"jni/{abi}/librgblibuniffi.so"] = (TARGET / target / "release/librgblibuniffi.so").read_bytes()
    output = ARTIFACTS / f'rgb-lib-bfa-android-{manifest["version"]}.aar'
    zip_entries(output, entries)
    return output


def package_ios(manifest):
    import plistlib
    stage = WORK / "swift-package"
    stage.mkdir(parents=True, exist_ok=True)
    headers = stage / "headers"
    headers.mkdir(exist_ok=True)
    shutil.copyfile(GENERATED / "swift/rgb_libFFI.h", headers / "rgb_libFFI.h")
    (headers / "module.modulemap").write_text('module rgb_libFFI { header "rgb_libFFI.h" export * }\n')
    simulator = stage / "ios-simulator/librgblibuniffi.a"
    simulator.parent.mkdir(exist_ok=True)
    run("xcrun", "lipo", "-create", TARGET / "aarch64-apple-ios-sim/release/librgblibuniffi.a",
        TARGET / "x86_64-apple-ios/release/librgblibuniffi.a", "-output", simulator)
    framework = stage / "rgb_libFFI.xcframework"
    if framework.exists():
        shutil.rmtree(framework)
    run("xcodebuild", "-create-xcframework", "-library", TARGET / "aarch64-apple-ios/release/librgblibuniffi.a",
        "-headers", headers, "-library", simulator, "-headers", headers, "-output", framework)
    plist = plistlib.loads((framework / "Info.plist").read_bytes())
    if len(plist["AvailableLibraries"]) != 2:
        raise ValueError("The generated iOS package has unexpected slices.")
    entries = {"version.json": json.dumps(metadata(manifest, "apple"), sort_keys=True).encode(),
               "Sources/RgbLib/RgbLib.swift": (GENERATED / "swift/rgb_lib.swift").read_bytes(),
               "LICENSE": (SOURCE / "LICENSE").read_bytes()}
    entries.update(release_attribution(manifest))
    for path in framework.rglob("*"):
        if path.is_file():
            entries[path.relative_to(stage).as_posix()] = path.read_bytes()
    output = ARTIFACTS / f'rgb-lib-bfa-swift-{manifest["version"]}.zip'
    zip_entries(output, entries)
    return output


def package(manifest, platform):
    verify_source(manifest)
    verify_dependencies(manifest)
    verify_generated(manifest)
    verify_built_targets(manifest, platform)
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    record_path = ARTIFACTS / "build-record.json"
    record = {"identity": metadata(manifest, "cross-platform"), "artifacts": {}}
    if record_path.exists():
        previous = json.loads(record_path.read_text())
        if previous["identity"] != record["identity"]:
            raise ValueError("Existing build record is for a different source/tool identity.")
        record = previous
    paths = []
    if platform in ("all", "android"):
        paths.append(package_android(manifest))
    if platform in ("all", "ios"):
        paths.append(package_ios(manifest))
    inventory, license_texts = dependency_inventory(manifest)
    inventory_path = ARTIFACTS / f'rgb-lib-bfa-dependency-inventory-{manifest["version"]}.json'
    inventory_path.write_bytes(inventory)
    paths.extend((inventory_path, package_source(manifest, inventory, license_texts)))
    for path in paths:
        record["artifacts"][path.name] = {"sha256": digest(path), "sizeBytes": path.stat().st_size}
    record_path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    print(json.dumps(record, indent=2, sort_keys=True), flush=True)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "seal", "verify", "generate", "build", "package"))
    parser.add_argument("--source", help="Exact-commit local mirror for offline source preparation")
    parser.add_argument("--target", action="append", default=[])
    parser.add_argument("--platform", choices=("all", "android", "ios"), default="all")
    args = parser.parse_args()
    manifest = read_manifest()
    if args.command == "seal":
        seal(manifest)
    elif args.command == "prepare":
        prepare(manifest, args.source)
    elif args.command == "verify":
        verify_source(manifest)
        prepare_esplora(manifest)
        prepare_sqlite(manifest)
    elif args.command == "generate":
        generate(manifest)
    elif args.command == "build":
        build(manifest, args.target)
    elif args.command == "package":
        package(manifest, args.platform)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError, KeyError) as error:
        sys.exit("BFA.7 native build failed: " + str(error))

#!/usr/bin/env python3
"""Fault tests for immutable native source admission and deterministic packaging."""

import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zipfile


SPEC = importlib.util.spec_from_file_location(
    "build_rgb_lib_bfa7", Path(__file__).with_name("build_rgb_lib_bfa7.py")
)
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class NativeAdmissionTests(unittest.TestCase):
    def test_ios_sqlite_flags_are_exact_target_specific_and_not_ambient(self):
        manifest = {"build": {"minIosVersion": "16.0"}, "sqlite3": {
            "iosCompileFlags": ["SQLITE_ENABLE_LOCKING_STYLE=0", "RGB_SQLITE_IOS_CONTAINER_ONLY=1"]}}
        with patch.dict(os.environ, {"LIBSQLITE3_FLAGS": "-U__APPLE__"}), \
                patch.object(BUILD, "run", return_value="/admitted/ios-sdk"):
            for target in ("aarch64-apple-ios", "aarch64-apple-ios-sim", "x86_64-apple-ios"):
                env = BUILD.build_env(manifest, target)
                self.assertEqual(env["LIBSQLITE3_FLAGS"],
                                 "-DSQLITE_ENABLE_LOCKING_STYLE=0 -DRGB_SQLITE_IOS_CONTAINER_ONLY=1")
                self.assertEqual(env["SDKROOT"], "/admitted/ios-sdk")
                self.assertNotIn("-U__APPLE__", env["LIBSQLITE3_FLAGS"])
            self.assertNotIn("LIBSQLITE3_FLAGS", BUILD.build_env(manifest))
            manifest["sqlite3"]["iosCompileFlags"].append("-U__APPLE__")
            with self.assertRaisesRegex(ValueError, "Unreviewed iOS SQLite"):
                BUILD.build_env(manifest, "aarch64-apple-ios")

    def test_patch_content_and_containment_are_both_required(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            native = root / "native"
            native.mkdir()
            admitted = native / "overlay.patch"
            admitted.write_bytes(b"reviewed")
            outside = root / "outside.patch"
            outside.write_bytes(b"reviewed")
            pin = {"path": "overlay.patch", "sha256": BUILD.digest(admitted)}
            with patch.object(BUILD, "NATIVE", native):
                self.assertEqual(BUILD.checked_patch(pin), admitted.resolve())
                for path in ("../outside.patch", str(outside)):
                    with self.assertRaises(ValueError):
                        BUILD.checked_patch({**pin, "path": path})
                admitted.write_bytes(b"altered")
                with self.assertRaises(ValueError):
                    BUILD.checked_patch(pin)

    def test_crate_extract_rejects_symlinks_traversal_and_git(self):
        for name, kind in (("crate/../../outside", tarfile.REGTYPE),
                           ("crate/link", tarfile.SYMTYPE),
                           ("crate/.git/config", tarfile.REGTYPE),
                           ("other/source.rs", tarfile.REGTYPE)):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                output = io.BytesIO()
                with tarfile.open(fileobj=output, mode="w:gz") as archive:
                    entry = tarfile.TarInfo(name)
                    entry.type = kind
                    entry.linkname = "../outside"
                    archive.addfile(entry)
                with self.assertRaises(ValueError):
                    BUILD.extract_crate(output.getvalue(), temporary, "crate")
                self.assertEqual(list(Path(temporary).iterdir()), [])

    def test_crate_extract_accepts_regular_files(self):
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode="w:gz") as archive:
            entry = tarfile.TarInfo("crate/source.rs")
            entry.size = 4
            archive.addfile(entry, io.BytesIO(b"safe"))
        with tempfile.TemporaryDirectory() as temporary:
            BUILD.extract_crate(output.getvalue(), temporary, "crate")
            self.assertEqual((Path(temporary) / "crate/source.rs").read_bytes(), b"safe")

    def test_unsealed_and_dirty_source_cannot_build(self):
        manifest = {"source": {"revision": "commit", "tree": "base", "coreOverlayTree": "core"},
                    "integration": {"tree": None}}
        def reply(_, *args):
            return "commit" if args == ("rev-parse", "HEAD") else "base"
        with patch.object(BUILD, "git", side_effect=reply):
            with self.assertRaisesRegex(ValueError, "not been sealed"):
                BUILD.verify_source(manifest)
        manifest["integration"]["tree"] = "admitted"
        def changed(_, *args):
            return {("rev-parse", "HEAD"): "commit", ("rev-parse", "HEAD^{tree}"): "base",
                    ("write-tree",): "admitted", ("diff", "--name-only"): "src/changed.rs"}[args]
        with patch.object(BUILD, "git", side_effect=changed):
            with self.assertRaisesRegex(ValueError, "unadmitted changes"):
                BUILD.verify_source(manifest)

    def test_seal_preserves_base_and_records_new_files_and_lock(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            native = root / "native"
            source.mkdir()
            native.mkdir()
            def git(*args):
                return subprocess.check_output(["git", "-C", str(source), *args], text=True).strip()
            git("init", "--quiet")
            (source / "base.rs").write_text("base\n")
            lock = source / "bindings/uniffi/Cargo.lock"
            lock.parent.mkdir(parents=True)
            lock.write_text("base lock\n")
            git("add", "--all")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.test", "commit", "--quiet", "-m", "base")
            commit = git("rev-parse", "HEAD")
            base_tree = git("write-tree")
            (source / "base.rs").write_text("integrated\n")
            new_file = source / "extension.rs"
            new_file.write_text("new integration file\n")
            manifest = {"source": {"revision": commit, "tree": base_tree, "coreOverlayTree": base_tree},
                        "integration": {"patch": "source-overlay.patch", "tree": None}}
            with patch.object(BUILD, "SOURCE", source), patch.object(BUILD, "NATIVE", native), \
                    patch.object(BUILD, "MANIFEST", native / "source-manifest.json"):
                BUILD.seal(manifest)
                self.assertEqual(git("rev-parse", "HEAD"), commit)
                self.assertEqual(git("diff", "--name-only"), "")
                overlay = (native / "source-overlay.patch").read_text()
                self.assertIn("new integration file", overlay)
                self.assertIn("integrated", overlay)
                self.assertEqual(manifest["integration"]["tree"], git("write-tree"))
                self.assertEqual(manifest["integration"]["uniffiLockSha256"], BUILD.digest(lock))
                BUILD.verify_source(manifest)
                new_file.write_text("later alteration")
                with self.assertRaises(ValueError):
                    BUILD.verify_source(manifest)

    def test_bridge_seal_preserves_preceding_overlay_patch(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            native = root / "native"
            source.mkdir()
            native.mkdir()
            BUILD.git(source, "init", "--quiet")
            lock = source / "bindings/uniffi/Cargo.lock"
            lock.parent.mkdir(parents=True)
            lock.write_text("base lock\n")
            BUILD.git(source, "add", "--all")
            BUILD.git(source, "-c", "user.name=Fixture", "-c",
                      "user.email=fixture@example.test", "commit", "--quiet", "-m", "base")
            base = BUILD.git(source, "rev-parse", "HEAD")
            base_tree = BUILD.git(source, "write-tree")
            lock.write_text("preceding integrated lock\n")
            BUILD.git(source, "add", "--all")
            preceding = BUILD.git(source, "write-tree")
            overlay = native / "source-overlay.patch"
            overlay.write_text("preceding patch\n")
            lock.write_text("bridge lock\n")
            manifest = {"source": {"revision": base, "tree": base_tree, "coreOverlayTree": base_tree},
                        "integration": {"patch": overlay.name, "patchSha256": BUILD.digest(overlay),
                                        "bridgePatch": {"path": "bridge.patch",
                                                        "baseIntegrationTree": preceding}}}
            with patch.object(BUILD, "SOURCE", source), patch.object(BUILD, "NATIVE", native), \
                    patch.object(BUILD, "MANIFEST", native / "source-bridge-manifest.json"):
                BUILD.seal(manifest)
                self.assertEqual(overlay.read_text(), "preceding patch\n")
                self.assertIn("preceding integrated lock", (native / "bridge.patch").read_text())
                self.assertEqual(manifest["integration"]["bridgePatch"]["sha256"],
                                 BUILD.digest(native / "bridge.patch"))
                BUILD.verify_source(manifest)

    def test_packaging_is_deterministic_across_input_order(self):
        with tempfile.TemporaryDirectory() as temporary:
            first = Path(temporary) / "first.zip"
            second = Path(temporary) / "second.zip"
            BUILD.zip_entries(first, {"b.txt": b"B", "a.txt": b"A"})
            BUILD.zip_entries(second, {"a.txt": b"A", "b.txt": b"B"})
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as archive:
                self.assertEqual(archive.namelist(), ["a.txt", "b.txt"])
                self.assertTrue(all(entry.date_time == (2026, 1, 1, 0, 0, 0) for entry in archive.infolist()))

    def test_source_bundle_preserves_executable_modes(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "source.zip"
            BUILD.zip_entries(archive, {"build.sh": b"script", "Cargo.toml": b"manifest"},
                              {"build.sh": 0o100755})
            with zipfile.ZipFile(archive) as source:
                self.assertEqual(source.getinfo("build.sh").external_attr >> 16, 0o100755)
                self.assertEqual(source.getinfo("Cargo.toml").external_attr >> 16, 0o100644)

    def test_extracted_source_preserves_both_cargo_sqlite_dependency_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, esplora, sqlite = (root / name for name in ("source", "esplora", "sqlite"))
            for directory in (source, esplora, sqlite):
                directory.mkdir()
                (directory / "Cargo.toml").write_text('[package]\nname="fixture"\nversion="1.0.0"\n')
                subprocess.run(["git", "init", "--quiet", str(directory)], check=True)
            uniffi = source / "bindings/uniffi"
            uniffi.mkdir(parents=True)
            (uniffi / "Cargo.toml").write_text('[patch.crates-io]\nlibsqlite3-sys={path="../../../sqlite3-sys"}\n')
            with (source / "Cargo.toml").open("a") as manifest:
                manifest.write('[patch.crates-io]\nlibsqlite3-sys={path="../sqlite3-sys"}\n')
            for directory in (source, esplora, sqlite):
                subprocess.run(["git", "-C", str(directory), "add", "--all"], check=True)
            native = root / "native"
            native.mkdir()
            pin = native / "source-manifest.json"
            pin.write_text('{}')
            artifacts = root / "artifacts"
            artifacts.mkdir()
            (root / "tool").mkdir()
            for name in ("build_rgb_lib_bfa7.py", "test_build_rgb_lib_bfa7.py", "install_rgb_lib_ios.py"):
                (root / "tool" / name).write_text('# source-build tool\n')
            with patch.object(BUILD, "ROOT", root), patch.object(BUILD, "SOURCE", source), \
                    patch.object(BUILD, "ESPLORA", esplora), patch.object(BUILD, "SQLITE", sqlite), \
                    patch.object(BUILD, "NATIVE", native), patch.object(BUILD, "MANIFEST", pin), \
                    patch.object(BUILD, "ARTIFACTS", artifacts), \
                    patch.object(BUILD, "GENERATED", root / "generated"), \
                    patch.object(BUILD, "release_attribution", return_value={}):
                archive = BUILD.package_source({"version": "fixture", "sqlite3": {}}, b'{}', {})
            unpacked = root / "unpacked"
            with zipfile.ZipFile(archive) as bundle:
                bundle.extractall(unpacked)
            self.assertTrue((unpacked / "rgb-lib-bfa/../sqlite3-sys/Cargo.toml").is_file())
            self.assertTrue((unpacked / "rgb-lib-bfa/bindings/uniffi/../../../sqlite3-sys/Cargo.toml").is_file())

    def test_dependency_inventory_discloses_missing_license_text_without_local_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "dep"
            package.mkdir()
            (package / "LICENSE-MIT").write_text("copyright and permission")
            metadata = {"packages": [
                {"name": "dep", "version": "1", "manifest_path": str(package / "Cargo.toml"),
                 "source": "registry+https://github.com/rust-lang/crates.io-index", "license": "MIT"},
                {"name": "missing", "version": "2", "manifest_path": str(root / "Cargo.toml"),
                 "source": None, "license": None},
            ]}
            manifest = {"integration": {"tree": "tree", "uniffiLockSha256": "lock"}}
            with patch.object(BUILD, "cargo", return_value=json.dumps(metadata)):
                inventory, texts = BUILD.dependency_inventory(manifest)
            data = json.loads(inventory)
            self.assertEqual(data["packagesWithoutBundledLicenseText"], ["missing-2"])
            self.assertEqual(texts["third-party-licenses/dep-1/LICENSE-MIT"], b"copyright and permission")
            self.assertNotIn(str(root), inventory.decode())
            self.assertIn("not a complete SBOM/license approval", data["kind"])

    def test_binary_attribution_preserves_upstream_notice_and_exact_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            native = root / "native"
            source.mkdir()
            native.mkdir()
            (source / "LICENSE").write_bytes(b"original upstream copyright and MIT permission")
            (native / "LICENSE-MPL-2.0.txt").write_bytes(b"Mozilla license")
            (native / "NOTICE.txt").write_bytes(b"origin and binding attribution")
            (native / "source-manifest.json").write_bytes(b"exact sealed source identity")
            with patch.object(BUILD, "SOURCE", source), patch.object(BUILD, "NATIVE", native), \
                    patch.object(BUILD, "MANIFEST", native / "source-manifest.json"):
                entries = BUILD.release_attribution({})
            self.assertEqual(entries["LICENSE.rgb-lib.txt"], (source / "LICENSE").read_bytes())
            self.assertEqual(entries["source-manifest.json"], b"exact sealed source identity")
            self.assertEqual(entries["NOTICE.txt"], b"origin and binding attribution")

    def test_pinned_artifact_hashes_cannot_accept_altered_cached_jars(self):
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            jars = work / "build-jars"
            jars.mkdir()
            (jars / "tool-1.jar").write_bytes(b"altered")
            manifest = {"build": {"kotlinJars": [{"name": "tool", "version": "1", "url": "https://example.test/tool.jar",
                                                    "sha256": hashlib.sha256(b"expected").hexdigest(), "sizeBytes": 7}]}}
            with patch.object(BUILD, "WORK", work), patch.object(BUILD, "download") as download:
                with self.assertRaises(ValueError):
                    BUILD.kotlin_jars(manifest)
                download.assert_not_called()

    def test_generated_bindings_require_current_source_and_exact_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            generated = Path(temporary)
            source = generated / "kotlin/binding.kt"
            source.parent.mkdir()
            source.write_bytes(b"binding")
            manifest = {"integration": {"tree": "source"}, "build": {"bindgenFiles": {"lock": "hash"}}}
            recorded = {"integrationTree": "source", "bindgenFiles": {"lock": "hash"},
                        "files": {"kotlin/binding.kt": BUILD.digest(source)}}
            record = generated / "manifest.json"
            record.write_text(json.dumps(recorded))
            with patch.object(BUILD, "GENERATED", generated):
                BUILD.verify_generated(manifest)
                source.write_bytes(b"altered")
                with self.assertRaisesRegex(ValueError, "content differs"):
                    BUILD.verify_generated(manifest)
                recorded["integrationTree"] = "previous-source"
                record.write_text(json.dumps(recorded))
                with self.assertRaisesRegex(ValueError, "identity is stale"):
                    BUILD.verify_generated(manifest)

    def test_packaging_different_identity_preserves_existing_artifact(self):
        with tempfile.TemporaryDirectory() as temporary:
            artifacts = Path(temporary)
            previous = artifacts / "candidate.aar"
            previous.write_bytes(b"previous qualified bytes")
            (artifacts / "build-record.json").write_text(json.dumps({"identity": "previous", "artifacts": {}}))
            with patch.object(BUILD, "ARTIFACTS", artifacts), patch.object(BUILD, "verify_source"), \
                    patch.object(BUILD, "verify_dependencies"), \
                    patch.object(BUILD, "verify_generated"), patch.object(BUILD, "verify_built_targets"), \
                    patch.object(BUILD, "metadata", return_value="current"), \
                    patch.object(BUILD, "package_android") as package_android:
                with self.assertRaisesRegex(ValueError, "different source/tool identity"):
                    BUILD.package({}, "android")
                package_android.assert_not_called()
                self.assertEqual(previous.read_bytes(), b"previous qualified bytes")

    def test_build_checks_external_path_dependency_before_and_after_compilation(self):
        manifest = {"build": {"targets": ["target"]}}
        with tempfile.TemporaryDirectory() as temporary, \
                patch.object(BUILD, "WORK", Path(temporary)), \
                patch.object(BUILD, "verify_source"), \
                patch.object(BUILD.shutil, "disk_usage", return_value=type("Disk", (), {"free": 7 * 1024**3})()), \
                patch.object(BUILD, "verify_dependencies", side_effect=[None, ValueError("changed Esplora")]) as dependencies, \
                patch.object(BUILD, "target_identity", return_value="identity"), \
                patch.object(BUILD, "cargo") as cargo:
            with self.assertRaisesRegex(ValueError, "changed Esplora"):
                BUILD.build(manifest, [])
            self.assertEqual(dependencies.call_count, 2)
            cargo.assert_called_once()
            self.assertFalse((Path(temporary) / "built-targets").exists())

    def test_android_bindgen_has_target_headers_without_changing_host_generation(self):
        with tempfile.TemporaryDirectory(prefix="sdk with spaces ") as temporary:
            sdk = Path(temporary)
            ndk = sdk / "ndk/28.2.13676358"
            tool = ndk / "toolchains/llvm/prebuilt/darwin-x86_64/bin"
            tool.mkdir(parents=True)
            (tool / "aarch64-linux-android24-clang").touch()
            (ndk / "source.properties").write_text("Pkg.Revision = 28.2.13676358\n")
            manifest = {"build": {"minIosVersion": "16.0", "androidNdk": "28.2.13676358", "minAndroidApi": 24}}
            with patch.dict("os.environ", {"ANDROID_HOME": str(sdk)}):
                cross = BUILD.build_env(manifest, "aarch64-linux-android")
                host = BUILD.build_env(manifest)
            arguments = cross["BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android"]
            self.assertIn("--target=aarch64-linux-android24", arguments)
            self.assertIn('--sysroot="', arguments)
            self.assertIn("/usr/include/aarch64-linux-android", arguments)
            self.assertIn("16384", cross["CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS"])
            self.assertEqual(cross["AWS_LC_SYS_CMAKE_BUILDER"], "0")
            self.assertNotIn("BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android", host)

    def test_ios_build_supersedes_inherited_macos_sdk_without_changing_host(self):
        manifest = {"build": {"minIosVersion": "16.0"}}
        with patch.dict("os.environ", {"SDKROOT": "/CLT/MacOSX.sdk"}), \
                patch.object(BUILD, "run", side_effect=["/Xcode/iPhoneOS.sdk", "/Xcode/iPhoneSimulator.sdk"]) as run:
            device = BUILD.build_env(manifest, "aarch64-apple-ios")
            simulator = BUILD.build_env(manifest, "x86_64-apple-ios")
            host = BUILD.build_env(manifest)
        self.assertEqual(device["SDKROOT"], "/Xcode/iPhoneOS.sdk")
        self.assertEqual(simulator["SDKROOT"], "/Xcode/iPhoneSimulator.sdk")
        self.assertEqual(host["SDKROOT"], "/CLT/MacOSX.sdk")
        self.assertEqual(device["AWS_LC_SYS_CMAKE_BUILDER"], "0")
        self.assertEqual(simulator["AWS_LC_SYS_CMAKE_BUILDER"], "0")
        self.assertEqual(run.call_args_list[0].args[:4], ("xcrun", "--sdk", "iphoneos", "--show-sdk-path"))
        self.assertEqual(run.call_args_list[1].args[:4], ("xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"))

    def test_target_stamp_rejects_stale_generation_or_changed_binary(self):
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            target = "aarch64-linux-android"
            binary = work / "native.so"
            binary.write_bytes(b"compiled")
            stamps = work / "built-targets"
            stamps.mkdir()
            (stamps / (target + ".json")).write_text(json.dumps({
                "identity": "current", "sha256": BUILD.digest(binary), "sizeBytes": 8,
            }))
            manifest = {"build": {"targets": [target]}}
            with patch.object(BUILD, "WORK", work), patch.object(BUILD, "target_binary", return_value=binary), \
                    patch.object(BUILD, "target_identity", return_value="current") as identity:
                BUILD.verify_built_targets(manifest, "android")
                binary.write_bytes(b"altered!")
                with self.assertRaisesRegex(ValueError, "stale or has changed"):
                    BUILD.verify_built_targets(manifest, "android")
                binary.write_bytes(b"compiled")
                identity.return_value = "new-source-generation"
                with self.assertRaisesRegex(ValueError, "stale or has changed"):
                    BUILD.verify_built_targets(manifest, "android")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Reject artifact identity substitution before any native framework work."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "install_rgb_lib_ios", Path(__file__).with_name("install_rgb_lib_ios.py")
)
INSTALL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INSTALL)


class IosArtifactAdmissionTests(unittest.TestCase):
    def test_every_overlay_identity_field_is_required_and_exact(self):
        fields = {
            "version": "version", "bridge_version": "bridgeVersion",
            "source_commit": "sourceRevision", "source_lock_sha256": "sourceLockSha256",
            "integration_tree": "integrationTree", "overlay_patch_sha256": "sourceOverlaySha256",
            "source_manifest_sha256": "sourceManifestSha256", "native_overlay": "nativeOverlay",
        }
        provenance = {key: (5 if key == "bridge_version" else key + "-admitted") for key in fields}
        pin = {pin_key: provenance[key] for key, pin_key in fields.items()}
        with patch.object(INSTALL, "PIN", pin):
            INSTALL.verify_provenance(provenance)
            for key in fields:
                with self.subTest(key=key):
                    changed = {**provenance, key: "another-generation"}
                    with self.assertRaisesRegex(ValueError, key):
                        INSTALL.verify_provenance(changed)
                    missing = {k: value for k, value in provenance.items() if k != key}
                    with self.assertRaisesRegex(ValueError, key):
                        INSTALL.verify_provenance(missing)
        with patch.object(INSTALL, "PIN", {}):
            with self.assertRaises(ValueError):
                INSTALL.verify_provenance(provenance)

    def test_exact_size_and_hash_are_both_required(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "candidate.zip"
            archive.write_bytes(b"admitted native artifact")
            pin = {"ios": {"sizeBytes": archive.stat().st_size, "sha256": INSTALL.sha256(archive)}}
            with patch.object(INSTALL, "PIN", pin):
                INSTALL.verify_archive(archive)
                archive.write_bytes(b"substitute native bytes!")
                with self.assertRaises(ValueError):
                    INSTALL.verify_archive(archive)
                archive.write_bytes(b"admitted native artifact" + b"extra")
                with self.assertRaises(ValueError):
                    INSTALL.verify_archive(archive)

    def test_installer_selects_xcode_locally_without_changing_explicit_choice(self):
        with patch.dict("os.environ", {}, clear=True), patch.object(Path, "is_dir", return_value=True), \
                patch.object(INSTALL.subprocess, "check_output", return_value="ok") as command:
            INSTALL.run("xcodebuild", "-version")
            self.assertEqual(command.call_args.kwargs["env"]["DEVELOPER_DIR"],
                             "/Applications/Xcode.app/Contents/Developer")
        with patch.dict("os.environ", {"DEVELOPER_DIR": "/explicit/Xcode"}, clear=True), \
                patch.object(Path, "is_dir", return_value=True), \
                patch.object(INSTALL.subprocess, "check_output", return_value="ok") as command:
            INSTALL.run("xcodebuild", "-version")
            self.assertEqual(command.call_args.kwargs["env"]["DEVELOPER_DIR"], "/explicit/Xcode")

    def test_installed_framework_retains_original_licenses_and_source_notices(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            release = root / "release"
            framework = root / "candidate.framework"
            release.mkdir()
            framework.mkdir()
            for filename in INSTALL.ATTRIBUTION_FILES:
                (release / filename).write_bytes((filename + " exact original attribution").encode())
            INSTALL.copy_attribution(release, framework)
            for filename in INSTALL.ATTRIBUTION_FILES:
                self.assertEqual((framework / filename).read_bytes(), (release / filename).read_bytes())
            (release / INSTALL.ATTRIBUTION_FILES[0]).unlink()
            with self.assertRaises(OSError):
                INSTALL.copy_attribution(release, framework)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Host-only admission tests; no Rust build, native artifact edit or wallet work."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
import build_durable_onchain_ios_sim as builder
import stage_durable_onchain_ios_sim as stager


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.sdk = self.root / "sdk"
        (self.sdk / "native").mkdir(parents=True)
        self.source = self.root / "source"
        self.rln = self.repository(self.source)
        (self.source / ".git/info/exclude").write_text("_recovery-deps/\nrust-lightning/\n")
        self.rgb = self.repository(self.source / "_recovery-deps/rgb-lib")
        self.ldk = self.repository(self.source / "rust-lightning")
        for name in ("rln.patch", "rgb.patch"):
            (self.sdk / "native" / name).write_text("+++ b/lib.rs\n")
        self.manifest = {
            "rln": {"commit": self.rln, "patch": "rln.patch"},
            "rgbLib": {"commit": self.rgb, "patch": "rgb.patch", "checkoutPath": "_recovery-deps/rgb-lib"},
            "lightningCommit": self.ldk,
        }
        self.sdk_patch = patch.object(builder, "SDK", self.sdk)
        self.sdk_patch.start()
        self.addCleanup(self.sdk_patch.stop)

    def repository(self, root):
        root.mkdir(parents=True)
        self.git(root, "init", "--quiet")
        (root / "lib.rs").write_text("// pinned source\n")
        (root / "other.rs").write_text("// other pinned source\n")
        self.git(root, "add", "lib.rs", "other.rs")
        self.git(root, "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
                 "-c", "user.name=Admission Fixture", "-c",
                 "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "fixture")
        return self.git(root, "rev-parse", "HEAD").strip()

    @staticmethod
    def git(root, *arguments):
        return subprocess.check_output(["git", "-C", str(root), *arguments],
                                       text=True, stderr=subprocess.PIPE)

    def test_snapshot_binds_effective_reviewed_source_bytes(self):
        before = builder.source_snapshot(self.source, self.manifest)
        (self.source / "lib.rs").write_text("// reviewed source change\n")
        after = builder.source_snapshot(self.source, self.manifest)
        self.assertNotEqual(before["rln"]["files"]["lib.rs"], after["rln"]["files"]["lib.rs"])
        self.assertEqual(before["rgbLib"], after["rgbLib"])

    def test_extra_tracked_edit_is_refused(self):
        (self.source / "other.rs").write_text("// unreviewed edit\n")
        with self.assertRaisesRegex(RuntimeError, "outside the reviewed"):
            builder.source_snapshot(self.source, self.manifest)

    def test_staged_edit_inside_an_allowed_file_is_refused(self):
        (self.source / "lib.rs").write_text("// hidden staged edit\n")
        self.git(self.source, "add", "lib.rs")
        with self.assertRaisesRegex(RuntimeError, "staged source edits"):
            builder.source_snapshot(self.source, self.manifest)

    def test_extra_untracked_rust_input_is_refused(self):
        (self.source / "surprise.rs").write_text("// unreviewed module\n")
        with self.assertRaisesRegex(RuntimeError, "unexpected untracked"):
            builder.source_snapshot(self.source, self.manifest)

    def test_dirty_lightning_source_is_refused(self):
        (self.source / "rust-lightning/lib.rs").write_text("// unreviewed dependency\n")
        with self.assertRaisesRegex(RuntimeError, "Lightning source must be clean"):
            builder.source_snapshot(self.source, self.manifest)

    def test_wrong_source_commit_is_refused(self):
        self.manifest["rgbLib"]["commit"] = "0" * 40
        with self.assertRaisesRegex(RuntimeError, "source commit"):
            builder.source_snapshot(self.source, self.manifest)

    def test_existing_output_is_preserved(self):
        output = self.root / "existing"
        output.mkdir()
        (output / "evidence").write_text("preserve me")
        with self.assertRaisesRegex(RuntimeError, "previous evidence is preserved"):
            builder.admitted_output(output)
        self.assertEqual((output / "evidence").read_text(), "preserve me")

    def test_output_in_any_repository_requires_git_ignore(self):
        with self.assertRaisesRegex(RuntimeError, "must be ignored"):
            builder.admitted_output(self.source / "candidate-output")
        with (self.source / ".git/info/exclude").open("a") as file:
            file.write("candidate-output/\n")
        builder.admitted_output(self.source / "candidate-output")

    def test_failed_or_changed_source_build_cannot_stage(self):
        evidence = self.root / "build"
        evidence.mkdir()
        inputs = {"scope": builder.SCOPE, "releaseArtifact": False, "target": builder.TARGET}
        (evidence / "build-inputs.json").write_text(json.dumps(inputs))
        for result in ({"exitCode": 1, "sourceUnchanged": True},
                       {"exitCode": 0, "sourceUnchanged": False}):
            result.update({"scope": builder.SCOPE, "releaseArtifact": False})
            (evidence / "build-result.json").write_text(json.dumps(result))
            output = self.root / "fixture"
            with patch("sys.argv", ["stage", "--build", str(evidence), "--output", str(output)]):
                with self.assertRaisesRegex(RuntimeError, "unchanged-source"):
                    stager.main()
            self.assertFalse(output.exists())

    def test_explicit_hold_prevents_staging(self):
        evidence = self.root / "held-build"
        evidence.mkdir()
        (evidence / "HOLD_STAGING").write_text("Superseded native candidate")
        output = self.root / "fixture"
        with patch("sys.argv", ["stage", "--build", str(evidence), "--output", str(output)]):
            with self.assertRaisesRegex(RuntimeError, "explicitly held"):
                stager.main()
        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()

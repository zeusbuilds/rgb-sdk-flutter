"""Prove a Flutter native upgrade cannot silently replace its released reference."""

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location(
    'reference', ROOT / 'tool/validate_rn_beta40_reference.py')
REFERENCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REFERENCE)


class NativeDivergenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'tool').mkdir()
        shutil.copytree(ROOT / 'native/rgb_l1', self.root / 'native/rgb_l1')
        self.lock = self.root / 'tool/reference.json'
        self.reference = json.loads((ROOT / 'tool/rn_beta40_rgb_lib_reference.json').read_text())
        manifest_path = self.root / 'native/rgb_l1/source-manifest.json'
        manifest = json.loads(manifest_path.read_text())
        self.current = copy.deepcopy(self.reference)
        self.current.update(
            version=manifest['version'], sourceRevision=manifest['source']['revision'],
            bridgeVersion=manifest['bridgeVersion'],
            sourceOverlaySha256=manifest['integration']['patchSha256'],
            integrationTree=manifest['integration']['tree'],
            sourceLockSha256=manifest['integration']['uniffiLockSha256'],
            nativeOverlay=manifest['nativeOverlay'],
            sourceManifestSha256=hashlib.sha256(manifest_path.read_bytes()).hexdigest())

    def verify(self, current=None):
        with patch.object(REFERENCE, 'LOCK', self.lock):
            REFERENCE.validate_flutter_native_upgrade(
                self.current if current is None else current, self.reference)

    def test_frozen_reference_and_recorded_divergence_are_admitted(self):
        self.verify(self.reference)
        self.verify()

    def test_each_identity_field_is_required(self):
        for field in ('version', 'sourceRevision', 'bridgeVersion', 'uniffiVersion',
                      'swiftModule', 'sourceOverlaySha256', 'integrationTree',
                      'sourceLockSha256', 'nativeOverlay', 'sourceManifestSha256'):
            with self.subTest(field=field):
                changed = copy.deepcopy(self.current)
                changed[field] = 'unreviewed'
                with self.assertRaises(ValueError):
                    self.verify(changed)

    def test_native_patch_tamper_is_rejected(self):
        directory = self.root / 'native/rgb_l1'
        for relative in ('source-overlay.patch',
                         'patches/rgb-lib-bfa.7-registration.patch',
                         'patches/esplora-client-0.12.3-guarded-blocking.patch'):
            path = directory / relative
            original = path.read_bytes()
            path.write_bytes(original + b'\ntampered\n')
            with self.subTest(path=relative), self.assertRaises(ValueError):
                self.verify()
            path.write_bytes(original)

    def test_archive_pins_require_hex_digest_and_positive_integer_size(self):
        for platform, digest, size in (('ios', 'sha256', 'sizeBytes'),
                                       ('android', 'archiveSha256', 'archiveSizeBytes')):
            for field, value in ((digest, 'x' * 64), (size, 0), (size, True), (size, '10')):
                changed = copy.deepcopy(self.current)
                changed[platform][field] = value
                with self.subTest(platform=platform, field=field, value=value):
                    with self.assertRaises(ValueError):
                        self.verify(changed)


if __name__ == '__main__':
    unittest.main()

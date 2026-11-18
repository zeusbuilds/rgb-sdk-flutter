#!/usr/bin/env python3
"""Check integrity of SDK source admitted to a staged BFA.8 candidate."""

import os
from pathlib import Path
import tempfile
import unittest

if __package__:
    from .stage_bfa8_candidate import digest, verify_sdk_inputs
else:
    from stage_bfa8_candidate import digest, verify_sdk_inputs


class StageSourceIntegrityTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.sdk = self.root / 'sdk'
        self.sources = (
            self.write('ios/Classes/nested/Wallet.swift'),
            self.write('android/src/main/kotlin/Wallet.kt'),
            self.write('lib/src/wallet.dart'),
        )
        self.hashes = {path.relative_to(self.sdk).as_posix(): digest(path)
                       for path in self.sources}

    def write(self, name):
        path = self.sdk / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('admitted source\n')
        return path

    def test_build_caches_outside_source_roots_are_allowed(self):
        self.write('android/build/generated/Wallet.kt')
        self.write('.dart_tool/build/generated/wallet.dart')
        self.write('ios/RgbLibBindings/framework/Wallet.swift')
        verify_sdk_inputs(self.sdk, self.hashes)

    def test_unlisted_sources_are_rejected_in_all_compilable_roots(self):
        for source in self.sources:
            with self.subTest(source=source):
                added = source.with_stem('Added')
                added.write_bytes(source.read_bytes())
                with self.assertRaisesRegex(ValueError, 'source inventory changed.*Added:'):
                    verify_sdk_inputs(self.sdk, self.hashes)
                added.unlink()

    def test_missing_sources_and_changed_bytes_are_rejected(self):
        source = self.sources[0]
        source.write_text('changed bytes\n')
        with self.assertRaisesRegex(ValueError, 'SDK input changed'):
            verify_sdk_inputs(self.sdk, self.hashes)
        source.unlink()
        with self.assertRaisesRegex(ValueError, 'source inventory changed.*Missing:'):
            verify_sdk_inputs(self.sdk, self.hashes)

    def test_dangling_file_and_directory_symlinks_are_rejected(self):
        folder = self.sdk / 'lib/src'
        for target in (self.sources[0], self.root, self.root / 'missing'):
            with self.subTest(target=target):
                symlink = folder / 'extra'
                symlink.symlink_to(target)
                with self.assertRaisesRegex(ValueError, 'Symlink in staged SDK source'):
                    verify_sdk_inputs(self.sdk, self.hashes)
                symlink.unlink()

    def test_compile_root_cannot_itself_be_a_symlink(self):
        sdk_lib = self.sdk / 'lib'
        relocated = self.root / 'relocated'
        sdk_lib.rename(relocated)
        sdk_lib.symlink_to(relocated, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Expected a regular SDK source directory: lib'):
            verify_sdk_inputs(self.sdk, self.hashes)

    @unittest.skipUnless(hasattr(os, 'mkfifo'), 'requires POSIX filesystem support')
    def test_nonregular_source_entries_are_rejected(self):
        os.mkfifo(self.sdk / 'ios/Classes/Extra.swift')
        with self.assertRaisesRegex(ValueError, 'Unexpected filesystem entry'):
            verify_sdk_inputs(self.sdk, self.hashes)


if __name__ == '__main__':
    unittest.main()

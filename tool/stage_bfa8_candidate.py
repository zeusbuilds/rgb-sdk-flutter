#!/usr/bin/env python3
"""Stage a verified, local-only BFA.8 plugin and its two mobile archives."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = Path('.buildlog/bfa8-upgrade')
DEFAULT_OUTPUT = BUILD_DIR / 'staged-mobile'
SOURCE_MANIFEST = Path('native/rgb_l1/source-bfa8-manifest.json')
BUILD_SCRIPT = Path('tool/build_rgb_lib_bfa7.py')
WRAPPER_PATCH = Path('tool/bfa8_candidate_wrappers.patch')
VERSION = '0.3.0-beta.7-upstream-dev-bfa.8-bfa-flutter.1'
PREVIOUS_VERSION = '0.3.0-beta.7-upstream-dev-bfa.7-bfa-flutter.2'
SOURCE_TAG = 'v0.3.0-beta.7-upstream-dev-bfa.8'
TAG_COMMIT = '2f7b21d8637baad548504ea870deb2c0d4d0a37d'
REVISION = 'cafe66e49d58038a69dd05f8065e3fe96a9d1601'
OVERLAY = 'flutter-bfa7-durable-v1'
BRIDGE_VERSION = 6
SCOPE = 'local-bfa8-mobile-sdk-candidate'
SDK_SCOPES = (
    '.fvmrc', '.metadata', 'LICENSE', 'README.md', 'analysis_options.yaml',
    'pubspec.yaml', 'pubspec.lock', 'lib', 'android', 'ios', 'example', 'licenses',
    'tool/release_baseline.json', 'tool/release_baseline.sh', 'tool/download_rln_ios.sh',
    'tool/verify_native_artifacts.sh', 'tool/install_rgb_lib_ios.py',
    'tool/rgb_lib_native_baseline.json',
)
COMPILABLE_ROOTS = ('ios/Classes', 'android/src', 'lib')
RUNTIME_KEYS = {
    'expectedVersion': 'version',
    'expectedSourceRevision': 'source_commit',
    'expectedBridgeVersion': 'bridge_version',
    'expectedIntegrationTree': 'integration_tree',
    'expectedOverlayPatchSha256': 'overlay_patch_sha256',
    'expectedSourceLockSha256': 'source_lock_sha256',
    'expectedSourceManifestSha256': 'source_manifest_sha256',
}
ARCHIVES = {
    f'rgb-lib-bfa-swift-{VERSION}.zip': ('apple', 'version.json'),
    f'rgb-lib-bfa-android-{VERSION}.aar': ('android', 'assets/rgb-lib-bfa-version.json'),
}
TARGETS = {
    'apple': {'aarch64-apple-ios', 'aarch64-apple-ios-sim', 'x86_64-apple-ios'},
    'android': {'aarch64-linux-android', 'x86_64-linux-android'},
}
ARCHIVE_MEMBERS = {
    'apple': (
        'Sources/RgbLib/RgbLib.swift',
        'rgb_libFFI.xcframework/ios-arm64/librgblibuniffi.a',
        'rgb_libFFI.xcframework/ios-arm64/Headers/rgb_libFFI.h',
        'rgb_libFFI.xcframework/ios-arm64_x86_64-simulator/librgblibuniffi.a',
        'rgb_libFFI.xcframework/ios-arm64_x86_64-simulator/Headers/rgb_libFFI.h',
    ),
    'android': (
        'classes.jar',
        'jni/arm64-v8a/librgblibuniffi.so',
        'jni/x86_64/librgblibuniffi.so',
    ),
}


def checked_file(path):
    if not path.is_file() or path.resolve() != path:
        raise ValueError(f'Expected a regular file: {path}')
    return path


def digest(path):
    with checked_file(path).open('rb') as stream:
        result = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
        return result.hexdigest()


def read_json(path):
    return json.loads(checked_file(path).read_bytes())


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def targets_match(value, expected):
    return isinstance(value, list) and len(value) == len(expected) and set(value) == expected


def check_identity(manifest, sha256, build_script_sha256, identity):
    source = manifest['source']
    integration = manifest['integration']
    build = manifest['build']
    features = manifest['features']
    if ((manifest['version'], manifest['bridgeVersion'], source['revision'], manifest['nativeOverlay'])
            != (VERSION, BRIDGE_VERSION, REVISION, OVERLAY)
            or source['upstreamTag'] != SOURCE_TAG or source['upstreamTagCommit'] != TAG_COMMIT
            or features.get('durableHostedBridge') is not True
            or features.get('dispatchedRgbRevocation') is not True):
        raise ValueError('Sealed manifest does not identify the admitted BFA.8 mobile overlay.')

    expected = {
        'schema_version': 2,
        'version': VERSION,
        'native_overlay': OVERLAY,
        'bridge_version': BRIDGE_VERSION,
        'source_repository': 'UTEXO-Protocol/rgb-lib-bfa',
        'source_commit': REVISION,
        'source_lock_sha256': integration['uniffiLockSha256'],
        'core_overlay_tree': source['coreOverlayTree'],
        'integration_tree': integration['tree'],
        'overlay_patch_sha256': integration['patchSha256'],
        'source_manifest_sha256': sha256,
        'build_script_sha256': build_script_sha256,
        'bridge_patch_sha256': integration.get('bridgePatch', {}).get('sha256', integration['patchSha256']),
        'sqlite_overlay_tree': manifest.get('sqlite3', {}).get('overlayTree'),
        'ios_sqlite_compile_flags': manifest.get('sqlite3', {}).get('iosCompileFlags', []),
        'dispatched_rgb_revocation': True,
        'durable_hosted_bridge': True,
        'min_android_api': build['minAndroidApi'],
        'min_ios_version': build['minIosVersion'],
        'android_ndk': build['androidNdk'],
        'kotlin_version': build['kotlinVersion'],
        'build_profile': 'release',
        'local_candidate': True,
        'platform': 'cross-platform',
    }
    all_targets = TARGETS['apple'] | TARGETS['android']
    for field, value in expected.items():
        if type(identity.get(field)) is not type(value) or identity[field] != value:
            raise ValueError(f'Build record does not match the sealed manifest: {field}.')
    if not targets_match(build['targets'], all_targets) or not targets_match(identity.get('targets'), all_targets):
        raise ValueError('Build record does not cover all five mobile targets.')


def inspect_archives(directory, record):
    verified = {}
    for name, (platform, metadata_name) in ARCHIVES.items():
        entry = record['artifacts'][name]
        archive_path = checked_file(directory / name)
        if (type(entry['sizeBytes']) is not int or not re.fullmatch(r'[0-9a-f]{64}', entry['sha256'])
                or archive_path.stat().st_size != entry['sizeBytes'] or digest(archive_path) != entry['sha256']):
            raise ValueError(f'Mobile archive differs from the build record: {name}.')
        with zipfile.ZipFile(archive_path) as archive:
            members = archive.namelist()
            for required in ARCHIVE_MEMBERS[platform]:
                if members.count(required) != 1 or archive.getinfo(required).file_size == 0:
                    raise ValueError(f'Mobile archive is missing a unique required member: {required}.')
            matches = [item for item in archive.infolist() if item.filename == metadata_name]
            if len(matches) != 1 or not 0 < matches[0].file_size < 256 * 1024:
                raise ValueError(f'Mobile archive requires exactly one bounded provenance entry: {name}.')
            metadata = json.loads(archive.read(matches[0]))
        # Each packager emits the same identity, with only these two fields
        # describing the selected platform and compiled target subset.
        expected = {**record['identity'], 'platform': platform}
        target_order = expected.pop('targets')
        expected['targets'] = [target for target in target_order if target in TARGETS[platform]]
        if metadata != expected:
            raise ValueError(f'Mobile archive embeds provenance for a different build: {name}.')
        verified[name] = entry
    return verified


def copy_checked(source, destination):
    before = digest(source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    if digest(destination) != before or digest(source) != before:
        raise ValueError(f'Input changed during staging: {source}.')


def tracked_sdk_paths(root):
    names = subprocess.check_output(['git', '-C', root, 'ls-files', '-z', '--', *SDK_SCOPES])
    return sorted(name for name in os.fsdecode(names).split('\0') if name)


def replace_once(path, old, new):
    text = path.read_text()
    if text.count(old) != 1:
        raise ValueError(f'SDK build override boundary changed: {path.name}.')
    path.write_text(text.replace(old, new))


def configure_wrapper_abi(sdk, patch, source_version):
    """Apply the historical ABI delta, or verify it is already fully present.

    Staging may start from the old BFA.7 checkout or from the promoted BFA.8
    default. A reverse check makes the latter an explicit, validated no-op;
    failed forward application alone never means that a patch is present.
    """
    environment = os.environ.copy()
    environment['GIT_CEILING_DIRECTORIES'] = str(sdk.parent)
    if source_version == VERSION:
        arguments = ['--reverse', '--check']
    elif source_version == PREVIOUS_VERSION:
        arguments = ['--check']
    else:
        raise ValueError(f'Unsupported SDK native baseline for BFA.8 staging: {source_version}.')
    checked = subprocess.run(['git', '-C', sdk, 'apply', *arguments, patch],
                             env=environment, capture_output=True, text=True)
    if checked.returncode != 0:
        raise ValueError('SDK wrappers do not match their declared BFA native ABI: '
                         + checked.stderr.strip())
    if source_version == PREVIOUS_VERSION:
        subprocess.run(['git', '-C', sdk, 'apply', patch], env=environment, check=True)


def configure_sdk(sdk, manifest, record, patch):
    source_pin = read_json(sdk / 'tool/rgb_lib_native_baseline.json')
    identity = record['identity']
    archives = record['artifacts']
    swift = archives[f'rgb-lib-bfa-swift-{VERSION}.zip']
    android = archives[f'rgb-lib-bfa-android-{VERSION}.aar']
    pin = {
        'version': VERSION,
        'sourceTag': SOURCE_TAG,
        'sourceRevision': REVISION,
        'bridgeVersion': BRIDGE_VERSION,
        'uniffiVersion': manifest['build']['uniffi'],
        'swiftModule': 'RGBLib',
        'sourceLockSha256': identity['source_lock_sha256'],
        'integrationTree': identity['integration_tree'],
        'sourceOverlaySha256': identity['overlay_patch_sha256'],
        'sourceManifestSha256': identity['source_manifest_sha256'],
        'nativeOverlay': OVERLAY,
        'localCandidate': True,
        'features': {'dispatchedRgbRevocation': True, 'durableHostedBridge': True},
        'ios': {'sha256': swift['sha256'], 'sizeBytes': swift['sizeBytes'],
                'minIosVersion': manifest['build']['minIosVersion']},
        'android': {'mavenCoordinate': f'com.utexo:rgb-lib-bfa-android:{VERSION}',
                    'archiveSha256': android['sha256'], 'archiveSizeBytes': android['sizeBytes'],
                    'abis': ['arm64-v8a', 'x86_64']},
    }
    if source_pin['version'] == VERSION:
        # Promotion adds remote download URLs, while a local stage must still
        # require the exact admitted archives. Check every shared identity
        # field before replacing download configuration with local overrides.
        for field, value in pin.items():
            if field == 'localCandidate':
                continue
            actual = source_pin.get(field)
            if isinstance(value, dict):
                if not isinstance(actual, dict) or any(actual.get(k) != v for k, v in value.items()):
                    raise ValueError(f'Promoted BFA.8 baseline differs from its sealed archive: {field}.')
            elif actual != value:
                raise ValueError(f'Promoted BFA.8 baseline differs from its sealed archive: {field}.')
    configure_wrapper_abi(sdk, patch, source_pin['version'])
    write_json(sdk / 'tool/rgb_lib_native_baseline.json', pin)

    runtime = sdk / 'lib/src/wallet/rgb_lib/wire.dart'
    text = runtime.read_text()
    for dart_key, metadata_key in RUNTIME_KEYS.items():
        expression = rf"(static const {dart_key}\s*=\s*)(?:'[^']+'|\d+);"
        text, count = re.subn(expression, lambda match: f'{match[1]}{identity[metadata_key]!r};', text)
        if count != 1:
            raise ValueError(f'SDK native runtime declaration changed: {dart_key}.')
    runtime.write_text(text)

    # Candidate builds must explicitly select the admitted local files. The
    # stock installers still enforce archive size, digest and iOS provenance.
    replace_once(sdk / 'tool/install_rgb_lib_ios.py',
                 '    identity = build_identity()\n',
                 '    if not os.environ.get("RGB_LIB_IOS_ARCHIVE_PATH"):\n'
                 '        raise ValueError("BFA.8 candidate requires RGB_LIB_IOS_ARCHIVE_PATH.")\n'
                 '    identity = build_identity()\n')
    replace_once(sdk / 'android/build.gradle.kts',
                 'val rgbLibExpectedSize =',
                 'require(rgbLibAndroidArtifactDirectory.isPresent) {\n'
                 '    "BFA.8 candidate requires RGB_LIB_ANDROID_ARTIFACT_DIR."\n'
                 '}\nval rgbLibExpectedSize =')

def verify_sdk_inputs(sdk, expected_hashes):
    for relative in COMPILABLE_ROOTS:
        root = sdk / relative
        if not root.is_dir() or root.resolve() != root:
            raise ValueError(f'Expected a regular SDK source directory: {relative}.')
        expected = {name for name in expected_hashes if name.startswith(relative + '/')}
        actual = set()
        directories = [root]
        while directories:
            for path in directories.pop().iterdir():
                name = path.relative_to(sdk).as_posix()
                if path.is_symlink():
                    raise ValueError(f'Symlink in staged SDK source: {name}.')
                if path.is_dir():
                    directories.append(path)
                elif path.is_file():
                    actual.add(name)
                else:
                    raise ValueError(f'Unexpected filesystem entry in staged SDK source: {name}.')
        if actual != expected:
            missing = ', '.join(sorted(expected - actual))
            added = ', '.join(sorted(actual - expected))
            raise ValueError(f'Staged SDK source inventory changed under {relative}. '
                             f'Missing: {missing or "none"}. Added: {added or "none"}.')

    for name, expected in expected_hashes.items():
        path = sdk / name
        if not path.resolve().is_relative_to(sdk) or digest(path) != expected:
            raise ValueError(f'Staged SDK input changed: {name}.')


def verify(output):
    receipt = read_json(output / 'stage-input.json')
    if receipt['scope'] != SCOPE or receipt['releaseArtifact'] is not False:
        raise ValueError('Directory does not contain a local BFA.8 SDK staging receipt.')
    manifest_path = output / 'sealed-source-manifest.json'
    record_path = output / 'build-record.json'
    record = read_json(record_path)
    if digest(record_path) != receipt['buildRecordSha256']:
        raise ValueError('Staged build record changed.')
    check_identity(read_json(manifest_path), digest(manifest_path),
                   digest(output / 'native-build-script.py'), record['identity'])
    if inspect_archives(output / 'artifacts', record) != receipt['archives']:
        raise ValueError('Staged archives differ from the staging receipt.')
    verify_sdk_inputs(output / 'sdk', receipt['sdkInputs'])


def stage(root, output):
    artifacts = root / BUILD_DIR / 'artifacts'
    source_manifest = root / SOURCE_MANIFEST
    manifest = read_json(source_manifest)
    manifest_digest = digest(source_manifest)
    record_path = artifacts / 'build-record.json'
    record = read_json(record_path)
    record_digest = digest(record_path)
    check_identity(manifest, manifest_digest, digest(root / BUILD_SCRIPT), record['identity'])
    archives = inspect_archives(artifacts, record)

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.stage-bfa8-', dir=output.parent) as work:
        target = Path(work) / 'candidate'
        sdk = target / 'sdk'
        names = tracked_sdk_paths(root)
        for name in names:
            copy_checked(root / name, sdk / name)
        copy_checked(root / WRAPPER_PATCH, target / 'wrapper.patch')
        configure_sdk(sdk, manifest, record, target / 'wrapper.patch')
        copy_checked(source_manifest, target / 'sealed-source-manifest.json')
        copy_checked(root / BUILD_SCRIPT, target / 'native-build-script.py')
        copy_checked(record_path, target / 'build-record.json')
        if digest(target / 'sealed-source-manifest.json') != manifest_digest:
            raise ValueError('Sealed source manifest changed during staging.')
        for name in archives:
            copy_checked(artifacts / name, target / 'artifacts' / name)
        write_json(target / 'stage-input.json', {
            'scope': SCOPE,
            'releaseArtifact': False,
            'sourceHead': subprocess.check_output(['git', '-C', root, 'rev-parse', 'HEAD'], text=True).strip(),
            'nativeVersion': VERSION,
            'nativeRevision': REVISION,
            'bridgeVersion': BRIDGE_VERSION,
            'buildRecordSha256': record_digest,
            'sdkInputs': {name: digest(sdk / name) for name in names},
            'archives': archives,
        })
        verify(target)
        if output.exists() or output.is_symlink():
            raise ValueError('Output already exists. Use a new directory to preserve the previous stage.')
        target.rename(output)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / DEFAULT_OUTPUT)
    parser.add_argument('--verify', action='store_true', help='Verify an existing stage without changing it.')
    args = parser.parse_args()
    output = args.output.absolute()
    buildlog = ROOT / '.buildlog'
    try:
        if output != output.resolve() or output == buildlog or not output.is_relative_to(buildlog):
            raise ValueError('Output must be a nonsymlink path under the SDK .buildlog directory.')
        if args.verify:
            verify(output)
        else:
            if output.exists():
                raise ValueError('Output already exists. Use a new directory to preserve the previous stage.')
            stage(ROOT, output)
        print(f'Verified local-only BFA.8 SDK: {output / "sdk"}')
        print('export RGB_LIB_IOS_ARCHIVE_PATH=' + shlex.quote(str(output / 'artifacts' / f'rgb-lib-bfa-swift-{VERSION}.zip')))
        print('export RGB_LIB_IOS_OFFLINE=1')
        print('export RGB_LIB_ANDROID_ARTIFACT_DIR=' + shlex.quote(str(output / 'artifacts')))
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        sys.exit(f'BFA.8 staging failed: {error}')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3.13
"""Build a host consumer only from the verified prepared sealed native tree."""
import hashlib, json, os, subprocess, tomllib
from pathlib import Path

SDK = Path(__file__).resolve().parents[2]
TOOL = Path(__file__).resolve().parent
NATIVE = SDK / '.buildlog/bfa7-finalize'
MANIFEST = SDK / 'native/rgb_l1/source-manifest.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def packages(path):
    return {(p['name'], p['version'], p.get('source'), p.get('checksum'))
            for p in tomllib.loads(path.read_text())['package']}



def load_verified_build():
    """Read-only admission for every executable qualification helper."""
    manifest_bytes = MANIFEST.read_bytes()
    manifest = json.loads(manifest_bytes)
    source = NATIVE / 'source'
    native_lock = source / 'bindings/uniffi/Cargo.lock'
    binary = NATIVE / 'target-host/debug/flutter-bfa7-native-qualification'
    built = json.loads((NATIVE / 'qualification-client-build.json').read_text())
    expected = {
        'binarySha256': digest(binary),
        'integrationTree': manifest['integration']['tree'],
        'sourceManifestSha256': hashlib.sha256(manifest_bytes).hexdigest(),
        'sourceLockSha256': digest(native_lock),
        'consumerLockSha256': digest(TOOL / 'Cargo.lock'),
        'consumerSourceSha256': digest(TOOL / 'src/main.rs'),
        'consumerManifestSha256': digest(TOOL / 'Cargo.toml'),
        'rustToolchain': manifest['build']['rust'],
    }
    if any(built.get(key) != value for key, value in expected.items()):
        raise RuntimeError('Host qualification build does not match the current seal.')
    if expected['sourceLockSha256'] != manifest['integration']['uniffiLockSha256']:
        raise RuntimeError('Native lock differs from the current seal.')
    if packages(TOOL / 'Cargo.lock') - packages(native_lock) != {
            ('flutter-bfa7-native-qualification', '0.1.0', None, None)}:
        raise RuntimeError('Qualification consumer dependency graph differs from the seal.')
    if subprocess.run(['git', '-C', str(source), 'diff', '--quiet',
                       expected['integrationTree']], capture_output=True).returncode != 0:
        raise RuntimeError('Prepared source differs from the current seal.')
    return built


def main():
    manifest_digest = digest(MANIFEST)
    manifest = json.loads(MANIFEST.read_text())
    tree = manifest['integration']['tree']
    source = NATIVE / 'source'
    lock = source / 'bindings/uniffi/Cargo.lock'
    assert subprocess.run(['git', '-C', str(source), 'diff', '--quiet', tree],
                          capture_output=True).returncode == 0, 'Prepared source differs from seal.'
    assert digest(lock) == manifest['integration']['uniffiLockSha256'], 'Native lock differs from seal.'
    common = packages(lock)
    consumer = packages(TOOL / 'Cargo.lock')
    assert consumer - common == {('flutter-bfa7-native-qualification', '0.1.0', None, None)}, 'Unpinned consumer dependency.'
    env = dict(os.environ, CARGO_TARGET_DIR=str(NATIVE / 'target-host'), CARGO_BUILD_JOBS='2',
               CARGO_PROFILE_DEV_DEBUG='0', CARGO_INCREMENTAL='0')
    toolchain = manifest['build']['rust']
    compiler = subprocess.check_output(['rustc', '+' + toolchain, '--version'], text=True).strip()
    subprocess.run(['cargo', '+' + toolchain, 'build', '--offline', '--locked', '--manifest-path', str(TOOL / 'Cargo.toml')],
                   env=env, check=True)
    assert digest(MANIFEST) == manifest_digest, 'Seal changed during build.'
    assert subprocess.run(['git', '-C', str(source), 'diff', '--quiet', tree],
                          capture_output=True).returncode == 0, 'Native source changed during build.'
    binary = NATIVE / 'target-host/debug/flutter-bfa7-native-qualification'
    result = {'binarySha256': digest(binary), 'integrationTree': tree,
              'sourceManifestSha256': manifest_digest, 'sourceLockSha256': digest(lock),
              'consumerLockSha256': digest(TOOL / 'Cargo.lock'),
              'consumerSourceSha256': digest(TOOL / 'src/main.rs'),
              'consumerManifestSha256': digest(TOOL / 'Cargo.toml'),
              'sharedPackages': len(common & consumer), 'consumerOnlyPackage': 'flutter-bfa7-native-qualification',
              'rustToolchain': toolchain, 'rustc': compiler,
              'host': 'macOS native Rust, not a mobile ABI claim'}
    target = NATIVE / 'qualification-client-build.json'
    temp = target.with_suffix('.json.tmp')
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as stream:
        json.dump(result, stream, indent=2)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temp, target)
    print(json.dumps(result))


if __name__ == '__main__':
    main()

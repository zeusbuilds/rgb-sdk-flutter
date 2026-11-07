#!/usr/bin/env python3.13
"""Run offline observation tests against a sealed-source copy, never a live stack.

The only source overlay is one cfg(test) include of the tracked test module.
Published source and its executable qualification clients remain unchanged.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import time

SDK = Path(__file__).resolve().parents[2]
NATIVE = SDK / '.buildlog/bfa7-finalize'
SOURCE = NATIVE / 'source'
MANIFEST = SDK / 'native/rgb_l1/source-manifest.json'
TEST = SDK / 'native/rgb_l1/qualification/durable_fault_qualification.rs'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pristine(tree):
    subprocess.run(['git', '-C', str(SOURCE), 'diff', '--exit-code', tree],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)


def main():
    manifest_digest = sha(MANIFEST)
    manifest = json.loads(MANIFEST.read_text())
    tree = manifest['integration']['tree']
    # The seal-specific names retain every historical run rather than mixing
    # an old production tree with the currently admitted source manifest.
    copy = NATIVE / ('fault-host-source-' + tree[:12])
    log_path = NATIVE / ('fault-observation-host-' + tree[:12] + '.log')
    proof_path = NATIVE / ('fault-observation-host-' + tree[:12] + '-proof.json')
    pristine(tree)
    if copy.exists() or log_path.exists() or proof_path.exists():
        raise RuntimeError('Preserve previous evidence: use a new dedicated test-copy path.')
    raw = subprocess.check_output(['git', '-C', str(SOURCE), 'archive', '--format=tar', tree])
    copy.mkdir(mode=0o700)
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        archive.extractall(copy, filter='data')
    relative = 'src/wallet/durable_observation.rs'
    with (copy / relative).open('a') as file:
        file.write('\n#[cfg(all(test, feature = "esplora"))]\n#[path = ' + json.dumps(str(TEST)) + ']\nmod fault_qualification;\n')
    # The source root's exact lock already includes its development-only mockito
    # dependency. No Cargo graph, source revision or production body is changed.
    command = ['cargo', '+' + manifest['build']['rust'], 'test', '--offline', '--locked',
               '--manifest-path', str(copy / 'Cargo.toml'), '--no-default-features',
               '--features', 'wallet,electrum,esplora', '--lib',
               'wallet::durable_observation::fault_qualification::', '--', '--nocapture']
    env = dict(os.environ, CARGO_TARGET_DIR=str(NATIVE / 'target-host'),
               CARGO_BUILD_JOBS='2', CARGO_PROFILE_DEV_DEBUG='0', CARGO_INCREMENTAL='0')
    start = time.time()
    with log_path.open('x') as log:
        result = subprocess.run(command, env=env, cwd=SDK, stdout=log, stderr=subprocess.STDOUT)
    pristine(tree)
    if sha(MANIFEST) != manifest_digest:
        raise RuntimeError('Source seal changed during test; result not admitted.')
    text = log_path.read_text()
    if result.returncode:
        print(text[-12000:])
        raise SystemExit(result.returncode)
    assert '8 passed; 0 failed' in text
    proof = {'passed': True, 'scope': 'mock HTTP native observation logic; no live chain/reorg or monetary actions',
             'integrationTree': tree, 'sourceManifestSha256': manifest_digest,
             'testSourceSha256': sha(TEST), 'coreLockSha256': sha(copy / 'Cargo.lock'),
             'runtimeSourceUnchanged': True, 'productionSourceOverlay': False,
             'testOnlyModuleOverlay': relative, 'cases': 8,
             'rustToolchain': manifest['build']['rust'], 'logSha256': sha(log_path),
             'elapsedSeconds': round(time.time() - start, 3)}
    with proof_path.open('x') as output:
        output.write(json.dumps(proof, indent=2) + '\n')
    print(json.dumps(proof, indent=2))


if __name__ == '__main__':
    main()

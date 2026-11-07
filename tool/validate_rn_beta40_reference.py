#!/usr/bin/env python3
"""Verify the published RN package and reproduce the audited source delta.

This does not install or execute upstream code, or change the Flutter baseline.
"""

import argparse
import base64
import gzip
import hashlib
import io
import json
import re
import sys
import tarfile
from pathlib import Path
from urllib.request import urlopen


LOCK = Path(__file__).with_name('rn_beta40_reference.json')
MAX_ARCHIVE_BYTES = 4 * 1024 * 1024
MAX_SOURCE_BYTES = 8 * 1024 * 1024
MAX_MEMBERS = 512


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_archive(url, path):
    if path is None:
        handle = urlopen(url, timeout=30)
    else:
        handle = path.open('rb')
    with handle:
        data = handle.read(MAX_ARCHIVE_BYTES + 1)
    require(len(data) <= MAX_ARCHIVE_BYTES, 'Reference archive exceeds the size limit')
    return data


def source_files(data, root, commit=None):
    files = {}
    seen = set()
    with gzip.GzipFile(fileobj=io.BytesIO(data)) as compressed:
        unpacked = compressed.read(MAX_SOURCE_BYTES + 1)
    require(len(unpacked) <= MAX_SOURCE_BYTES,
            'Reference archive exceeds the unpacked size limit')
    with tarfile.open(fileobj=io.BytesIO(unpacked), mode='r:') as archive:
        for index, member in enumerate(archive):
            require(index < MAX_MEMBERS, 'Reference archive has too many members')
            parts = member.name.split('/')
            require(parts[0] == root, 'Reference archive root does not match its pin')
            require(all(part not in ('', '.', '..') for part in parts)
                    and not re.search(r'[\\\r\n\x00]', member.name),
                    'Unsafe path in the reference archive')
            require(member.name not in seen, 'Duplicate path in the reference archive')
            seen.add(member.name)
            if member.isdir():
                continue
            require(member.isreg() and len(parts) > 1 and not member.issparse(),
                    'Unexpected member in the reference archive')
            require(0 <= member.size <= MAX_SOURCE_BYTES, 'Unexpected reference file size')
            with archive.extractfile(member) as content:
                files['/'.join(parts[1:])] = content.read()
        if commit is not None:
            require(archive.pax_headers.get('comment') == commit,
                    'GitHub source archive commit does not match its pin')
    return files


def read_source(pin, path):
    commit = pin['commit']
    require(re.fullmatch(r'[0-9a-f]{40}', commit), 'Expected a full upstream commit ID')
    url = f'https://codeload.github.com/UTEXO-Protocol/rgb-sdk-rn/tar.gz/{commit}'
    files = source_files(read_archive(url, path), f'rgb-sdk-rn-{commit}', commit)
    digest = hashlib.sha256()
    for name, content in sorted(files.items()):
        digest.update(f'{hashlib.sha256(content).hexdigest()}  {name}\n'.encode())
    require(len(files) == pin['fileCount'] and digest.hexdigest() == pin['filesSha256'],
            f'GitHub source file count or content does not match commit {commit}')
    return files


def verify(args):
    lock = json.loads(LOCK.read_text(encoding='utf-8'))
    if args.check_latest:
        latest_url = 'https://registry.npmjs.org/@utexo%2Frgb-sdk-rn/latest'
        latest = json.loads(read_archive(latest_url, None))
        require((latest['version'], latest['gitHead'])
                == (lock['version'], lock['source']['commit']),
                'A newer or different RN release needs a parity review')
    older = read_source(lock['legacy'], args.legacy_source)
    source = read_source(lock['source'], args.source)
    require(json.loads(older['package.json'])['version'] == lock['legacy']['version'],
            'Legacy package version does not match its source pin')

    registry = lock['registry']
    data = read_archive(registry['url'], args.package)
    require(len(data) == registry['sizeBytes'], 'npm archive size does not match its pin')
    require(hashlib.sha256(data).hexdigest() == registry['archiveSha256'],
            'npm archive SHA-256 does not match its pin')
    integrity = 'sha512-' + base64.b64encode(hashlib.sha512(data).digest()).decode('ascii')
    require(integrity == registry['integritySha512'], 'npm registry integrity check failed')
    package = source_files(data, 'package')
    require(len(package) == registry['fileCount'], 'Unexpected npm archive file count')
    shared = source.keys() & package.keys()
    require(len(shared) == registry['sharedSourceFileCount'],
            'Unexpected number of npm files shared with the GitHub source')
    for name in sorted(shared):
        require(source[name] == package[name], f'npm file differs from GitHub source: {name}')

    metadata = json.loads(package['package.json'])
    require((metadata['name'], metadata['version']) == (lock['package'], lock['version']),
            'Unexpected package name or version')
    require(metadata['repository']['url'] == lock['repository'] + '.git',
            'npm package repository does not match the source pin')
    require(metadata['rgbSdk']['rln'] is False, 'Expected RLN to be disabled in beta.40')

    native_manifest = json.loads(source['src/bindings/rgb-lib/manifest.json'])
    # Preserve the exact released RN native reference even when Flutter carries a
    # separately qualified source overlay. Advancing Flutter must not relabel RN.
    reference_pin = lock['nativeReference']
    reference_path = LOCK.with_name(reference_pin['path'])
    reference_bytes = reference_path.read_bytes()
    require(hashlib.sha256(reference_bytes).hexdigest() == reference_pin['sha256'],
            'Frozen RN native reference digest changed')
    reference_native = json.loads(reference_bytes)
    for field in ('version', 'sourceTag', 'sourceRevision', 'uniffiVersion',
                  'bridgeVersion', 'swiftModule'):
        require(reference_native[field] == native_manifest[field],
                f'Released RN RGB_L1 reference differs: {field}')
    for field in ('url', 'sha256', 'minIosVersion'):
        require(reference_native['ios'][field] == native_manifest['ios'][field],
                f'Released RN RGB_L1 iOS reference differs: {field}')
    flutter_native = json.loads(LOCK.with_name('rgb_lib_native_baseline.json')
                                .read_text(encoding='utf-8'))
    validate_flutter_native_upgrade(flutter_native, reference_native)

    added = source.keys() - older.keys()
    removed = older.keys() - source.keys()
    modified = {name for name in older.keys() & source.keys() if older[name] != source[name]}
    changes = sorted([f'+ {name}' for name in added]
                     + [f'- {name}' for name in removed]
                     + [f'~ {name}' for name in modified])
    expected = lock['delta']
    require((len(added), len(removed), len(modified))
            == (expected['added'], expected['removed'], expected['modified']),
            'Unexpected number of changed upstream paths')
    require(hashlib.sha256('\n'.join(changes).encode()).hexdigest() == expected['pathsSha256'],
            'Upstream delta paths do not match the audit')
    if args.list_changes:
        print('\n'.join(changes))
    print(f"Verified {lock['package']}@{lock['version']} at {lock['source']['commit']}. "
          f'{len(shared)} shipped source files match; {len(changes)} changed paths verified.')


def validate_flutter_native_upgrade(current, reference):
    """Validate the explicit BFA.7 divergence; never accept an arbitrary new pin."""
    if current == reference:
        return
    root = LOCK.parent.parent
    manifest_path = root / 'native/rgb_l1/source-manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    require(current['version'] == manifest['version']
            == '0.3.0-beta.7-upstream-dev-bfa.7-bfa-flutter.1',
            'Flutter native upgrade has an unreviewed version')
    require(current['sourceRevision'] == manifest['source']['revision']
            == '9ec49c08be2e68f08521281e3efbd760ec989cb9',
            'Flutter native upgrade has an unreviewed source')
    require(current['bridgeVersion'] == manifest['bridgeVersion'] == 5
            and current['uniffiVersion'] == manifest['build']['uniffi'] == '0.32.2'
            and current['swiftModule'] == reference['swiftModule'] == 'RGBLib',
            'Flutter native upgrade ABI differs from its reviewed contract')
    integration = manifest['integration']
    require(re.fullmatch(r'[0-9a-f]{64}', integration['patchSha256'])
            and current['sourceOverlaySha256'] == integration['patchSha256']
            and current['integrationTree'] == integration['tree']
            and re.fullmatch(r'[0-9a-f]{40}', integration['tree'])
            and current['sourceLockSha256'] == integration['uniffiLockSha256']
            and re.fullmatch(r'[0-9a-f]{64}', integration['uniffiLockSha256'])
            and current['nativeOverlay'] == manifest['nativeOverlay']
            == 'flutter-bfa7-durable-v1'
            and current['sourceManifestSha256']
            == hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
            'Flutter native upgrade provenance is incomplete or mismatched')
    for patch in manifest['corePatches'] + [manifest['esplora']['patch']]:
        path = manifest_path.parent / patch['path']
        require(hashlib.sha256(path.read_bytes()).hexdigest() == patch['sha256'],
                f'Flutter native core patch differs: {patch["path"]}')
    overlay = manifest_path.parent / integration['patch']
    require(hashlib.sha256(overlay.read_bytes()).hexdigest()
            == integration['patchSha256'], 'Flutter native integration patch differs')
    for platform, archive_key in [('ios', 'sha256'), ('android', 'archiveSha256')]:
        require(isinstance(current[platform][archive_key], str)
                and re.fullmatch(r'[0-9a-f]{64}', current[platform][archive_key]),
                f'Flutter {platform} native archive is not checksum pinned')
    require(type(current['ios']['sizeBytes']) is int and current['ios']['sizeBytes'] > 0
            and type(current['android']['archiveSizeBytes']) is int
            and current['android']['archiveSizeBytes'] > 0,
            'Flutter native archive sizes must be pinned')
    print('Flutter BFA.7 overlay is separate from the frozen RN beta.40 native reference.')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--legacy-source', type=Path, help='Use a local beta.39 source archive.')
    parser.add_argument('--source', type=Path, help='Use a local beta.40 source archive.')
    parser.add_argument('--package', type=Path, help='Use a local beta.40 npm archive.')
    parser.add_argument('--check-latest', action='store_true',
                        help='Also verify the current npm latest tag.')
    parser.add_argument('--list-changes', action='store_true', help='Print every changed source path.')
    try:
        verify(parser.parse_args())
    except (OSError, EOFError, ValueError, KeyError, tarfile.TarError) as error:
        sys.exit(f'RN beta.40 reference validation failed: {error}')


if __name__ == '__main__':
    main()

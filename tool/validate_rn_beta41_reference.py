#!/usr/bin/env python3
"""Verify the released RGB_L1 engine, its Core contract and the full source delta."""

import argparse
import hashlib
import json
import sys
import tarfile
from pathlib import Path
from urllib.parse import quote

from validate_rn_beta40_reference import (
    read_archive,
    read_npm_package,
    read_source,
    require,
    validate_flutter_native_upgrade,
    verify_source_delta,
)


LOCK = Path(__file__).with_name('rn_beta41_reference.json')


def registry_metadata(package, tag):
    url = f'https://registry.npmjs.org/{quote(package, safe="@")}/{tag}'
    return json.loads(read_archive(url, None))


def verify_registry_metadata(metadata, package, version, commit, pin):
    require((metadata['name'], metadata['version'], metadata['gitHead'])
            == (package, version, commit), f'Unexpected npm release for {package}')
    dist = metadata['dist']
    require((dist['tarball'], dist['fileCount'], dist['integrity'])
            == (pin['url'], pin['fileCount'], pin['integritySha512']),
            f'npm publication differs from the audit for {package}')


def verify_released_native(source, pin):
    reference_bytes = LOCK.with_name(pin['path']).read_bytes()
    require(hashlib.sha256(reference_bytes).hexdigest() == pin['sha256'],
            'Frozen RN native reference digest changed')
    reference = json.loads(reference_bytes)
    manifest = json.loads(source['src/bindings/rgb-lib/manifest.json'])
    for field in ('version', 'sourceTag', 'sourceRevision', 'uniffiVersion',
                  'bridgeVersion', 'swiftModule'):
        require(reference[field] == manifest[field], f'RN native pin differs: {field}')
    for field in ('url', 'sha256', 'minIosVersion'):
        require(reference['ios'][field] == manifest['ios'][field],
                f'RN iOS artifact differs: {field}')
    group, artifact, version = reference['android']['mavenCoordinate'].split(':')
    gradle = source['android/build.gradle'].decode()
    require(f'implementation "{group}:{artifact}:${{rgbLibPin.version}}"' in gradle
            and version == manifest['version'],
            'RN Android artifact coordinate differs from the native pin')
    return reference


def verify(args):
    lock = json.loads(LOCK.read_bytes())
    historical = json.loads(LOCK.with_name('rn_beta40_reference.json').read_bytes())
    registry = lock['registry']
    core_pin = lock['core']
    if args.check_latest:
        verify_registry_metadata(registry_metadata(lock['package'], 'latest'),
                                 lock['package'], lock['version'],
                                 lock['source']['commit'], registry)
        verify_registry_metadata(registry_metadata(core_pin['package'], core_pin['version']),
                                 core_pin['package'], core_pin['version'],
                                 core_pin['commit'], core_pin)

    older = read_source(historical['source'], args.previous_source)
    source = read_source(lock['source'], args.source)
    changes = verify_source_delta(older, source, lock['delta'])
    package = read_npm_package(registry, args.package)
    shared = source.keys() & package.keys()
    require(len(shared) == registry['sharedSourceFileCount'],
            'Unexpected number of npm files shared with the GitHub source')
    for name in sorted(shared):
        require(source[name] == package[name], f'npm file differs from GitHub source: {name}')

    metadata = json.loads(package['package.json'])
    require((metadata['name'], metadata['version'], metadata['repository']['url'])
            == (lock['package'], lock['version'], lock['repository'] + '.git'),
            'Unexpected npm package name, version or repository')
    require('rgbSdk' not in metadata and 'Rgb.podspec' not in source and 'RgbLib.podspec' in source,
            'Expected only the RGB_L1 engine in the beta.41 native build')
    core = read_npm_package(core_pin, args.core_package)
    core_metadata = json.loads(core['package.json'])
    require((core_metadata['name'], core_metadata['version'])
            == (core_pin['package'], core_pin['version'])
            and metadata['devDependencies'][core_pin['package']] == core_pin['version']
            and metadata['peerDependencies'][core_pin['package']] == '^' + core_pin['version'],
            'Core contract differs from the RN release requirements')
    for name, digest in core_pin['extractedFiles'].items():
        require(hashlib.sha256(core[name]).hexdigest() == digest,
                f'Published Core file differs from its pin: {name}')

    reference = verify_released_native(source, lock['nativeReference'])
    flutter_native = json.loads(LOCK.with_name('rgb_lib_native_baseline.json').read_bytes())
    validate_flutter_native_upgrade(flutter_native, reference)
    if args.list_changes:
        print('\n'.join(changes))
    print(f"Verified {lock['package']}@{lock['version']} at {lock['source']['commit']}, "
          f"Core {core_pin['version']}, {len(shared)} shipped source files and "
          f'{len(changes)} changed paths. Flutter retains its separately pinned native overlay.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--previous-source', type=Path, help='Use a local beta.40 source archive.')
    parser.add_argument('--source', type=Path, help='Use a local beta.41 source archive.')
    parser.add_argument('--package', type=Path, help='Use a local beta.41 npm archive.')
    parser.add_argument('--core-package', type=Path, help='Use a local Core beta.10 npm archive.')
    parser.add_argument('--check-latest', action='store_true', help='Verify npm registry metadata.')
    parser.add_argument('--list-changes', action='store_true', help='Print every changed source path.')
    try:
        verify(parser.parse_args())
    except (OSError, EOFError, ValueError, KeyError, tarfile.TarError) as error:
        sys.exit(f'RN beta.41 reference validation failed: {error}')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Verify exact RN beta.42 publication, Core beta.11 and reviewed native source.

This proves reference identity and source delta, not full Flutter API parity.
PSBT and generic begin/end flows remain an explicitly documented divergence.
"""

import argparse
import hashlib
import json
import sys
import tarfile
from pathlib import Path

from validate_rn_beta40_reference import (
    read_npm_package,
    read_source,
    require,
    validate_flutter_native_upgrade,
    verify_source_delta,
)
from validate_rn_beta41_reference import (
    registry_metadata,
    verify_registry_metadata,
    verify_released_native,
)

LOCK = Path(__file__).with_name('rn_beta42_reference.json')


def verify(args):
    lock = json.loads(LOCK.read_bytes())
    historical = json.loads(LOCK.with_name('rn_beta41_reference.json').read_bytes())
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
            'Expected only the RGB_L1 engine in the beta.42 native build')
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
    native = json.loads(LOCK.with_name('rgb_lib_native_baseline.json').read_bytes())
    validate_flutter_native_upgrade(native, reference)
    require(native['sourceRevision'] == reference['sourceRevision']
            == 'cafe66e49d58038a69dd05f8065e3fe96a9d1601'
            and native['sourceTag'] == reference['sourceTag']
            == 'v0.3.0-beta.7-upstream-dev-bfa.8',
            'Flutter must load the reviewed BFA.8 source, not merely stage a candidate')
    require(native['version'] == '0.3.0-beta.7-upstream-dev-bfa.8-bfa-flutter.1',
            'Flutter must preserve its separately versioned durable recovery overlay')
    if args.list_changes:
        print('\n'.join(changes))
    print(f"Verified {lock['package']}@{lock['version']} at {lock['source']['commit']}, "
          f"Core {core_pin['version']}, {len(shared)} shipped source files and "
          f'{len(changes)} changed paths; Flutter defaults to the same BFA.8 base '
          'with its separate native overlay. This is reference verification, not full API parity.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--previous-source', type=Path, help='Use a local beta.41 source archive.')
    parser.add_argument('--source', type=Path, help='Use a local beta.42 source archive.')
    parser.add_argument('--package', type=Path, help='Use a local beta.42 npm archive.')
    parser.add_argument('--core-package', type=Path, help='Use a local Core beta.11 npm archive.')
    parser.add_argument('--check-latest', action='store_true', help='Verify npm registry metadata.')
    parser.add_argument('--list-changes', action='store_true', help='Print every changed source path.')
    try:
        verify(parser.parse_args())
    except (OSError, EOFError, ValueError, KeyError, tarfile.TarError) as error:
        sys.exit(f'RN beta.42 reference validation failed: {error}')


if __name__ == '__main__':
    main()

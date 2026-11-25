# BFA.8 Flutter native integration

The default SDK native baseline selects `0.3.0-beta.7-upstream-dev-bfa.8-bfa-flutter.1`
with UniFFI 0.32.2 and Flutter bridge 6. Both upstream mobile artifacts name
`cafe66e49d58038a69dd05f8065e3fe96a9d1601`. The BFA.8 source tag points to
its first parent `2f7b21d8637baad548504ea870deb2c0d4d0a37d`. This integration
uses the artifact commit, including the upstream bindgen compatibility merge.
It matches the BFA.8 source used by React Native `1.0.0-beta.42`.

The selected archives are the exact previously sealed Flutter candidate bytes.
Their original `local_candidate: true` metadata and source manifest remain
unchanged; promotion does not relabel their provenance or approve production.
`tool/rgb_lib_native_baseline.json` records the download URLs, sizes and digests.
Both archives are available from the
[Flutter BFA.8 native prerelease](https://github.com/UTEXO-Protocol/flutter-sdk/releases/tag/native-bfa8-flutter.1).
Fresh anonymous downloads from the SDK's pinned URLs matched the sealed sizes
and SHA-256 digests. Consumers of SDK commit `82bb992` use these archives by
default.

Flutter carries forward exact-ID genesis-only registration, the guarded
network clients, Dev Signet checkpoint, SQLite container rules, and durable
prepare/commit/status/cancel/revoke. The native migration for prepared sweeps
is retained for BFA.7 storage. Wallet profiles, authenticated outboxes and
version-3 command fingerprints retain their original format identifiers.
Runtime provenance separately verifies the actual BFA.8 source and lock.
Restored snapshots retain the spending fence.

The BFA.8 Android and iOS wrappers supply `false` for the upstream options
that bypass schema and contract checks. The integration admits NIA, UDA and
CFA schemas on mainnet, as required by BFA.8. It preserves exact BFA initial
supply from the wallet database. BFA.8's observed circulating supply can
include unfinalized EVM locks. It represents neither spendable balance nor
settlement evidence.

## Build and use locally

Use the pinned Rust, Xcode, Android NDK and UniFFI inputs in
[`source-bfa8-manifest.json`](../native/rgb_l1/source-bfa8-manifest.json).
Run the following commands from the Flutter SDK checkout. The mirror must
contain the exact upstream commit identified by the manifest.

```sh
python3 tool/build_rgb_lib_bfa7.py prepare --bfa8 --source /path/to/rgb-lib-bfa
python3 tool/build_rgb_lib_bfa7.py generate --bfa8
python3 tool/build_rgb_lib_bfa7.py build --bfa8
python3 tool/build_rgb_lib_bfa7.py package --bfa8
python3 tool/stage_bfa8_candidate.py
```

Point a test consumer's `rgb_sdk_flutter` path dependency to the verified
`.buildlog/bfa8-upgrade/staged-mobile/sdk`. Use the artifact environment
variables printed by the staging command. The staging receipt binds the
exact iOS ZIP, Android AAR, wrapper inputs and sealed source manifest.
`python3 tool/stage_bfa8_candidate.py --verify` rechecks that receipt.

The stage tool accepts both the historical BFA.7 wrapper source and the promoted
BFA.8 default. It checks the complete native ABI patch before applying it, or
checks that the complete patch is already present before leaving the wrappers
unchanged. Existing immutable stage receipts remain verifiable.

Aster's production RGB_L1 gate is closed. Use dedicated qualification wallets.
The local candidate receipt is ineligible for production release. The package's
RGB_L1 default does not authorize changing an existing Aster wallet's backend;
Aster keeps explicit backend selection.

## Verification

The sealed port reconstructed from a clean upstream checkout and compiled
for all five mobile targets. Both Android AAR libraries passed ELF checks
for 16 KiB pages. The installed Android test APKs passed ZIP alignment and
ran on Android 17 with 16 KiB pages. The installed iOS tests ran on an iOS 27
iPhone 18 Pro simulator.

On both platforms, the installed BFA.8 SDK reopened BFA.7 app storage with
the same wallet identity and recovery cohort. Tests covered a mismatched
contract ID, repeat registration without balance credit, the original
encrypted BFA.7 archive, the restored wallet's spending fence, fresh backup
round trips, and the BFA.8 mainnet schema policy. The SDK suite passed 729
tests. An additional 55 Rust tests covered recovery, backup validation,
prepared sweeps and reorg accounting.

These checks used dedicated test wallets and no funded broadcasts. Funded
settlement still requires a compatible fixture. The existing shared regtest
USDT export is a version-0 consignment, while this native runtime requires
version 1.

### Independent-engine follow-up, November 24

After extracting `RlnWallet` and changing `UtexoWallet` to composition with
RGB_L1 default, four native smoke cases passed on both iOS 27 and Android 17
with 16 KiB pages. They covered mainnet schema policy, the restored RGB wallet
spending fence, the default facade sharing one RGB_L1 session, and the explicit
RLN engine sharing its lifecycle with the facade. The SDK passed all 748 Dart
tests, and Aster passed 2,090 tests with explicit backend selection. Both
repositories passed analysis. These tests used isolated unfunded wallet storage;
production RGB_L1 and funded BFA.8 settlement qualification remain gated.

## Privacy and distribution status

The BFA.8 iOS archive has no code-backed exact-binary required-reason API review
yet. Its disposition is **unreviewed**, and production remains blocked. The
earlier BFA.7 linked-component review applies only to its exact source/archive
pair. Final signed-app API and aggregate privacy-manifest review, plus the
independent RLN privacy disposition, remain required.

The sealed BFA.8 source inventory contains 544 components, including build and
non-mobile dependencies. Compared with published BFA.7 Flutter.2, only the
`rustix`, `typed-path` and `zip` dependency versions changed; each includes
license text. All recorded license-text digests match the source bundle, and
the inherited-license payload is unchanged. The same 49 packages have no
package-local license text, and `rgb-lib-uniffi` has no package-level declared
license; inherited notices and the root source license retain their original
scope. The comparison found no new missing-notice issue, but is not a complete
linked-component SBOM or final licensing approval. Native binaries must be
distributed with their matching source, inventory and notices.

## Dependency review

The binding lock retains the guarded Esplora and SQLite builds, carries
forward the prior `ctutils`, Tokio and Arrow remediations, and pins
`rustix` 1.1.6. The exact mobile build lock had zero vulnerabilities and
zero unsound notices in the RustSec advisory database revision
`472a4c9a785030434f15d7da84964d60fbe789ab`. The scan reported four
unmaintained dependencies. The separate Rust test graph contains an
advisory through `biscuit-auth` and `crypto-bigint`.

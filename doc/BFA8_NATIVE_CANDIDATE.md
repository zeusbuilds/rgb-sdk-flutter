# BFA.8 Flutter native candidate

The local candidate builds `0.3.0-beta.7-upstream-dev-bfa.8-bfa-flutter.1`
with UniFFI 0.32.2 and Flutter bridge 6. Both upstream mobile artifacts name
`cafe66e49d58038a69dd05f8065e3fe96a9d1601`. The BFA.8 source tag points to
its first parent `2f7b21d8637baad548504ea870deb2c0d4d0a37d`. The candidate
uses the artifact commit, including the upstream bindgen compatibility merge.

Flutter carries forward exact-ID genesis-only registration, the guarded
network clients, Dev Signet checkpoint, SQLite container rules, and durable
prepare/commit/status/cancel/revoke. The native migration for prepared sweeps
is retained for BFA.7 storage. Wallet profiles, authenticated outboxes and
version-3 command fingerprints retain their original format identifiers.
Runtime provenance separately verifies the actual BFA.8 source and lock.
Restored snapshots retain the spending fence.

The BFA.8 Android and iOS wrappers supply `false` for the upstream options
that bypass schema and contract checks. The candidate admits NIA, UDA and
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

The default SDK download pin remains the published BFA.7 build. Aster's
production RGB_L1 gate is closed. Use the BFA.8 candidate with dedicated
qualification wallets. The local candidate receipt is ineligible for
production release.

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

## Dependency review

The binding lock retains the guarded Esplora and SQLite builds, carries
forward the prior `ctutils`, Tokio and Arrow remediations, and pins
`rustix` 1.1.6. The exact mobile build lock had zero vulnerabilities and
zero unsound notices in the RustSec advisory database revision
`472a4c9a785030434f15d7da84964d60fbe789ab`. The scan reported four
unmaintained dependencies. The separate Rust test graph contains an
advisory through `biscuit-auth` and `crypto-bigint`.

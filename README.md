# RGB SDK Flutter

Flutter plugin for Bitcoin and RGB assets using native rgb-lib or the legacy
RGB Lightning Node backend.

This package is the Flutter counterpart to
[`@utexo/rgb-sdk-rn`](https://github.com/UTEXO-Protocol/rgb-sdk-rn). It exposes
a stable Dart wallet facade for app code and an explicit advanced entrypoint
for RN/native parity diagnostics.

## Status

**Not production ready. Do not use this revision with mainnet funds.**

Current package version: `0.2.0-beta.3`.

The on-chain `RgbLibWallet` now uses a separately versioned BFA.7 Flutter
native integration with standalone contract registration and durable
prepare/commit/status/cancel recovery. It uses dedicated storage, an immutable
recovery cohort and a protocol 1.0 RGB proxy. Restored backup snapshots stay
fenced until freshness can be established. See
[the BFA.7 integration and remaining gates](doc/BFA7_NATIVE_INTEGRATION.md).
The original React Native `1.0.0-beta.40` BFA.5 artifact reference remains
independently frozen and verified.

The existing `UtexoWallet` remains an explicit RLN facade. Its baseline is:

- `UTEXO-Protocol/rgb-sdk-rn` `dev` at
  `41ff170f794edff2a1822a672ddab37e29505f14`
- `@utexo/rgb-sdk-rn` `1.0.0-beta.39`
- `@utexo/rgb-sdk-core` `1.0.0-beta.9`
- RGB Lightning Node `0.17.0-beta.3`

Legacy RLN parity checks retain that baseline. Current
release eligibility still depends on the clean-candidate native, consumer, and
funded/unfunded evidence recorded in the tracker. The accepted production
constraints include `PKG-006` artifact provenance and the upstream lifecycle /
recovery findings recorded by OCT-037. Native artifacts are pinned and checksum
verified; a dependency upgrade does not close those qualification requirements.

That means internal-beta development may proceed, while public/funds-bearing
production use still requires upstream signatures, trusted-key verification,
and reproducible-build/source attestations for every native artifact. The
authoritative ledger is
[doc/RELEASE_READINESS_TRACKER.md](doc/RELEASE_READINESS_TRACKER.md).

The current release scope is **Bitcoin/RGB onchain**. Lightning, LSP and APay
success flows are deferred, not release-qualified. Their APIs remain available
on non-mainnet networks for RN compatibility; mainnet wallet/LSP orchestration
rejects before side effects. RLN 0.17 uses onchain-only native startup on
mainnet; Lightning endpoints reject with 403. Non-mainnet runtime behavior is
unchanged. BFA/Ethereum and VSS qualification remain independent onchain
obligations; the pinned consensus event-selection defect remains tracked.

## Features

- BFA asset models, native burn capabilities, exact-u64 burns and saved
  consignment reads. Burns are irreversible and must not be automatically retried.
- Optional `rgb_sdk_flutter_webrgb.dart` provider for host-approved dApp
  sessions, with witness receiving, native message signing, durable burn
  journaling and explicit proof-export consent. The optional WalletConnect
  router validates authorized requests; it does not install WalletKit or
  implement relay pairing, proposal negotiation or a consent interface.
  See [WebRGB and burns](doc/WEBRGB_AND_BURNS.md) for host responsibilities.
- RN-compatible mainnet Lightning restrictions. This is not authorization to
  use mainnet onchain funds; the release constraint above still applies.

- On-device RGB Lightning Node integration for iOS and Android.
- Stable `UtexoWallet` facade for Bitcoin, RGB, Lightning, peer, channel,
  LSP, APay, signer, and lifecycle workflows.
- RGB asset issuance and transfer support for the native/RN-supported surface.
- On-chain BTC balance, address, UTXO, transaction, and send workflows.
- Lightning invoice, payment, peer, channel, keysend, decode, and status
  workflows.
- LSP integration for Lightning Address discovery and quotes, linked/canonical
  asset selection, async payment hash pools, APay receive, RGB/Lightning
  bridge flows, cryptographically verified APay external invoices, and locally
  verified bridge and external-payment relay quotes.
- Password signer and native external signer strategies.
- Strict Dart domain DTOs on the stable API boundary.
- Advanced RN/native entrypoint for `RlnClient`, `RLNBinding`, `RLNManager`,
  raw `Rln*` models, bridge diagnostics, and parity tooling.
- Local release gates for Dart tests, native iOS XCTest, Android bridge tests,
  clean consumer archives, funded/unfunded regtest smokes, and external signer
  restart proofs.

## Platform Requirements

| Platform | Requirement |
| --- | --- |
| Flutter | `>=3.41.0` |
| Dart | `>=3.11.0 <4.0.0` |
| iOS | `18.5+`, required by the pinned RLN iOS artifact object metadata |
| Android | min SDK `24`, compile SDK from `tool/release_baseline.json` |
| Native services | Electrum and/or bitcoind RPC plus RGB proxy at unlock time |

The tested local toolchain is pinned in `.fvmrc`.

## Installation

This release line is Git/path only and is not published to pub.dev. Use an
immutable commit in consuming apps.

```yaml
dependencies:
  rgb_sdk_flutter:
    git:
      url: https://github.com/UTEXO-Protocol/flutter-sdk.git
      ref: <immutable-commit>
```

Then run:

```sh
flutter pub get
```

### iOS

The podspec automatically prepares and verifies the pinned
`RGBLightningNode.xcframework` and generated bindings before CocoaPods collects
source files. This works for Flutter's `:path` integration, including fresh Git
SDK dependencies, without an artifact-download hook in the app's Podfile.
Verified installed files are reused; missing artifacts use the explicit archive,
cache, or pinned download below. Preparation errors stop pod installation.

```sh
cd ios
pod install
```

Set the app's iOS deployment target and Podfile platform to `18.5`. In the
existing `post_install` hook, also lift lower pod targets to the same minimum
after `flutter_additional_ios_build_settings(target)`. New Xcode versions may
reject Flutter's generated placeholder pod target even when Runner is correct:

```ruby
target.build_configurations.each do |config|
  current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
  if current.nil? || Gem::Version.new(current) < Gem::Version.new('18.5')
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.5'
  end
end
```

For deterministic local release runs, prefer a pre-resolved archive or cache:

```sh
RLN_ARCHIVE_PATH=/path/to/rgb-lightning-node-swift-0.17.0-beta.3.zip pod install
RLN_CACHE_DIR=/path/to/rln-cache pod install
RLN_OFFLINE=1 pod install
```

### Android

Android resolves the SDK-owned
`com.utexo.flutter:rgb-lightning-node-android:0.17.0-beta.3-16k.1` artifact through
its exclusive HTTPS repository. The official RLN 0.17 AAR still has 4 KiB ELF
alignment. This derived build uses the exact upstream source and unchanged
Kotlin bindings with NDK 28 / 16 KiB linker settings. Gradle verifies the
pinned AAR size and SHA-256 before compilation; strict native checks cover the
ABI set and every packaged ELF library. See the recorded inputs in
[tool/rln_android_16k_build.json](tool/rln_android_16k_build.json) and the
[build procedure](doc/INTEGRATION_SECURITY_AND_RELEASE.md#android-16-kib-build).
The native artifact remains pinned to the published beta.1 release URL and
checksum in `tool/release_baseline.json`; beta.2 reuses those exact native bytes.
Local review can use the checksum-enforced artifact directory in that procedure.

Apps targeting Android 17 (API 37) or later must declare and request
`android.permission.ACCESS_LOCAL_NETWORK` before connecting to LAN backends,
including an emulator's `10.0.2.2` development services. The host app owns the
runtime consent flow and must handle denial or revocation before native unlock;
the SDK does not display permission prompts. The example's shared-stack test
uses an explicit Activity request and waits for the system consent result.
See Android's [local network permission guidance](https://developer.android.com/privacy-and-security/local-network-permission).

## Quick Start

Import the stable package entrypoint for app code:

```dart
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
```

Create a wallet with app-owned storage and a signer:

```dart
final keys = await generateKeys('regtest');

final wallet = UtexoWallet(
  config: UtexoWalletConfig(
    storageDirPath: appRgbNodeStoragePath,
    daemonListeningPort: 9735,
    ldkPeerListeningPort: 9736,
    network: 'regtest',
  ),
  signer: PasswordRlnSigner(
    password: passwordFromUser,
    mnemonic: keys.mnemonic,
  ),
);

await wallet.init();
await wallet.unlock(
  config: UtexoUnlockConfig(
    bitcoindRpcUsername: 'user',
    bitcoindRpcPassword: 'password',
    bitcoindRpcHost: '127.0.0.1',
    bitcoindRpcPort: 18444,
    indexerUrl: '127.0.0.1:50002',
    proxyEndpoint: 'rpc://127.0.0.1:3013/json-rpc',
  ),
);

final address = await wallet.getAddress();
final balance = await wallet.getBtcBalance();

await wallet.syncWallet();
await wallet.createUtxos(
  upTo: false,
  num: 4,
  feeRate: 1,
);

final receive = await wallet.onchainReceive(
  RgbInvoiceRequest(
    witness: false,
    minConfirmations: 1,
  ),
);

// Present these values in your UI. Never log private wallet data or invoices.
```

Restart the same wallet instance after shutdown:

```dart
await wallet.shutdown();
await wallet.reinit(
  password: passwordFromApprovedSecureStorage,
  unlockConfig: unlockConfig,
);
```

Release all SDK-owned native resources when the app is done with the wallet:

```dart
await wallet.destroy();
```

## Signers

`PasswordRlnSigner` is the password-based signer. The mnemonic is required for
first initialization and may be omitted for later unlock-only sessions when the
node storage already exists.

```dart
final firstRunSigner = PasswordRlnSigner(
  password: passwordFromUser,
  mnemonic: keys.mnemonic,
);

final unlockOnlySigner = PasswordRlnSigner(password: passwordFromUser);
```

`NativeExternalRlnSigner` uses the native external-signer path and accepts
mnemonic, seed bytes, or seed hex key material. It and custom signer strategies
are unsupported on mainnet: `init`/`reinit` fail before native node allocation.
The initial mainnet scope permits only the built-in `PasswordRlnSigner` (also
the default when supplying a password). The same guard applies with or without
VSS. External-signer regtest support remains available for upstream research;
its crash recovery, teardown and VSS-key security are not production-qualified.

```dart
final signer = NativeExternalRlnSigner(
  keys: RlnKeyMaterial.mnemonic(keys.mnemonic),
  network: 'regtest',
);
```

Durable credential storage is app-owned. The SDK does not silently persist
passwords, mnemonics, seed hex, or app auth tokens.

## API Entry Points

Use the stable root library for normal app code:

```dart
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
```

Use the advanced library only for parity tests, diagnostics, migration tooling,
or low-level integrations that intentionally need the RN/native shape:

```dart
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';
```

The stable facade returns Dart domain DTOs. Raw native/RN models remain behind
the advanced entrypoint.

## Common Workflows

| Area | Stable API examples |
| --- | --- |
| Wallet lifecycle | `init`, `unlock`, `shutdown`, `reinit`, `destroy` |
| BTC | `getBtcBalance`, `getAddress`, `rotateVanillaAddress`, `sendBtc` |
| UTXOs | `createUtxos`, `listUnspents` |
| RGB assets | `listAssets`, `getAssetBalance`, `issueAssetNia`, `issueAssetIfa` |
| RGB receive/send | `onchainReceive`, `blindReceive`, `witnessReceive`, `onchainSend`, `decodeRgbInvoice` |
| Transactions/transfers | `listTransactions`, `listTransfers`, `failTransfers`, `refreshTransfers`, `refreshWallet`, `syncWallet` |
| Lightning | `createLightningInvoice`, `payLightningInvoice`, `keysend`, `listPayments`, `decodeLnInvoice` |
| Channels/peers | `connectPeer`, `disconnectPeer`, `listPeers`, `openChannel`, `closeChannel`, `listChannels` |
| LSP/APay | `createLsp`, `discoverAddress`, `quoteAddress`, `selectPaymentAsset`, `receiveAsset`, `sendAsset`, `requestExternalInvoice`, `quoteExternalPayment`, `payExternalInvoice`, `enableLightningAddress`, `refillHashPool` |
| Signing | wallet node-message signing plus explicit experimental account-key Schnorr opt-in |

## Accepted Constraints

The current internal-beta line intentionally keeps these constraints explicit:

- Native backup/recovery is blocked until upstream provides and proves a real
  implementation.
- `sendRgb(skipSync: true)` fails fast because the pinned native artifact has
  no real skip-sync field.
- Standalone pure-Dart account-key Schnorr signing fails closed by default and
  requires `SchnorrSigningMode.experimentalDart`.
- Durable credential storage is app-owned.
- Native builds and funded regtest smokes are local release gates, not CI
  gates.
- `publish_to: none` remains until publishing/version distribution policy is
  decided.
- Production native artifact provenance is accepted as an internal-beta
  constraint under `PKG-006`; production supply-chain mode must still fail
  until upstream signatures and reproducible-build/source attestations exist.

The [native provenance verifier](doc/NATIVE_PROVENANCE_VERIFICATION.md) checks
real signed archive/source/build/reproduction evidence against separately
reviewed trust roots. Current artifacts still lack that evidence. Production
also independently rejects the known P03/P04/P06 on-chain defects and unresolved
selected native TLS advisories; a green Pub audit does not cover Rust code.

## Local Validation

Use the pinned Flutter toolchain from `.fvmrc`.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test example/integration_test tool pigeons
flutter analyze --fatal-infos
dart run tool/test_dart_coverage.dart
dart run tool/validate_coverage_policy.dart
dart run tool/validate_release_governance.dart
dart run tool/validate_codebase_hardening.dart
dart run tool/validate_public_api_docs.dart
dart run tool/validate_release_language.dart
dart run tool/validate_api_snapshot.dart
dart run tool/validate_bridge_vectors.dart
RGB_SDK_RN_PATH=/path/to/rgb-sdk-rn dart run tool/validate_rn_parity.dart
```

The full local candidate gate is:

```sh
RELEASE_PROFILE=mainnet-onchain \
  IOS_DEVICE=EXPLICIT_IOS_ID ANDROID_DEVICE=EXPLICIT_ANDROID_ID \
  RELEASE_RUN_ID=UNIQUE_RUN_ID RUN_CONSUMER_ARCHIVES=1 \
  ./tool/test_release_candidate.sh
```

The default `mainnet-onchain` profile runs production supply-chain verification,
Dart/package checks, clean consumer archives and native bridge tests. It then
requires exact-candidate iOS/Android onchain qualification reports from the
**existing isolated** `wdk-rln-017-qualification` stack. It never starts/resets
containers or dispatches the legacy funded Lightning/external-signer runners.
No successful Lightning flow is required; mainnet Lightning rejection is.
Read [the evidence contract](doc/RELEASE_EVIDENCE_SCHEMA.md#mainnet-onchain-production-profile)
for the strict required cases and existing stack identities. Missing proofs,
including reorg rollback and fresh-device recovery, fail the aggregate gate;
adding a profile does not establish that those scenarios passed.

The historical SDK-owned stack and Lightning regression suite is available only
with explicit `RELEASE_PROFILE=internal-beta RUN_PLATFORM=1`. That profile can
manage its historical SDK-owned stack; it is **not** appropriate when preserving
existing infrastructure and cannot qualify this mainnet release.

For the existing shared-stack campaign, read that stack's `AGENTS.md`,
`docs/CONSUMERS.md` and `artifacts/consumer-config.json` first, then use:

```sh
python3 tool/regtest/flutter_shared_stack_wallet.py \
  --device DEVICE_ID --run-id UNIQUE_RUN_ID --stack-dir /path/to/utexo-local-stack
```

This runner requires the separately operated loopback controller on port
29671 (and Android `adb reverse tcp:29671 tcp:29671`). It launches no stack or
container, uses separate random wallet storage and never retries financial
requests. `--lifecycle-only` runs without funding. Private closed-fixture
snapshots remain under ignored `build/full-wallet-20261015`; they are local
test evidence, not portable SDK recovery. Retain failed transaction journals
for explicit reconciliation before any further mutation.

## Security and Recovery

Read [doc/SECURITY.md](doc/SECURITY.md) before integrating the package.

Do not put mnemonics, seeds, passwords, private keys, bearer tokens, invoices,
preimages, wallet paths, or native error bodies in logs, screenshots, reports,
or issue trackers. SDK diagnostics are redacted as defense in depth, not as a
license to log secrets.

Native local backup/recovery remains blocked. This release line must not claim
recovery readiness.

## Documentation

- [Release Readiness Tracker](doc/RELEASE_READINESS_TRACKER.md)
- [Integration, Security, and Release Policy](doc/INTEGRATION_SECURITY_AND_RELEASE.md)
- [API Compatibility and Divergence Policy](doc/API_COMPATIBILITY_AND_DIVERGENCE.md)
- [Bridge Behavior Contract](doc/BRIDGE_BEHAVIOR_CONTRACT.md)
- [Release Evidence Schema](doc/RELEASE_EVIDENCE_SCHEMA.md)
- [Public API Reference](doc/PUBLIC_API_REFERENCE.md)
- [Dart Coverage Policy](doc/COVERAGE_POLICY.md)
- [Security Policy](doc/SECURITY.md)
- [Machine-Readable Test Matrix](tool/test_matrix/README.md)
- [Example App](example/README.md)

The dual-engine Android example packages only complete 64-bit targets
(`arm64-v8a` and `x86_64`). Its Flutter `target-platform` selection also excludes
all unselected JNI directories; a pure 32-bit or unknown target fails before
packaging. RGB_L1 has no 32-bit native runtime. This example policy does not
remove legacy RLN's separately available 32-bit SDK APIs/artifact support.

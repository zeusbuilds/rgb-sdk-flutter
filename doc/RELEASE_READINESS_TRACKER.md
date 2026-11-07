# RGB SDK Flutter Release Readiness Tracker

This is the sole authoritative release-readiness tracker for
`rgb-sdk-flutter`.
Historical phase plans, parity claims, risk registers, and readiness documents
were removed because they overlapped and had drifted from the implementation.

## Document Control

### November 8 RGB_L1 successor qualification

The `.2` native candidate is separately sealed as
`8ac556ee67db70b93abb69b4ebd8fb0e6752dc0e`. Both installed SDK mobile consumers
passed ten funded/ABI/recovery cases on iOS 27 and Android 17; the Android guest
uses 16 KiB pages with compatibility fallbacks disabled. Final native checks
include 48 recovery/backup/accounting/storage tests and eight additional offline
observation cases. Historical failures and earlier source identities remain in
[the executed evidence](BFA7_QUALIFICATION.md), rather than being relabeled.

The user confirmed there is no approved recovery service/protocol. Portable RGB
restored-wallet spending and mnemonic-only RGB recovery therefore remain
unsupported. Aster's normal RGB_L1 activation and production gates remain closed;
Dev also requires the team's new approved contract and deployment. Local fixture
qualification does not approve Dev or mainnet assets. Aster's final full-flow
and distinct process-cold acceptance now pass on both platforms, separately from
the 14 offline existing-only wrapper cases. Android additionally proves pending,
nonspendable RGB at zero confirmations and settlement after exactly one.

API change/migration note for NOV-005: additions are `openExisting`, explicit
`revokeOnchainSend`, strictly typed capability fields and the immutable
`RgbLibBackupRecoveryCapabilities` descriptor. `init`/`reinit` keep their prior
create-or-open behavior. Existing clients are source compatible; persistent
wallet hosts should adopt `openExisting` and separate app metadata from the
SDK's exclusive root. No application migration is required for this unreleased
app. Snapshot spending is not enabled. The reviewed API snapshot also records
the new bridge policy/reader declarations, with no Pigeon schema change.

The separately authorized native-only `.2` beta is now public and all seven
anonymous downloads, the fresh unmodified iOS installer and the actual Android
public-repository artifact task pass. The freshly converted six Apple pairs
retain zero DiskSpace imports. This is component/consumer acquisition evidence;
it does not approve final signed-app privacy or the independent legacy runtime.
See the exact acquisition digests in [the qualification record](BFA7_QUALIFICATION.md).

### November 6 React Native beta.40 and RGB_L1

November 7 follow-up: Flutter now carries a separately named BFA.7 source
overlay with native contract registration and durable recovery. Aster's gated
adapter consumes those APIs; the factory and release gates remain closed.
See [current BFA.7 mechanisms and qualification limits](BFA7_NATIVE_INTEGRATION.md).
The original RN BFA.5 source/archive reference below remains immutable.

The published reference switches its default wallet to rgb-lib BFA.5.
Flutter adds a separately selected RGB_L1 backend and preserves the existing
RLN constructor. Aster remains gated on durable send and release qualification.
See [the source audit and dispositions](UPSTREAM_PARITY_BETA40.md).

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| NOV-001 | P1 | Verified | The beta.40 source, npm archive, and BFA.5 native provenance are pinned. Flutter has typed RGB_L1 session, exact amount, receive, transfer, issuance, backup and maintenance APIs. Existing RLN compatibility checks are still pinned independently. | Continue reviewing upstream changes against the immutable reference and keep separate native artifact evidence. |
| NOV-002 | P0 | In progress | BFA.7 Flutter overlay implements authenticated native exact-payment identity, dispatch boundary, read-only status, cancellation tombstones and receipt recovery. Native fault/restart/backup tests pass. Restored snapshots remain fenced because an old backup cannot prove absence of a later payment. Aster has the adapter but stays gated. | Qualify funded mobile interruption/reorg cases and a freshness authority for unrestricted restored-wallet spending. No status or restart may replay End, proxy submission or broadcast. |
| NOV-003 | P0 | In progress | Patched BFA.7 UniFFI lock has zero known vulnerabilities and zero unsound notices at the recorded RustSec revision; three unmaintained dependencies remain disclosed. The exact `.2` converter's six Apple framework/architecture pairs have no DiskSpace imports and retain fcntl/fsync. Unreferenced Rustix calls remain in static inputs; other linking configurations do not inherit that result. Dual-engine packages retain independent RLN security/privacy gates. | Final signed-app required-API and aggregate privacy evidence, plus the independent legacy RLN review, remain required. Advisory or component remediation alone does not approve a release. |
| NOV-004 | P0 | In progress | BFA.7 native standalone genesis registration and exact Aster metadata bootstrap are implemented. Proxy 1.0, issuer-approved current contracts, backing deployment and funded acceptance remain required; historical BFA.5 exports cannot authenticate Dev or mainnet assets. | Obtain approved current export/hash/name/ticker/precision/backing contracts and explicit EVM mint-lock policy, then qualify exact BTC/USDT receive/send/history/restart on both mobile platforms. |
| NOV-005 | P0 | Verified | Actual Aster qualification found its ownership marker in the SDK required-empty native root. A dedicated native child fixes that integration. READY opens require existing storage, authenticated profile/cohort checks and a compiled-wrapper capability. Bounded strict profile readers reject corrupt input instead of admitting new state or exhausting memory. Fourteen separate offline wrapper/device cases pass, followed by actual Aster funded flow and distinct process-cold reopen on both platforms. | Preserve old/partial state and reject missing storage before replacement. Qualification does not lift production/restore/Dev gates. See the API migration note and exact evidence above. |

### October 16 Production Privacy Disposition

The current `0.2.0-beta.3` candidate retains the exact native inputs below.
The SDK's FileTimestamp `C617.1` declaration and package checks pass, while the
native DiskSpace required-reason audit remains unresolved. This is now an
explicit code-backed production blocker tied to native source
`ecc69f20308231400561f6f060fea88acfa40cc4` and iOS archive SHA-256
`dd5c483753e58c0c1c49f94098a2cc6eef18e16d3eebd167d31131fbd888890a`.
Unknown source/archive pairs also block; editable metadata, signatures and
environment flags cannot grant approval. The mainnet aggregate fails before
builds or supplied child evidence, and the production supply-chain audit now
has twelve expected findings, including this independent privacy finding.
Its report marks `nativeIosPrivacyReview.productionReady=false` and
`status=blocked-known-unresolved`. The native publisher still needs to remove
unused APIs or justify their actual linked use; final signed-archive required-API
and aggregate privacy reports remain external closure evidence. No DiskSpace
reason has been invented. See `doc/IOS_PRIVACY_API_AUDIT.md`.

Working-tree verification: known/unknown input, forged JSON approval and
environment-bypass subprocess regressions pass, as does an actual aggregate
preflight regression asserting failed/ineligible status before any build or
supplied-evidence step. These checks enforce the blocker; they do not close the
underlying native privacy audit or qualify a clean immutable release.

### October 15 Existing-Stack Wallet Qualification (Active)

The user now authorizes connecting the app and SDK to the existing shared
`utexo_local` infrastructure. This supersedes the earlier disconnected-only
instruction below. No stack or container is created, reset or replaced.
Consumer configuration and public contract identity are verified before use;
SDK wallets use separate random owner-only storage and are closed and privately
backed up before the test runner removes its example application.

The next package candidate is `0.2.0-beta.2`. It retains the beta.1 published
16 KiB Android AAR and the same official iOS archive; no proposed WDK lifecycle
overlay or replacement native binary is included.

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| ROOT-01 | P0 | In progress | Additive durable on-chain prepare/commit/status/cancel protocol and strict wallet-bound Dart command/status validation implemented locally; public official native artifacts remain unchanged and unsupported. The staged iOS native rebuild is separate unpublished evidence. | Verify interrupted BTC/RGB sends and exactly-once outcomes on the existing isolated qualification stack. Publish and qualify immutable native artifacts before production enablement; Android source is unbuilt. Preserve legacy unknown-operation fences and do not claim general mainnet readiness. |
| OCT-038 | P1 | Verified | The stable facade could not import the shared canonical BFA public contract although released RLN already provides that API. Added `importRgbContract` through both bridges with expected-ID verification, canonical Base64 bounded to 16 MiB characters and exact typed UInt64 supply metadata. Three focused Dart tests and actual canonical zero-balance/idempotent import assertions pass on iOS 27 and Android 17. | Keep this explicit Flutter extension in the divergence register and signature-check it independently of RN parity. Re-audit when RN adds the wrapper. |
| OCT-039 | P1 | Verified | `destroy()` previously continued releasing native ownership after shutdown failure. The facade now quarantines failed shutdown/cleanup, retains remaining owners and permits only explicit destroy retry. Fresh-init and replacement cleanup faults also retain ownership. Full 504-test Dart suite and cleanup-fault regressions pass. | Preserve retryable ownership; these wrapper guarantees do not prove native workers/listeners/pools have terminated or close OCT-037/P01. |
| OCT-040 | P1 | Verified | API 37 local-network permission denial appeared as native indexer/unlock failure. The example now targets API 37, presents the real OS consent prompt after its first frame and verifies LAN access before native initialization. Android 17 / 16 KiB guest native unlock and funded transfers succeed after real Allow consent. Added bounded operation/code getters without raw native messages so hosts can classify recoverable failures. | Consuming apps own declaration, consent, denial and revocation handling; the SDK library must not silently prompt or bypass permission. |
| OCT-041 | P1 | Verified | Existing-stack SDK evidence covers BTC send/receive, canonical BFA mint, blind/witness transfers, native burn, exact EVM payout and funded same-store reopen on both platforms through explicitly composed reports. iOS combines initial A and pre-burn resume B. Android C retains its failed host acknowledgement; the original proof later receives exactly one successful payout after signer readiness, and read-only E independently verifies the same closed wallet identities and 1.58m/0.4m balances through funded reinit. | Preserve original failures, separate recovery evidence and private fixtures. This scoped onchain evidence does not close Lightning/LSP/VSS, destructive recovery, general P04, native lifecycle or clean immutable candidate qualification. |
| OCT-042 | P1 | Verified | Stable decoded invoices dropped native recipient type, preventing hosts from distinguishing blind receivers from witness receivers requiring a Bitcoin output. `CoreInvoiceData.recipientType` is now optional for constructor compatibility and receives exact native Blind/Witness or unknown future values. A focused regression proves both known values, unknown preservation and omitted-field null. | Hosts must reject null/unknown kinds before broadcast and explicitly review witness Bitcoin output value separately from fees; do not parse invoice strings or silently switch receive modes. |
| OCT-043 | P1 | Verified | Both platform unspent serializers omitted released RLN `pendingBlinded`, while Dart fabricated a missing value as zero. Reserved outputs could therefore appear available. Swift/Kotlin now preserve the UInt32 count; native-map decoding requires its presence and range. Dart boundary/client-wire tests, 31 JVM tests and the production Swift wire-codec host probe pass; the new XCTest vector is registered but not yet run on iOS. | Keep reservation counts distinct from allocation readiness and retain native authorization. Advanced wire mocks must supply an explicit count; do not hot reload new Dart code over an old native bridge. Final iOS compilation/device execution remains part of app qualification. |

Local evidence (ignored, contains private fixture backups):
`build/full-wallet-20261015/sdk-full-ios27-20261015-a/`,
`build/full-wallet-20261015/sdk-resume-ios27-20261015-b/` and
`build/full-wallet-20261015/sdk-full-android17-20261015-c/` and
`build/full-wallet-20261015/sdk-verify-android17-20261015-e/`.
Android C records `sourceChangedDuringRun: false` and strict 16 KiB execution,
but its overall result remains failed at host payout. Host recovery verifies
matching relay/signer block heights before one unlock. The retained-proof
payout `0xe7b567a9ea198b43d2c5843670dad22a8257c53fcfab9cc2ac81fb90c8ea6f21`
transfers exactly 20,000 units with one BridgeFundsOut event. No new native
burn or mint is performed. Read-only E passes original pubkey, exact balances
and both-wallet funded shutdown/reinit; its closed backup is retained. D
passed the same native assertions but failed the framework semantics-handle
check. E fixes the test-owned accessibility lifetime without disabling leak
checks. No original report is relabeled.
The earlier iOS run failed because the test omitted the explicit witness
satoshi value; the corrected resume performs no new fund or mint operation.
A pending incoming witness transfer on each platform reports the exact future
balance once in this canonical BFA profile; this single profile is not general
upstream P04 closure. Host coverage passes all package floors (507 tests,
package 88.7%, wallet 87.1%, models 88.1%); this is working-tree evidence,
not clean immutable release qualification. The bridge-vector gate still fails
for the pre-existing missing VSS platform-success vector; no VSS result is invented.

### October 15 RLN 0.17 and Android Page Size Upgrade (Historical)

Initial authorization: upgrade the SDK to the latest RLN, inspect the React
Native SDK and WDK RLN 17 PR, then move Aster to the new SDK while keeping the
existing local stack disconnected. The later authorization above supersedes
that connection restriction; creating or resetting infrastructure remains prohibited.

Current source baseline: RLN `v0.17.0-beta.3` at
`ecc69f20308231400561f6f060fea88acfa40cc4`; RN `1.0.0-beta.39` at
`41ff170f794edff2a1822a672ddab37e29505f14`; core remains `1.0.0-beta.9`.
The candidate package is `0.2.0-beta.1`, qualified with Flutter `3.47.7` /
Dart `3.13.5`. Historical evidence below is not relabeled as current evidence.

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| OCT-035 | P1 | Verified | RN beta.39 adds Tron Base58Check burn recipients, WebRGB burn-recipient namespaces and rejection of payout records without their native recipient commitment. | Implement shared EVM/Tron validation, retain the host allowlist, test malformed/checksum/version/zero/casing/missing-commit cases and refresh exact source/API manifests. Native integer money boundaries remain signed-64; JS-safe limits remain at WebRGB JSON boundaries. |
| OCT-036 | P1 | In progress | Independently verified official RLN 0.17 Android AAR SHA-256 `148e8e50c1014237c737b26120469ceefc8a79bb6c77cd74ddda89ea316c6dac`. Its arm64-v8a and x86_64 ELF LOAD segments are still 4 KiB aligned and have offsets incongruent at 16 KiB. | Build exact source with 16 KiB linker layout, retain ABI/checksum provenance, verify every packaged native library plus APK ZIP alignment, and execute on a confirmed 16 KiB guest. Never patch ELF header alignment or replace published Maven bytes in place. |
| OCT-037 | P1 | Blocked upstream | WDK PR45 at `81182153193c9910e89a9d91b1d457e0725787aa` and Node PR24 at `2caa14962e6a7e10549c888880d46c85aee0b81d` propose a P01 signer/session teardown repair. Their unpublished 26-file overlay changes core runtime, UniFFI and C-FFI behavior used by the Node/Bare peers; it is not included in released RLN 0.17. P01 mobile closure and P02/P03/P04/P06 remain open. | Obtain qualified native lifecycle/recovery fixes and real current-platform/funded evidence. Reported WDK/Node host results have their own source and runtime scope; they are not Flutter reproductions. Do not simulate native revocation by dropping wrapper handles or claim a version bump closes these defects. |

The October 15 upstream refresh reviewed WDK PR45 at
`81182153193c9910e89a9d91b1d457e0725787aa` and Node PR24 at
`2caa14962e6a7e10549c888880d46c85aee0b81d`, both open and unmerged.
The shared 26-file overlay SHA-256 is
`7f89dc518f8fe69dc6baf62c4ee96e9d5a25d6b6ae70ab529c7b4bcc65979c90`.
It adds terminal signer revocation, owned worker/listener teardown and cleanup
error propagation through core, UniFFI and C-FFI to the Node/Bare adapters.
Its latest change closes terminal metadata pools on their owning runtime while
retaining the database for a nonterminal REST lock. This is a runtime repair,
not merely a binding update.

Upstream reports 31 native lifecycle/signer/startup/VSS tests plus 14 C-FFI tests
and 123 lifecycle cycles on each optimized Darwin arm64 Node and Bare host.
These are proposed P01 source/host fixes. P01 mobile closure, replacement
seven-target Bare and five-target Node artifact matrices, rebuilt mobile
packaging and funded iOS 27 BTC/BFA acceptance remain pending. P02 interrupted
BTC reservations, P03 RGB reorg rollback, P04 pending witness accounting and
P06 BFA event-order acceptance remain open. Earlier failures retain their
original artifact identities; the new host results do not qualify Flutter.

The latest published UniFFI release remains RLN `v0.17.0-beta.3` at
`ecc69f20308231400561f6f060fea88acfa40cc4`. This Flutter candidate uses that
released source without the WDK/Node overlay. Adopting the proposed repair
would require separately reviewed native artifacts, regenerated bindings and
qualification against their exact source and bytes.

The executed derived Android recipe produces
`com.utexo.flutter:rgb-lightning-node-android:0.17.0-beta.3-16k.1`,
91,930,898 bytes, SHA-256
`ca1aa12d44c1e83c0a0f51a38c7bf1486e0ea3ac796dcc02d479acbdf4d832c5`.
All three ABIs preserve canonical Kotlin before/after stripping, 242 FFI/metadata
exports and only system libc/libdl/libm dependencies. Non-JNI AAR entries match
stock byte for byte. The exact final arm64 bytes pass dlopen, UniFFI contract
26/checksum 28125, healthcheck and buffer release on a fresh Android 17.2 / API
37 / 16 KiB guest with fatal compatibility enforcement. Artifact and API
integrity are established; publication and full candidate/platform gates are
recorded separately. Build inputs: `tool/rln_android_16k_build.json`;
local evidence: `build/rln17-upgrade/qualified2/` and
`build/rln17-upgrade/native-load-probe/final-android17/`.

OCT-035 tests cover supported Tron chains, checksum/version/zero/casing,
permission-filtered namespace advertising, missing v2 native commitments and
control-character chain IDs. Live RN drift/API/doc gates pass against the exact
beta.39 commit. No external payout or funded native burn is claimed.

The official iOS archive SHA-256 is
`dd5c483753e58c0c1c49f94098a2cc6eef18e16d3eebd167d31131fbd888890a`.
Generated Swift/FFI bindings are unchanged from 0.16; independently inspected
native objects retain the iOS `18.5` floor. The published release is a prerelease.

References: [RLN release](https://github.com/UTEXO-Protocol/rgb-lightning-node/releases/tag/v0.17.0-beta.3),
[RN source](https://github.com/UTEXO-Protocol/rgb-sdk-rn/commit/41ff170f794edff2a1822a672ddab37e29505f14),
[WDK PR45](https://github.com/UTEXO-Protocol/wdk-rgb-lightning/pull/45),
[Node adapter PR24](https://github.com/UTEXO-Protocol/rgb-lightning-node-nodejs/pull/24),
[Android page-size requirements](https://developer.android.com/guide/practices/page-sizes).
PKG-006, OCT-002/007/027/033 and other unresolved gates remain in force.

### October 13 Native and WebRGB Upgrade (Historical)

The user now authorizes upgrading to the latest published RLN, superseding
the October 9 native-version freeze. Starting SDK commit: `063bd7f203c644f6ed2870e1838ef4ba617c681d`.
Verified upstream RN dev: `e38329eba11cce16e3bea75b8a4e7becd52c0036`
(`1.0.0-beta.37`); latest published RLN: `v0.16.0-beta.3`, commit
`8777d71d7781b408fcce89c9c965ae29e8ad2300`. Core remains beta.9.
WebRGB and its separate WalletConnect transport are both version 0.1.2.
Neither a dependency bump nor a passing unit suite is a production qualification.
Lightning remains outside release scope. PKG-006 remains accepted for internal beta.

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| OCT-028 | P1 | In progress | SDK still pins RLN 0.15; RN beta.37 uses 0.16 with onchain-only mainnet startup and new external unlock requests. | Independently verify archive bytes, sources, ABI/API changes, regenerate baselines and run both native build/test paths. |
| OCT-029 | P1 | Verified | Added WebRGB witnessReceive and per-request approved native signMessage from peer 0.1.2. | The full 429-test suite passes, including method advertisement, confirmation floor, exact Unicode/unpaired surrogate rejection and revocation races. Native-funded provider qualification remains OCT-004. |
| OCT-030 | P1 | Verified | Journal cancels only pre-dispatch or native-proven pre-broadcast funding failures and supports the optional error field. | Tests cover both funding codes including mapped native causes, successful native result followed by failed persistence, legacy error round trips and uncertain-outcome fencing. New persisted errors are sanitized codes. Funded recovery remains OCT-002. |
| OCT-031 | P1 | In progress | Flutter has no WebRGB WalletConnect transport adapter. RN uses a separate experimental rgb/webrgb:1 transport, not a generic injected provider. | Audit source and implement bounded typed routing, permissions, expiry/revocation, duplicate request protection and proof chunking. Live relay evidence requires an app-owned project ID and approval UI. |
| OCT-032 | P1 | Verified | External-signer ethRpcUrl now reaches RLN 0.16 request-based unlock through generated Pigeon and both native bridges. | Dart forwarding/guard tests, 30 Android bridge tests and iOS compile pass. External-signer burn remains unsupported; real Ethereum acceptance/rejection remains OCT-002. |
| OCT-033 | P1 | In progress | No qualification evidence exists for the upgraded exact SDK/app candidate. | Strict analyzer, full tests, native bridge tests, iOS/Android builds, app integration regression and clean immutable dependency resolution; record unavailable services rather than passing mocks as native proof. |
| OCT-034 | P2 | Verified | Pigeon regeneration overwrote formatted Dart with the generator's raw layout; a last regeneration could invalidate the formatting gate. | The generation wrapper now formats its Dart output. Regeneration is byte-stable across all three languages and the formatter check passes; no generated source is manually edited. |

OCT-027 remains blocked: the 0.16 Cargo.lock still pins consensus `2faf6118`,
despite moving rgb-lib to `74a096a5` (beta.47-bfa). Its event-selection fix is
not implied by this upgrade. October 9 results below are historical, not current
candidate evidence. App integration is tracked separately in Aster's tracker.

#### October 13 Verification and Remaining Scope

- RN dev drift/API/source gate passes at e38329eba11c. Core stays beta.9;
  WebRGB peer/source manifest and exact native archive/install hashes are updated.
- 429 Dart tests pass. Coverage gates pass: package 88.0%, wallet 86.0%,
  LSP 88.4%, crypto 91.1%, models 87.5%, WebRGB 95.0%. Analyzer has no findings;
  dartdoc has zero warnings/errors. These are working-tree results, not an exact
  clean release-candidate report.
- Android JVM bridge suite: 30 passing tests. iOS simulator app and XCTest
  bundle compile; lipo independently reports arm64 and x86_64 in both Runner
  and the plugin framework. XCTest has not executed: all simulators are shut
  down and authorization to boot the dedicated Aster simulator is pending.
- New WalletConnect router tests cover expiration during approval, queued
  requests, wallet changes, method revocation, duplicate IDs, immutable input
  snapshots, independent reply copies and proof chunking. Review found and
  fixed mutable cached replies and UI-isolate hashing. No live relay evidence.
- OCT-031 is **not complete**: router dispatch is implemented, but WalletKit
  pairing, verified proposals, persistent sessions, event subscription and app
  consent UI are still needed. An app-owned Reown project ID is required for
  live verification, not an excuse to claim unimplemented transport as done.
- No funded BFA/Ethereum/VSS, installed Android or process-restart evidence is
  claimed. Existing onchain and provenance blockers are not waived. Source
  inspection confirms native onchain-only mainnet startup; runtime proof remains
  part of OCT-028/033. No mainnet funds were used.

### October 9 Onchain Release Scope (Historical)

User decision: keep RLN **0.15.0-beta.3** and its exact archives. Do not upgrade
to 0.16 or describe its onchain-only startup as behavior of the pinned binary.
RN dev is now `a7e31b3eec8d71f4275c9655339641a113b0f7e6` (beta.36).
Lightning/LSP/APay success qualification is deferred for this release, not
passed. Mainnet denial and no-side-effect regressions remain mandatory;
regtest/signet Lightning APIs stay available for RN API compatibility.
Existing onchain, BFA/Ethereum, VSS, lifecycle, clean-consumer and platform
evidence requirements remain. No gate is weakened to manufacture a full-SDK
release pass. The current 0.15 binary still starts its legacy Lightning runtime
on mainnet; Dart guards cannot backport 0.16 startup isolation. This remains an
accepted native-runtime limitation, independently of PKG-006. It does not mean
that unused Lightning API support is itself a proven onchain funds defect.

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| OCT-024 | P1 | Verified | Direct UtexoLsp construction bypassed the canonical wallet's mainnet guard and could perform HTTP requests before rejection. Reproduced with a counting transport. | Shared policy rejects before client allocation and at all 18 orchestration methods. Matrix-bound tests prove zero wallet/HTTP effects on mainnet, network-change races at discovery/polling, and unchanged non-mainnet construction. Five regressions pass in the full 407-test suite. Low-level standalone HTTP transport intentionally has no wallet policy; funded Lightning success is not claimed. |
| OCT-025 | P1 | Verified | RN beta.36 transfer history distinguishes requested outgoing amount from change/batch allocations, preserves decimal UInt64 and adds InflationRight parsing. Flutter previously summed outgoing change and rejected large WebRGB history values. | All six transfer kinds, unknown versus zero, full UInt64, malformed/overflow values and WebRGB JSON boundaries pass regression tests. Live RN drift, API snapshot and documentation gates pass without changing RLN. Added real transfer assertions distinguishing 100 sent from 900 change to the funded harness; their platform execution remains OCT-007, not claimed here. |
| OCT-026 | P1 | Verified | The October 9 version freeze is superseded by the October 13 authorized upgrade to exact RLN 0.16.0-beta.3 artifacts. Native source now selects onchain-only mainnet startup. | Freeze removed, not a runtime qualification claim. Both-platform mainnet startup verification remains OCT-028/033 and PKG-006 still prevents a mainnet-ready claim. |
| OCT-027 | P1 | Blocked upstream | RLN 0.15 Cargo.lock pins rgb-lib aaf5b52 and rgb-consensus 2faf6118. The latter selects the first event for an OpId before comparing its amount: an earlier wrong-amount lock can hide a later correctly backed mint and invalidate its lane. Upstream WDK reproduced this; rgb-lib PR103 remains open. | Native validation must select any matching reason/amount, with missing-lock/wrong-only rejection and valid-after-wrong settlement tests. Source graph and exact correction were independently inspected; no new Flutter device reproduction is claimed. Fixing this needs an approved native artifact change. Never filter events, credit funds, or replace native validation in Dart. |

Flutter retains its host payout-chain allowlist for irreversible WebRGB burns.
RN beta.36 removes that requirement in favor of CAIP-2 syntax alone. This is an
explicit, stricter host authorization policy, not hidden parity or proof of an
external payout. Scope changes do not erase unresolved historical findings.

#### Latest Working-Tree Verification

These results supersede the earlier October 9 Dart/static/build results below,
not their remaining execution requirements. Candidate: uncommitted changes over
`734f5ae6fb175bbf2d8500a9b43f29b5363c1e52`, Flutter 3.47.0 / Dart 3.13.0,
Xcode 27.0. No exact-commit release pass, commit or push is claimed.

| Gate | Measured result | Evidence boundary |
| --- | --- | --- |
| Dart suite and coverage | 407 tests pass; package 87.9%, wallet 85.9%, LSP 88.4%, crypto 91.1%, models 87.5%, WebRGB 97.1%; all floors pass | `/private/tmp/rgb-sdk-onchain-20261009-full-tests.log`, fresh coverage/evidence.json. Fixtures prove contracts, not native service success. |
| Strict analyzer / Dartdoc | Zero analyzer diagnostics with fatal infos/warnings; three libraries documented with zero warnings/errors | `/private/tmp/rgb-sdk-onchain-20261009-dartdoc.log`. |
| Android bridge JVM | 30 tests pass | `build/test-reports/native/native-android-20261009T091645Z-734f5ae.json`; dirty-tree host evidence, not installed execution. Later Dart/integration changes require final-candidate rerun. |
| Generic iOS simulator application and XCTest bundle | `xcodebuild build-for-testing` succeeds; lipo independently confirms arm64 and x86_64 in both Runner and rgb_sdk_flutter.framework | `/private/tmp/rgb-sdk-onchain-20261009-ios-build.log`. Does not execute XCTest or qualify a clean external consumer. |
| Swift wire codec / generation / API | Host wire-codec regressions, Pigeon identical regeneration, baseline generation, AST API snapshot, RN live source/method/export drift, 232-symbol public docs and package/language/hardening gates pass | RN beta.36 at a7e31b3; no changed native archive, no runtime equivalence inferred. |
| Artifact gates | Internal-beta artifact/license/OSV/ABI-symbol checks pass with explicit PKG-006 warnings | `/private/tmp/rgb-sdk-onchain-20261009-supply.log`. Missing iOS signature, trusted-key Android verification and reproducible source attestations remain accepted constraints, not a production-mode pass. |
| Behavior-vector gate | Fails for rgb_assets and vss missing platform-smoke-or-regtest-success evidence | The gate remains enabled. BFA/Ethereum/VSS real success and recovery evidence, installed-platform smokes, clean consumers and full fresh audit remain unfinished. |

Dedicated SDK-device boot and a local Zeus candidate commit were requested;
neither has been performed without the requested confirmation. No other task's
devices, stack or data were reused. The full-SDK release verdict remains NO-GO.

#### Pinned BFA Validation Evidence

- RLN tag `v0.15.0-beta.3`, Cargo.lock: rgb-lib
  `aaf5b52f63ff2ee966707f099aacadd5f2e6037f`; rgb-consensus
  `2faf6118b2f5fe30dd90dd5244d5a7dc32bcd757`.
- [Consensus correction](https://github.com/UTEXO-Protocol/rgb-consensus-s-bfa/compare/2faf6118b2f5fe30dd90dd5244d5a7dc32bcd757...c250a9e37b0076c86940853ebeb0b007b6e63e1f)
  changes `src/vm/ether_extension.rs` from first-reason-match selection to
  reason-and-amount matching across events, with order/negative regressions.
- [rgb-lib PR103](https://github.com/UTEXO-Protocol/rgb-lib/pull/103) is open
  and unmerged on October 9. It adds funded mint/lane acceptance cases.
- [WDK qualification](https://github.com/UTEXO-Protocol/wdk-rgb-lightning/blob/0d44024e4949f399cbd24fd55c4d5c9b48dfda02/BFA-QUALIFICATION.md)
  is upstream host evidence, not Flutter mobile evidence. Its fixture uses the
  same rgb-lib graph but its external unlock requires RLN PR192, absent from
  our published binary. Do not run that external-signer fixture unchanged or
  silently substitute WDK's newer native build.
- A compatible password-signer Flutter BFA/Ethereum fixture and independent
  burn recovery verifier still need implementation/execution. The SDK-owned
  Bitcoin/Electrum/proxy stack alone cannot produce this evidence.

### October 9 Storage-Unblocked Qualification (Active)

Resumed with 32 GiB available after the user-requested build-cache cleanup.
The worktree remains uncommitted over `734f5ae6fb175bbf2d8500a9b43f29b5363c1e52`.
Rerunning the final Dart coverage suite, Android bridge regressions, iOS
XCTest/builds and packaging in that order. Results below from October 8 remain
historical until each new command completes. No service success is inferred
from newly available disk space. Dedicated SDK devices and a local Zeus
candidate commit were requested separately; no foreign devices are reused.

| Gate | October 9 result | Evidence boundary |
| --- | --- | --- |
| Full Dart suite | 393 tests pass; all coverage floors pass: package 87.8%, wallet 85.9%, LSP 88.1%, crypto 91.1%, models 87.2%, WebRGB 97.3% | Fresh `coverage/evidence.json` binds source inputs and LCOV. Not native behavioral parity. |
| Android bridge JVM | 30 tests pass, including both-signer unlock rollback classification | `build/test-reports/native/native-android-20261009T060243Z-734f5ae.json`; dirty-tree evidence. Flutter's concurrent generated iOS project migration also changes its candidate inventory; rerun on the final candidate. |
| Complete generic iOS simulator build | Application and XCTest bundle build successfully for arm64 and x86_64; `lipo -info` verifies both slices in Runner and the plugin framework | `/private/tmp/rgb-sdk-qualification-20261009-ios-build.log`; build-for-testing only, not XCTest execution or a clean-consumer archive. |
| iOS device release build | `flutter build ios --release --no-codesign` passes; Runner.app is 139.9 MB | Unsigned example build, not physical-device installation, App Store signing, or an independent consumer. Log: `/private/tmp/rgb-sdk-qualification-20261009-ios-release.log`. |
| Android release build | `flutter build apk --release --target-platform android-arm64` passes; APK is 224.3 MB | Example ARM64 build, not installed execution or an independent consumer. Log: `/private/tmp/rgb-sdk-qualification-20261009-android-release.log`. |
| Swift host wire codec | Exact UInt64, integer, boolean and nested-null regressions pass with compiler warnings fatal | Host executable only, not XCTest execution. |
| Strict analyzer and tracker governance | Zero analyzer diagnostics; ledger counts and remaining groups validate | Static validation does not close platform behavior gates. |
| SDK-owned regtest | Bitcoin RPC/Electrum startup checks pass; RGB proxy server.info returns version 0.3.0, protocol 0.2 | Only rgb-sdk-flutter-regtest was started, retaining its own data at ports 18444/50002/3013. This establishes service health, not funded mobile flows. |
| Flutter 3.47 packaging integration | Flutter regenerated the example Xcode project/scheme for its Swift Package Manager framework integration and Android Gradle compatibility flags | CocoaPods fallback works, but native SPM support is absent. Flutter also warns about future removal of support for Gradle 8.14, AGP 8.11.1 and Kotlin 2.2.20. No warning-bypass flags or global tool changes were used; follow-up remains with OCT-013 packaging qualification. |

OCT-022 and OCT-023 now have their previously missing regression execution and
are Verified. The newly available storage does not supply real BFA/Ethereum,
LSP/APay/VSS services, a clean committed candidate, or simulator execution.
Docker initially failed to answer status queries, then recovered after a
start request (which reported already running); no Docker restart/reset was
performed. SDK container labels and bind mounts were verified before startup.
No foreign stack or simulator was reused. Approximately 22 GiB remained after
the native builds. Device execution and exact committed-candidate consumer
qualification await the requested dedicated-device/local-commit decisions.

### October 8 Qualification Follow-Up (Historical)

Latest follow-up result: **NO-GO; qualification is incomplete**. The isolated
Flutter 3.47.0 `debug_unpack_ios` target passed for `arm64 x86_64`, and `lipo
-info` confirmed both slices. This removes the reproduced toolchain defect as
the immediate blocker, not the obligation to build clean consumers. Its 84 MiB
disposable output was removed after verification when disk space became critical.

Strict analysis passed with warnings/infos fatal. The first full Dart run on
3.47.0 passed 387 tests. Subsequent focused regression runs verified OCT-017
through OCT-021, but the final full coverage rerun failed before its first test
with `errno = 28` while copying Flutter compiler output. It was interrupted;
there is no final full-suite pass or fresh usable coverage report. Available
disk dropped to 188 MiB (235 MiB after interruption). Only this pass's disposable
framework output and SDK test cache were removed; no foreign cache/data was touched.
The new OCT-022 Android regression has not run. No iOS XCTest, installed Android
execution, funded/unfunded smoke or clean consumer archive was run in this follow-up.

The final bounded checks pass: strict analysis, API snapshot, codebase
hardening, release-package policy and RN source parity against live dev
`3bb39df43f28`. Pigeon was regenerated and formatted with Dart 3.13, not hand
edited. Hardening initially failed because its nested analyzer could not create
the telemetry file (`errno 28`), not because of a source diagnostic or PATH
problem. The SDK example's disposable simulator output and test cache were also
removed to permit saving this work; reports and source were retained. This
cleanup does not provide the space required for full qualification.

Direct Dart probes import the real model/validation implementation: OCT-023
preserves one valid transaction and rejects 18 malformed amount cases; OCT-019
preserves seven valid signed-decimal/truncation cases and rejects 18 malformed
cases. The signed `+.5` precision-zero case failed before its follow-up fix.
These probes supplement, not replace, the committed Flutter regressions or the
final full suite. OCT-022 and OCT-023 remain In progress until their remaining
regressions execute. No current clean-candidate test report is claimed.

### Fresh Source Audit Coverage

[SOURCE_AUDIT_2026_10_08.json](SOURCE_AUDIT_2026_10_08.json) inventories 264
repository-owned tracked/unignored files with content hashes, excluding the
receipt itself. It records 98 files read in full in this follow-up, including
all 75 handwritten Dart/native runtime files. Six generated bridge/baseline
files are separately classified, not claimed as manually reviewed. The other
160 files remain `pending-fresh-full-review`, including partially inspected
tests, integration harnesses, tools, platform/example configuration, docs and
assets. Reading and hashing a file are not execution evidence. This is not a
claim that the complete unchanged repository has been independently audited.
OCT-006 remains unresolved and owns completion of the receipt's pending rows.

### Qualification Prerequisites

| Requested gate | What is proven in this follow-up | What still prevents closure |
| --- | --- | --- |
| Funded BFA and recovery | Journal/consent fault regressions from catch-up; source review of dispatch, journal and native adapters | Non-production issued BFA, funded sending/receiving wallets, independent proof/recovery verifier and both-platform real burn/proof/process-death execution. A method-name or mock success does not meet this gate. |
| Ethereum validation | Password ethRpcUrl forwarding and external-signer rejection are implemented | Approved non-production RPC/chain, bridge contract/reject-list fixture and positive/negative native validation. No credentials or production payout is requested or assumed. |
| LSP/APay/linked assets | Source review and cryptographic/contract regressions | Real compatible LSP/APay deployment, its declared peer/network and canonical-linked asset policy, funded peers and settle/fail/restart scenarios. Provide configuration file locations, not secrets in chat. |
| VSS | Configuration/lifecycle surface is present; success vector remains red | Dedicated VSS service/configuration, authenticated success, fence/conflict and recovery scenarios. Existing Bitcoin/Electrum/proxy Compose is not VSS. |
| Both-platform execution | Earlier Android JVM pass and iOS build-only evidence remain historical for later changes | At least the existing 10 GiB disk minimum, SDK-owned devices, iOS XCTest, updated Android JVM tests and funded/unfunded platform smokes. Other tasks' devices are not reused. |
| Dual-architecture packaging | Flutter 3.47 debug_unpack_ios succeeds and lipo verifies arm64 plus x86_64 | Complete generic simulator application and consumer build; component success is insufficient. |
| Clean consumers/exact candidate | Runner now stops on disk-preflight failure; package/API/RN policy gates pass | Committed clean candidate, sufficient disk, fresh path/Git consumers with Android/iOS archives, final suite/coverage and immutable reports. |
| Complete fresh audit | 98 fully read files, 75 of them handwritten runtime sources | Finish 160 pending receipt rows and review findings; source audit itself is not blocked by missing services and is not marked complete. |

Local evidence: `/private/tmp/rgb-sdk-qualification-347-tests.log` (387-test
pass before the later fixes), `/private/tmp/rgb-sdk-qualification-final-tests.log`
(disk-full failure), and `/private/tmp/rgb-sdk-lipo-347-qualification.log`
(successful target, no console output). All are development evidence on a dirty
tree, not exact-commit release attestations.

The follow-up retains all previous uncommitted work and all unresolved gates.
It is not a new clean candidate. Disk preflight found only 2.3 GiB free, below
the existing 10 GiB release-runner minimum. No foreign simulator, stack, cache,
wallet directory or credential was reused/deleted. Large consumer/runtime runs
must wait for sufficient space; source review and bounded checks continue.

Flutter 3.47.0 is already installed, clean, and matches the official tag at
`4cf24164269a5ebf0c16a028a00727d0e77bbb05`. Its Darwin framework builder includes
the upstream per-architecture lipo verification fix (flutter/flutter#188625).
The repository-local qualification pin is updated; global tooling and package
minimum versions are unchanged. A new complete dual-architecture build remains
required before OCT-013 can close. The initial official storage manifest lookup
returned HTTP 404; the Git tag and installed source were verified instead.

Service prerequisites remain explicit: the SDK-owned Compose project provides
Bitcoin, Electrum and RGB proxy only, not a BFA issuer, Ethereum validation
fixture, funded RLN/LSP peers, APay registry or VSS service. Test doubles are
not substitutes. Configuration locations and sufficient disk space have been
requested from the user; no mainnet mutation will be used as qualification.

## October 8 Upstream Catch-Up Ledger

The original October 8 reference was RN `dev` at
`3bb39df43f281fe0c4723d588c496ddc01e5176e` (`1.0.0-beta.34`), core
`1.0.0-beta.9`, and RLN `0.15.0-beta.3`. The clean starting Flutter commit is
`734f5ae6fb175bbf2d8500a9b43f29b5363c1e52`. September evidence below remains
historical; it is not qualification of this new reference. Verdict: **NO-GO**
until the open implementation and evidence requirements below are satisfied.

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| OCT-001 | P1 | In progress | Updated RN beta.34/RLN 0.15.0-beta.3 pins, source commit, archive sizes, SHA-256, installed iOS hashes and Android ABIs. Both native bridges compile; 29 Android JVM tests pass. | Artifact and internal-beta supply-chain checks pass. Fresh installed-platform execution and consumer archives remain open under OCT-007; generic dual-architecture simulator packaging is blocked under OCT-013. |
| OCT-002 | P1 | In progress | Implemented BFA assets, four native/wallet methods, full unsigned amounts, signer restrictions, and password `ethRpcUrl`. Android serialization/boundary tests pass; corresponding XCTest tests compile. | Execute real BFA receive/burn, saved-proof retrieval, Ethereum RPC/reject-list, and restart cases on both platforms. No BFA issuance API is present in RN's public wallet, and none is fabricated here. |
| OCT-003 | P0 | Verified | Implemented wallet-scoped durable BurnOperations: prepared/pending/complete/cancelled states, shared queue, uncertain-outcome fence, retry-persistence-only, strict legacy normalization and independent-verifier recovery contract. | Dart fault tests cover failures before/after durable writes, revocation at both pre-dispatch writes, result persistence failure, wrapper/restart recovery and corrupted records. This closes the journal contract defect, not funded native recovery qualification (OCT-002/007). No production in-memory store or proof verifier is supplied. |
| OCT-004 | P1 | In progress | Implemented separate optional WebRGB library and all RN provider methods. Typed wire results, revision-bound consent, chain allowlist, JS-safe amounts, 16 MiB proof limit/Keccak, native-error redaction and revoke/re-enable tests pass. | WebRGB Dart coverage is 97.3%. Complete native-backed provider conformance and funded burn/proof flows on both platforms. Host transport, authenticated origin, durable storage and independent asset/bridge-route approval remain real integration obligations. |
| OCT-005 | P1 | Verified | All 22 RN canonical mainnet Lightning entrypoints reject with LIGHTNING_DISABLED_ON_MAINNET before native dispatch. Onchain access remains allowed. | Exhaustive entrypoint regression plus unchanged non-mainnet wallet tests pass. This is a policy contract, not permission to use this candidate with mainnet funds. |
| OCT-006 | P1 | In progress | Static parity covers 66 RlnClient methods, 104 wallet methods, core/LSP contracts, BFA exports and the optional provider. Latest RN drift check, Pigeon regeneration and API snapshot pass. Fresh source receipt covers all 75 handwritten runtime files plus 23 other files. | Source/method checks are not behavioral equivalence. Complete 160 pending repository-file reviews; full new native success vectors and unresolved service/platform evidence remain open. The complete unchanged repository is not yet independently re-audited. |
| OCT-007 | P1 | Open | Existing current-candidate gaps (including TEST-036/TEST-042, VSS, live LSP/APay, clean consumers, restart and funded/unfunded platform evidence) remain unresolved. | Execute gates on this candidate, retain explicit blockers with concrete evidence. Existing accepted constraints remain in force and cannot justify a mainnet production claim. |
| OCT-008 | P1 | Verified | iOS compilation exposed the newly added native LightningUnsupportedOnMainnet enum case. It is now explicitly mapped as non-retryable unsupported in Swift/Kotlin/Dart without a masking default branch. | iOS XCTest target build succeeds; Android enum assertions and Dart native-identity/category/retryability tests pass. XCTest execution remains OCT-007. |
| OCT-009 | P1 | Verified | WebRGB proof hashing initially captured controller/session objects in the isolate closure, making valid proof reads fail. | Top-level immutable-input isolate helper; published Keccak known vector and concurrent distinct proof tests pass. |
| OCT-010 | P2 | Verified | Fault tests found raw journal type errors, an ignored advanced external-signer eth RPC option, and stale documentation claiming bitcoin is an accepted wallet network. | Typed fail-closed validation, explicit unsupported option rejection, and truthful network documentation are implemented and covered by the passing suite. |
| OCT-011 | P2 | Verified | WebRGB getAddress initially returned a Dart record, unlike every other JSON-serializable provider result. | Replaced with immutable WebRgbAddressResult.toJson; tests assert exact address/info/assets/balance/transfer/status/invoice wire shapes. |
| OCT-012 | P2 | Verified | Adding BFA pushed native plugin responsibilities beyond the existing hardening size limit. | Extracted pure asset serialization into RlnAssetMapper on both platforms; preserved existing integer/media/linked-asset mappings, added BFA serializer tests, refreshed CocoaPods and compiled both bridges. No lifecycle ownership moved. |
| OCT-013 | P1 | In progress | Flutter 3.47.0 includes upstream flutter/flutter#188625. On October 9, Xcode 27.0 (27A266a) successfully builds the complete generic simulator app and XCTest bundle; lipo verifies arm64 and x86_64 in Runner and the SDK framework. No global-tool patch or architecture exclusion is used. | Clean path/Git consumer archives remain required. Flutter-generated SPM framework integration builds with this plugin's CocoaPods fallback; native plugin SPM support is absent and Flutter warns about future fallback removal. Do not equate build-for-testing with runtime execution. |
| OCT-014 | P2 | Verified | Parity extraction treated a colon inside an inferred-return method body as a return annotation; optional WebRGB peer resolution also lacked a lockfile check. | Restrict annotations to the immediate signature, explicitly recognize inferred return shape, pin reviewed WebRGB source hashes and resolved 0.1.0 archive/integrity. Live-dev drift check and reviewed tarball verification pass. |
| OCT-015 | P1 | Verified | Independent review reproduced native InvalidRequest mapping to WebRGB INTERNAL_ERROR instead of INVALID_PARAMS. Generic native NotFound cannot safely identify an unknown asset, and named-asset receive lacked preflight validation. | Preserve typed BadRequestError as sanitized INVALID_PARAMS; verify named assets against wallet inventory before blind-receive consent or balance lookup, while allowing no-asset receiving. Regression failed before the fix and passes afterward; do not infer subjects from native error text. |
| OCT-016 | P1 | Verified | Final snapshot review found the line-based export collector omitted multiline directives, including BurnParams/BurnResult, crypto/signer exports and WebRGB errors. Repeated exports also used last-write visibility instead of union. | Replaced it with an analyzer-AST export/part graph, show/hide propagation, union and cycle convergence. Five regressions include the real package entrypoints and fail-closed conditional/external exports. Regenerated the snapshot with no caller migration: this change repairs gate coverage, not runtime API behavior. |
| OCT-017 | P1 | Verified | Endpoint sanitization returned early after removing query/credentials, leaking path payment hashes. Transport-policy errors independently retained sensitive callback paths. HTTP diagnostics now redact after URI stripping; policy diagnostics expose only the origin. | Both focused regressions failed before their fixes and pass afterward, covering toString/toJson, credentials, query, fragment and path identity. Final full-suite rerun is separately blocked by disk. |
| OCT-018 | P2 | Verified | generateKeys and deriveKeysFromMnemonicOrSeed returned futures inside try blocks without awaiting them. Async errors bypassed wrapping and the RN-compatible mnemonic-to-seed fallback. | Await both calls; preserve typed validation and redact generation failures. Focused fallback/error-contract regression passes; strict analysis confirms the missing-await warnings are gone. |
| OCT-019 | P1 | Verified | Unit conversion truncated before validating text, accepting malformed values such as 1.2x at lower precision and empty input as zero. Negative fromUnitsNumber precision leaked a RangeError. A follow-up probe also found +.5 at precision zero failed instead of truncating to zero. | Validate the whole decimal grammar and normalize both signs before parsing; return typed invalid precision. Focused regressions passed; the signed-decimal probe failed before and passes after the follow-up (7 valid and 18 invalid vectors). Final full-suite evidence remains separate. Stricter malformed-input handling is documented as an RN safety divergence. |
| OCT-020 | P2 | Verified | Malformed compressed secp256k1 points in an APay proof leaked PointyCastle ArgumentError/StateError instead of the declared quote-verification failure. | Wrap only point-decoding argument/state failures in the typed quote exception. Two invalid-point vectors failed before and pass afterward. This does not constitute real APay service execution. |
| OCT-021 | P1 | Verified | The release disk preflight recorded failure but continued into consumers/tests because run_step intentionally accumulates failures. It also ran after dependency resolution. | Move the prerequisite before dependency/build work and stop on its recorded nonzero status without disabling nested errexit. Isolated regression failed before the fix; all five runner safety tests pass. The 10 GiB minimum is unchanged. |
| OCT-022 | P2 | Verified | Android unlock rollback called bridgeError on an existing FlutterError, replacing invalidArgument/field/category with FlutterError/native. Both password and external-signer incomplete-RPC paths are affected; Swift already preserves classified errors. | Preservation and the two-signer rollback regression pass in the October 9 native Android suite: 30 tests, zero failures, including taxonomy and lifecycle tests. This verifies the regression, not installed Android or exact clean-candidate qualification. |
| OCT-023 | P2 | Verified | The transaction wire decoder fabricated zero received/sent/fee values when required native fields were missing or malformed. Both pinned platform serializers supply these fields. | Require exact non-negative satoshis; updated two old exact-integer fixtures to include sent. The committed malformed-amount regression passes in the October 9 full 393-test Dart coverage run, and all coverage floors pass. |

Implementation sequence: OCT-001/002/005, OCT-003/004, then OCT-006/007 and an
independent review of the resulting diff. Update individual rows with measured
verification, not simply source completion. No application changes are part of
this SDK task.

### Earlier Catch-Up Evidence (October 8 Working Tree)

All evidence below is for uncommitted changes over 734f5ae, not an immutable
release candidate. Historical verified rows below do not automatically qualify
the new binaries. Test doubles are confined to test sources; no successful burn,
payout, balance or consignment is synthesized in production code.

| Gate | Measured result | Limitation |
| --- | --- | --- |
| Pinned toolchain | Flutter 3.41.9 / Dart 3.11.5; Xcode 27.0 (27A266a) | New Xcode lipo issue is OCT-013. |
| Dart suite and attributed coverage | 386 tests pass; package 87.4%, wallet 85.9%, LSP 87.5%, crypto 89.3%, models 87.1%, WebRGB 97.3%; every configured floor passes | Line coverage and fixtures do not establish native behavior. |
| Strict analyze | Zero diagnostics, warnings/infos fatal | Static only. |
| Pigeon regeneration | Dart/Swift/Kotlin hashes identical after regeneration and formatter | Schema/codec generation, not native success. |
| RN dev and peer contract | Live dev remains 3bb39df; all static parity and method matrices pass; WebRGB resolved peer archive checked | Reviewed changed RN contracts, not a new full unchanged-layer audit. |
| API/docs/packaging static gates | Snapshot, baseline generation, public API docs (231 symbols), README examples, release language and package checks pass | Clean external consumers are still required. |
| Dartdoc | Three libraries generated; zero warnings and zero errors | Link/syntax health is not a behavioral or completeness proof. |
| Android JVM | 29 tests, zero failures/errors/skips | Not Android device/regtest execution. |
| iOS | ARM64 application and XCTest build-for-testing succeed | XCTest has not executed; no simulator from another task was reused. |
| Swift host wire codec | Exact unsigned integer, boolean and null regressions pass | Runs on the host, not in an iOS application. |
| Artifact gate | Installed iOS and Android archives, sizes/hashes and ABI checks pass; internal-beta supply-chain gate passes with explicit warnings | PKG-006 production signatures/attestations remain an accepted constraint. |
| Bridge behavior vectors | FAIL: rgb_assets and vss lack platform-smoke-or-regtest-success | No vector or gate was weakened to report green. |
| Release candidate/consumer matrix | Not current: worktree uncommitted, less than 10 GiB free, no SDK-owned simulator or running regtest stack at inspection | Existing Aster/Iris/other projects and their data were not reused or reset. |

Remaining real-service work includes BFA issuance/receipt from an independent
issuer, native burn and saved proof on both platforms, Ethereum-RPC/reject-list
success/failure, process death with uncertain burn outcome, live LSP/APay/linked
asset flows, VSS success, clean consumer archives and an exact clean candidate
run. Pending burns must remain blocked without an independent proof verifier;
there is no honest generic retry or fake recovery shortcut.

### Review Scope and Reproduction

The changed upstream source/native surface was compared between RN
`821ae4fd10ca3933445ab926cb0af0230b108913` and `3bb39df43f281fe0c4723d588c496ddc01e5176e`.
This is a source-delta review plus targeted review of existing dependencies,
not a claim that every unchanged line has been independently re-audited.

| Area reviewed | Flutter implementation and checks | Remaining qualification |
| --- | --- | --- |
| Native and facade contracts | BFA collections, capabilities, burn/proof methods, signer support, ethRpcUrl, full-u64 amounts and all 22 RN mainnet Lightning guards | Installed native success/fault scenarios |
| Generated and native mappings | Pigeon schema/codecs, Swift/Kotlin asset mapping, new native error enum, release constants and exact artifacts | Both platform runtimes and external consumers |
| Irreversible operations | Durable journal transitions, queue ownership, failed writes, uncertain outcomes, restart fence and independent-verifier contract | Funded native burn, process death and real proof verification |
| Optional WebRGB | Every RN provider method, request/result shapes, consent/revocation races, origin policy, error mapping, proof bounds/digest and private data boundaries | Native-backed dApp/provider conformance and independent bridge-route validation |
| Existing dependencies | Targeted wallet/binding lifecycle, native handle ownership, network/amount policy, LSP HTTP and APay/linked-asset boundaries | Existing open issues and full unchanged-layer independent audit are not erased by this delta review |
| Quality/evidence | Regression tests, strict analyzer, API/source manifests, code generation, coverage attribution, docs, governance and release gates | Exact committed candidate remains mandatory |

Reproduction uses the SDK's Flutter 3.41.9/Dart 3.11.5 tools. Commands run include
`dart run tool/test_dart_coverage.dart`, `dart run tool/validate_coverage_policy.dart`,
`flutter analyze --fatal-infos --fatal-warnings`, the static validators listed
above, `tool/test_native_android.sh` and `tool/test_swift_wire_codec.sh`.
The RN parity gate uses `RGB_SDK_RN_PATH` pointing to the isolated reviewed
checkout and validates the pinned core and WebRGB archives, not just versions.
The iOS build used `xcodebuild ... -sdk iphonesimulator -destination
'generic/platform=iOS Simulator' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
CODE_SIGNING_ALLOWED=NO build-for-testing` from `example/ios`.

The latest Android child report is
`build/test-reports/native/native-android-20261008T065607Z-734f5ae.json`.
Local logs are `/private/tmp/rgb-sdk-coverage-final-oct08.log`,
`/private/tmp/rgb-sdk-webrgb-final-oct08.log`,
`/private/tmp/rgb-sdk-dartdoc-final-oct08.log`,
`/private/tmp/rgb-sdk-parity-final-oct08.log`, and
`/private/tmp/rgb-sdk-ios-tests-build.log`. These are development evidence;
temporary logs and dirty-source child reports are not publishable release
attestations. At final inspection only another task's iOS simulator was booted,
ADB listed no devices, and disk space remained below the release runner's
10 GiB minimum. No ownership or disk-space gate was bypassed.

### Historical September Baseline

| Field | Value |
| --- | --- |
| Audit date | 2026-09-20 |
| P0 remediation started | 2026-07-28 |
| Release verdict | **NO-GO: corrective audit defects, complete current platform evidence, and upstream mutation recovery remain unresolved** |
| Flutter baseline commit | Current committed `HEAD`; release evidence is valid only when the latest `build/test-reports/release/release-candidate-*.json` records that exact full commit and `workingTree.dirty: false` |
| Candidate state | September corrective working tree based on `a443470b733d33397ee8a438b708e39bb76c5c4b`, not a qualified release commit. Current checks include 330 Dart tests, 26 Android JVM tests, passing Swift host-codec assertions, and a zero-warning iOS XCTest target build. iOS XCTest execution, real-service/platform smokes, clean consumer archives and a combined immutable-candidate report are not current. The bridge-vector gate remains red for missing VSS platform success. See the corrective evidence section for exact scope. |
| React Native reference | `UTEXO-Protocol/rgb-sdk-rn` `dev` at `821ae4fd10ca3933445ab926cb0af0230b108913` |
| React Native package | `@utexo/rgb-sdk-rn` `1.0.0-beta.32` |
| Canonical core contract | `@utexo/rgb-sdk-core` `1.0.0-beta.9` |
| Flutter code currently targets | RN `1.0.0-beta.32`; core `1.0.0-beta.9`; RLN `0.13.0-beta.3` |
| Current RN native artifacts | RLN `0.13.0-beta.3` from source tag/commit `v0.13.0-beta.3` / `af03c7f1a65135a429f05a5820600338215954dc` |
| Audit confidence | Source-surface comparison is current against RN dev `821ae4fd10ca`; this is not behavioral parity proof. Both installed artifact sets are checksum-verified. Dart and Android JVM evidence is current on the working tree. iOS has build-only evidence in this pass. Live LSP/APay/linked/VSS scenarios and complete clean qualification remain unresolved. |

## Source Recovery and Publication, 2026-09-20

The September SDK changes remained in a temporary checkout while the permanent
checkout and both GitHub `main` branches still pointed to `3dd82e23`. Pushing the
permanent checkout therefore reported up to date without publishing those changes.
The temporary checkout subsequently lost Git metadata, objects, and source files.
Its surviving contents were archived locally before recovery.

The original Zeus-authored commit
`b3bf942107ac3239892cf8ea46fc6d0b5a2bee59` was recovered without rewriting it:
all 206 indexed files were checked against their original blob hashes, and the
reconstructed tree exactly matches the tree recorded in that commit. Missing
source was recovered from recorded patches; generated baseline source was
regenerated. Later uncommitted work was restored from surviving files and
recorded patches, including the missing LSP source and method matrix files.

Recovery verification on Flutter 3.41.9 / Dart 3.11.5:

- All 223 Dart tests and the example widget test pass.
- Analysis reports no diagnostics; codebase hardening and diff checks pass.
- Pigeon regeneration plus formatting is byte-identical across Dart, Swift, and
  Kotlin; generated release baseline files are current.
- API snapshot, test matrix, public API documentation, release governance,
  package metadata/secret scan, and coverage policy checks pass.
- Coverage is 83.5% overall, 83.9% wallet, 86.4% LSP, 89.2% crypto, and 75.2%
  models. Dartdoc reports zero warnings and zero errors when run with the pinned
  Flutter root; the first invocation without that root failed in the launcher.

This recovery does not refresh live upstream parity, native bridge suites,
consumer archives, restart proofs, or funded/unfunded platform smokes. Those
release gates remain open below. The recovered source belongs in the permanent
SDK checkout, with Zeus attribution and ordinary fast-forward pushes to both
the Zeus repository and `UTEXO-Protocol/flutter-sdk`.

## Historical September Verdict

The package is not yet release eligible. The beta.32/core beta.9/RLN 0.13
contract is implemented, including detailed refresh results,
`WaitingBroadcast`, real `utxo.exists`, decoded-invoice description fields,
proxy recipient IDs, linked-IFA metadata, `SdkLdkChainSync`, and two-asset
LSP/APay flows. Deterministic tests exercise these contracts, but source parity
does not establish behavior against real services. The bridge-vector gate still
fails for missing VSS platform success, and this source has not crossed the
exact clean consumer/platform release gate.

The historical beta.27 candidate remains regression evidence only and must not
be relabeled as beta.32 evidence. PKG-006 remains accepted as a production
supply-chain constraint, API-019 remains native-blocked for backup/recovery,
and LSP-019 records a real upstream idempotency/reconciliation gap for
state-changing HTTP calls.

Static parity, matrices, unit tests, bridge suites, and platform smokes support
only the behavior they inspect. Governance therefore keeps source/API evidence,
native bridge evidence, funded behavior, consumer packaging, and upstream
supply-chain provenance as separate claims.
## Tracker Rules

### Priority

| Priority | Meaning |
| --- | --- |
| P0 | Funds, durable wallet state, secret exposure, or catastrophic release risk |
| P1 | Release-blocking correctness, API, native, platform, or packaging defect |
| P2 | Required production hardening or material maintainability problem |
| P3 | Quality improvement that can follow the first production release |

### Status

| Status | Meaning |
| --- | --- |
| Open | Confirmed and not fixed |
| In progress | An owner is actively implementing it |
| Blocked upstream | Cannot be completed without a native/upstream change |
| Accepted constraint | Deliberate boundary approved for this release line |
| Needs decision | Product or architecture decision is required |
| Verified | Fixed and independently rechecked against its exit criteria |

An issue moves to `Verified` only after its implementation, tests, platform
evidence, and documentation are complete. A passing name-based parity script is
not sufficient evidence.

## Historical Recovery Evidence

This table records the earlier recovery pass, not the present corrective tree.
Its supply-chain, XCTest, test-count and blanket gate results must not be used
as current qualification. Current results and explicit gaps are recorded under
"Active implementation evidence, 2026-09-20" below.

| Check | Result | Interpretation |
| --- | --- | --- |
| Direct toolchain | Flutter `3.41.9`, Dart `3.11.5` | Commands below use the repository-pinned FVM Flutter SDK or its exact bundled Dart executable. |
| `flutter analyze --no-fatal-warnings --no-fatal-infos` | Pass with zero diagnostics | The current candidate reports no analyzer warnings or infos; `dart run tool/validate_codebase_hardening.dart` now also fails release candidates unless analyzer JSON contains zero diagnostics |
| `flutter test --coverage` | Pass, 223 tests; package and subsystem percentages recorded by the current coverage-policy run below | Full Dart unit/contract suite and every configured coverage floor pass on the current beta.32 source; native behavior remains a separate evidence layer. |
| `flutter test` in `example/` | Pass, 1 test | Example widget smoke passes |
| `dart format --set-exit-if-changed lib test example/integration_test tool pigeons` | Pass, 79 files, 0 changed | Current handwritten and schema Dart files are formatter-canonical. |
| `dart doc` | Pass, 0 warnings and 0 errors | Syntax/link health only; public API completeness is enforced separately by `dart run tool/validate_public_api_docs.dart` |
| `dart run tool/generate_release_baseline.dart --check` | Pass | Generated Dart/Swift/Kotlin constants are current; Gradle, podspec, and shell tooling read the same manifest directly |
| Pigeon regenerate/checksum comparison | Pass | Regenerating Pigeon followed by Dart formatting is idempotent against the candidate diff |
| `dart run tool/validate_test_matrix.dart` | Pass: 62 `RlnClient`, 100 `UtexoWallet`, 30 core exports, 20 `UtexoLsp`, 14 `IUtexoLspClient` methods | Validator proves declaration, implementation, contract, and evidence-bucket coverage; behavior claims still require their executable tests. |
| `dart run tool/validate_release_governance.dart` | Pass | Tracker rollup, remaining-open group coverage, policy docs, evidence catalog, public API reference, coverage policy, and stale README claims are mechanically checked |
| `dart run tool/validate_codebase_hardening.dart` | Pass | Strict analyzer config, wallet contract split, line-count guardrails, public docs/tools, and collection-boundary hardening markers pass |
| `dart run tool/validate_public_api_docs.dart` | Pass: 217 stable root symbols | Every stable root symbol is documented; advanced/raw symbols are forbidden from the stable root except explicitly classified stable contracts. |
| `dart run tool/validate_release_language.dart` | Pass | Stale baseline wording and unsafe release/parity claims are mechanically rejected outside historical tracker/changelog context |
| `dart run tool/validate_coverage_policy.dart` | Pending refresh after final receive-bridge preflight vector | Exact-clean-candidate execution remains under TEST-036. |
| `dart run tool/validate_api_snapshot.dart` | Pass | Exported Dart API, complete stable and advanced wallet signatures, Pigeon schema/generated bridge, and native bridge/store markers match the reviewed snapshot. |
| `RGB_SDK_RN_PATH=<rgb-sdk-rn-checkout> RGB_SDK_CORE_TARBALL=<beta.9.tgz> dart run tool/validate_rn_parity.dart` | Pass against live RN `origin/dev` `821ae4fd10ca` | Exact native, wallet, LSP/client signature, runtime-export, package/core version, lockfile, RLN pin, and beta.9 tarball provenance checks match RN beta.32. The validator checks live upstream drift before accepting the local checkout. |
| `dart run tool/validate_release_package.dart` | Pass | Package metadata, repo-local Flutter pin, CI Flutter pin usage, Android release permission, iOS privacy bundling, `.pubignore`, version alignment, internal-beta artifact boundary, honest iOS 18.5 minimum, iOS artifact cache/offline acquisition policy, governance artifact presence, external-signer restart release-gate wiring, and secret-pattern scan pass |
| `dart run tool/validate_supply_chain.dart` | Pass with explicit internal-beta warnings | Current beta.32 dependencies and RLN 0.13 artifacts pass SBOM-style inventory, fail-closed license classification, live hosted Pub OSV audit, ABI-symbol checks, and manifest-backed provenance checks. PKG-006 still accepts missing/insufficient upstream signatures and reproducible/source attestations for internal beta only. |
| `dart pub publish --dry-run` | Pending exact clean candidate | The historical clean-consumer run applies to beta.27. The beta.32 package snapshot must be rechecked from the final clean commit under PKG-018/TEST-036. |
| `./tool/verify_native_artifacts.sh --require-android` | Pass on current dirty source candidate | Installed iOS files and the resolved Android AAR match the exact RLN `0.13.0-beta.3` baseline, including checksums, size, installed-file hashes, slices, and ABIs. Exact-clean-candidate verification remains under PKG-018. |
| `RUN_CONSUMER_ARCHIVES=1 tool/test_clean_consumer_matrix.sh` | Pending exact clean candidate | Historical beta.27 path/Git Android/iOS consumers passed, but beta.32/core beta.9/RLN 0.13 must be rebuilt after the final commit under PKG-018/TEST-036. |
| CocoaPods metadata/integration | `pod ipc spec` passes; plain `pod lib lint` is non-authoritative for this package | Podspec resolves MIT license, path source, iOS 18.5, deployment-target xconfigs, privacy bundle, and source files; plain `pod lib lint` resolves public Flutter 3.13.0 and fails on missing task-queue APIs that are present in the pinned Flutter 3.41.9 consumer toolchain |
| iOS XCTest bridge suite | Pass, 18 cases on dirty beta.32 candidate | Current Swift source graph and RLN 0.13 bridge contract pass. This is useful implementation evidence but is not exact-clean release evidence. |
| Android JVM bridge suite | Pass, 20 cases on dirty beta.32 candidate | Current Kotlin source graph and RLN 0.13 bridge contract pass. This is useful implementation evidence but is not exact-clean release evidence. |
| iOS external-signer process restart | Pending exact clean candidate | The last clean restart proof is historical beta.27 evidence and cannot be relabeled for beta.32. |
| Android external-signer process restart | Pending exact clean candidate | The last clean restart proof is historical beta.27 evidence and cannot be relabeled for beta.32. |
| Current general funded/unfunded platform smokes | Pending exact clean candidate | The beta.32 candidate has not yet completed the four iOS/Android funded/unfunded smokes on its final clean commit. TEST-036 owns this gate. |
| Combined release-candidate script | Pending exact clean candidate | No release-eligible beta.32 report exists yet. The final report must name the exact current commit, record `workingTree.dirty: false`, run every mandatory child gate without skips, and report `releaseEligible: true`. |

The repository now pins Flutter `3.41.9` in `.fvmrc`, and CI installs that
version through `flutter-version-file: .fvmrc`. Historical evidence based only
on the previously broken local `fvm flutter ...` and `fvm dart ...` commands
remains invalid.

## Audit Scope and Method

This review used three independent contracts rather than trusting the existing
parity manifest: current RN `NativeRgb.ts` and both native implementations,
current RN `UTEXOWallet`, and the exact core package declaration/runtime
published with RN. Those were compared against every Flutter public library,
Pigeon source and generated bridge, Swift/Kotlin implementation, wire/domain
model, lifecycle and LSP path, test/tool, package manifest, artifact script,
workflow, example, and public document.

Static comparison proves the source-level findings in this tracker. Current
beta.32 bridge behavior has targeted dirty-candidate iOS/Android evidence, but
clean consumer archives, funded/unfunded flows, restart proofs, and the combined
report still belong to the earlier beta.27 candidate. The report-to-HEAD and
clean-worktree checks prevent that older evidence from being relabeled as
current. PKG-006 remains an independent accepted production-provenance
constraint.

## September Corrective Audit

### Active implementation evidence, 2026-09-20

This work is not a completed release qualification. Remediation currently includes
pre-dispatch deadline validation, signer deadline/cleanup ownership, engine-local
native stores and detach barriers, generation-safe handles, secret-safe error
adaptation, quote funding/recipient binding, APay host binding, bounded polling,
same-asset Any receive handling, full UInt64 RGB read models, and stable network
and transfer adaptation. Release scripts are being changed to reject skips,
uncommitted source, stale coverage and self-asserted provenance.

Observed verification: 330 full-suite Dart tests passed with fresh source-bound
coverage (85.9% overall, wallet 84.2%, LSP 87.4%, crypto 89.3%, models 85.6%).
Android JVM runs all 26 tests, including
detach/unlock contention, checked shutdown failure and RGS rejection. The
production Swift codec executes successfully on the host; its XCTest counterpart
and the complete iOS test target compile with zero warnings/errors. Full iOS
XCTest was not executed in this pass. Native iOS/Android artifacts match the
manifest. README compilation and full Dartdoc generation pass without warnings;
Pigeon regeneration is byte-identical. These are working-tree checks, not proof
for committed HEAD or a published candidate.

The final local recheck reports zero analyzer diagnostics. Format, API snapshot,
release governance/language/package checks, README compilation, generated
baseline consistency, public docs (219 stable symbols), codebase hardening,
coverage policy, the example widget test, and `git diff --check` pass. Detailed
command output is retained in `build/test-reports/corrective-2026-09-20/`.
The final Android report is
`build/test-reports/native/native-android-20260920T173044Z-a443470.json`;
it explicitly remains ineligible because the source is uncommitted. The latest
iOS build-for-testing completed at `2026-09-20T17:31Z`, with 23 XCTest methods
compiled and zero build warnings/errors, but no simulator test execution.

No commit or publication was made during this corrective pass. All new findings
are included below; unexecuted native and real-service criteria remain open or
in progress, not accepted implicitly.

The strengthened bridge-vector validator currently fails on the missing VSS
platform-success requirement. Applicability is now computed from Pigeon AST:
primitive/void responses are not JSON, numeric bounds apply only to non-handle
numeric inputs, and accepted API-019 backup requires explicit native rejection
instead of fake success. Regression tests prevent these exclusions from hiding
new JSON/numeric fields or missing methods. Every JSON-returning method now
rejects malformed/non-object responses, including corrupt entries after valid
list prefixes. No VSS success label was invented to turn the gate green.
TEST-042 remains in progress, and TEST-036 remains open:
real LSP/APay/linked/canonical/VSS success and recovery scenarios are still absent.

TEST-040/TEST-041 now have clean start/end content identities, non-eligible drafts,
completed-log hashing, child-report checks, actual tool/device/owned-stack identity
collection and negative regression tests. Finalization re-reads and verifies all
nine child reports and logs, enforces matching devices and both platform types,
rejects missing Flutter revisions, and prevents external paths/symlinks from
qualifying as repository-owned evidence. Full clean consumer/platform execution
and the remaining expanded inventory/attachment requirements still need proof.
Do not use draft schema-v1 files or a passing child exit code as release evidence.

The current external OSV vulnerability query was blocked by the permission review
because it exports dependency names/versions to `api.osv.dev`. Approval has been
requested; no alternate transport or bypass was used. Local native checksums
passed, but the current vulnerability inventory is unverified. No simulator was
booted or another task's infrastructure reused while device approval is pending.

The implementation loop also caught and recorded six additional findings:
PKG-020, LIFE-018, LIFE-019, MODEL-032, MODEL-033 and TEST-044. The independent
wire-codec review fixed NSNull serialization, and native ownership preflight now
precedes allocation. The funded smoke's peer port and a missing confirmed Bitcoin
send assertion were corrected, but that scenario has not been executed.

New finding PKG-020: Xcode 27 rejects Flutter's generated iOS 13 placeholder pod.
The example now lifts lower pod deployment targets to its existing iOS 18.5
minimum. The clean consumer template and setup documentation now use the same
policy; generated Pods files are not edited manually. Clean consumer execution
still needs to prove that policy on an immutable candidate.

The 2026-09-20 audit supersedes earlier blanket parity/readiness claims. It
identified code defects as well as missing runtime evidence; this is not only a
release rerun. Existing rows are reopened instead of counting the same finding
twice. Seven previously accepted constraints are unchanged. No new limitation
is accepted implicitly. No release eligibility is claimed during remediation.

| ID | Priority | Status | Finding | Closure |
| --- | --- | --- | --- | --- |
| PKG-020 | P1 | In progress | Current Xcode rejects generated Flutter pod iOS 13 deployment settings despite the package/example requiring iOS 18.5. | Apply the existing minimum in example and clean consumer Podfile hooks, regenerate pods, and build/test with the current Xcode. Document the consumer requirement. |
| LIFE-018 | P1 | Verified | Corrective review found local preconditions checked after native side effects: missing init password could create a node; invalid reinit unlock configuration could shut down/replace the active node. Partial destroy also retained a facade node ID after node cleanup succeeded but signer cleanup failed. A second review found failed password init consumed secrets without updating the facade prerequisite flag. | 2026-09-20 corrective verification (working tree, not release qualification): Missing credentials and invalid reinit configuration have zero native side effects; partial destroy retries only remaining signer cleanup. Failed init now requires fresh credentials before allocating again. Four focused corrective regressions pass. |
| MODEL-032 | P1 | Verified | Corrective review found the same double-to-int saturation in three separate LSP/APay decoders, beyond raw wallet models. The advanced `toNumber(BigInt)` helper could also clamp rather than reject. | 2026-09-20 corrective verification (working tree, not release qualification): Shared exact signed parser now protects all three LSP/APay boundaries and toNumber rejects oversized BigInt. Real response decoders plus safe-double/string boundaries are tested. |
| LIFE-019 | P1 | In progress | Node creation checked duplicate storage ownership only after allocating the native node. Android could leave the rejected new UniFFI handle to nondeterministic cleanup. | Preflight storage ownership inside the per-engine operation barrier before native allocation on both platforms. Keep the final store check and fresh monotonic handles; test duplicate and shutdown-path behavior. |
| TEST-044 | P1 | In progress | Funded smoke connected wallet B to wallet A's daemon port 34033 instead of peer port 34032, and the Bitcoin-send evidence row pointed to an RGB-only transfer scenario. | Correct peer routing; add a real BTC send with both-wallet confirmation and exact received-satoshi assertions. Source/analyzer validation does not replace funded platform execution. |
| MODEL-033 | P1 | Verified | Independent codec review found iOS `latestRgsSnapshotTimestamp` uses `NSNull()` when absent, but the recursive wire serializer stringified explicit NSNull through its default branch. This could turn a missing timestamp into a malformed string instead of JSON null. | 2026-09-20 corrective verification (working tree, not release qualification): Explicit NSNull is preserved by the extracted production Swift codec. Host Swift assertions execute exact UInt64, integer/boolean and nested-null behavior; the matching XCTest compiles. Broader engine execution remains TEST-036. |
| TEST-040 | P1 | In progress | AUD-25: Evidence attribution is not bound to the final immutable candidate. | Complete the corrective contract and verification described in the September remediation register below. |
| TEST-041 | P1 | In progress | AUD-26: Log hashes and child report schema are not reliably enforced. | Complete the corrective contract and verification described in the September remediation register below. |
| TEST-042 | P2 | In progress | AUD-27: Test-matrix labels can pass without executable scenarios. | Complete the corrective contract and verification described in the September remediation register below. |
| TEST-043 | P2 | Verified | AUD-28: Coverage validator accepts incomplete, unattributed LCOV. | 2026-09-20 corrective verification (working tree, not release qualification): Fresh LCOV is bound to source/test/tool/fixture inputs, HEAD and complete source inventory; parsed line hits must agree with totals. AST-only declaration exemptions and tampering cases pass. Fresh full-suite coverage passes every existing floor. |
| SEC-013 | P2 | Verified | AUD-37: Expanded seed-list input silently wraps invalid byte values. | 2026-09-20 corrective verification (working tree, not release qualification): Expanded seed lists reject values outside byte range instead of wrapping. Key boundary regression tests pass. |
| API-045 | P2 | Verified | AUD-38: Wallet identity configuration accepts options that are ignored. | 2026-09-20 corrective verification (working tree, not release qualification): Unsupported identity overrides now fail before native allocation rather than being accepted and ignored. Corrective config tests and compatibility docs cover the change. |
| API-046 | P2 | Verified | Additional audit contract table: stable field aliases, node localBalanceMsat, optional carriers, root placement and acknowledgement semantics need explicit compatibility coverage. | 2026-09-20 corrective verification (working tree, not release qualification): Stable aliases and exact node balance are preserved; optional PSBT/begin-end carriers are typed without inventing support; acknowledgement semantics and advanced root placement are documented and compile-checked. |
| LSP-029 | P1 | Verified | Audit follow-up: verify get_info peer binding in APay provisioning and conversion eligibility in automatic relay asset selection. These are investigation items, not yet confirmed exploits. | 2026-09-20 corrective verification (working tree, not release qualification): APay validates advertised host pubkey/network against configured trust. Upstream convertible_asset.go confirms pair authority is operator-side, not a get_info pair graph. Automatic relay choice remains provisional; rejected quote cannot trigger payment. Source commit and rejection regression are documented. |

## Issue Rollup

| Measure | Count |
| --- | ---: |
| Total tracked findings | 292 |
| P0 | 13 |
| P1 | 200 |
| P2 | 79 |
| P3 | 0 |
| Open | 2 |
| In progress | 26 |
| Blocked upstream | 3 |
| Needs decision | 0 |
| Accepted constraint | 7 |
| Verified | 254 |

This rollup is generated from all finding rows; verified code is not equivalent
to clean-candidate platform qualification. Seven accepted constraints remain.

## Remaining Open Work Groups

| Group | Scope | Tracker rows | Count | P0/P1/P2/P3 | Exit condition |
| --- | --- | --- | ---: | --- | --- |
| 1 | Native lifecycle and upstream recovery | LIFE-009, LIFE-010, LIFE-019, LSP-019 | 4 | 0/4/0/0 | Execute native engine/fault and same-path tests on both platforms; obtain upstream recovery contract for ambiguous mutations. |
| 2 | Native contract verification | CODE-014, MODEL-014, API-030 | 3 | 0/3/0/0 | Run iOS enum/fee/RGS regression cases and preserve matching Android evidence. |
| 3 | Qualification, real services and packaging | BASE-010, PKG-016, PKG-019, PKG-020, TEST-040, TEST-041, TEST-042, TEST-036, TEST-044 | 9 | 1/7/1/0 | Complete missing behavior vectors and live LSP/APay/linked/VSS scenarios, clean consumer archives, exact candidate reports and remaining provenance verification. |
| 4 | October BFA/WebRGB qualification | OCT-001, OCT-002, OCT-004, OCT-006, OCT-007, OCT-013 | 6 | 0/6/0/0 | Execute real new-feature and existing service scenarios, complete consumer packaging, independently review remaining unchanged layers, and qualify an exact committed candidate. |
| 5 | Pinned BFA native validation | OCT-027 | 1 | 0/1/0/0 | Requires an approved native artifact change and negative/positive funded cases; do not bypass native validation in Dart. Wrapper policy and amount-contract fixes OCT-024/025 are verified separately. |
| 6 | Native and WalletConnect qualification | OCT-028, OCT-031, OCT-033 | 3 | 0/3/0/0 | Complete live session transport and exact clean consumer/platform qualification. Provider and journal contracts verified separately do not close these rows. |

| 7 | RLN 0.17 page size and upstream recovery | OCT-036, OCT-037 | 2 | 0/2/0/0 | Qualify exact native artifacts, independent current-platform execution and upstream recovery; do not inherit WDK host passes. |

| 8 | RGB_L1 production admission | NOV-002, NOV-003, NOV-004 | 3 | 3/0/0/0 | Qualify durable payment recovery, exact native security and privacy, and the BTC/USDT deployment on both platforms. |

## P0 Execution Log

| Date | Scope | State | Evidence |
| --- | --- | --- | --- |
| 2026-09-15 | RN beta.32 native ABI and model adaptation | In progress | Pinned RN `821ae4fd10ca3933445ab926cb0af0230b108913`, core beta.9, and RLN `0.13.0-beta.3`; installed and checksum-verified the exact iOS/Android artifacts; regenerated Pigeon; added deterministic `SdkLdkChainSync` selection; adapted merged native history methods; and preserved detailed refresh, `WaitingBroadcast`, UTXO existence, invoice descriptions, proxy recipient IDs, and linked IFA metadata through strict immutable Dart models. The complete Dart suite now passes 223 tests, analyzer is zero-diagnostic, Android passes 20 native tests, and iOS passes 18 XCTest cases on the dedicated iPhone 17e simulator. Rows remain in progress until clean-consumer, funded behavior, validator, documentation, and exact-clean-candidate evidence is current. |
| 2026-09-16 | LSP bridge and external-target trust boundaries | Verified | Added local RGB/BOLT11 binding for both bridge directions, including invoice identity, network, asset, smallest-unit amount, expiry, configured payee, conversion metadata, and caller overrides before payment. Added `ILspWallet.decodeRgbInvoice` as an explicit Flutter safety adaptation, adversarial no-payment vectors, and separated true external loopback from the Android-only configured `10.0.2.2` alias. Focused LSP/wallet tests pass; full static and platform evidence is recorded in the audit table. This verifies LSP-022, LSP-023, and LSP-024. |
| 2026-09-16 | Independent LSP/APay boundary review | Verified | Rechecked the new beta.9 orchestration against RLN 0.13 protocol source rather than relying on declaration parity. Centralized native network identity so `utexo`/`signet` and numeric aliases cannot false-reject valid signed invoices; bound native APay responses and proof objects to the requested host and exact v1 status/index/hash invariants; enforced the BIP32 child-index and batch limits; accepted DNS-equivalent domain casing without weakening the signed local part; rejected whitespace relay fields; validated the locally created BOLT11 plus caller hash/UInt16 CLTV/positive-amount inputs before LSP mutation; measured bridge expiry against monotonic elapsed time and rejected exhausted invoices before HTTP mutation; and ignored generated dartdoc output. The full 223-test suite, analyzer, coverage policy, and hardening gate pass. This verifies MODEL-029, MODEL-030, LSP-025, LSP-026, LSP-027, LSP-028, and CODE-021. |
| 2026-08-06 | Error taxonomy and codebase ownership slice | Verified | Removed message-substring native error classification from `mapNativeBridgeException` and introduced structured native bridge categories (`invalidRequest`, `notFound`, `conflict`, `network`, `configuration`, `unsupported`, `native`) with retryability and structured-cause metadata. Android and iOS now emit category/retryable/feature fields for helper-generated errors, unsupported native-blocked paths, and invalid bridge arguments; iOS bridge taxonomy helpers live in `RlnBridgeErrorDetails.swift` so the plugin entrypoint remains below native line-count guardrails. Split `UtexoWallet` into private ownership parts for lifecycle, LSP/APay, on-chain/RGB, Lightning, guards, and unlock resolution while preserving the public class surface through internal mixins; split `RLNBinding` into request/timeout types plus lifecycle, Lightning, and on-chain/RGB operation owners. Updated snapshot, public-doc, RN-parity, matrix, and hardening validators to understand Dart libraries with `part` files and to require zero analyzer diagnostics. Evidence: full `flutter test` with 160 tests, `flutter analyze --no-fatal-warnings --no-fatal-infos` with no issues, `dart run tool/validate_codebase_hardening.dart`, `dart run tool/validate_public_api_docs.dart` with 183 stable symbols, `dart run tool/validate_api_snapshot.dart`, `dart run tool/validate_test_matrix.dart`, `RGB_SDK_RN_PATH=<rgb-sdk-rn-checkout> dart run tool/validate_rn_parity.dart`, release governance/language/package validators, `tool/test_native_android.sh` with 18 plugin tests, `IOS_DEVICE=8B3E2FF7-3A8C-4834-94E9-CC6AD707F2E5 tool/test_native_ios.sh` with 16 XCTest cases, `dart run tool/validate_supply_chain.dart` with expected internal-beta warnings, and `git diff --check` pass. This verifies CODE-013, CODE-014, and CODE-015. |
| 2026-08-06 | Core beta.7 LSP/API parity slice | Verified | Implemented RN beta.27 `createLsp()` discovery semantics, replacing the beta.6 LSP discovery model with beta.7 `LspGetInfoResponse`/`LspSupportedAsset` fields and exact `BigInt` u64 policy limits. Tightened LSP/APay DTO parsers to fail closed on malformed required strings, integers, u64 strings, optional proof maps, and list entries. Audited RN beta.27 root utility exports against the current RN source: `toUnitsNumber`/`fromUnitsNumber` remain exported, while core-only BigInt helpers and `toNetworkName` are not root-exported by RN; Flutter keeps the stable root at RN parity while making `toUnitsNumber` fail above JavaScript `Number.MAX_SAFE_INTEGER` and making internal network-name resolution exact. Evidence: full `flutter test` with 159 tests, `flutter test test/utexo_wallet_test.dart` with targeted beta.7 LSP vectors, `dart run tool/validate_public_api_docs.dart` with 183 stable symbols, `dart run tool/validate_api_snapshot.dart`, `dart run tool/validate_test_matrix.dart`, `RGB_SDK_RN_PATH=<rgb-sdk-rn-checkout> dart run tool/validate_rn_parity.dart`, release governance/language/package validators, `dart run tool/validate_codebase_hardening.dart`, and `git diff --check` pass. This verifies API-033, API-034, API-035, MODEL-018, and MODEL-019. |
| 2026-08-06 | Platform abstraction, crypto-gating, and cleanup slice | Verified with accepted SEC-007 divergence | Removed the template `RgbSdkFlutterPlatform`/`MethodChannelRgbSdkFlutter` layer and `plugin_platform_interface` dependency so native work has one bridge owner: generated Pigeon `RlnHostApi` through `RlnClient`/`RLNBinding`; `RgbSdkFlutter.nativeArtifactInfo()` now uses an internal Pigeon metadata reader only. Added `SchnorrSigningMode` and `ExperimentalCryptoException` so standalone pure-Dart BIP340 signing fails closed by default and requires explicit `SchnorrSigningMode.experimentalDart`; wallet node-message signing remains native RLN-backed and verification remains available. This is an intentional production-safety divergence from RN's top-level core `signMessage`, which remains callable by default through `@utexo/rgb-sdk-core`; wallet/node signing remains RN-aligned. Replaced binding unlock conflict substring matching with typed SDK/native conflict checks, changed UTEXO bridge helper failures to SDK taxonomy errors, and made wallet init/reinit cleanup failures surface as aggregated `WalletException` causes instead of being swallowed. Updated public API docs, architecture/divergence notes, README, API snapshot, and hardening validator gates. Evidence: `dart format --set-exit-if-changed lib test tool`, `flutter analyze --no-fatal-warnings --no-fatal-infos`, full `flutter test` with 156 tests, `dart doc --dry-run`, `dart run tool/validate_public_api_docs.dart` with 182 stable symbols, `dart run tool/validate_api_snapshot.dart`, `dart run tool/validate_codebase_hardening.dart`, `dart run tool/validate_release_governance.dart`, `dart run tool/validate_release_package.dart`, `dart run tool/validate_test_matrix.dart`, `dart run tool/validate_release_language.dart`, `RGB_SDK_RN_PATH=<rgb-sdk-rn-checkout> dart run tool/validate_rn_parity.dart`, `dart run tool/validate_supply_chain.dart`, and `git diff --check` pass. This verifies LIFE-013 and CODE-004, and records SEC-007 as an accepted constraint. |
| 2026-08-06 | Stable model/policy/error taxonomy slice | Verified | Added `WalletInputPolicy` as the single stable wallet-facade validation owner and delegated wallet string, range, fee-rate, config, dependency-owner, and unsupported `skipSync` checks through it. Added `UtexoDomainPolicy` as the single public domain vocabulary owner for transaction types, transfer statuses/kinds, and channel statuses; `Core*`/`Lightning*` mappers now consume that policy instead of local literals. Converted LSP errors to inherit from `RgbSdkException` subclasses, added `OperationCancelledError`, removed public LSP `ArgumentError`/`StateError` paths, made LSP claimable-payment detection use canonical status helpers, documented model/policy ownership and the updated error taxonomy, expanded `tool/validate_codebase_hardening.dart` to gate these boundaries, and refreshed the API snapshot for the intentional stable error export. Evidence: `dart format lib/src/wallet/wallet_policy.dart lib/src/models/utexo_domain_policy.dart lib/src/models/utexo_core_models.dart lib/src/wallet/utexo_wallet.dart lib/src/binding/rln_binding.dart lib/src/errors/rgb_sdk_exception.dart lib/src/lsp/lsp_errors.dart lib/src/lsp/utexo_lsp_client.dart lib/src/lsp/utexo_lsp.dart test/utexo_wallet_test.dart tool/validate_codebase_hardening.dart`, `flutter analyze --no-fatal-warnings --no-fatal-infos`, full `flutter test` with 156 tests, `dart run tool/validate_codebase_hardening.dart`, `dart run tool/validate_public_api_docs.dart` with 180 stable symbols, `dart run tool/validate_api_snapshot.dart`, `dart run tool/validate_release_governance.dart`, `dart run tool/validate_release_package.dart`, `dart run tool/validate_test_matrix.dart`, `dart run tool/validate_release_language.dart`, and `RGB_SDK_RN_PATH=<rgb-sdk-rn-checkout> dart run tool/validate_rn_parity.dart` pass. This verifies CODE-005, CODE-006, and CODE-012. |
| 2026-08-05 | Facade transfer/lifecycle/unit hardening slice | Partial verified | `UtexoWallet` now owns an `RLNBinding` and routes wallet-facing node operations through the binding's serialized operation owner, while signer strategies use the same underlying `RlnClient` only for private signer handles. Wallet operation guards now require initialized/unlocked state before chain, RGB, Lightning, channel, VSS, and lookup calls can reach native code. `reinit()` now stops before create when shutdown fails, leaves the wallet in a retryable shutdown state when recreate fails, and destroys replacement plus retired shutdown handles when unlock fails. `listTransfers()` now fails closed with `UnsupportedWalletFeatureException` if the pinned artifact rejects unfiltered listing, rather than falling back to known asset IDs and silently omitting no-asset transfers. Public model/request docs now spell out sats, msats, asset-smallest-unit, duration seconds, and Unix-second timestamp fields; unit-boundary tests preserve those values. Evidence: `flutter analyze --no-fatal-warnings --no-fatal-infos` passes and `flutter test test/utexo_wallet_test.dart` passes with 74 tests. This verifies API-028, MODEL-016, LIFE-004, LIFE-005, and LIFE-007. |
| 2026-08-06 | Lifecycle timeout and native store cleanup slice | Verified | Added `RlnOperationTimeoutPolicy` and `RlnOperationTimeoutException` so binding-owned native operations have explicit default `DEFAULT_API_TIMEOUT` deadlines by category while acknowledging that Pigeon/RLN calls cannot be cancelled once native execution starts. A timed-out binding is quarantined for regular operations, its internal queue still waits for native completion, and destroy remains the non-timed cleanup gate. `UtexoWallet.destroy()` now also cleans binding-owned nodes after a timed-out create that returned no facade node id. Android store removal and `clearAll()` now drop handles/metadata before closing native nodes/signers, so injected close failures still leave the store empty. iOS store replacement removes the old shutdown node before installing the replacement, rejects initialized-state drift after unlocked/shutdown, and exposes a native snapshot for deterministic cleanup proof. Evidence: `flutter test test/rln_manager_contract_test.dart test/utexo_wallet_test.dart` passes with 80 tests, Android JVM `./gradlew testDebugUnitTest` passes with 18 plugin tests, iOS XCTest on iPhone Air passes with 16 cases, and analyzer passes. This verifies LIFE-008, LIFE-010, LIFE-011, and TEST-007. |
| 2026-08-06 | Stable root and RN-shaped API quarantine slice | Verified | Added `package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart` as the explicit RN/native parity entrypoint for `RlnClient`, `RLNBinding`, `RLNManager`, `IRLN*`, raw `Rln*` models, native bridge diagnostics, logger access, network defaults, and RN-uppercase compatibility extensions. Narrowed the stable root `rgb_sdk_flutter.dart` to app-facing wallet/domain/errors/LSP types, validation, crypto helpers, native artifact metadata, and `RlnOperationTimeoutPolicy`; removed `RgbSdkFlutter.rlnClient()` and `RgbSdkFlutter.rlnManager()` from the stable entrypoint; moved `decodeRGBInvoice` and `decodeRGBInvoiceCore` out of `UtexoWallet` into an advanced compatibility extension; and moved bridge/parity tests plus the low-level regtest smoke to the advanced import. Added a public-doc validator guard that fails if known raw/RN/internal symbols are exported from the stable root, updated RN parity validation to include both root and advanced entrypoints, refreshed the API snapshot, updated docs, and removed stale uppercase wallet rows from the wallet matrix. Evidence: `dart format --set-exit-if-changed lib test tool`, `flutter analyze --no-fatal-warnings --no-fatal-infos`, full `flutter test` with 155 tests, `dart doc --dry-run`, public API docs validator, API snapshot validator, RN parity validator, test matrix validator, release governance/package/language validators, codebase hardening validator, and `git diff --check` pass. This verifies CODE-001 and CODE-002. |
| 2026-08-05 | Group 1 stale facade/export/error slice | Partial verified | Removed stale stable-facade wallet methods `getXpub`, generic `send`, `getLightningReceiveRequest`, and `getLightningSendRequest`; `onchainSend` is now the only high-level RGB send spelling and requires an explicit `amount` rather than falling back to decoded invoice assignment. Removed root exports for obsolete `RNSigner`, flat PSBT helpers, and UTEXO bridge/network map helpers, while keeping RN-current account-key crypto helpers and low-level RLN advanced APIs. Added explicit node-key wallet aliases `signNodeMessage` and `verifyNodeMessage` and documented the key-identity split from top-level account-key `signMessage`/`verifyMessage`. Core-compatible SDK errors now carry stable `code`, optional `statusCode`, cause, and `toJson()` serialization. Updated public API docs, divergence notes, test matrix, and API snapshot. Evidence: targeted wallet/manager/DTO tests pass, analyzer passes, public API docs/snapshot/test-matrix validators pass, and full Dart tests pass. This verifies API-014, API-016, API-018, API-024, and API-026. |
| 2026-08-05 | Group 1 facade/domain contract slice | Partial verified | Canonical `UtexoWallet` methods now return stable wallet/domain DTOs for Bitcoin/RGB core data plus node, network, peer, channel, payment, keysend, invoice-status, and decode flows. Raw native `Rln*` DTOs remain available only through explicit `Raw` methods such as `getBtcBalanceRaw`, `listChannelsRaw`, `decodeLnInvoiceRaw`, `invoiceStatusRaw`, and `keysendRaw`. Added wallet-facing domain DTOs and mappers in `lib/src/models/utexo_core_models.dart`, rewired LSP and integration-smoke call sites to consume stable channel/payment shapes, documented the canonical-vs-raw migration rule in `doc/PUBLIC_API_REFERENCE.md` and `doc/API_COMPATIBILITY_AND_DIVERGENCE.md`, and refreshed `tool/api_snapshot.json` as an intentional API change. Evidence: `flutter test test/utexo_wallet_test.dart`, `flutter analyze --no-fatal-warnings --no-fatal-infos`, `dart run tool/validate_public_api_docs.dart`, and `dart run tool/validate_api_snapshot.dart` pass. This verifies API-007 and API-010. |
| 2026-08-05 | Group 8 lifecycle stress and cleanup evidence | Verified by later exact run | Added deterministic Dart lifecycle/fault tests for queued init/unlock/shutdown/destroy contention, failed-init temporary-node cleanup before retry, and destroy fault reporting after node cleanup. Hardened `example/integration_test/plugin_integration_test.dart` so low-level, facade, and funded regtest smokes always attempt node/wallet cleanup, delete their temporary storage directories, report cleanup failures with `RGB_SDK_FLUTTER_CLEANUP_ERROR`, and fail successful smokes if cleanup did not actually complete. Added the new lifecycle stress cases to the `unfunded_lifecycle` evidence bucket. Initial evidence was dirty-candidate only; the current exact clean run `20260806T094500Z` now covers the resulting lifecycle/platform smoke gates. TEST-015 is verified. Native timeout/cancellation and native store cleanup completion are closed by the 2026-08-06 lifecycle slice. |
| 2026-08-05 | Group 7 native artifact provenance gate | Accepted constraint | Added `tool/native_artifact_provenance.json` as the machine-readable provenance record for the pinned RLN `0.10.0-beta.3` native artifacts and made `tool/validate_supply_chain.dart` consume it. The validator now checks provenance entries against `tool/release_baseline.json`, records Android Maven AAR signature availability as `present-unverified`, records the iOS GitHub release asset signature as absent, records missing per-artifact attestations/reproducible-build evidence, and keeps `--production` fail-closed until every native artifact has verified signature and reproducible-build/source attestation evidence. `tool/validate_release_package.dart` now requires the manifest and validator wiring. Live upstream check on 2026-08-05 found GitHub release assets `rgb-lightning-node-kotlin-android-0.10.0-beta.3.zip`, `rgb-lightning-node-swift-0.10.0-beta.3.zip`, and `rln-wasm-sdk-pkg-0.10.0-beta.3.tar.gz` only, while Maven Central exposes `rgb-lightning-node-android-0.10.0-beta.3.aar.asc`. Evidence: `dart run tool/validate_supply_chain.dart` passes with internal-beta warnings, `dart run tool/validate_supply_chain.dart --production` fails as required, `dart run tool/validate_release_package.dart`, `dart run tool/validate_release_governance.dart`, `dart run tool/validate_release_language.dart`, and `git diff --check` pass. PKG-006 is accepted for this internal-beta line because upstream iOS signatures, trusted-key Android signature verification, and reproducible-build/source attestations are not present; do not promote the package beyond internal beta until those proofs exist. |
| 2026-08-05 | Group 6 exact release-candidate runtime proof | Verified | Fixed the local release runner so `RUN_PLATFORM=1` now requires iOS and Android external-signer process-restart proofs in addition to native bridge tests and funded/unfunded platform smokes. Fixed native/platform/restart child reports so `releaseEligible` is computed from exit code plus clean worktree instead of being hard-coded false. Fixed the environment blockers by restarting Docker after its VM wedged, running the SDK regtest stack on `RGB_PROXY_PORT=3013`, creating and booting the dedicated `rgb_sdk_release_api36` Android AVD from the release runner, and clearing generated build output without deleting warmed artifact caches. The exact clean candidate run `20260805T163000Z` passed on commit `bb1fe028c49ff307dcccfa68e4157623ccf2fce7` with `releaseEligible: true` and `dirty: false`. Evidence: `build/test-reports/release/release-candidate-20260805T163000Z-bb1fe02.json`, clean-consumer report `build/test-reports/release/clean-consumer-matrix-20260805T161420Z-bb1fe02.json`, native reports `native-android-20260805T163000Z-bb1fe02.json` and `native-ios-8B3E2FF7-3A8C-4834-94E9-CC6AD707F2E5-20260805T163000Z-bb1fe02.json`, platform smoke reports for iOS/Android funded and unfunded, and external-signer restart reports for iOS/Android all passed from a clean worktree. This verifies API-032 and TEST-002. |
| 2026-08-05 | Group 5 codebase hardening and public documentation depth | Verified | Split wallet public contract types/status helpers from `lib/src/wallet/utexo_wallet.dart` into `lib/src/wallet/utexo_wallet_types.dart`, updated signer/LSP/barrel imports, and refreshed `tool/api_snapshot.json` for the intentional exported-source reorganization. Enabled strict casts, strict inference, strict raw types, generated Pigeon exclusions, and production-oriented lints in `analysis_options.yaml`; `flutter analyze --no-fatal-warnings --no-fatal-infos` reports no issues. Hardened public collection boundaries with defensive unmodifiable copies across wallet configs/requests, binding params, RLN/core DTOs, LSP wire wrappers, and UTEXO network presets; `test/public_dto_immutability_test.dart` proves caller mutation and exposed collection mutation cannot alter DTO state. Added `doc/PUBLIC_API_REFERENCE.md`, `doc/COVERAGE_POLICY.md`, `tool/validate_public_api_docs.dart`, `tool/validate_release_language.dart`, `tool/validate_coverage_policy.dart`, and `tool/validate_codebase_hardening.dart`; wired the new gates into release package/governance validation and `tool/test_release_candidate.sh`. Evidence: `dart format --set-exit-if-changed lib test tool`, `flutter analyze --no-fatal-warnings --no-fatal-infos`, `flutter test --coverage` (145 tests), `dart run tool/validate_coverage_policy.dart` (package 70.0%, wallet 82.2%, LSP 67.7%, crypto 71.0%, models 74.6%), `dart run tool/validate_codebase_hardening.dart`, `dart run tool/validate_public_api_docs.dart` (263 symbols), `dart run tool/validate_release_language.dart`, `dart run tool/validate_release_governance.dart`, `dart run tool/validate_release_package.dart`, and `dart run tool/validate_api_snapshot.dart` pass. This verifies LIFE-012, CODE-003, CODE-007, CODE-008, CODE-011, and TEST-003. |
| 2026-08-05 | Group 4 packaging, platform minimums, and supply chain | Partial verified | Raised the declared iOS support floor from 13.0 to the pinned RLN artifact's real `LC_BUILD_VERSION` minimum of 18.5 in `tool/release_baseline.json`, `ios/rgb_sdk_flutter.podspec`, and the example iOS project; podspec xconfigs now propagate that deployment target to pod and user targets. Added deterministic iOS artifact acquisition modes to `tool/download_rln_ios.sh`: explicit `RLN_ARCHIVE_PATH`, checksum-verified `RLN_CACHE_DIR`, and fail-closed `RLN_OFFLINE=1`. Completed podspec license/source metadata and replaced plain `pod lib lint` as an authoritative gate because CocoaPods resolves public `Flutter` pod 3.13.0, which lacks the task-queue API required by the pinned Flutter 3.41.9/Pigeon bridge; `pod ipc spec ios/rgb_sdk_flutter.podspec` plus clean Flutter consumer archives are the release gates. Expanded `doc/INTEGRATION_SECURITY_AND_RELEASE.md` with support matrix, artifact acquisition, artifact upgrade procedure, CocoaPods validation policy, and API policy summary. Evidence: root `dart pub publish --dry-run` has only the expected dirty-worktree warning until commit, the clean-consumer candidate snapshot dry-run is warning-free and passes path/Git Android/iOS archives at `build/test-reports/group-4/clean-consumer-matrix-20260805T114259Z-d366bca.json`, `pod ipc spec ios/rgb_sdk_flutter.podspec` resolves platform 18.5/license/source/privacy metadata, `dart run tool/validate_release_package.dart` passes, and `REPORT_DIR=build/test-reports/group-4 dart run tool/validate_supply_chain.dart` passes with internal-beta provenance warning. This verifies PKG-001, PKG-002, PKG-008, PKG-014, PKG-015, and DOC-004. PKG-006 is accepted as an internal-beta supply-chain constraint because upstream artifact signatures and reproducible-build attestations are still absent and production supply-chain mode intentionally fails. |
| 2026-08-05 | Group 3 LSP/service behavior and security audit | Verified, superseded by 2026-08-06 crypto-gating slice | Added reproducible hosted Pub OSV vulnerability checks and fail-closed license classification to `tool/validate_supply_chain.dart`; the generated report `build/test-reports/group-3/supply-chain-c131f50.json` records 55 accepted dependency/license entries, 0 unknown, 0 rejected, 52 hosted Pub package queries, and 0 vulnerable packages, with the separate internal-beta warning that upstream artifact signatures/reproducible attestations are still absent under PKG-006. Added wallet/LSP tests proving typed `ConflictError` is the only peer-connect idempotence success path, same-host/foreign LSP errors are not unsafe fallbacks, `receiveAsset`/`sendAsset` preserve LSP service failures, failed settlement throws `LspSettlementException`, APay registration failures surface explicitly, HODL claims never fabricate missing preimages, HODL native claim failures are reported per payment, and VSS failures are not rewritten. Added BIP340 tamper and scalar/byte-length boundary tests beyond the official vectors. Evidence: `flutter test test/utexo_wallet_test.dart`, `flutter test test/crypto_bip340_vectors_test.dart`, `REPORT_DIR=build/test-reports/group-3 dart run tool/validate_supply_chain.dart`, `dart run tool/validate_test_matrix.dart`, and `dart run tool/validate_release_package.dart` pass. This verified LSP-008, SEC-008, TEST-006, and TEST-009; SEC-007 is recorded as an accepted fail-closed standalone-signing divergence by the 2026-08-06 crypto-gating slice. |
| 2026-08-05 | Group 2 low-level bridge and native behavior vectors | Verified | Added `doc/BRIDGE_BEHAVIOR_CONTRACT.md` and `tool/test_matrix/bridge_behavior_vectors.json` to define bridge family vectors, critical method vectors, malformed-wire behavior, and the signed-Int64 Pigeon numeric boundary; added `tool/validate_bridge_vectors.dart` and wired it into the release-candidate and package gates; added Dart malformed-wire tests for invalid JSON, non-object single responses, and non-object list entries; added Dart model tests proving decimal integer strings parse through signed `Int64.max` and out-of-range native UInt64 strings throw `NativeProtocolException` instead of becoming `0`/`null`; fixed Swift/Kotlin request-heavy bridge methods so request validation happens before node lookup for `openChannel`, `lnInvoice`, `keysend`, and `sendPayment`; added mirrored Android JVM and iOS XCTest vectors for Group 2 numeric boundaries, unknown RGB assignment kinds, and unknown-node operation details across rotate/sign/verify/txid history methods. Evidence: `flutter test test/rln_client_contract_test.dart`, `flutter test test/utexo_wallet_test.dart`, `tool/test_native_android.sh`, `IOS_DEVICE=8B3E2FF7-3A8C-4834-94E9-CC6AD707F2E5 tool/test_native_ios.sh`, `flutter analyze --no-fatal-warnings --no-fatal-infos`, `dart run tool/validate_test_matrix.dart`, `dart run tool/validate_bridge_vectors.dart`, `dart run tool/validate_release_package.dart`, `dart run tool/validate_release_governance.dart`, and `git diff --check` pass after updating `tool/api_snapshot.json` for the intentional exported constants/native bridge drift. This verifies API-001, API-002, API-003, API-004, API-012, MODEL-015, TEST-001, TEST-005, and TEST-008. Later exact clean run `20260806T094500Z` closes the funded runtime evidence through API-032 and TEST-002. |
| 2026-08-04 | Group 1 release truth, divergence, and evidence schema | Verified | Added `doc/API_COMPATIBILITY_AND_DIVERGENCE.md` with source precedence, an approved divergence register, API stability tiers, Dart adaptation map, deprecation/breaking-change plan, and architecture decisions for Pigeon vs FFI/UniFFI, artifact ownership, and stable layering; added `doc/RELEASE_EVIDENCE_SCHEMA.md` with evidence IDs, required fields, sanitization, matrix evidence catalog rules, API/ABI snapshot policy, and documentation completeness criteria; added `tool/test_matrix/evidence_catalog.json` and made `tool/validate_test_matrix.dart` require every bucket to resolve to test IDs, report families, claim levels, and assertions; added `tool/api_snapshot.json` plus `tool/validate_api_snapshot.dart` for exported Dart, Pigeon, generated bridge, and native bridge surface drift; added `tool/validate_release_governance.dart` to check tracker rollups and remaining-open group coverage mechanically; wired the new governance and snapshot gates into `tool/test_release_candidate.sh`; updated release report wrappers to include schema version, evidence IDs, full commit, dirty state, unique run IDs, sanitized repo-relative log paths, and log SHA-256; and fixed stale README/matrix docs. Evidence: `bash -n` passes for modified shell wrappers; `dart format` passes for modified tools; `dart run tool/validate_api_snapshot.dart`, `dart run tool/validate_test_matrix.dart`, `dart run tool/validate_release_package.dart`, and `dart run tool/validate_release_governance.dart` pass after tracker update. This verifies BASE-006, API-020, API-029, CODE-009, CODE-010, TEST-011, TEST-014, TEST-016, and DOC-005. Later exact clean-candidate runtime proof is closed under API-032 and TEST-002. |
| 2026-08-04 | Consumer/supply-chain/crypto/secret hardening pass | Partial verified | Added `tool/test_clean_consumer_matrix.sh`, which snapshots tracked/unignored candidate files, verifies package tarball contents, installs the SDK into fresh Flutter consumers by path and local Git ref, builds Android release APKs and iOS release no-codesign apps for both, checks prepared RLN iOS artifacts, and reruns CocoaPods with `--deployment --no-repo-update`; added `tool/validate_supply_chain.dart`, which produces an SBOM-style dependency inventory, license-file inventory, pinned provenance status, and iOS/Android ABI-symbol marker checks while failing production mode until upstream signatures/reproducible attestations exist; wired both gates into `tool/test_release_candidate.sh`; expanded package validation to require those gates and scan untracked candidate files; switched low-level Schnorr signing/verification to current BIP340 arbitrary-message semantics and added the official Bitcoin BIP340 vector fixture; wiped SDK-owned seed/private-key byte buffers after derivation/signing where possible; consumed native external signer seed hex after native handoff; and cleared password signer secrets after unlock while allowing explicit password refresh for future sessions. Evidence: `dart run tool/validate_supply_chain.dart`, `RUN_CONSUMER_ARCHIVES=1 REPORT_DIR=build/test-reports/current-candidate tool/test_clean_consumer_matrix.sh`, and targeted `flutter test test/crypto_bip340_vectors_test.dart test/utexo_wallet_test.dart` pass. This verified SEC-002 and PKG-016 at the time; Group 3 later added the missing license/vulnerability audit and BIP340 boundary coverage. PKG-006 is now accepted for internal beta while still blocking production supply-chain mode. |
| 2026-08-04 | P1 typed bridge/lifecycle/platform evidence pass | Superseded by exact candidate evidence | Replaced broad generated Pigeon response maps with a typed `RlnWireResponse` JSON wire envelope and strict Dart decode that rejects malformed/non-object payloads; updated the RN parity validator to forbid broad response maps at the Pigeon boundary while preserving public semantic return categories; added Android/iOS detach cleanup that unregisters Pigeon and closes engine-owned native node/signer stores; made same-storage restart state transitions deterministic; exported iOS FFI headers to consumer/test targets through the podspec; extended Dart lifecycle guards so chain, RGB, Lightning, and channel operations fail before unlock; added native clear-all and unlock-gate tests; and made the release runner prepare the iOS simulator plus check Pigeon drift in dirty candidates without comparing against `HEAD`. Evidence: analyzer, `flutter test` (132 tests), release package validation, matrix validation, RN parity validation, generated-baseline check, native artifact verification, `dart format --output=none --set-exit-if-changed .`, `git diff --check`, Android JVM bridge tests (14 cases), iOS XCTest bridge tests (10 cases), four funded/unfunded platform smokes, and the all-up local release-candidate script pass on dirty commit `c131f50`. This verified MODEL-001, LIFE-009, and TEST-013 at the time; later rows and the exact clean candidate closed the native behavior, lifecycle/fault, clean consumer, provenance inventory, and clean-commit evidence gaps. |
| 2026-08-04 | Phase 6-7 LSP/network/security/package hardening | Partial verified | Ported current core LSP routing semantics into Dart: same-host Lightning Address resolution stays on the authenticated LSP client, foreign hosts use unauthenticated LNURL over the same injected HTTP client, callback rebasing preserves base path prefixes, non-loopback HTTP is rejected, LSP bodies/errors are bounded and redacted, missing HODL preimages are reported without native claim calls, polling uses monotonic timers with validated intervals, SDK network parsing is strict while native `utexo` maps to `signet`, core default timeout/log-level/endpoints are aligned, Android release `INTERNET` and iOS privacy bundling are declared, duplicate Android settings are removed, package constraints and versions are coherent, `.pubignore` is explicit, and package validation is a local/CI gate. Evidence: `flutter analyze --no-fatal-warnings --no-fatal-infos`, `flutter test` (129 tests), `dart run tool/validate_release_package.dart`, `dart run tool/validate_test_matrix.dart`, `RGB_SDK_RN_PATH=<rgb-sdk-rn-checkout> dart run tool/validate_rn_parity.dart`, generated-baseline check, and `git diff --check` pass. `dart pub publish --dry-run` still exits 65 because the worktree is dirty and `android/settings.gradle` is deleted-but-tracked until commit; native consumer archives/provenance/SBOM/pod lint/platform smokes were not run in this phase. |
| 2026-08-04 | P1 API/lifecycle/error-mapping pass | Superseded by exact candidate evidence | Added Pigeon background task queues for every HostApi method and regenerated Dart/Swift/Kotlin; removed native `Thread.sleep`/`usleep` readiness polling and unknown conflict-as-success transitions; preserved full `onchainReceive` metadata; made canonical `estimateFeeRate` return `RlnFeeRate` with a scalar compatibility alias; added typed optional carrier slots for PSBT and begin/end flows; completed HODL invoice metadata returned by the facade; centralized `PlatformException` mapping into typed SDK errors with structured native cause; fixed UTEXO bridge status encoding plus HTTP timeout/close/required-field/error semantics; deduplicated known-asset transfer fallback. Evidence: `flutter test` (131 tests), analyzer, package validation, matrix validation, RN parity, generated-baseline check, `git diff --check`, Android JVM bridge tests (13 cases), and iOS XCTest bridge tests (10 cases) pass. Later rows and the exact clean candidate closed the native behavior, funded/unfunded platform smoke, clean consumer archive, typed bridge envelope, supply-chain inventory, and Schnorr-gating evidence gaps. |
| 2026-08-04 | P1 source-hardening pass | Superseded by exact candidate evidence | Added `.fvmrc` Flutter `3.41.9`, pinned CI to that file, and gated both in package validation; verified package/pod/Android module version alignment; added canonical `LightningChannel` mapping with sat-to-msat conversion and a facade method; changed facade defaults and native bridge validation so fractional fee rates fail instead of truncating; moved fee validation before native node lookup for bridge determinism; exposed external-signer RGB UTXO/issuance capabilities and fail-fast guards before native calls; and made the local release-candidate script require Android AAR checksum/ABI verification. Evidence: `flutter test` (130 tests) and Android JVM bridge tests (13 cases) pass for this slice. Later rows and the exact clean candidate closed the native iOS XCTest, background-threading, canonical API migration, platform smoke, typed bridge, and clean release evidence gaps. |
| 2026-08-04 | Wallet API decisions | Verified | Removed Flutter-only `UtexoWallet.issueAssetCfa` and `UtexoWallet.issueAssetUda` from the stable wallet facade to match current `rgb-sdk-rn` wallet parity. CFA/UDA remain available only through low-level RN-parity `RlnClient`/`RLNBinding` APIs. Publishing/version distribution policy is accepted as deferred until the package is prepared for publication. Evidence: wallet method matrix now reports 89 wallet APIs. |
| 2026-08-04 | Phase 4-5 Dart model/lifecycle hardening | Partial verified | Added `NativeProtocolException`, strict required-field decoding for high-risk RLN wallet models, current RN optionality for node/channel/payment/invoice/transfer/unspent fields, `pendingBlinded` preservation, strict outpoint/transfer enum mapping, PascalCase Lightning payment statuses, `gossipRgsServerUrl` fail-fast rejection, defensive seed-byte copying, and a serialized `UtexoWallet` lifecycle state machine with concurrent init/unlock coalescing and post-shutdown operation rejection. Evidence: `flutter analyze --no-fatal-warnings --no-fatal-infos`, `flutter test` (126 tests), `dart run tool/validate_test_matrix.dart`, and `RGB_SDK_RN_PATH=<rgb-sdk-rn-checkout> dart run tool/validate_rn_parity.dart` pass. Native iOS/Android lifecycle races, Pigeon typed DTOs, platform fixtures, and funded smokes were not run in this phase. |
| 2026-08-04 | Phase 0-3 beta.26/static parity | Verified | `tool/release_baseline.json` now pins RN `d5916c142077b501ffb86d028c457a9c21b60d59`, core `1.0.0-beta.6`, RLN `0.10.0-beta.3`, iOS archive SHA-256 `be2adacc4f1e608648659b08b36baab92dc113818c950b311cf0c352a25130f5`, Android AAR SHA-256 `1b29fe696ea7a2ce38a30f7a67cd692271349394863da879d7abb55719f4f6a5`, iOS slices `arm64`/`arm64,x86_64`, and Android ABIs `arm64-v8a`, `armeabi-v7a`, `x86_64`. `validate_rn_parity`, `validate_test_matrix`, generated-baseline check, artifact verification, analyzer, full Dart tests, example tests, and Android JVM bridge tests pass. The release script correctly fails when iOS XCTest and platform smokes are skipped. |
| 2026-08-02 | Upstream beta.26 refresh | Superseded | Fresh `origin/dev` is `d5916c142077b501ffb86d028c457a9c21b60d59`, package `1.0.0-beta.26`, core `1.0.0-beta.6`, and RLN `0.10.0-beta.3`. The upstream delta added richer native RLN error messages, category-correct iOS errors, `FailedVssInit`, and additional core UMA exports. The 2026-08-04 phase 0-3 row now owns the verified static/artifact baseline; all prior beta.25 runtime evidence remains historical until rerun. |
| 2026-07-28 | Baseline refresh | Verified | Refetched RN `origin/dev`; it remains `cb4fe938b171ac3771093e46b494f5eca190e804`, package `1.0.0-beta.25`, core `1.0.0-beta.5`, RLN `0.9.0-beta.3`. One manifest now feeds generated constants and direct build/script readers; exact commit/source, checksums, installed iOS files/slices, and Android AAR/ABIs verify. |
| 2026-07-28 | Durable external signer | Verified | Both plugins use RLN `newWithStorage(storageDirPath)` before attachment, Dart owns signer handles transactionally, native storage is owner-only, and funded process-restart/channel-payment proofs pass on iOS and Android. |
| 2026-07-28 | Restart proof | Verified | One run-scoped binary/APK is installed once per platform, settles both directions, orderly-shuts down RLN, crosses an OS-enforced process boundary, relaunches without reinstalling, proves unchanged storage plus stable node/channel identities, and settles both directions again. This is not an abrupt-crash/power-loss proof; the 2026-08-06 lifecycle slice adds deterministic store cleanup/fault coverage but still does not claim power-loss recovery. |
| 2026-07-28 | Native storage policy | Verified | New roots are created with exact mode `0700`; symlink, non-directory, foreign-owner, broad, and owner-only-but-unusable paths fail closed without permission mutation. Current native suites pass 9 iOS and 12 Android cases, and both funded process-restart smokes pass. |
| 2026-07-28 | iOS native test source graph | Verified | `test_native_ios.sh` now runs `pod install` before `xcodebuild`; the subsequent run compiled `RlnStorageDirectoryPolicy.swift` from the current source graph and all nine XCTest cases passed. |
| 2026-07-28 | Regtest readiness | Verified | Startup mines a current tip when Bitcoin Core reports IBD, waits for IBD to clear, and requires a valid Electrum `server.version` JSON response. The gate passed before both final platform restart runs. |
| 2026-07-28 | Restart fixture contract | Verified | Funded execution proved RLN beta.3 rejects RGB UTXO creation as well as asset issuance in external-signer mode. The executable proof now matches upstream's supported safety regression: a funded external-signer device opens a `trusted_no_broadcast` BTC channel to an allowlisted password-backed host, both directions settle before a process boundary, then identities, the exact channel, and both payment directions recover in a new Flutter process. |
| 2026-07-28 | Restart oracle refinement | Verified | The oracle requires `trusted_no_broadcast` on the external-signer opener and binds the acceptor by peer identity, channel ID, capacity, and funding transaction, matching RLN beta.3's opener-only mode annotation. Both platform runs satisfied it. |
| 2026-07-28 | iOS funded process restart | Verified | Run `20260727T204201Z-81121` built and installed one dedicated iOS simulator binary with a run-unique seed, serviced its fresh funding request, prepared a trusted virtual channel, settled both payment directions, force-terminated PID `81897`, relaunched the same installed binary and unchanged data container as PID `81978`, recovered the same identities/channel ID, and settled both directions again. Evidence: `build/test-reports/platform/external-signer-restart-8B3E2FF7-3A8C-4834-94E9-CC6AD707F2E5-b310f15e0b90.json` (`workingTreeDirty: true`). |
| 2026-07-28 | Android funded process restart | Verified | Run `20260727T204304Z-82076` built and installed one APK with a run-unique seed on ARM64 Android 17/API 37, serviced its fresh funding request, prepared a trusted virtual channel, settled both payment directions, force-stopped the package, relaunched it with the same app data directory, recovered the same identities/channel ID, and settled both directions again. Evidence: `build/test-reports/platform/external-signer-restart-emulator-5554-b310f15e0b90.json` (`workingTreeDirty: true`). |

## Release Gates

| Gate | Status | Exit condition |
| --- | --- | --- |
| G-01 Baseline and artifact pin | Passed current static/artifact gate | One authoritative manifest pins RN beta.32/core beta.9/RLN 0.13 versions, immutable sources, checksums, ABI/slices, installed files, and platform requirements. Exact-clean verification remains part of PKG-018. |
| G-02 Low-level bridge parity | Passed current source/dirty-native gate | Every current RN `NativeRgb` method and parameter exists on Dart, iOS, and Android; Pigeon regeneration is idempotent; 20 Android and 18 iOS bridge tests cover the current high-risk behavior vectors. Exact-clean rerun remains under TEST-036. |
| G-03 Public wallet contract | Passed current source gate | Canonical methods, capabilities, defaults, errors, and return models match the exact beta.32/core beta.9 contract or cite an accepted constraint. |
| G-04 Durable lifecycle | Pending exact-clean restart evidence | Dart facade has a serialized lifecycle state machine, init/unlock coalescing, post-shutdown rejection, cleanup aggregation, native detach cleanup, and fault coverage. The beta.32 iOS/Android process-restart proofs remain under TEST-036. |
| G-05 Threading and responsiveness | Passed current bridge-threading gate | Blocking RLN bridge calls run on generated background Pigeon queues; cancellation/long-call policy and deeper stress remain tracked separately |
| G-06 Model integrity | Passed current source/dirty-native gate | Dart wire mappers fail closed for high-risk required fields, preserve current RN optionality for core wallet state, use a typed Pigeon JSON envelope at the platform boundary, and have numeric-boundary, documentation, and bridge-fixture coverage. |
| G-07 Security | Passed internal-beta gate with accepted constraints | Signer persistence, LSP transport policy, LSP diagnostic redaction, native bridge error taxonomy, best-effort secret lifetime minimization, official BIP340 vectors, tamper/boundary tests, standalone Dart signing fail-closed default, and dependency vulnerability/license checks are reviewed; upstream native artifact provenance is accepted under G-08/PKG-006 for internal beta only |
| G-08 Packaging and supply chain | Partially passed; exact-clean consumers pending | Package metadata, privacy manifest bundling, Android release permission, version/toolchain constraints, `.pubignore`, deterministic iOS artifact policy, iOS 18.5 minimum, podspec metadata, exact RLN 0.13 artifacts, SBOM-style inventory, license classification, live hosted Pub OSV audit, ABI-symbol markers, and manifest-backed provenance pass. Beta.32 path/Git consumer archives remain under PKG-018; PKG-006 accepts missing upstream provenance for internal beta only. |
| G-09 Test evidence | Pending exact-clean beta.32 gate | Current Dart/static and dirty-native suites pass. Clean path/Git consumers, both restart proofs, four funded/unfunded smokes, and the combined report still must run on one final clean commit with no mandatory skips. |
| G-10 Documentation | Passed current documentation gate | Release/security documentation covers beta.32/core beta.9/RLN 0.13 support, artifact acquisition and upgrade, CocoaPods validation, secure-storage boundaries, LSP/APay verification, API policy, local gates, public API symbol coverage, stale-language validation, and coverage policy. |
| G-11 Recovery | Accepted constraint | Local backup remains explicitly native-blocked; no recovery-ready/mainnet claim is allowed |
| G-12 CI scope | Accepted constraint | Native builds and regtest smokes remain local-only, with mandatory signed/local release evidence |

## Exact Native API Delta

### Low-Level Bridge Remediation

The seven originally missing low-level methods (`rlnRotateAddress`, `rlnSignMessage`,
`rlnVerifyMessage`, `rlnInflate`, `rlnListTransactionsByTxid`,
`rlnListTransfersByTxid`, and `rlnVssBackup`) now exist through Pigeon, Dart,
Swift, and Kotlin. The four changed signatures now carry `reuseAddresses`,
durable signer `storageDirPath`, Lightning `descriptionHash`, and RGB
`assignmentKind`. Generated bridge regeneration is byte-stable.

This closes structural low-level parity, not behavioral release evidence.
TEST-005 and TEST-008 retain the missing cross-platform method-family and
malformed-response coverage.

### Current Release-Candidate Gap Summary

The implementation catch-up is complete at the deterministic source and dirty
native-bridge layers. Remaining release work is deliberately narrow:

| Area | Current status | Owning rows |
| --- | --- | --- |
| Exact candidate evidence | Clean consumers, four funded/unfunded platform smokes, restart proofs, and a combined report must run after the final commit | BASE-010, PKG-018, TEST-036 |
| Mutation recovery | State-changing LSP HTTP calls are one-attempt because upstream exposes no idempotency or universal reconciliation contract | LSP-019 |
| Production supply chain | Internal-beta inventory exists, but production signatures, trusted-key verification, and reproducible-build/source attestations remain accepted only for this release line | PKG-006 |

## Master Issue Ledger

### Baseline and Parity

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| BASE-001 | P0 | Verified | This original baseline-control finding was closed on RN beta.27/core beta.7/RLN 0.10. `BASE-010` owns the current beta.32/core beta.9/RLN 0.13 baseline and prevents this historical evidence from being treated as current. | Keep baseline generation/drift checks and exact artifact verification mandatory whenever upstream changes. |
| BASE-002 | P1 | Verified | `pubspec.yaml`, `ios/rgb_sdk_flutter.podspec`, and `android/build.gradle.kts` now use package version `0.1.0`, and `tool/validate_release_package.dart` gates all three. | Keep platform metadata tied to the package version policy until a generated single-source version file is introduced. |
| BASE-003 | P1 | Verified | `.fvmrc` now pins Flutter `3.41.9`, CI uses `flutter-version-file: .fvmrc` instead of floating `stable`, and release package validation gates both. | Test the oldest supported toolchain when the official release support window is selected. |
| BASE-004 | P1 | Verified | Baseline metadata moved out of the alias-only parity manifest into `tool/release_baseline.json`, which pins exact RN/core/RLN source and artifact identities without a personal checkout path. | Keep the exact-commit validator and generated baseline as the only current-version authority. |
| BASE-005 | P1 | Verified | The local live-upstream parity gate was established against RN beta.27. Its mechanism now passes against beta.32 commit `821ae4fd10ca`; `BASE-010` owns current-candidate closure, while CI/native-smoke execution remains intentionally local-only under TEST-017. | Keep `RGB_SDK_RN_PATH=<exact-dev> dart run tool/validate_rn_parity.dart` mandatory for release evidence. |
| BASE-006 | P2 | Verified | `doc/API_COMPATIBILITY_AND_DIVERGENCE.md` now defines native/core/RN/Flutter precedence and records approved divergences with owner, tracker row, evidence, and reversal trigger, including `createBackup`. `dart run tool/validate_release_governance.dart` gates the document. | Keep new divergences recorded before implementation and tied to a tracker row plus evidence. |
| BASE-007 | P1 | Verified | The baseline generator emitted Dart that `dart format` changed, so CI's format step made the subsequent generated-drift check fail even when both started from generated output. | Generated Dart is now formatter-canonical; generate, `dart format --set-exit-if-changed`, and `--check` pass consecutively in CI order. |
| BASE-008 | P1 | Verified | This beta.27 refresh proved the baseline-update mechanism across generated constants, installed artifacts, static parity, and clean platform evidence. It is historical regression evidence; `BASE-010`, `PKG-018`, and `TEST-036` own the current beta.32 candidate. | Keep baseline pins and exact evidence refreshed whenever RN/core/RLN changes. |
| BASE-009 | P1 | Verified | This row reconciled all public documents and generated consumers to beta.27 at that point in history. The current beta.32 documentation/source reconciliation is verified under `DOC-010`, while exact clean runtime evidence remains open under `BASE-010`. | Keep this historical row immutable and reopen the newest baseline row whenever RN/core/RLN moves. |
| BASE-010 | P0 | In progress | Flutter now pins RN `821ae4fd10ca3933445ab926cb0af0230b108913`/beta.32, core beta.9, and RLN `af03c7f1a65135a429f05a5820600338215954dc`/0.13.0-beta.3 across the baseline manifest and generated consumers. Live RN drift validation, exact core-tarball provenance, static parity, 20 Android bridge tests, and 18 iOS bridge tests pass on the dirty candidate. | Close only after PKG-018 and TEST-036 prove the same baseline through clean consumers, funded/unfunded platform smokes, restart evidence, and an exact clean committed release report. |

### Public and Native API

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| API-001 | P1 | Verified | Low-level beta.26 catch-up methods now have declared critical bridge vectors in `tool/test_matrix/bridge_behavior_vectors.json`; Dart delegation covers all 62 `RlnClient` calls, malformed wire decoding is covered, and Android/iOS native bridge suites cover unknown-node and request-boundary behavior for rotate/sign/verify, txid histories, invoice, RGB invoice, and inflate families. | Keep exact funded runtime behavior proof under API-032/TEST-002; any new low-level method must add a bridge-vector row before release. |
| API-002 | P1 | Verified | `reuseAddresses`, signer storage path, `descriptionHash`, and `assignmentKind` are covered by Dart request delegation and mirrored Android/iOS invalid-request vectors; unknown `assignmentKind` fails before native node lookup on both platforms, and `lnInvoice` now validates request fields before node lookup. | Keep platform smokes tied to the exact release candidate; new request fields must be added to bridge vectors and native tests. |
| API-003 | P1 | Verified | Rotate, inflate, node-key sign, and node-key verify now have Dart delegation, facade return-shape tests, malformed-wire tests where applicable, Android/iOS unknown-node vectors, and native numeric-boundary coverage for inflate. | Keep deeper funded semantic proofs under TEST-002; do not treat these bridge vectors as independent funds-flow evidence. |
| API-004 | P1 | Verified | Txid-filtered transaction and transfer APIs have Dart request-shape coverage including `skipSync`, malformed list-response rejection, facade return-shape tests, and mirrored Android/iOS unknown-node operation-detail tests. | Keep exact-candidate funded/regtest history proof under TEST-002 before release. |
| API-005 | P1 | Verified | `backupNow`, `getLightningReceiveStatus`, and `getLightningSendStatus` now exist on the public wallet facade and the live RN validator passes. | Keep canonical Lightning status APIs primary; old RGB-folding helpers were removed under API-016. |
| API-006 | P1 | Accepted constraint | The current pinned RLN artifact still has no RGB `skipSync` request field; RN accepts and silently discards the value. | Keep Flutter fail-fast and its tests until upstream adds real support; never claim parity by ignoring the option. |
| API-007 | P1 | Verified | Canonical Bitcoin/RGB wallet methods return stable domain/core DTOs (`CoreBtcBalance`, `CoreUnspent`, `CoreListAssets`, `CoreAssetBalance`, `CoreInvoiceReceiveData`, `CoreInvoiceData`, `CoreTransaction`, `CoreTransfer`) while native `Rln*` DTOs are isolated behind explicit advanced `Raw` methods. Duplicate `*Core` aliases were removed from the prerelease facade. | Keep one canonical stable spelling per operation; do not add wallet methods that return `Rln*` DTOs. |
| API-008 | P1 | Verified | `onchainReceive` preserves invoice, recipient ID, expiration timestamp, and batch transfer index in `OnchainReceiveResponse`; wallet contract vectors assert every field and exact funded platform smokes exercise the native receive path. | Keep response-field assertions in the wallet contract and exact-candidate platform smokes. |
| API-009 | P1 | Verified | Canonical `estimateFeeRate` returns `FeeEstimationResponse`, matching the core contract. Native `RlnFeeRate` is available only through advanced `estimateFeeRateRaw`; obsolete scalar aliases were removed. | Keep the stable typed response and advanced raw escape hatch distinct in API snapshots and docs. |
| API-010 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-36): Stable network fields are not normalized like RN/core. Earlier evidence: Node, network, peer, channel, Lightning payment, keysend, invoice-status, and decode methods map native `Rln*` DTOs into stable wallet/domain DTOs (`WalletNodeInfo`, `WalletNetworkInfo`, `LightningPeer`, `LightningChannel`, `LightningPayment`, `SendPaymentResult`, canonical status strings, and `DecodedLightningInvoice`). | 2026-09-20 corrective verification (working tree, not release qualification): Stable network aliases and height/blockHeight contract normalize against core; exact model and wallet tests pass. |
| API-011 | P1 | Verified | Public canonical Lightning status methods now return normalized RLN Lightning vocabularies (`Pending`, `Claimable`, `Succeeded`, etc.); compatibility RGB-transfer folding helpers are removed from the wallet facade. | Keep LSP settlement polling on canonical Lightning status APIs. |
| API-012 | P1 | Verified | `createLightningInvoice`/`rlnLnInvoice` supports `descriptionHash` and CLTV fields through Dart/Pigeon/Swift/Kotlin, now validates request fields before node lookup on both platforms, and is included in the critical bridge-vector manifest. HODL facade metadata remains covered by wallet tests. | Keep service-level LNURL/HODL settlement behavior under TEST-006; bridge request/shape parity for this method is verified. |
| API-013 | P1 | Verified | `openChannel` defaults `withAnchors` to true; facade delegation tests and mirrored native request-boundary vectors assert the request contract. | Keep `withAnchors` in the bridge-vector manifest and both native bridge suites. |
| API-014 | P2 | Verified | `UtexoWallet.onchainSend` now requires `RgbSendRequest.amount` explicitly and no longer falls back to the decoded RGB invoice assignment, matching current RN `UTEXOWallet.onchainSend`. | Covered by `test/utexo_wallet_test.dart::requires explicit onchainSend amount instead of decoded fallback` and documented in `RgbSendRequest` plus the divergence map. |
| API-015 | P1 | Verified | Always-present wallet facade stubs for PSBT/begin-end/bridge-only/service-only methods were removed; callers now see absent `psbt`/`beginEnd` carriers and false capability flags instead of callable `Object`-typed throwers. | Keep `createBackup` as the explicit accepted native-blocked exception under API-019. |
| API-016 | P2 | Verified | Removed stale wallet facade methods `getXpub`, generic `send`, `getLightningReceiveRequest`, and `getLightningSendRequest`; integration tests now call `onchainSend`. | `onchainSend`, `getLightningReceiveStatus`, and `getLightningSendStatus` are the stable spellings. Deleted names are also removed from the wallet method matrix. |
| API-017 | P2 | Verified | RN beta.40 adds high-level CFA/UDA issuance. Flutter exposes typed CFA/UDA methods for both engines with bounded local media handling on RLN and retains the existing raw digest methods. | Keep funded issuance and media evidence scoped to the exact qualified native artifact. |
| API-018 | P2 | Verified | Added explicit wallet node-key aliases `signNodeMessage` and `verifyNodeMessage`; documented that top-level `signMessage`/`verifyMessage` are account-key helpers while wallet `signMessage`/`verifyMessage` remain RN node-key aliases. | Keep both key identities covered separately by wallet node-key tests and RN-core Schnorr/account-xpub tests. |
| API-019 | P1 | Accepted constraint | `createBackup` is now explicitly native-blocked and tested to throw without invoking native backup; recovery/mainnet readiness remains forbidden until upstream supplies a real implementation. | Preserve this boundary until native recovery is implemented and independently proven. |
| API-020 | P2 | Verified | `doc/API_COMPATIBILITY_AND_DIVERGENCE.md` now defines stable facade, advanced parity, compatibility shim, unsupported/native-blocked, and internal tiers; it also defines deprecation and breaking-change rules. `tool/api_snapshot.json` plus `dart run tool/validate_api_snapshot.dart` gate the current exported Dart, Pigeon, generated bridge, and native bridge surface. | Update the snapshot and migration note in the same change as any intentional public API or bridge-surface change. |
| API-021 | P1 | Verified | Exported core defaults now match beta.6 for API timeout (`120000`) and default log level (`3`, ERROR); the utility/defaults test asserts both values. | Replace raw integer log-level export with a richer typed compatibility layer under API-029 if the public API policy requires it. |
| API-022 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-34): Three default indexers differ from the latest core contract. Earlier evidence: Default transport/indexer endpoints now match current core beta.6, including local regtest Esplora `http://127.0.0.1:3002`; unlock resolution trims blank caller fields before applying defaults. | 2026-09-20 corrective verification (working tree, not release qualification): The three differing network defaults now match the pinned core beta.9 source. Wallet tests and fresh RN source drift validation pass. |
| API-023 | P1 | Verified | SDK network validation now uses exact core network names, rejects native-only `signet_custom`, preserves numeric aliases for `0`/`1`/`2`/`3`, and maps native `utexo` to RLN `signet` only at the native-boundary helper. | Keep any future native-only networks out of SDK-facing validation unless product explicitly supports them. |
| API-024 | P1 | Verified | The root package no longer exports obsolete RN-removed `RNSigner`, flat PSBT helpers, UTEXO bridge/network maps, `getBridgeAPI`, `TransferStatuses`, or bridge helper functions. | The API docs validator and API snapshot now understand `export ... hide`; direct `src/` imports remain unsupported implementation access. |
| API-025 | P1 | Verified | Legacy `FetchClient`/bridge helpers now expose timeout and close ownership, require string fields instead of stringifying missing data as `"null"`, and only treat HTTP 404 transfer lookup as not-found. | Quarantine or deprecate the whole obsolete bridge surface under API-024/CODE-001. |
| API-026 | P2 | Verified | Reopened by 2026-09-20 audit (AUD-18): RN-compatible error names have incompatible base type/status defaults. Earlier evidence: SDK/core-compatible errors now expose stable `code`, optional `statusCode`, preserved `cause`, and `toJson()` serialization; validation/native-protocol/unsupported errors include their semantic fields. | 2026-09-20 corrective verification (working tree, not release qualification): Core-compatible errors inherit SDKError and preserve optional statusCode defaults; stable API and wallet contract tests pass. |
| API-027 | P2 | Verified | Runtime export inventory is refreshed against the current RN baseline; UMA helpers/constants are mapped and `validate_rn_parity` passes the runtime export gate. | Keep export validation tied to the exact RN source baseline. |
| API-028 | P1 | Verified | `UtexoWallet.listTransfers()` now calls native unfiltered listing when available and fails closed with `UnsupportedWalletFeatureException` when the pinned artifact rejects it, rather than falling back to known asset IDs and silently omitting no-asset transfers. Asset-filtered listing remains available through `listTransfers(assetId: ...)`. | Covered by `test/utexo_wallet_test.dart::listTransfers fails closed when unfiltered native listing is rejected`; remove the fail-closed divergence only after native unfiltered listing is fixed and platform fixtures prove no-asset transfers are included. |
| API-029 | P2 | Verified | `doc/API_COMPATIBILITY_AND_DIVERGENCE.md` now records the approved Dart adaptation map for lifecycle credentials, network/default resolution, `sendRgb(skipSync)`, Lightning aliases, on-chain request DTOs, and raw bridge DTOs, with linked tracker rows and executable evidence references. | Keep field-level implementation and native behavior gaps tracked under the owning API/model/test rows; new Dart-shaped signatures must extend the adaptation map before shipping. |
| API-030 | P1 | In progress | Reopened by 2026-09-20 audit (AUD-21): Password RGS configuration is incorrectly blocked. Earlier evidence: `resolveUnlockConfig` now rejects non-empty `gossipRgsServerUrl` with `UnsupportedWalletFeatureException` before either password or native-external signer unlock can reach the native no-op field. | Complete the corrective contracts and verification in the September remediation register below. Earlier passing tests do not close these reproduced/source-confirmed gaps. |
| API-031 | P1 | Verified | `UtexoWallet` now exposes typed `PsbtWalletCarrier?` and `BeginEndWalletCarrier?` slots, and capability flags are derived from carrier presence so declarations cannot drift from behavior. | Keep future optional feature groups carrier-backed rather than adding standalone booleans. |
| API-032 | P1 | Verified | External-signer wallets expose false RGB UTXO/issuance capabilities, fail fast before native calls, and the approved trusted virtual BTC-channel external-signer regression now passes on the exact clean beta.27/core beta.7 candidate. | Current iOS and Android external-signer restart reports record the exact committed source, `releaseEligible: true`, and successful prepare/verify phases across a real process boundary. |
| API-033 | P1 | Verified | `UtexoWallet.createLsp()` now matches RN beta.27 discovery semantics: no-arg creation fetches `GET /get_info`, enables virtual channels for `info.pubkey`, uses `info.host ?? Uri.parse(baseUrl).host`, and uses `info.port ?? peerPort`. | Covered by `test/utexo_wallet_test.dart::createLsp discovers peer host and port from beta.7 get_info`, including host-only, port-only, both-present, and both-absent responses. |
| API-034 | P2 | Verified | RN beta.27 root exports were audited against `src/index.ts`: RN exposes `toUnitsNumber` and `fromUnitsNumber`, while the published core beta.7 package also contains non-root BigInt helpers. Flutter keeps the stable root at RN package parity, makes exported `toUnitsNumber` fail above JavaScript `Number.MAX_SAFE_INTEGER`, and records the BigInt helpers as core-only/not root-exported for this baseline. | Covered by `test/utexo_wallet_test.dart::matches RN-core seed derivation and utility behavior`, `tool/rn_parity_manifest.json`, `tool/test_matrix/core_exports.json`, and `doc/API_COMPATIBILITY_AND_DIVERGENCE.md`. |
| API-035 | P2 | Verified | Stable public network helpers no longer use substring heuristics. `toNetworkName()` now accepts only exact `NETWORK_MAP` keys and throws for malformed values, so strings such as `not-testnet` or `signet_custom` cannot silently select a real network. | Covered by `test/utexo_wallet_test.dart::matches RN-core seed derivation and utility behavior`; the safety tightening is documented in `doc/API_COMPATIBILITY_AND_DIVERGENCE.md`. |
| API-036 | P1 | Verified | The stable root no longer leaks raw/Pigeon types through signer hosts, LSP DTO factories, artifact DTO factories, wallet return models, or hidden generic parameters. `UtexoWalletRawApi`, raw models, `RlnClient`, and injectable bridge ownership are advanced-only. | `test/stable_api_contract_test.dart`, public-doc validation, API snapshots, and hardening scans gate the stable/advanced boundary. |
| API-037 | P1 | Verified | Lightning facade models and return shapes now match RN beta.27/core beta.7: `listPayments` returns canonical `LightningPayment`, `listLightningPayments` returns `LightningSendRequest` records, `keysend` returns `SendPaymentResult`, and invoice status methods return canonical status strings. | Keep the complete RN wallet return-shape map and exhaustive status/type vectors mandatory on baseline changes. |
| API-038 | P1 | Verified | Stable wallet input semantics now match RN/core rather than the native bridge: canonical read/list/refresh methods no longer expose low-level sync/filter options; Lightning methods no longer accept duplicate msat/field aliases; channel opening uses `peerPubkey`, `isPublic`, and `assetLocalAmount`; and `onchainReceive` preserves the `witness` option. Lower-level controls remain advanced-only. | RN parity validation pins these high-risk Dart parameter contracts, the API snapshot pins the full facade, and wallet/integration vectors use the canonical shapes. |
| API-039 | P1 | Verified | `rlnRefreshTransfers(skipSync)` now returns a typed Pigeon response and strict immutable raw/domain result, while `refreshWallet()` retains its void compatibility contract and `refreshTransfers(skipSync)` exposes beta.32 detail. Malformed keys, duplicate rows, failures, statuses, and `skipSync` delegation are covered. | Keep the refresh result in the wallet and bridge matrices; do not collapse per-transfer failures into a single boolean. |
| API-040 | P1 | Verified | Swift and Kotlin now adapt RLN 0.13's merged transaction/transfer filters while preserving RN's public method spellings. Unfiltered `listTransfers()` is real, txid filters remain exact, and no-asset transfers are no longer hidden behind the removed 0.10 fallback. | Keep native fixtures for unfiltered, asset-filtered, and txid-filtered calls when RLN changes its history ABI. |
| API-041 | P1 | Verified | The stable Flutter surface now exposes field-equivalent beta.9 LSP/APay discovery, selection, quote, relay, response, and error contracts plus all 18 core `UtexoLsp` methods. The API snapshot, public docs, parity inventories, and 37-test beta.9 contract suite cover the surface and behavior. | Any core/RN LSP addition must fail the exact method/type inventories until its Dart shape, behavior, docs, and evidence are added. |
| API-042 | P2 | Verified | The RLN 0.13 methods and fields not exposed by RN beta.32 are explicitly scoped out: linked-asset/swap/media/onion operations, external-signer-only native helpers, and `SdkIssueAssetIfaRequest.issuanceType`. The live parity validator compares the pinned Swift protocol to RN call sites and fails on an unreviewed exclusion. | Keep these capabilities out of the stable Flutter API until RN exposes them or an independently approved Flutter extension is specified. |
| API-043 | P1 | Verified | `UtexoLspClient` is stable-root exported and documented with explicit SDK-owned versus injected-client disposal semantics. Runtime export parity and the AST API snapshot fail if the concrete RN-equivalent client disappears from the stable entry point. | Keep raw transport helpers private/advanced while preserving the concrete client contract. |
| API-044 | P1 | Verified | Earlier parity checks covered wallet/native names but not exact LSP signatures. `core_lsp_parity_manifest.json` now inventories 18 core orchestration methods, two Flutter lifecycle adaptations, nine core client methods, five transport adaptations, eleven `ILspWallet` methods, the `network` getter, all signatures, runtime errors, and RN-exported LSP types. | `validate_rn_parity.dart` must continue parsing Dart AST declarations and live RN exports rather than trusting name-only documentation. |

### Models, Serialization, and Numeric Correctness

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| MODEL-001 | P1 | Verified | Generated Pigeon response methods now return a typed `RlnWireResponse` JSON envelope, issue methods no longer expose broad response maps, Dart decoding rejects malformed JSON and non-object roots with `NativeProtocolException`, and RN parity validation forbids broad response maps at the Pigeon boundary while preserving public semantic return categories. | Per-response generated DTO classes are intentionally not claimed; keep strict domain decoders and platform fixtures under MODEL-015/TEST-005/TEST-008. |
| MODEL-002 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-20): Malformed numeric wire amounts can silently saturate. Earlier evidence: `rln_models.dart` now throws `NativeProtocolException` for missing/malformed required strings, integers, finite numbers, booleans, maps, and lists instead of returning empty strings, zeroes, false, or empty maps. | 2026-09-20 corrective verification (working tree, not release qualification): Signed integer decoding rejects saturation, non-decimal encodings and unsafe large doubles; malformed/native-boundary tests pass. |
| MODEL-003 | P1 | Verified | Assignment kind, rotate/sign/verify/inflate response models, and `RlnUnspent.pendingBlinded` are represented and covered by facade/model tests, mirrored bridge vectors, and the applicable exact platform smokes. | Keep each new native response field represented in a strict decoder plus an executable evidence bucket. |
| MODEL-004 | P1 | Verified | `RlnNodeInfo` now preserves current RN optionality for removed/optional metrics and no longer fabricates optional node metrics as zero. | Move xpub compatibility fields behind a migration boundary under API-016/CODE-001. |
| MODEL-005 | P1 | Verified | `RlnMedia` now requires `filePath`, `digest`, and `mime`; `RlnAssetBalance` keeps off-chain amounts optional-at-wire with explicit `0` domain defaults matching RN/core mapping. | Add fixture vectors for both camelCase and native platform spellings if upstream introduces them. |
| MODEL-006 | P1 | Verified | Every current transaction case (`RGB_SEND`, `DRAIN`, `CREATE_UTXOS`, `SEND_BTC`, `INCOMING`) has a table-driven domain-mapper vector, and unknown transaction types throw `NativeProtocolException` instead of collapsing to `User`. | Keep the exhaustive mapper table synchronized with `UtexoDomainPolicy.transactionTypes`. |
| MODEL-007 | P1 | Verified | Transfer optionality is preserved for created/updated times and transport endpoints; every current status and kind has a Cartesian mapper vector, and unknown values fail closed. | Keep the exhaustive transfer vectors synchronized with the core status/kind declarations. |
| MODEL-008 | P1 | Verified | `RlnUnspent.pendingBlinded` is decoded and preserved through `RlnUnspent.toCore()`. | Keep this in platform smoke assertions once RGB receive flows are covered. |
| MODEL-009 | P1 | Verified | Lightning payment type/status mapping returns canonical PascalCase values, derives inbound direction correctly, handles all published payment/invoice statuses, and now canonicalizes all-caps no-underscore native enums instead of misclassifying `OUTBOUND`. | Table-driven vectors cover every current status/type; unknown public statuses remain nullable only where the core contract permits them. |
| MODEL-010 | P1 | Verified | `LightningChannel` models the RN/core contract; mapping translates `public` to `isPublic`, normalizes every current channel status, preserves optional fields, and converts `localBalanceSat` to `localBalanceMsat`. `UtexoWallet.listChannels()` and exhaustive mapper vectors cover the boundary. | Keep channel status vocabulary centralized in `UtexoDomainPolicy` and fail closed on unknown native states. |
| MODEL-011 | P1 | Verified | `RlnInvoice.recipientId` and `CoreInvoiceReceiveData.recipientId` now preserve upstream optionality instead of becoming an empty required string. | Validate recipient ID only in workflows that require it. |
| MODEL-012 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-22): Stable transfer model drops `requestedAssignment`. Earlier evidence: Core transfer mapping does not invent `batchTransferIdx`, status, or kind values; optional values remain nullable, all current status/kind combinations are covered, and unknown state throws. | 2026-09-20 corrective verification (working tree, not release qualification): Stable transfers retain requestedAssignment separately from actual assignments; exact model tests pass. |
| MODEL-013 | P1 | Verified | Outpoint parsing requires `<txid>:<vout>` with a non-negative integer vout, and assignment parsing accepts only supported shapes plus the RN/core numeric fungible shorthand. Boundary, malformed, and large-integer parser vectors pass under TEST-009. | Extend the parser corpus whenever a new wire grammar is introduced. |
| MODEL-014 | P1 | In progress | Reopened by 2026-09-20 audit (AUD-19): Fee-rate boundary can trap on iOS or clamp on Android. Earlier evidence: Facade fee-rate defaults are integer-equivalent (`1`); Dart, Swift, and Kotlin reject fractional rates before native execution rather than reproducing RN's truncation. Dart, Android JVM, and iOS XCTest vectors cover `1.5`. | Complete the corrective contracts and verification in the September remediation register below. Earlier passing tests do not close these reproduced/source-confirmed gaps. |
| MODEL-015 | P2 | Verified | Reopened by 2026-09-20 audit (AUD-35): Some valid native UInt64 asset values are unreadable. Earlier evidence: `doc/BRIDGE_BEHAVIOR_CONTRACT.md`, `bridge_behavior_vectors.json`, and `rln_models.dart` now define the Pigeon numeric contract: request integers are bounded to signed `Int64` over Pigeon, narrower unsigned fields are rejected natively before mutation, native unsigned outputs may arrive as decimal strings, signed domain fields parse decimal strings through signed `Int64.max`, and out-of-range values throw `NativeProtocolException` rather than fabricating `0`/`null`. | 2026-09-20 corrective verification (working tree, not release qualification): RGB balances, supplies, assignments and asset-valued Lightning fields preserve full UInt64 through BigInt. All asset-family UInt64 boundary tests pass; breaking adaptation is documented. |
| MODEL-016 | P2 | Verified | Public request/model fields now document sats, msats, asset-smallest-unit amounts, duration seconds, and Unix-second timestamps at the field boundary in `utexo_wallet_types.dart`, `rln_models.dart`, and `utexo_core_models.dart`; the public reference keeps the package-wide units table. | Covered by `test/utexo_wallet_test.dart::documents and preserves timestamp and amount units at model boundaries`; add new field-level unit docs with any future numeric public DTO. |
| MODEL-017 | P1 | Verified | Exact clean iOS funded regtest candidate run `20260805T160450Z-5b2a55f` reached the funded RGB send flow and then failed in `RlnNodeInfo.fromMap` because native returned `channelAssetMaxAmount` as an unsigned UInt64 decimal above signed `Int64.max`; the old Dart model rejected it as a malformed signed integer. | `RlnNodeInfo.channelAssetMaxAmount` is now an exact `BigInt?`, `BRIDGE_BEHAVIOR_CONTRACT.md`, `PUBLIC_API_REFERENCE.md`, and `bridge_behavior_vectors.json` document the field-level unsigned-output policy, and `test/utexo_wallet_test.dart::parses and bounds native integer strings at model boundaries` proves `18446744073709551615` survives exactly while `18446744073709551616` is rejected. |
| MODEL-018 | P1 | Verified | `LspGetInfoResponse` now models the core beta.7 discovery document with `apiVersion`, `pubkey`, `network`, optional `host`/`port`, `supportedAssets`, exact `BigInt` u64 payment/channel/asset limits, optional `virtualChannelMode`, and Lightning-address sendable bounds. The stale beta.6 alias/channel-count fields are gone. | Covered by `test/utexo_wallet_test.dart::LSP get_info parser matches beta.7 shape and preserves u64`, including max-u64 preservation, and by the public API docs validator for `LspSupportedAsset`. |
| MODEL-019 | P1 | Verified | LSP/APay DTO decoders now fail closed for missing required strings, malformed integers/u64 values, non-list list fields, non-map list entries, and malformed optional proof maps instead of fabricating empty strings, zeroes, or dropping bad entries. Optional fields remain optional. | Covered by `test/utexo_wallet_test.dart::LSP DTO parsers fail closed for malformed required fields` and the existing wallet/LSP regression suite. |
| MODEL-020 | P1 | Verified | Stable DTOs no longer depend on raw `RlnMap`, generated Pigeon classes, or raw model factories. Internal decoders own native adaptation, and core nested DTOs (`CoreBlockTime`, media, token attachments, transfer endpoints) are stable-domain types. | Public API validation and `test/stable_api_contract_test.dart` prevent hidden raw/native type leakage from returning. |
| MODEL-021 | P1 | Verified | `WaitingBroadcast`, `WAITING_BROADCAST`, and `waitingBroadcast` normalize through the single transfer-status policy; every history and refresh mapper accepts the current vocabulary and rejects unknown states. | Keep status normalization exhaustive and centralized. |
| MODEL-022 | P1 | Verified | Required RLN 0.13 `Utxo.exists` is bridged on both platforms, strictly decoded, and preserved as true or false without a fabricated default. Missing or malformed values fail closed. | Keep platform fixtures and stable model tests for both existence states. |
| MODEL-023 | P1 | Verified | Optional BOLT11 `description` and `descriptionHash` now survive Swift/Kotlin serialization, raw decoding, and stable `DecodedLightningInvoice` mapping with absent/null/present vectors. | Preserve their optionality and units whenever the native decode contract changes. |
| MODEL-024 | P1 | Verified | Required decoded-RGB and optional transfer `proxyRecipientId` fields are serialized and strictly decoded on both platforms, while remaining advanced-only where core beta.9 has no stable field. | Keep the raw/stable boundary aligned with RN rather than leaking upstream-only fields. |
| MODEL-025 | P1 | Verified | IFA issuance-link outpoints and linked-from/linked-to asset IDs are represented by immutable raw DTOs and serialized by Swift/Kotlin with strict nullability and bounds. | Keep these raw fields out of core-facing models until the shared contract exposes them. |
| MODEL-026 | P1 | Verified | Refresh maps now preserve signed batch-transfer IDs and independently optional status/failure outcomes in immutable raw and stable DTOs. Required failure strings, duplicate keys, and malformed rows fail closed. | Keep unchanged records and partial failure detail observable to callers. |
| MODEL-027 | P2 | Verified | Refresh result keys accept the complete signed Int32 domain, including negative values, while rejecting overflow and duplicate Pigeon rows. | Preserve native signedness exactly even when production IDs are normally positive. |
| MODEL-028 | P2 | Verified | Reopened by 2026-09-20 audit (AUD-11): LNURL error envelopes become misleading protocol exceptions. Earlier evidence: Optional LNURL callback status/reason fields require strings, advertised precision is bounded to UInt8, and malformed response vectors fail closed rather than stringifying arbitrary objects. | 2026-09-20 corrective verification (working tree, not release qualification): LNURL ERROR envelopes become LnurlCallbackException instead of misleading missing-invoice errors; deterministic HTTP contract tests pass. |
| MODEL-029 | P1 | Verified | Native APay registration responses and HTTP proof objects were decoded as loosely typed integers and strings, so a wrong host, unsupported protocol/status, negative or inconsistent indices, non-contiguous batches, malformed payment hashes, oversized proof batches, or BIP32 derivation overflow could enter the stable model. The decoders now bind native responses to the requested host and enforce RLN APay v1's `active` status, index 1 origin, `0x7fffffff` derivation ceiling, 200-entry batch ceiling, exact range/accepted/next relationships, contiguous indices, and 32-byte payment hashes. | `test/utexo_wallet_test.dart::rejects malformed native APay batches before exposing them` and `test/lsp_beta9_contract_test.dart::rejects structurally invalid APay proof fields` must grow with any APay wire change; update `ApayProtocolPolicy` only from reviewed upstream protocol source. |
| MODEL-030 | P2 | Verified | Relay DTO required strings accepted whitespace-only values, allowing malformed invoices/hashes/status values to survive the wire boundary until later orchestration. Required relay strings now reject blank-after-trim input with `NativeProtocolException`; the malformed relay response vector covers the regression. | Apply blank-after-trim validation to every new required LSP wire string while preserving the original nonblank payload value. |
| MODEL-031 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-39): Sats-to-msats multiplication can overflow before validation. Earlier evidence: Stable wallet amount/count validation checked sign but did not cap generic Dart integers at Pigeon's signed 64-bit wire limit. Values above `9223372036854775807` could reach `StandardMessageCodec` and fail outside the SDK error taxonomy. `WalletInputPolicy` now owns the signed-Int64 ceiling for every generic positive/nonnegative stable-facade input; narrower UInt policies still apply where native fields require them. | 2026-09-20 corrective verification (working tree, not release qualification): Sats-to-msats overflow is rejected before multiplication or dispatch. Boundary tests pass. |

### Lifecycle, Threading, and Architecture

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| LIFE-001 | P1 | Verified | Every Pigeon HostApi method is annotated with `TaskQueueType.serialBackgroundThread`; regenerated Kotlin uses `binaryMessenger.makeBackgroundTaskQueue()`, regenerated Swift uses `makeBackgroundTaskQueue`, and Android/iOS native bridge suites pass with the regenerated source. | Keep Pigeon drift checks mandatory; typed DTO replacement remains separate under MODEL-001. |
| LIFE-002 | P1 | Verified | Native readiness checks no longer call `Thread.sleep` or `usleep`; Android and iOS now use a single non-blocking `nodeInfo` readiness check under the background Pigeon queue, and source scan plus native bridge suites confirm the change. | Timeout/cancellation semantics for long RLN calls are documented and covered under LIFE-011. |
| LIFE-003 | P1 | Verified | `UtexoWallet` now serializes lifecycle mutations and coalesces concurrent `init()`/`unlock()` calls; tests prove duplicate calls create/init/unlock only once and failed signer init remains retryable. | Native lifecycle/fault coverage is tracked under TEST-007; add new stress cases when new lifecycle paths are introduced. |
| LIFE-004 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-03): Stable signer lifecycle bypasses configured operation deadlines. Earlier evidence: `UtexoWallet` now owns an `RLNBinding` and routes wallet-facing native node operations through binding methods, while signer strategies share the same underlying `RlnClient` only for private signer-handle implementation. | 2026-09-20 corrective verification (working tree, not release qualification): Signer initialization, unlock and disposal now execute under the binding queue/deadline. Corrective safety tests cover timeout and cleanup ordering. |
| LIFE-005 | P1 | Verified | Wallet-facing chain, RGB, Lightning, channel, lookup, and sync calls require an unlocked node; node info requires initialization; `vssClearFence` requires initialization but remains callable before unlock. Disposed/shutdown states fail before native calls. | Lifecycle prerequisite tests cover each category and must be extended with every new facade operation. |
| LIFE-006 | P1 | Verified | `shutdown()` now enters an explicit `shutDown` state; `isInitialized`/`isUnlocked` become false, regular operations and `nodeId` fail until `reinit()`, and tests prove restart after shutdown works. | Native hot-restart/detach and same-path replacement coverage are tracked under LIFE-009/LIFE-010. |
| LIFE-007 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-02): Failed reinit can orphan a native signer after successful destroy. Earlier evidence: `reinit()` now stops before create when shutdown fails, leaves the wallet in a retryable shutdown state when create fails, and destroys both replacement and retired shutdown handles if unlock fails after recreate. `RLNBinding.rlnCreateNode` can intentionally replace a shutdown node and rolls back its owned node/retired-handle state on create failure. | 2026-09-20 corrective verification (working tree, not release qualification): Reinit preconditions are resolved before shutdown; orphaned signer ownership survives recreate/cleanup failures. Corrective safety and wallet fault tests pass. |
| LIFE-008 | P1 | Verified | Final native store/handle cleanup is now proven at the native store boundary: Android removes node/signer metadata before close and tests injected close failures for `remove`, `removeSigner`, and `clearAll`; iOS exposes deterministic store snapshots and tests final node/signer absence after remove/clearAll. Dart destroy remains idempotent and now cleans a binding-owned node even when create timed out before returning a facade node id. | Covered by Android JVM `nodeStoreRemovesHandlesEvenWhenNativeCloseFails`, iOS XCTest `testNodeStoreLifecycleAndFinalCleanupState` and `testNodeStoreClearAllRemovesNodesAndSigners`, plus `test/utexo_wallet_test.dart::timed-out create can still be destroyed after native completion`. iOS UniFFI node shutdown itself is non-throwing, so iOS fault injection is represented by deterministic final-state store assertions rather than a throwing shutdown double. |
| LIFE-009 | P1 | In progress | Reopened by 2026-09-20 audit (AUD-04, AUD-05): iOS engine-detach cleanup is not registered for notification; Android detach is neither an in-flight barrier nor engine-scoped. Earlier evidence: Android and iOS detach now unregister generated Pigeon APIs and clear engine-owned native node/signer stores; same-storage restart after shutdown uses deterministic created-state replacement, and Android/iOS native bridge suites plus store-level tests pass on the current candidate. | Complete the corrective contracts and verification in the September remediation register below. Earlier passing tests do not close these reproduced/source-confirmed gaps. |
| LIFE-010 | P1 | In progress | Reopened by 2026-09-20 audit (AUD-06): Reused handle IDs let an old wallet destroy a replacement. Earlier evidence: iOS same-path replacement now removes the old shutdown node before installing the replacement node, returns the same handle in `created` state, and both Android and iOS reject `markInitialized` after unlocked/shutdown state drift. | Complete the corrective contracts and verification in the September remediation register below. Earlier passing tests do not close these reproduced/source-confirmed gaps. |
| LIFE-011 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-01): Invalid send deadline still dispatches the send. Earlier evidence: `RLNBinding` now has explicit `RlnOperationTimeoutPolicy` categories for lifecycle, unlock, network, channel/payment, send/asset/UTXO, and sync/refresh operations. Defaults match core `DEFAULT_API_TIMEOUT`; `RlnOperationTimeoutException` documents the elapsed operation/deadline. Since Pigeon cannot cancel an in-flight native RLN call, timeout marks the binding unknown for regular operations, keeps the queue waiting for native completion, and leaves destroy as the ordered cleanup gate. | 2026-09-20 corrective verification (working tree, not release qualification): Deadline validation precedes queueing; expired queued work never dispatches; timeout quarantine retains native queue ownership. Corrective safety and wallet suites pass. |
| LIFE-012 | P2 | Verified | Wallet public contract types/status helpers live in `utexo_wallet_types.dart`, `UtexoWallet` owns lifecycle/orchestration, raw operations live in an advanced-only extension, and native plugin files stay below the documented 1500-line guardrail. | Keep DTOs, raw adaptation, orchestration, and native ownership in their current focused modules. |
| LIFE-013 | P2 | Verified | The misleading template platform-interface/method-channel abstraction was removed along with the `plugin_platform_interface` dependency. Native runtime work now has one owner: generated Pigeon `RlnHostApi` wrapped by `RlnClient` and serialized/quarantined by `RLNBinding`; `RgbSdkFlutter.nativeArtifactInfo()` is explicitly an internal diagnostics read through the same generated host API. | Keep metadata diagnostics internal and do not reintroduce a partial platform substitution layer unless it owns the complete bridge contract. |
| LIFE-014 | P1 | Verified | Native init/unlock no longer treats message text containing `"conflict"` as success, and init no longer returns an empty pubkey after a failed native init. The platform state machines either validate already-unlocked readiness or throw the original bridge error. | Keep conflict/error normalization covered whenever native init or unlock paths change. |
| LIFE-015 | P1 | Verified | Native external signer creation/attach is transactional in Dart: handles are assigned only after successful init/attach, failed temporary handles are destroyed, orphan cleanup blocks reuse until resolved, and retry/failure tests cover both init and cold attach paths. | Keep platform-level leak checks under LIFE-009/TEST-007. |
| LIFE-016 | P1 | Verified | `vssClearFence` previously required unlock even though RN documentation and native recovery semantics require clearing a stale single-writer fence after init and before unlock. The facade now enforces that sequence. | `test/utexo_wallet_test.dart::clears a stale VSS fence after init and before unlock` guards the recovery path. |
| LIFE-017 | P1 | Verified | Both native bridges now construct RLN 0.13 `SdkLdkChainSync`: complete validated RPC tuples select block sync; otherwise a non-empty indexer URL selects transaction sync. Partial RPC tuples, missing transaction-sync endpoints, and invalid ports fail before native mutation in mirrored Android/iOS tests. | Keep the chain-sync selection policy byte-for-byte aligned across platforms and covered when the RLN unlock ABI moves. |

### LSP and Network Behavior

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| LSP-001 | P1 | Verified | The Dart LSP implementation was reconciled with the then-current core beta.6 behavior for routing, callback rebasing, status polling, APay, claim handling, and HTTP policy while keeping a Flutter-native injectable client. Core beta.7 LSP DTO/discovery changes are now tracked separately under API-033, MODEL-018, and MODEL-019. | Avoid future manual drift by comparing against core source whenever RN/core changes. |
| LSP-002 | P1 | Verified | Callback rewrite now strips absolute callback URLs to path/query/fragment so requests rebase through `baseUrl` and preserve proxy path prefixes; the LSP HTTP policy test asserts `/lsp/pay/callback/...`. | Keep proxy-prefix coverage in package tests. |
| LSP-003 | P1 | Verified | `payAddress` routes by address host: same-LSP addresses use the authenticated LSP client and do not fall back on auth/server errors; foreign addresses use LNURL discovery directly. Controlled service tests cover routing, authentication/server failures, and foreign resolution. | Keep deterministic service vectors mandatory; add live failure fixtures only when the release stack exposes controllable LSP failures. |
| LSP-004 | P1 | Verified | Foreign LNURL fallback now goes through `IUtexoLspClient.resolveExternalAddress`, sharing the same injected HTTP client, timeout handling, status checks, body parsing, and HTTPS/loopback policy. | Keep raw HTTP out of high-level LSP orchestration. |
| LSP-005 | P1 | Verified | `claimPendingPayments` reports missing preimages and skips `claimHodlInvoice` instead of substituting an empty string; controlled vectors prove no native claim occurs without a preimage and valid claims delegate correctly. | Keep the no-fabrication claim vectors and exact funded settlement smoke in the release suite. |
| LSP-006 | P1 | Verified | Settlement polling calls `getLightningReceiveStatus` and normalizes Lightning invoice states; stale RGB-folding status helpers have been removed from the facade. | Keep Lightning and RGB status vocabularies separate. |
| LSP-007 | P2 | Verified | LSP polling and sleep now use `Stopwatch` monotonic elapsed time; timeout and poll interval inputs are validated before polling. | Add injectable time/sleep only if deterministic virtual-time tests become necessary. |
| LSP-008 | P2 | Verified | Peer-connect idempotence now accepts only typed `ConflictError`/`CONFLICT` errors; the Group 3 wallet test proves typed conflicts are swallowed and an untyped `StateError('already connected')` is rethrown instead of substring-matched. | Keep native bridge conflict mapping centralized in `native_bridge_error_mapper.dart`; do not reintroduce service-level substring matching. |
| LSP-009 | P2 | Verified | `UtexoLspClient` now tracks HTTP client ownership: SDK-created clients are closed, injected `http.Client`s are not; the public integration/security guide documents the contract. | Keep `IUtexoLspClient` lifecycle ownership explicit for future adapters. |
| LSP-010 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-14): Status lookup accepts another payment's hash. Earlier evidence: The concrete client implements strict discovery, `/lightning_send`, and relay-status calls; maps every beta.9 snake-case DTO; isolates bearer credentials from foreign LNURL hosts; enforces HTTPS except explicit loopback; and has deterministic request, timeout, redaction, response-size, and malformed-wire tests. | 2026-09-20 corrective verification (working tree, not release qualification): Relay-status payment identity is checked against the requested hash; mismatch tests pass before callers can accept another payment status. |
| LSP-011 | P0 | Verified | `receiveAsset()` now defaults to canonical/convertible resolution by omitting `asset_id`, offers explicit payout compatibility mode, and returns the resolved on-chain asset plus conversion flag. Both body shapes and results are covered. | Preserve omission semantics; sending a JSON null is not equivalent to omitting the key for older LSPs. |
| LSP-012 | P0 | Verified | Reopened by 2026-09-20 audit (AUD-08): Relay quote verification does not bind the selected funding asset. Earlier evidence: `quoteExternalPayment` and `payExternalInvoice` locally decode both BOLT11 invoices and reject payment-hash, network, payee, asset, asset-amount, msat, fee, expiry, conversion, and reported-leg mismatches before payment. Only verifier-created quote instances report `verified: true`. | 2026-09-20 corrective verification (working tree, not release qualification): Verified relay funding asset matches the caller-selected asset before any native payment; adversarial substitution tests pass in lsp_beta9_contract_test.dart. |
| LSP-013 | P1 | Verified | Address discovery is projected into payout/accepted/convertible menus, and selection uses the largest usable single-channel balance with payout-first ordering, deterministic deduplication, and typed empty/unknown/ambiguous/insufficient-liquidity failures. | Do not sum channels until cross-channel RGB MPP exists. |
| LSP-014 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-09): Default own-receive invoice is not bound to the local wallet identity. Earlier evidence: `quoteAddress` and `requestExternalInvoice` support explicit or selected assets, own/foreign addresses, APay proof propagation, and external-payer metadata. Discovery and its consuming callback are retained as one coherent exchange so verification cannot bind a later response to stale metadata. | 2026-09-20 corrective verification (working tree, not release qualification): Default own receive is bound to local identity, while explicit third-party receive remains supported; adversarial beta.9 tests pass. |
| LSP-015 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-12, AUD-13): Liquidity wait only examines the first usable channel; Polling deadlines/cancellation do not bound an iteration. Earlier evidence: Cancelled receives are terminal, liquidity timeout reports the last observed outbound amount, and all beta.9 errors use the package taxonomy while retaining monotonic cancellation, peer scoping, and missing-preimage fail-closed behavior. | 2026-09-20 corrective verification (working tree, not release qualification): Polling deadlines/cancellation bound each asynchronous iteration and use the largest eligible single channel; no MPP sum is assumed. Deadline and liquidity tests pass. |
| LSP-016 | P1 | Verified | The concrete LSP client uses core's 15-second default with positive per-client overrides, independent of the 120-second native-operation deadline. Contract tests and hardening validation pin the distinction. | Keep HTTP quote/discovery deadlines separate from long native RLN operations. |
| LSP-017 | P0 | Verified | Core/RN propagated APay proofs without validating them, allowing a payer to trust substituted hashes or unbound metadata. Flutter now verifies BOLT11 amount/asset/network/expiry/metadata hash/payee, address ownership, APay host/recipient/batch validity, Merkle inclusion, signed batch commitment, and external LDK recoverable-signature vectors before returning or paying a quote. | Retain this documented funds-safety divergence until core provides equivalent verification; every signed field needs a tamper vector. |
| LSP-018 | P1 | Verified | The original HTTP path trusted ambient DNS/proxy/redirect behavior and unbounded bodies. The SDK-owned transport now uses DIRECT connections, disables redirects, caps responses, aborts on timeout, strips secrets, rejects credential-bearing/non-public targets, rejects mixed public/private DNS answers, pins the selected IP while preserving TLS hostname validation, and covers IPv4 plus IPv6 loopback/private/mapped forms. True loopback is the only foreign-target exception; Android's `10.0.2.2` alias is restricted to an explicitly configured LSP base URL. | Injected clients remain caller-owned and must provide equivalent transport policy; this responsibility is documented. |
| LSP-019 | P1 | Blocked upstream | `resolveAddress` callbacks consume APay hashes, while `/onchain_send`, `/lightning_receive`, and `/lightning_send` create durable server-side mappings. If the request succeeds but the response is lost, the protocol exposes no idempotency key or universal lookup handle, so a client cannot safely distinguish retry from duplicate mutation. Flutter performs one attempt and never auto-retries these calls. | Upstream must add idempotency keys or reconciliation endpoints. Until then, surface ambiguous failures, never retry automatically, and require explicit operator/user reconciliation before another mutation. |
| LSP-020 | P2 | Verified | Address provisioning retried every failure eight times, hiding permanent authentication/configuration/protocol errors behind a long generic timeout. It now retries only network failures and 404/408/425/429/5xx responses, while permanent failures rethrow after one attempt. | Keep retry classification bounded and mutation-free; the 401 fail-fast regression test must remain. |
| LSP-021 | P1 | Verified | A proofless same-host LNURL invoice was structurally checked but not tied to the configured LSP identity. Same-host quotes now require the recovered BOLT11 payee to equal the configured peer even when a legacy server omits APay proof; foreign-host invoices retain domain-scoped verification. | Keep configured-peer binding in the invoice verifier and cover both proof-bearing and proofless paths. |
| LSP-022 | P1 | Verified | Core beta.9 retries a consuming foreign LNURL/APay callback and resolves discovery separately, so a lost response can consume more than one hash or bind verification to stale metadata. Flutter now returns discovery plus callback as one immutable resolution and attempts the consuming callback once. | Preserve one-attempt callback semantics until upstream provides idempotency/reconciliation; coherent resolution tests and the core adaptation manifest must remain current. |
| LSP-023 | P1 | Verified | `10.0.2.2` was treated as generic loopback, allowing a user-controlled external Lightning Address domain or callback to target host-side Android development services. It is now permitted only for an explicitly configured LSP base URL; external discovery accepts true loopback or public destinations under the existing DNS policy. | Keep configured development aliases separate from externally supplied trust decisions and retain the adversarial target vector. |
| LSP-024 | P0 | Verified | Reopened by 2026-09-20 audit (AUD-10): Supported same-asset `Any` receives are rejected after the mapping request. Earlier evidence: `receiveAsset()` trusted returned RGB metadata, while `sendAsset()` immediately paid the LSP-returned BOLT11 without locally binding it to the target RGB invoice. A compromised or misconfigured LSP could substitute an asset, amount, network, expiry, payee, or invoice. Flutter now decodes and verifies both signed legs and echoed metadata before exposing the receive result or paying; every mismatch proves zero payment calls. | 2026-09-20 corrective verification (working tree, not release qualification): Same-asset Any receive is supported without weakening converted-send/receive amount binding; beta.9 Any/conversion tests pass. |
| LSP-025 | P1 | Verified | The three signed-invoice verifiers independently canonicalized only `bitcoin`/`testnet3`; the stable wallet exposed its configured value unchanged. A valid default `utexo` wallet therefore compared against RLN-decoded `signet` and failed every APay/relay/bridge verification, while numeric network aliases could fail similarly. `LspNetworkPolicy` now owns exact alias identity and `UtexoWallet.network` exposes the canonical native network. APay, bridge, relay, numeric-alias, and wallet vectors cover the boundary. | Keep wallet creation and every signed invoice verifier on the same canonical policy; add a policy vector before accepting any new network alias. |
| LSP-026 | P2 | Verified | Plain Lightning Address parsing preserves local-part case for provider compatibility, but APay ownership verification also compared the DNS domain byte-for-byte. Mixed-case user input could resolve the same DNS host and then reject a valid lowercase-domain signature. Verification now accepts the exact signed domain first and its DNS-equivalent lowercase form second, without changing or lowercasing the username. | Keep domain canonicalization limited to DNS case equivalence; never normalize the signed local part or accept an unrelated host. |
| LSP-027 | P1 | Verified | Bridge inputs allowed a zero-satoshi receive to create a native invoice before failing fixed-amount verification, the locally created signed BOLT11 was not checked until after the durable LSP mapping call, and caller-supplied description/payment hashes plus `minFinalCltvExpiryDelta` were only checked for positivity/nonblank text. Receive now requires positive sats and verifies the signed invoice's network, validity, requested expiry duration, amount, asset, and asset amount before HTTP contact; hashes require exactly 32-byte hexadecimal; and CLTV fits UInt16. Tests assert no invoice/network/payment side effect after rejection. | Validate every future mutation-bound override and signed local artifact completely before the first native or HTTP side effect, and retain zero-contact assertions. |
| LSP-028 | P2 | Verified | `receiveAsset()` budgeted the returned BOLT11 expiry by subtracting wall-clock timestamps around the LSP request, and its minimum-one-second clamp could contact the LSP after a short invoice had already expired. A user or network time correction could also distort the budget. The bridge now measures request age with a monotonic `Stopwatch` and fails before HTTP mutation when the lifetime is exhausted, while retaining Unix time only for signed invoice expiry validation. | Keep duration budgets monotonic and reserve wall-clock time for protocol timestamps; the delayed-invoice no-contact regression must remain. |

### Security and Cryptography

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| SEC-001 | P0 | Verified | The former ephemeral VLS signer path was replaced with `newWithStorage(storageDirPath)` and transactional handle ownership. | Disk-backed signer creation and funded restart/channel-payment tests pass on both platforms. |
| SEC-002 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-07): Disposal retains avoidable unused secret references. Earlier evidence: SDK-owned seed/private-key byte buffers are wiped after derivation/signing where Dart allows it; `NativeExternalRlnSigner` consumes seed hex immediately after native signer handoff so retries require a fresh signer; `PasswordRlnSigner` clears password/mnemonic references after unlock and accepts explicit password refresh for future sessions; docs state that strings, BIP32 internals, VM copies, and app-owned storage cannot be reliably zeroized by this package. | 2026-09-20 corrective verification (working tree, not release qualification): Password/mnemonic/unused seed references are released on failed init and disposal. This minimizes references, not guaranteed erasure of immutable Dart strings. Corrective safety tests pass. |
| SEC-003 | P1 | Verified | `RlnClient` now maps every Pigeon `PlatformException` through a centralized native bridge mapper into typed SDK errors with operation, native code, details, and retryability in `NativeBridgeFailure`; unit tests cover direct mapping and wallet fallback behavior. | Extend redaction and taxonomy as new native error categories appear. |
| SEC-004 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-15): Diagnostic serialization bypasses secret redaction. Earlier evidence: LSP support-safe diagnostics now redact bearer tokens, common credential fields, preimages, seed hex/long hex material, and oversized previews; tests assert secret text is absent from `LspError.toString()`. | 2026-09-20 corrective verification (working tree, not release qualification): Serialized errors omit raw bodies/causes; native bridge messages are generic; malformed JSON, arbitrary status strings and claim failures no longer leak raw diagnostics. Safety and beta.9 regression tests pass. |
| SEC-005 | P1 | Verified | `LspError` response previews are bounded to 512 characters and redacted before exception display; full bodies are not preserved in public exceptions. | Add opt-in secure diagnostics only with explicit app consent. |
| SEC-006 | P1 | Verified | LSP/LNURL HTTP rejects non-loopback plain HTTP before requests are sent; HTTPS and explicit loopback development hosts remain allowed. | Apply the same transport policy to VSS/client APIs that still accept URLs. |
| SEC-007 | P1 | Accepted constraint | Standalone account-key BIP340 signing now fails closed by default with `ExperimentalCryptoException` and can only execute when callers explicitly pass `SchnorrSigningMode.experimentalDart`. This deliberately diverges from RN's top-level core `signMessage`, which is callable by default through `@utexo/rgb-sdk-core`. The divergence is accepted for this release line because Flutter's pure-Dart PointyCastle implementation is not audited/proven constant-time; wallet node-message signing remains native RLN-backed and RN-aligned. | Keep pure-Dart signing documented as experimental until replaced by a vetted/native primitive or a formal crypto review; do not remove the fail-closed default without a new tracker row, updated parity/divergence docs, and audited evidence. |
| SEC-008 | P2 | Verified | `tool/validate_supply_chain.dart` now performs fail-closed hosted Pub OSV vulnerability checks and deterministic license classification in addition to secret-pattern scanning, SBOM-style dependency inventory, pinned artifact provenance status, and ABI-symbol gates; the Group 3 report has 55 accepted license entries, 0 unknown/rejected, 52 hosted Pub queries, and 0 vulnerable packages. | Keep OSV/license results attached to every release-candidate evidence bundle; upstream artifact signatures/reproducibility remain tracked separately under PKG-006. |
| SEC-009 | P2 | Accepted constraint | Durable credential storage is app-owned, not SDK-owned. | Document the boundary; SDK still owns in-memory minimization and must never persist credentials implicitly. |
| SEC-010 | P1 | Verified | `RlnSeedBytesKeyMaterial` now defensively copies caller-provided `Uint8List` material and returns copies from its getter; tests prove caller mutation cannot change the derived seed. | Zeroization remains part of broader secret-lifetime work under SEC-002. |
| SEC-011 | P0 | Verified | Native node creation could leave a newly created storage root with group/other permissions, after which RLN correctly rejected `newWithStorage` and durable external-signer initialization could not start. | Both plugins now enforce owner-only storage roots and fail closed for unsafe existing paths; native policy tests and funded cross-process restart/payment smokes pass on iOS and Android. |
| SEC-012 | P1 | Verified | The native storage policies rejected group/other access but accepted owner-only directory modes missing required owner read/write/execute bits, such as `0600`; RLN would then fail later through a less stable error path despite the policy claiming `0700`. | Both platforms now require exact mode `0700`; the new negative cases pass in the 9-case iOS and 12-case Android native suites. |

### Packaging, Platforms, and Supply Chain

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| PKG-001 | P1 | Verified | Clean checkout iOS artifact acquisition is now deterministic through the pod `prepare_command`: installed artifacts verify before reuse, `RLN_ARCHIVE_PATH` supports an explicit pre-resolved archive, `RLN_CACHE_DIR` supports a checksum-verified archive cache, and `RLN_OFFLINE=1` fails closed unless one of those sources is already available. `validate_release_package.dart` gates these modes. | Keep iOS artifacts ignored from package contents, but require deterministic acquisition plus verification before consumer/archive evidence. |
| PKG-002 | P1 | Verified | CocoaPods `prepare_command` still performs artifact preparation, but it is now cache-aware, explicit-archive aware, checksum/size verified, lock-protected, and offline-fail-closed instead of an opaque mandatory network download. | Prefer pre-resolved internal artifacts for release runs by setting `RLN_ARCHIVE_PATH` or pre-populating `RLN_CACHE_DIR`; do not rely on live network fetches for release evidence. |
| PKG-003 | P1 | Verified | `tool/download_rln_ios.sh` verifies installed iOS artifacts against the release baseline before reuse and installs via a lock plus temporary extraction path before final verification. | Keep atomic install and checksum verification mandatory for new artifact versions. |
| PKG-004 | P1 | Verified | Dart, Swift, Kotlin, shell, Gradle, and podspec consumers now read generated constants or `tool/release_baseline.json`; `generate_release_baseline.dart --check` proves generated files are current. | Keep new metadata consumers generated or direct-manifest based. |
| PKG-005 | P1 | Verified | `tool/verify_native_artifacts.sh` verifies every resolved matching Android AAR by exact checksum, size, and ABI set, and `tool/test_release_candidate.sh` now requires Android artifact verification instead of running iOS-only. | Keep release-candidate artifact verification mandatory and attach resolved AAR paths in release evidence. |
| PKG-006 | P1 | Accepted constraint | Internal-beta supply-chain validation now records source pins, checksums, SBOM-style Dart dependency inventory, license-file inventory, iOS/Android ABI-symbol markers, architecture metadata, and `tool/native_artifact_provenance.json`. Live upstream review found Android Maven publishes `rgb-lightning-node-android-0.10.0-beta.3.aar.asc`, but this candidate has no pinned trusted signing-key verification result; the iOS GitHub release asset has no detached signature; neither platform has reproducible-build/source attestation evidence. Production mode intentionally fails. This is accepted only for the public UTEXO source mirror/internal-beta package line. | Keep `releaseTier: internal-beta` and keep production supply-chain mode fail-closed until per-artifact upstream signatures, pinned trusted signing-key/fingerprint policy, verified signature results, and reproducible-build/source attestations exist for iOS and Android. |
| PKG-007 | P1 | Verified | The podspec bundles `ios/Resources/PrivacyInfo.xcprivacy`; package validation gates the file and resource bundle declaration, and the clean consumer archive matrix under PKG-016 proves integration. | Keep privacy-manifest presence in both package and clean-archive gates. |
| PKG-008 | P1 | Verified | The pinned RLN iOS archive objects report `LC_BUILD_VERSION` `minos 18.5`; `tool/release_baseline.json`, `ios/rgb_sdk_flutter.podspec`, pod/user deployment-target xconfigs, and the example iOS project now declare iOS 18.5 instead of the false iOS 13.0 floor. | Revisit the minimum only when upstream ships artifacts built for a lower deployment target and the clean consumer matrix proves it. |
| PKG-009 | P1 | Verified | The plugin and example main Android manifests now declare `android.permission.INTERNET`, so release builds do not rely on debug/profile-only networking. | Verify release networking in clean consumer archive tests under PKG-016. |
| PKG-010 | P2 | Verified | `android/settings.gradle` was removed and committed, leaving `android/settings.gradle.kts` as the single plugin settings file; package validation checks this invariant. | Keep one Android settings owner. |
| PKG-011 | P2 | Verified | The supported baseline is now documented in `doc/INTEGRATION_SECURITY_AND_RELEASE.md` and enforced through `pubspec.yaml` plus `tool/release_baseline.json` checks. | Expand from baseline declaration to a tested compatibility matrix under PKG-016. |
| PKG-012 | P1 | Verified | `pubspec.yaml` now declares coherent constraints for the tested toolchain family: Dart `>=3.11.0 <4.0.0` and Flutter `>=3.41.0`. | Revisit constraints when the official release target is selected. |
| PKG-013 | P2 | Accepted constraint | `publish_to: none` and Git/path install are intentionally retained for this internal-beta line; immutable pub.dev/version distribution policy is deferred until publication work starts. | Before pub.dev or external production distribution, decide the tagged-release and package-publishing policy and document integrity/rollback. |
| PKG-014 | P2 | Verified | Package contents are intentional and exclude vendored native artifacts. The clean-consumer matrix runs `dart pub publish --dry-run` against a committed candidate snapshot and rejects warnings or unintended files. | Keep warning-free dry-run in every exact clean-candidate release run. |
| PKG-015 | P2 | Verified | Podspec metadata now declares MIT license type/file, path source, iOS 18.5, deployment-target xconfigs, privacy bundle, and source/preserve paths. `pod ipc spec ios/rgb_sdk_flutter.podspec` resolves this metadata. Plain `pod lib lint` is documented as non-authoritative because CocoaPods resolves public `Flutter` 3.13.0, which lacks the `FlutterBinaryMessenger` task-queue API required by the pinned Flutter 3.41.9/Pigeon bridge. | Use `pod ipc spec` plus clean Flutter consumer archive builds as the pod integration gate unless Flutter publishes a CocoaPods spec that matches the pinned toolchain API. |
| PKG-016 | P1 | In progress | Reopened by 2026-09-20 audit (AUD-23): Failed consumer builds can be recorded as passed. Earlier evidence: `tool/test_clean_consumer_matrix.sh` snapshots tracked/unignored candidate files, validates tarball contents with `dart pub publish --dry-run`, installs into fresh consumers by path and local Git ref, builds Android release APKs and iOS release no-codesign apps for both, checks prepared RLN iOS artifacts, and reruns CocoaPods with `--deployment --no-repo-update`; the archive-enabled Group 4 run passed with report `build/test-reports/group-4/clean-consumer-matrix-20260805T114259Z-d366bca.json`. | Complete the corrective contracts and verification in the September remediation register below. Earlier passing tests do not close these reproduced/source-confirmed gaps. |
| PKG-017 | P2 | Verified | `tool/release_baseline.json` keeps `releaseTier: internal-beta`, `validate_release_package.dart` gates that value, and public docs state that artifacts are development/internal beta only until provenance gates pass. | Change releaseTier only after provenance/SBOM/license/reproducibility gates are verified. |
| PKG-018 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-32): Permanent local iOS artifacts are stale. Earlier evidence: Exact RLN 0.13.0-beta.3 artifacts are installed and pinned to tag/commit `v0.13.0-beta.3`/`af03c7f1a65135a429f05a5820600338215954dc`: iOS archive 216,369,546 bytes/SHA-256 `c272c35d…`, Android AAR 90,444,658 bytes/SHA-256 `237f1e9a…`, plus installed-file hashes, slices/ABIs, Maven coordinate, generated APIs, and provenance. Dirty-candidate native suites pass 20 Android and 18 iOS cases. | 2026-09-20 corrective verification (working tree, not release qualification): The complete pinned iOS artifact set was reinstalled, not partially patched. Both installed iOS files/slices and Android AAR pass verify_native_artifacts.sh --require-android. Native execution remains TEST-036. |
| PKG-019 | P1 | In progress | Reopened by 2026-09-20 audit (AUD-29): Production provenance gate trusts status assertions. Earlier evidence: RN's core dependency previously had only a version assertion. The baseline now pins the exact beta.9 npm archive URL, size, SHA-256, registry SHA-512 integrity, and extracted `package.json`, `dist/index.d.ts`, and `dist/index.mjs` hashes; parity validation also requires RN's exact `yarn.lock` entry and verifies a supplied tarball byte-for-byte. | Complete the corrective contracts and verification in the September remediation register below. Earlier passing tests do not close these reproduced/source-confirmed gaps. |

### Testing and Release Evidence

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| TEST-001 | P1 | Verified | Dart bridge tests now cover all 62 low-level method delegations, `skipSync` fail-fast, platform error mapping, malformed wire response rejection, and Group 2 critical request/return shapes; Android/iOS bridge suites add native failure vectors for the high-risk families. | Keep exact funded success proof under TEST-002 and do not cite Dart-only tests as funds behavior. |
| TEST-002 | P1 | Verified | The release candidate now has layered contract, native, and end-to-end runtime evidence on the exact clean commit: Dart/package tests, Android JVM bridge tests, iOS XCTest bridge tests, clean consumer path/Git archives, iOS/Android unfunded smokes, iOS/Android funded RGB+Lightning smokes, and iOS/Android external-signer restart proofs. | The current combined report records the exact `HEAD`, `releaseEligible: true`, `workingTree.dirty: false`, and zero failed steps. |
| TEST-003 | P2 | Verified | `doc/COVERAGE_POLICY.md` defines Dart-only coverage scope and generated-code exclusions; `tool/validate_coverage_policy.dart` gates package and domain thresholds. Exact clean run `20260806T094500Z` passes with 167 tests and coverage floors: package 78.0%, wallet 82.9%, LSP 67.9%, crypto 89.2%, models 72.6%. | Raise thresholds as behavior coverage improves; do not use Dart coverage as native/funds evidence. |
| TEST-004 | P0 | Verified | No external-signer process-restart/channel-state/payment test existed. | The one-install/two-process funded restart proof passes on iOS and Android with pre/post-restart bidirectional settlement. |
| TEST-005 | P1 | Verified | Current beta.26 bridge vectors now cover rotate/sign/verify/inflate, txid histories, `backupNow`, assignment kinds, and `descriptionHash` across Dart contract/facade tests plus mirrored Android JVM and iOS XCTest failure/request-boundary vectors; the bridge-vector manifest points each critical method to executable evidence. | Keep exact funded/unfunded platform-smoke reports under TEST-002/TEST-013 for runtime funds behavior. |
| TEST-006 | P1 | Verified | Group 3 adds controlled negative-path tests for peer-connect idempotence, `receiveAsset`/`sendAsset` LSP failures, failed settlement status, APay registration failure, missing-preimage HODL claims, native HODL claim failure reporting, and VSS failure propagation. These are unit/service-orchestration proofs, not funds-movement proof. | Keep production funds behavior under TEST-002 and exact platform-smoke evidence; add live LSP failure fixtures only when the release stack exposes deterministic service controls. |
| TEST-007 | P1 | Verified | Lifecycle/concurrency/fault evidence now covers Dart queued init/unlock/shutdown/destroy contention, failed-init cleanup before retry, restart failure points, destroy fault reporting after node cleanup, timeout quarantine/ordered destroy after late native completion, Android native close-failure cleanup, and iOS native same-path replacement/final store state. | Evidence: targeted Dart lifecycle tests pass, Android JVM bridge suite passes with 18 plugin tests, iOS XCTest passes with 16 cases on iPhone Air, `tool/test_matrix/evidence_catalog.json` records the executable IDs, and the exact clean all-up release run `20260806T094500Z` passed. |
| TEST-008 | P1 | Verified | Native bridge tests now pass on Android JVM (17 cases) and iOS XCTest (13 cases), with mirrored Group 2 coverage for numeric-boundary rejection, unknown RGB assignment kind rejection, and unknown-node operation details across rotate/sign/verify/txid history methods; Dart covers malformed wire JSON/list roots because native XCTest/JVM cannot safely fabricate successful RLN payloads without a live node. | Keep live-node success/funds behavior in the platform smoke suite and exact-candidate release evidence. |
| TEST-009 | P2 | Verified | Group 2/3 tests now cover native integer-string boundaries, strict model decoding, enum/status normalization, parser rejection paths, official BIP340 vectors, BIP340 message/public-key/signature tampering, Schnorr scalar/byte-length boundaries, and fail-closed standalone signing without explicit experimental opt-in. | Extend with generated fuzz corpora if future API changes add new parsers or wire formats. |
| TEST-010 | P1 | Verified | `validate_rn_parity.dart` now compares exact RN commit/package/core/RLN pins, live upstream `origin/dev` drift, multiline NativeRgb method names, low-level parameter names/types/nullability, return categories, wallet method inventory, and runtime exports against RN `dev`. | Add generated AST/schema extraction later if regex parsing becomes insufficient, but current static parity is machine-checked. |
| TEST-011 | P1 | Verified | `tool/test_matrix/evidence_catalog.json` maps every evidence bucket to executable test IDs, platform report families, claim levels, and independent assertions; `dart run tool/validate_test_matrix.dart` now fails uncataloged buckets and still checks implementation symbols/source coverage. | Move from bucket-level links to row-specific immutable platform reports where later runtime rows require stronger evidence. |
| TEST-012 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-24): Required skips can still produce `releaseEligible: true`. Earlier evidence: `tool/test_release_candidate.sh` now records required skipped gates as exit code `125`, includes skip notes in the JSON report, and fails unless `ALLOW_SKIPPED_RELEASE_GATES=1`; dry run failed because `IOS_DEVICE` and platform smokes were skipped. | 2026-09-20 corrective verification (working tree, not release qualification): Required skips cannot yield release eligibility. Drafts remain ineligible until finalization. Nested failures and skipped-gate regression tests pass; combined candidate execution is separately open. |
| TEST-013 | P1 | Verified | Android JVM, iOS XCTest, four platform smokes, and the all-up local release runner passed on the exact clean beta.27/core beta.7/RLN 0.10 candidate. This verifies the release-evidence mechanism, not the current beta.32 candidate; `TEST-036` owns that rerun. | Keep rerunning this exact stack for every release-candidate commit; dirty and prior-baseline reports remain non-release evidence. |
| TEST-014 | P2 | Verified | `doc/RELEASE_EVIDENCE_SCHEMA.md` defines evidence IDs, required fields, sanitization, and release eligibility. `tool/test_release_candidate.sh`, `tool/test_native_android.sh`, `tool/test_native_ios.sh`, `tool/test_platform_unfunded.sh`, `tool/test_platform_funded.sh`, and `tool/test_external_signer_restart.sh` now emit unique run-ID filenames with schema version, evidence ID, full commit, dirty state, sanitized repo-relative log path, and log SHA-256. Exact clean run `20260806T094500Z` produced release-eligible child reports with `dirty: false`. | Continue treating skipped gates and dirty-worktree runs as non-release-eligible. |
| TEST-015 | P2 | Verified | Integration smokes now track low-level node creation, always attempt node/wallet cleanup, delete every temp storage directory they create, emit `RGB_SDK_FLUTTER_CLEANUP_ERROR` diagnostics for cleanup failures, and fail otherwise-successful low-level, facade, and funded smokes if cleanup did not complete. | Keep storage cleanup failure observable in every new integration smoke; native handle/store cleanup is covered under LIFE-008/TEST-007. |
| TEST-016 | P2 | Verified | `tool/api_snapshot.json` snapshots the normalized exported Dart surface, Pigeon schema, generated Dart/Swift/Kotlin bridge surface, native bridge/store markers, and stable-domain model declarations. Strict malformed-wire and exhaustive enum/status mapper vectors cover model behavior that a declaration snapshot cannot prove. | Refresh the snapshot and behavior vectors together for every intentional API, wire, or domain-model change. |
| TEST-017 | P2 | Accepted constraint | Native builds and regtest smokes will not run in CI. | Make the local release gate mandatory, reproducible, attributable, and impossible to report green when skipped. |
| TEST-018 | P1 | Verified | The native iOS test script reused a stale CocoaPods source graph and omitted newly added plugin files. It now runs `pod install` before `xcodebuild`, records that step, and the follow-up XCTest run compiled the new policy file and passed all nine cases. | Keep the explicit pod refresh in every local native iOS release run. |
| TEST-019 | P1 | Verified | Regtest startup considered electrs ready when its TCP port opened, even while a persisted stale Bitcoin tip kept bitcoind in IBD and electrs returned no protocol response; RLN unlock then failed after its startup timeout. | Startup now establishes a current non-IBD tip and validates an Electrum `server.version` JSON response; both final platform restart runs passed the gate. |
| TEST-020 | P1 | Verified | Two independent `flutter test` invocations reinstall the platform test app; on iOS the second install receives a new sandbox and deletes the first process's persisted node/signer state, so the apparent restart test cannot exercise recovery. | The controller now builds and installs one auto-phased binary, coordinates through atomic run-scoped files, force-terminates and relaunches without reinstalling, verifies unchanged storage, and requires second-process result markers on iOS and Android. |
| TEST-021 | P1 | Verified | `test_native_ios.sh` always placed `DEVICE` in Xcode's `name=` destination field, so a valid simulator UUID failed selection even while Xcode listed that UUID. | The script now emits `id=` for canonical UUIDs and `name=` otherwise, records the resolved destination, and the UUID path passed all nine XCTest cases. |
| TEST-022 | P1 | Verified | The restart fixture reused one constant signer seed, so a persisted regtest chain could contain spendable UTXOs from an earlier run and let the current prepare phase advance before its own funding request was serviced. | The controller now derives and validates a unique 32-byte seed per run; fresh-address funding and the full restart proof passed on both platforms. |
| TEST-023 | P1 | Verified | The iOS restart controller treated a listed simulator as runnable even when XCTest had left it shut down, so app installation failed before the test with CoreSimulator state error 405. | The controller now boots the selected simulator when needed, blocks on `simctl bootstatus`, and the subsequent full iOS restart proof passed. |
| TEST-024 | P1 | Verified | The combined release-candidate script did not run the external-signer process-restart proof even though Group 6 and the release definition require it, and child native/platform/restart reports hard-coded `releaseEligible: false` instead of computing eligibility for clean successful runs. | `tool/test_release_candidate.sh` now requires iOS and Android external-signer process restart when `RUN_PLATFORM=1`, `tool/validate_release_package.dart` gates that wiring, and native/platform/restart child reports compute `releaseEligible` from pass plus clean-worktree state. |
| TEST-025 | P1 | Verified | The exact release-candidate iOS unfunded smoke exposed that `UtexoWallet.reinit(unlockConfig: ...)` could create a replacement node and only then fail because a `PasswordRlnSigner` had consumed its password during the earlier unlock. | `reinit()` now preflights password-signer unlock readiness before shutdown/node recreation, the iOS unfunded and external-signer restart smokes pass a fresh password for password-signer cold restarts, and `test/utexo_wallet_test.dart` proves the missing-password path fails without creating another node. |
| TEST-026 | P1 | Verified | The combined release-candidate runner assumed Android was already attached and stable before the run, but local AVDs can exit while earlier iOS/package gates are still running. | `tool/test_release_candidate.sh` now supports `ANDROID_EMULATOR=<avd-name>`, boots that AVD headlessly immediately before Android platform smokes, waits for `sys.boot_completed`, resolves the live emulator serial, and records the emulator log under the release report directory. |
| TEST-027 | P1 | Verified | `tool/validate_rn_parity.dart` fails on stale RN checkouts before local source parsing: it checks live `origin/dev`, fetched `origin/dev` when present, the configured remote, local `HEAD`, package/core versions, RN RLN pins, exact LSP signatures, and optional core-tarball bytes. The release runner records the complete baseline object. | Current evidence: live RN beta.32 commit `821ae4fd10ca` and exact core beta.9 tarball validation pass. |
| TEST-028 | P1 | Verified | The release runner and report-to-commit contract passed all required gates on the exact clean beta.27/core beta.7 candidate. This is historical proof of the mechanism, not beta.32 release evidence. | `TEST-036` must produce the equivalent no-skip, clean-worktree, report-to-HEAD result for beta.32 before the current candidate is release eligible. |
| TEST-029 | P1 | Verified | The first exact clean beta.27 release run failed the clean consumer matrix because the stable root did not export `NetworkEndpoints`/`getNetworkDefaults()`, even though public docs and consumer fixtures treated network defaults as stable app-facing API. | `lib/rgb_sdk_flutter.dart` now exports only `NetworkEndpoints` and `getNetworkDefaults()` from `network_defaults.dart`, `doc/PUBLIC_API_REFERENCE.md` documents both symbols, and `dart run tool/validate_public_api_docs.dart` plus `dart run tool/validate_api_snapshot.dart` pass after refreshing `tool/api_snapshot.json`. |
| TEST-030 | P1 | Verified | The first exact clean beta.27 release run failed `tool/validate_coverage_policy.dart`: `lib/src/crypto/` coverage had regressed to `66.7%`, below the release floor. | Added `test/crypto_validation_contract_test.dart` for network/Lightning Address validation, primitive value validation, unit conversion boundaries, seed normalization, wallet key derivation helpers, and malformed extended-key errors. `flutter test --coverage` and `dart run tool/validate_coverage_policy.dart` now pass with package `78.0%`, wallet `82.9%`, LSP `67.9%`, crypto `89.2%`, and models `72.6%`. |
| TEST-031 | P1 | Verified | When Android device preparation failed in the first clean beta.27 release run, `tool/test_release_candidate.sh` dereferenced unset `ANDROID_DEVICE` and aborted with an unbound-variable shell error instead of recording dependent Android gates cleanly. | The runner now checks that Android preparation actually resolved `ANDROID_DEVICE` before launching Android smokes/restart; otherwise it records required skipped Android gates with explicit reasons. `bash -n tool/test_release_candidate.sh` passes. |
| TEST-032 | P1 | Verified | The first exact clean beta.27 release run started with less than 1 GiB free, which poisoned clean-consumer iOS RLN extraction and prevented the Android AVD from booting. Without an early gate, this creates noisy partial release evidence. | The runner now has a `release disk-space preflight` gate before clean consumer/platform-heavy work and requires at least `RELEASE_MIN_FREE_KB` KiB free, defaulting to 10 GiB. Generated Flutter/Xcode/Pub cache state was cleared before rerun; `df` showed roughly 21 GiB free afterward. |
| TEST-033 | P1 | Verified | The RN wallet parser was line-based and silently omitted multiline method declarations, allowing incomplete parity to pass. It now parses the complete class body, requires every RN method to have a canonical return contract or explicit advanced alias, pins high-risk stable input contracts, and gates all 62 low-level plus all current high-level methods. | Keep the validator pinned to live `origin/dev`; any new RN method or changed high-risk input must fail until its Dart shape and evidence are declared. |
| TEST-034 | P2 | Verified | The combined release runner's format gate omitted `example/integration_test`, even though those sources carry the funded, unfunded, and process-restart candidate flows. | The runner now formats `lib`, `test`, `example/integration_test`, `tool`, and `pigeons` before any release evidence is accepted. |
| TEST-035 | P1 | Verified | The SDK-owned regtest stack defaulted its RGB proxy to host port `3003`, which collides with the app devstack's Esplora service. Compose could recreate the SDK proxy without a host mapping, while all platform smokes then failed wallet unlock with `unable to connect to proxy`. | Host port `3013` is reserved by `tool/regtest/config.sh`, every smoke/release entrypoint sources that contract, Compose and Dart integration defaults agree, and package validation rejects drift. Fresh iOS and Android unfunded lifecycle smokes pass against the corrected mapping; the exact clean all-up runner remains the release evidence gate. |
| TEST-036 | P1 | Open | Reopened by 2026-09-20 audit (AUD-31, AUD-33): New LSP/APay/linked success platform scenarios do not exist; Exact-current clean native/consumer release evidence remains absent. Earlier evidence: Beta.32/core beta.9/RLN 0.13 static gates, 223 Dart tests, 20 Android bridge tests, and 18 iOS bridge tests pass on the dirty working candidate. Existing clean-consumer, funded/unfunded, restart, and combined release-eligible reports still describe the earlier beta.27 commit and cannot be relabeled. | Complete the corrective contracts and verification in the September remediation register below. Earlier passing tests do not close these reproduced/source-confirmed gaps. |
| TEST-037 | P1 | Verified | Machine-readable inventories now cover `UtexoLsp`, `IUtexoLspClient`, `ILspWallet`, the network getter, exact signatures, runtime errors, RN-exported LSP types, beta.32 wallet/native methods, bridge vectors, RLN 0.13 chain-sync markers, and every reviewed UDL-to-RN exclusion. Live RN `origin/dev` and exact core tarball provenance pass. | Extend these inventories before updating the baseline whenever RN/core/RLN changes. |
| TEST-038 | P1 | Verified | New linked/canonical and APay paths initially had only happy-path parity coverage. `test/lsp_beta9_contract_test.dart` now has 46 deterministic contract tests spanning wire requests, strict DTOs, asset policy, callback consumption, APay cryptography and native batches, network aliases, relay mismatch/tamper cases, signed receive preflight and expiry exhaustion, timeout/redaction/transport policy, IPv4/IPv6 SSRF vectors, and no-payment-on-failure assertions. The complete Dart suite passes 223 tests; exact current coverage is refreshed by the coverage-policy gate before commit. | Keep adversarial behavior evidence distinct from static declaration parity and from funded platform smokes under TEST-036. |
| TEST-039 | P1 | Verified | RN parity validation compared all method names and canonical return contracts but pinned Dart input shapes for only selected high-risk methods. An existing RN method's parameter or return declaration could therefore drift after a baseline update without a second independent shape gate. `rn_parity_manifest.json` now pins a normalized SHA-256 fingerprint over every non-constructor `UTEXOWallet` parameter and return declaration, while the existing inventories retain actionable method-level coverage. | Any fingerprint change requires a method-by-method input/output audit before the immutable value is updated; live `origin/dev` and the exact local RN commit must still match the release baseline. |

### Code Quality, Modularity, and Documentation

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| CODE-001 | P2 | Verified | Stable root exports are now intentionally narrow: raw bridge internals, `RlnClient`, `RLNBinding`, `RLNManager`, `IRLN*`, raw `Rln*` models, native bridge mapper, logger, network-default internals, and full LSP client internals moved behind `rgb_sdk_flutter_advanced.dart`; `tool/validate_public_api_docs.dart` fails if known advanced/raw symbols re-enter the stable root. | Keep advanced/parity imports explicit; remaining model/error ownership cleanup is tracked under CODE-005, CODE-006, and CODE-012. |
| CODE-002 | P2 | Verified | RN-shaped stable-root names are quarantined: `RgbSdkFlutter.rlnClient()`/`rlnManager()` were removed, `RLNManager`/`RLNBinding`/`IRLN*` are advanced-only, and only `decodeRGBInvoice` remains as an advanced compatibility spelling while stable code uses `decodeRgbInvoice`. | Keep literal RN/native spellings out of the stable root unless a tracker row explicitly reclassifies them. |
| CODE-003 | P2 | Verified | `analysis_options.yaml` now enables strict casts, strict inference, strict raw types, generated Pigeon exclusions, and a production-oriented lint set; `flutter analyze --no-fatal-warnings --no-fatal-infos` reports no issues and `dart run tool/validate_codebase_hardening.dart` gates the config. | Add stricter row-specific lints only after raw/advanced API contraction reduces intentional parity-shaped surfaces. |
| CODE-004 | P2 | Verified | Stable lifecycle/error paths now avoid substring-driven control flow: `RLNBinding` unlock conflict normalization accepts typed `ConflictError`/native conflict codes only, `UtexoWallet.listTransfers()` checks typed `BadRequestError` plus native operation metadata instead of parsing `InvalidRequest` text, and UTEXO bridge helper validation throws SDK taxonomy errors. Wallet init/reinit cleanup failures now surface aggregated `WalletException` causes instead of silently preserving only the original operation failure. `tool/validate_codebase_hardening.dart` gates the platform-abstraction removal, Schnorr fail-closed policy, binding conflict classification, and bridge helper error taxonomy. | Keep generated Pigeon catches excluded from this row; any intentional cleanup suppression in hand-written stable code must preserve/emit the cleanup cause. |
| CODE-005 | P2 | Verified | Raw/native, stable domain, wallet facade, compatibility/advanced, and LSP model layers are now documented in `doc/API_COMPATIBILITY_AND_DIVERGENCE.md`. `UtexoDomainPolicy` owns public transaction/channel/transfer vocabulary, stable mappers depend one direction from raw `Rln*` models into `Core*`/`Lightning*` DTOs, and `tool/validate_codebase_hardening.dart` gates the model-policy boundary. | Keep new raw DTOs advanced-only and add mapper-policy entries before exposing any new stable domain shape. |
| CODE-006 | P2 | Verified | `WalletInputPolicy` now owns stable wallet validation for strings, numeric ranges, UInt bridge bounds, integer fee rates, config validation, dependency-owner mismatch, and unsupported `skipSync`; LSP claimable-payment checks use canonical status helpers; domain status/default decisions are centralized in `UtexoDomainPolicy` and `network_defaults.dart`; the hardening validator fails if those policies are bypassed in the stable facade. | Keep generated/native contract checks in generated or raw layers; add policy methods instead of duplicating validation/status tables in feature code. |
| CODE-007 | P2 | Verified | `doc/PUBLIC_API_REFERENCE.md` documents stability tiers, lifecycle prerequisites, native operation deadline semantics, units, errors, side effects, secret handling, platform support, unsupported/native-blocked behavior, and all currently exported public symbols; `dart run tool/validate_public_api_docs.dart` passes for the current exported symbol set and `dart doc` passes with 0 warnings/errors on the clean evidence run. | Keep the reference synced with `tool/api_snapshot.json` whenever public exports change; future API removals need migration notes under Group 1 rows. |
| CODE-008 | P2 | Verified | `tool/validate_release_language.dart` rejects stale beta.19/55-of-55/unsafe release-ready or 100% parity wording outside historical tracker/changelog context; README baseline checks are now read from `tool/release_baseline.json`, so the language gate does not bake in stale RN/core versions. | Extend the forbidden-language list whenever a new stale baseline or marketing-style claim appears. |
| CODE-009 | P2 | Verified | `doc/API_COMPATIBILITY_AND_DIVERGENCE.md` records the Pigeon decision, FFI/UniFFI alternatives, reversal criteria, artifact ownership boundary, and intended stable/advanced/generated/native layering. | Reopen with a new tracker row if a UniFFI/FFI spike proves a superior bridge path. |
| CODE-010 | P2 | Verified | `doc/API_COMPATIBILITY_AND_DIVERGENCE.md` now defines the compatibility-shim tier and the five-step deprecation/breaking-change plan, including required migration notes and API snapshot updates. | Execute the actual stale-surface removals under API-016/API-024/CODE-001 rather than treating this policy as implementation cleanup. |
| CODE-011 | P2 | Verified | Public collection-bearing wallet configs/requests, binding params, RLN/core DTOs, LSP wire wrappers, and UTEXO network presets now defensively copy list/map inputs into unmodifiable collections; `test/public_dto_immutability_test.dart` proves source-list mutation and exposed collection mutation do not alter DTO state. | Value equality/copyWith remains a future API-design choice; current release boundary prevents mutable collection aliasing. |
| CODE-012 | P2 | Verified | Public LSP failures now inherit from `RgbSdkException` subclasses, `OperationCancelledError` covers caller cancellation, root-exported timeout policy misuse throws `ValidationError`, the stable wallet constructor dependency mismatch throws `ConfigurationError`, and public docs define the catch contract. `test/utexo_wallet_test.dart::public facade and LSP failures use SDK error taxonomy` plus hardening validation guard against the previous public `ArgumentError`/`StateError`/direct-`Exception` paths. | Keep raw native diagnostics behind advanced APIs; all stable public boundaries should surface typed SDK errors with causes preserved where available. |
| CODE-013 | P2 | Verified | `flutter analyze --no-fatal-warnings --no-fatal-infos` now reports no diagnostics, and `dart run tool/validate_codebase_hardening.dart` runs `dart analyze --format=json` internally and fails unless analyzer output is zero-diagnostic, not merely a zero exit code. | Keep the release gate zero-diagnostic for hand-written source and tools. |
| CODE-014 | P1 | In progress | Reopened by 2026-09-20 audit (AUD-16, AUD-17): iOS flattens native enum cases into `RlnError`; Native error taxonomy omits current native cases. Earlier evidence: Native bridge errors now carry structured category, retryability, operation, and feature/details metadata from Swift/Kotlin where known errors are generated. Dart maps by category first, falls back only to exact legacy native codes, and no longer classifies stable errors by message substrings; tests prove misleading message text does not alter taxonomy. | Complete the corrective contracts and verification in the September remediation register below. Earlier passing tests do not close these reproduced/source-confirmed gaps. |
| CODE-015 | P2 | Verified | `UtexoWallet` is split into lifecycle, LSP/APay, on-chain/RGB, Lightning, guard, and unlock-resolution ownership files while retaining the public class surface through private internal mixins. `RLNBinding` is split into request/timeout types plus lifecycle, Lightning, and on-chain/RGB operation owners. The iOS bridge taxonomy helper moved to its own Swift file, and hardening now requires these ownership files and enforces line-count guardrails. Current root owner sizes: `utexo_wallet.dart` 207 lines, `rln_binding.dart` 161 lines, iOS plugin 1468 lines, Android plugin 1376 lines. | Keep future feature work in the focused owner files and update the part-aware API/matrix validators whenever the library layout changes. |
| CODE-016 | P2 | Verified | Dead prerelease compatibility code was removed: obsolete bridge/network helpers, `RNSigner`, standalone signer duplication, unused native `unsupported` helpers, duplicate `*Core`/Lightning aliases, deprecated fee scalar aliases, and internal signer-client adapters accidentally exported by the advanced barrel. | API snapshot, wallet matrix, hardening scans, and advanced import tests gate against stale surface regrowth. |
| CODE-017 | P1 | Verified | Stable facade success paths no longer fabricate values from malformed native responses. BTC send, transfer failure, HODL claim, payment send, keysend, asset maps, and related domain mappers require their documented fields and throw `NativeProtocolException` on malformed success payloads. | `test/utexo_wallet_test.dart::rejects malformed native wallet success payloads` and strict model tests must grow with every new response mapper. |
| CODE-018 | P2 | Verified | LSP ownership is split into focused address, APay, asset-bridge, connection, relay, transport, type, asset-selection, and verifier modules. The public orchestrator remains small, dependencies point toward contracts/pure policy, and hardening plus the dedicated LSP matrices gate the boundaries. | Keep new behavior in the focused owner rather than regrowing `utexo_lsp.dart` or mixing HTTP wire parsing with funds verification. |
| CODE-019 | P2 | Verified | The old API snapshot relied on textual matching and could miss part files or signature-shape drift. The schema-v2 snapshot is generated from Dart AST declarations, includes stable/advanced wallet and LSP signatures plus Pigeon/native markers, and can change only through explicit `--update`; the default command is check-only. | Review snapshot diffs as API changes, never regenerate them as an unexplained test fix. |
| CODE-020 | P2 | Verified | Tracker governance drifted after the beta.32 implementation: rollups, open-work groups, baselines, and evidence contradicted the ledger. Governance now requires P0-P3 and every status count, rejects duplicate IDs, and requires every unresolved row exactly once in the dependency-ordered work table. | Update this tracker in the same change as implementation and evidence; a stale green narrative must fail validation. |
| CODE-021 | P2 | Verified | Running `dart doc` created an untracked `doc/api/` tree in release worktrees, contaminating clean-candidate checks with generated output that is never package source. `.gitignore` now excludes only that generated directory while retaining authored documentation under `doc/`. | Keep generated documentation out of commits and prove documentation health through the zero-warning `dart doc` gate. |
| DOC-001 | P1 | Verified | Root README claimed release-candidate hardening and 55/55 beta.19 parity after upstream changed. | README now states the exact audited baselines, no-go verdict, and limits of existing test/parity evidence. |
| DOC-002 | P2 | Verified | Sixteen overlapping historical docs were removed in favor of this tracker. | Keep this file authoritative; do not recreate parallel status documents. |
| DOC-003 | P2 | Verified | Example and test-matrix READMEs previously treated mocked/matrix checks as production evidence. | Both now state their exact scope, stale baseline, missing evidence, and authoritative release-gate link. |
| DOC-004 | P2 | Verified | `doc/INTEGRATION_SECURITY_AND_RELEASE.md` now documents the current toolchain baseline, support matrix, iOS 18.5 artifact floor, deterministic artifact acquisition modes, production provenance blocker, artifact upgrade procedure, clean consumer matrix, CocoaPods validation policy, transport policy, secure-storage boundary, local release gates, and API policy summary. | Keep public per-symbol API documentation under CODE-007; update this guide whenever artifact, platform, or release policy changes. |
| DOC-005 | P2 | Verified | `doc/RELEASE_EVIDENCE_SCHEMA.md` now defines documentation completeness criteria beyond `dart doc`: lifecycle prerequisites, platform support, units, side effects, error categories, unsupported behavior, secret handling, and executable or manually verified snippets for stable facade symbols. | Complete per-symbol public docs under CODE-007; `dart doc` remains only syntax/link evidence. |
| DOC-006 | P2 | Verified | GitHub issue templates referenced the deleted parity matrix, omitted exact baselines, and allowed tests to be deferred without release-gate semantics. | Templates now require tracker IDs, immutable baselines, typed cross-platform scope, executable evidence, and tracker updates. |
| DOC-007 | P1 | Verified | This row established consistent beta.27 documentation and exact report-to-`HEAD` evidence language. It is now historical; `DOC-010` owns beta.32/core beta.9/RLN 0.13 documentation truth, and `TEST-036` owns current clean evidence. | Keep docs updated whenever public model/API behavior changes; current baseline truth is guarded by `validate_release_language.dart` and `validate_release_governance.dart`. |
| DOC-008 | P1 | Verified | The tracker contained verified rows that still described removed aliases or demanded unfinished work, and its evidence counts predated the current facade. Rows now describe implemented behavior, accepted constraints remain explicit, and governance rejects duplicate issue IDs. | Keep tracker updates in the same change as code, tests, snapshots, and release evidence. |
| DOC-009 | P2 | Verified | Historical evidence commands in the authoritative tracker embedded a previous contributor's absolute checkout path, leaking workstation identity and making the commands non-portable. | All RN checkout references now use `<rgb-sdk-rn-checkout>`; the release package identity scan and final tracked-file review contain no previous contributor names or email addresses. |
| DOC-010 | P1 | Verified | Reopened by 2026-09-20 audit (AUD-30): Public README examples do not compile or use actual facade names. Earlier evidence: README, public API reference, compatibility/divergence guide, bridge contract, integration/release guide, matrices, changelog, and this tracker now describe beta.32/core beta.9/RLN 0.13, detailed refresh, linked/canonical assets, relay/APay invariants, transport ownership, and upstream exclusions. Public-doc validation covers 217 stable symbols. | 2026-09-20 corrective verification (working tree, not release qualification): README examples use actual facade names, named unlock arguments and replenished restart credentials. Real fenced examples compile with zero diagnostics; dart doc reports zero warnings/errors. |

## Accepted Decisions and Constraints

1. **Local backup/recovery:** keep `createBackup`/`rlnBackup` explicitly
   native-blocked. This is honest parity with actual native behavior, but it
   forbids recovery-ready and mainnet-production claims.
2. **Native CI:** do not run native builds or regtest smokes in CI. They remain
   mandatory local release gates with auditable evidence.
3. **Bridge technology:** keep Pigeon for this release line. UniFFI-Dart may be
   evaluated separately; a bridge rewrite does not replace API/model/lifecycle
   correctness work.
4. **Artifacts:** upstream artifacts are acceptable for development and
   internal beta only. Production requires provenance, compatibility, and
   reproducibility gates.
5. **Secure storage:** durable credential storage is app-level. The SDK remains
   responsible for minimizing in-memory secrets and documenting ownership.
6. **RGB `skipSync`:** keep fail-fast until the native artifact adds real
   support. RN silently discards the option on both platforms, which is
   not behavior Flutter should copy.

## Upstream Defects We Must Not Copy

The RN `dev` branch is the parity reference, not an automatic quality oracle.

| Upstream issue | Flutter policy |
| --- | --- |
| RN/core says lifecycle init/dispose is idempotent/retryable, but RN implementation does not fully enforce it | Implement the stronger core invariant and test failures/concurrency |
| Core declares `createBackup` implemented; current RN native bridge throws | Preserve explicit native-blocked status |
| RN artifact downloader skips existing iOS frameworks and lacks checksum verification | Verify before reuse |
| RN release workflow publishes after build without the full native/regtest/security matrix | Use the stronger Flutter local release gate |
| RN also truncates fractional fee rates | Fix the contract instead of reproducing the bug |
| Core/RN error and LSP-body handling is not sufficient for wallet secrets | Apply Flutter-specific redaction and diagnostics policy |
| Core LSP also uses broad fallback, empty-preimage claims, substring error matching, and wall-clock polling | Keep parity at the public contract while fixing unsafe orchestration behavior |
| Core `toNetworkName` also misclassifies network-like strings through substring heuristics | Flutter's public helper intentionally uses exhaustive exact mapping with invalid-value vectors |
| RN also accepts `gossipRgsServerUrl` for native external-signer unlock and silently drops it in both native plugins | Reject unsupported configuration or add real upstream support; do not claim the option was applied |
| RN also uses conflict-string heuristics around lifecycle operations | Require typed errors and verified state transitions |
| RN accepts RGB `skipSync` but omits it from both native `SendRgbRequest` constructions because the pinned RLN artifact has no such field | Preserve Flutter's explicit fail-fast behavior until the artifact supports it |

## Current Release State Definition

For the current internal-beta line, this tracker is complete when every row is
`Verified` or `Accepted constraint`, the issue rollup reports zero open rows,
and the exact local release-candidate report records the current committed
`HEAD`, a clean worktree, zero failed steps, and `releaseEligible: true`.

That condition was satisfied for the historical RN beta.27 candidate. It is not
yet satisfied for RN beta.32/core beta.9/RLN 0.13: `BASE-010`, `PKG-018`, and
`TEST-036` remain unresolved, and `LSP-019` remains blocked on an upstream
idempotency or reconciliation contract.

Funds-bearing/public production approval requires more than the current
internal-beta definition. Before that claim can be made, the accepted
constraints must be re-reviewed, and PKG-006 must move from
`Accepted constraint` to `Verified` with production supply-chain mode passing
against verified upstream signatures, pinned trusted signing identities, and
reproducible-build/source attestations for every native artifact.

Any future RN/core/RLN change, public API change, native artifact change,
security policy change, or evidence gap must reopen the relevant row or add a
new row before the README, changelog, or release verdict is updated.

## September Remediation Register

This register preserves every numbered audit finding. Status is owned by the
linked master-ledger row, not by a second parallel tally. References identify
the audited source; line numbers can move as fixes land. Each completion must
record commands/results here before changing its owner to Verified.

### AUD-01: Invalid send deadline still dispatches the send

Owner: `LIFE-011`. Audit priority: P1.

**Reproduced, Flutter-specific.** [RLNBinding queues the operation first](lib/src/binding/rln_binding.dart:78), then rejects a nonpositive timeout at line 93. With `sendTimeout: Duration.zero`, the caller gets a validation failure, but the queued fake-native send still executes once. An application could retry believing validation prevented any side effect.

Fix: validate the policy before scheduling or changing the queue. Add invalid-deadline tests across all mutation families that assert zero native invocations. Never equate a validation exception with non-dispatch unless this is guaranteed.

### AUD-02: Failed reinit can orphan a native signer after successful destroy

Owner: `LIFE-007`. Audit priority: P1.

**Reproduced, Flutter-specific.** [Reinit failure clears the node identity](lib/src/wallet/utexo_wallet_lifecycle.dart:152); [destroy disposes the signer only when that identity exists](lib/src/wallet/utexo_wallet_lifecycle.dart:212). A created/attached external signer survives failed unlock, node cleanup, and a later successful terminal `destroy()`.

The mock-host test leaves signer 99 in the host store and the wallet reports disposed. Signer ownership must be independent of a live node ID, with retryable cleanup after partial initialization and attachment failures.

### AUD-03: Stable signer lifecycle bypasses configured operation deadlines

Owner: `LIFE-004`. Audit priority: P2.

**Reproduced for password and external-signer unlock.** [Facade unlock](lib/src/wallet/utexo_wallet_lifecycle.dart:86) delegates directly through the signer host/client rather than the deadline-aware binding. With a 5 ms unlock policy, both tested calls remain pending after 1,000 ms of virtual time, also holding queued shutdown/destroy until the mock resolves. Initialization uses the same direct boundary but was source-reviewed rather than independently timed.

The accepted lack of native cancellation does not justify failing to apply the promised Dart deadline. Unify dispatch/deadline/unknown-outcome semantics while retaining ordered native completion and cleanup.

### AUD-04: iOS engine-detach cleanup is not registered for notification

Owner: `LIFE-009`. Audit priority: P1.

**Source-confirmed against the pinned Flutter engine contract.** [Plugin registration](ios/Classes/RgbSdkFlutterPlugin.swift:5) sets up Pigeon but does not publish the plugin instance. Flutter calls `detachFromEngine` on published plugins. The cleanup method therefore is not enough to ensure cleanup when an engine is destroyed without explicit wallet disposal.

Register lifecycle ownership correctly and verify engine destruction/recreation with actual node/signer handles. Coordinate this with engine-scoped stores; simply enabling global cleanup could affect another engine.

### AUD-05: Android detach is neither an in-flight barrier nor engine-scoped

Owner: `LIFE-009`. Audit priority: P1.

**Source-confirmed; no device race reproduction.** [Detach unregisters handlers and clears the global store](android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbSdkFlutterPlugin.kt:1412). An already-running create can insert a node after cleanup. Separately, detaching one engine clears handles owned by another engine because store ownership is global.

Use engine ownership and a closing generation/barrier. Test pending create/attach work during detach and two simultaneously active engines, including failure paths.

### AUD-06: Reused handle IDs let an old wallet destroy a replacement

Owner: `LIFE-010`. Audit priority: P2.

**Source-confirmed, shared design risk with RN.** [Swift store](ios/Classes/RlnNodeStore.swift:30) and [Kotlin store](android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnNodeStore.kt:29) reuse the same identifier after shutdown/same-path replacement. Wallet A can shut down, wallet B can reopen the path under the reused ID, then A's delayed destroy removes B's active node.

Use generation-safe handles or enforce explicit exclusive ownership through transfer/destruction. Single app-owned runtime discipline reduces exposure but does not establish a safe public SDK contract.

### AUD-07: Disposal retains avoidable unused secret references

Owner: `SEC-002`. Audit priority: P2.

**Source-confirmed.** [PasswordRlnSigner](lib/src/wallet/rln_signers.dart:149) inherits no-op disposal: init followed by destroy without unlock retains its password; failed initialization can retain its mnemonic. [NativeExternalRlnSigner.dispose](lib/src/wallet/rln_signers.dart:295) does not clear unused `_seedHex`. The wallet retains the signer object after disposal.

Clear SDK-owned secret references on all terminal/error paths and release the signer reference after successful cleanup. This is distinct from the unavoidable limitation that immutable Dart strings cannot be guaranteed zeroized.

### AUD-08: Relay quote verification does not bind the selected funding asset

Owner: `LSP-012`. Audit priority: P1.

**Reproduced with Dart and core fixtures; inherited upstream.** [Orchestration resolves `payWithAssetId`](lib/src/lsp/utexo_lsp_relay.dart:28) but never gives it to [the verifier](lib/src/lsp/lsp_quote_verifier.dart:78). A request selecting asset A accepts a response whose signed inbound invoice and echoed inbound leg consistently specify C. The resulting quote is marked verified and the payment path submits C's invoice.

Other invariants remain valid in the reproduction. Financial impact requires a misbehaving LSP and a payable substituted asset; no funded exploit was run. Verify against caller-selected funding asset, not only agreement between two server-provided values. Submit the equivalent fix upstream rather than preserving the defect for parity.

### AUD-09: Default own-receive invoice is not bound to the local wallet identity

Owner: `LSP-014`. Audit priority: P1.

**Reproduced in Dart with valid fixture proof signatures; inherited source omission in core.** [requestExternalInvoice without an address](lib/src/lsp/utexo_lsp_address.dart:138) resolves an address for wallet A, but [proof verification](lib/src/lsp/lsp_address_quote_verifier.dart:219) only binds recipient B to discovery B. It does not require that recipient to be A. A wrong-account lookup can yield a valid invoice for another recipient presented as this wallet's receive invoice.

Carry the expected local node key through the own-address path and enforce it on lookup/discovery/proof. Preserve explicit other-address use cases. Native payment to the returned fixture was not exercised.

### AUD-10: Supported same-asset `Any` receives are rejected after the mapping request

Owner: `LSP-024`. Audit priority: P1.

**Reproduced compatibility difference with decoded fixtures.** [Receive request](lib/src/lsp/utexo_lsp_asset_bridge.dart:52) can omit assignment. [Flutter verification](lib/src/lsp/utexo_lsp_bridge_quote_verifier.dart:240) nevertheless unconditionally requires a positive `Fungible` assignment. A same-asset/payout fixture decoded as `Any` is rejected after the mocked mapping endpoint returns. Core accepts the response without decoding its RGB invoice; no real `Any` invoice was parsed by core. Source order places this verification after the real mapping mutation in production, but no real mapping was created during the audit.

The inspected LSP source preserves `Any` for non-converted receives; the deployed-server revision was not verified. Define verification by flow: preserve supported open/same-asset receives while requiring fixed, bound amounts where conversion requires them. Do not remove the other integrity checks wholesale.

### AUD-11: LNURL error envelopes become misleading protocol exceptions

Owner: `MODEL-028`. Audit priority: P2.

**Reproduced, Flutter compatibility difference.** HTTP 200 `{"status":"ERROR","reason":"hash_pool_empty"}` reaches [the callback parser](lib/src/lsp/lsp_types.dart:393), which requires an invoice before interpreting failure. Flutter throws about missing `pr`; core retains the business error/reason.

Parse the error/success union first. Expose a typed failure retaining safe business status so callers can distinguish hash-pool exhaustion from malformed success data.

### AUD-12: Liquidity wait only examines the first usable channel

Owner: `LSP-015`. Audit priority: P2.

**Reproduced in Dart/core; inherited.** [Channel selection](lib/src/lsp/utexo_lsp_connection.dart:114) uses `firstOrNull`. Two usable peer channels with 1 and 1,000,000 msat produce a false timeout for 500,000 msat when the smaller channel is first.

Select a sufficient individual channel or the largest eligible one. Do not sum channels without a supported multipath-payment contract. `isUsable: false` is already handled correctly and is not this bug.

### AUD-13: Polling deadlines/cancellation do not bound an iteration

Owner: `LSP-015`. Audit priority: P2.

**Deadline overrun reproduced; cancellation consequence source-confirmed; inherited structure.** [Polling loops](lib/src/lsp/utexo_lsp_connection.dart:25) check before awaited work, then can accept success after the configured deadline or cancellation. A 20 ms deadline accepted success after a roughly 150 ms hook.

Define whether timeout is an overall deadline or polling budget. Enforce the documented deadline across awaits and recheck cancellation before success; preserve unknown-outcome semantics for native calls already dispatched. Cover channel, liquidity, and settlement waits.

### AUD-14: Status lookup accepts another payment's hash

Owner: `LSP-010`. Audit priority: P2.

**Reproduced; inherited response-integrity weakness.** [lightningSendStatus](lib/src/lsp/utexo_lsp_client.dart:400) requests hash A but accepts a response for B with status settled. This permits wrong-row/cache results to pass through.

Bind response ID to requested ID. This is an identity check, not proof that an LSP's settlement claim is independently trustworthy; final settlement still needs appropriate wallet evidence.

### AUD-15: Diagnostic serialization bypasses secret redaction

Owner: `SEC-004`. Audit priority: P1.

**Reproduced on two independent HTTP paths and a synthetic native error.** [Base exception JSON](lib/src/errors/rgb_sdk_exception.dart:15) serializes `cause.toString()` verbatim. Malformed secret-bearing HTTP JSON becomes a `FormatException` whose source snippet leaks through `LspError.toJson()['cause']`, although its displayed message/body are redacted. Separately, [truncating before redaction](lib/src/lsp/utexo_lsp_client.dart:575) can expose a sensitive value prefix when its closing delimiter falls beyond the preview boundary. Native error message/details are also preserved without a central safe diagnostic boundary.

Use structured allowlisted diagnostics; redact before truncation and never serialize arbitrary causes or raw native payloads. Keep developer-only causes separate from safe public serialization. All probes used synthetic values, not user secrets.

### AUD-16: iOS flattens native enum cases into `RlnError`

Owner: `CODE-014`. Audit priority: P1.

**Source-confirmed against current generated Swift and RN helper.** [errorClassName](ios/Classes/RgbSdkFlutterPlugin.swift:281) returns the enum type, not its case. `Conflict`, `NotFound`, and `InvalidRequest` therefore lose category information, producing generic node errors. The message extractor also looks for an outdated `details:` representation instead of the actual associated message contract.

This affects conflict/retry handling, including already-connected logic. Match exact generated enum cases and extract associated messages deliberately. Test every native category through the actual Swift bridge, not only manually constructed Dart exceptions. RN's Swift helper preserves case identity.

### AUD-17: Native error taxonomy omits current native cases

Owner: `CODE-014`. Audit priority: P2.

**Source-confirmed.** [Dart fallback taxonomy](lib/src/errors/native_bridge_error_mapper.dart:92) and native category tables do not classify current names such as `FailedPeerConnection`, `FailedBitcoindConnection`, and `UnsupportedInExternalSignerMode`. Even after correcting iOS case extraction, these become generic native errors rather than appropriate network/unsupported errors.

Maintain one explicit category contract against the pinned generated native enum and test complete case coverage. Do not derive mutation retry safety solely from an error category.

### AUD-18: RN-compatible error names have incompatible base type/status defaults

Owner: `API-026`. Audit priority: P2.

**Reproduced.** [NetworkError and other aliases](lib/src/errors/rgb_sdk_exception.dart:155) extend `RgbSdkException`, not `SDKError`. Catching `SDKError` misses them, unlike core. `BadRequestError`, `NotFoundError`, and `ConflictError` default to null status rather than core's 400/404/409.

Make the error hierarchy and default metadata match the promised contract while retaining Dart-specific extra context. Test catches and serialization, not just class names.

### AUD-19: Fee-rate boundary can trap on iOS or clamp on Android

Owner: `MODEL-014`. Audit priority: P2.

**Source-confirmed with isolated Swift numeric reproduction.** [Swift conversion](ios/Classes/RgbSdkFlutterPlugin.swift:242) admits `Double(UInt64.max)`, which rounds to 2^64, then converts with a trapping UInt64 initializer. Kotlin's signed bound also rounds and `.toLong()` saturates. [Dart validation](lib/src/wallet/wallet_policy.dart:102) has no matching upper bound.

The isolated Swift check confirmed guard acceptance and `UInt64(exactly:) == nil`; no application crash was deliberately triggered. Establish a consistent exact range and reject before dispatch; test adjacent representable boundary values on both platforms.

### AUD-20: Malformed numeric wire amounts can silently saturate

Owner: `MODEL-002`. Audit priority: P2.

**Reproduced defensive parsing defect.** [Raw integer helpers](lib/src/models/rln_models.dart:35) accept a finite integral double then use `.toInt()` without a range check. An out-of-range balance double becomes `9223372036854775807` rather than failing. The string path is stricter.

Current native bridges normally encode large unsigned values as strings, so this is not evidence of ordinary valid balances being corrupted. Make all wire representations fail closed on overflow and keep raw BigInt versus stable signed-int policy explicit.

### AUD-21: Password RGS configuration is incorrectly blocked

Owner: `API-030`. Audit priority: P2.

**Source-confirmed all the way to pinned native consumption.** [resolveUnlockConfig](lib/src/wallet/utexo_unlock_config_resolver.dart:7) rejects every nonempty `gossipRgsServerUrl` and later writes null. Both Flutter password bridges forward the field, and native password unlock constructs `RapidGossipSync` and fetches/applies its snapshots.

The external-signer UniFFI method really does discard this option, so that signer-specific restriction remains correct. Reopen API-030, preserve password forwarding, retain external-signer fail-fast, and correct the divergence docs and rejection test. [Native consumer](https://github.com/UTEXO-Protocol/rgb-lightning-node/blob/af03c7f1a65135a429f05a5820600338215954dc/src/gossip.rs#L108).

### AUD-22: Stable transfer model drops `requestedAssignment`

Owner: `MODEL-012`. Audit priority: P2.

**Source-confirmed, also omitted by current RN mapper.** [CoreTransfer](lib/src/models/utexo_core_models.dart:197) and its adapter omit a field that raw/native preserve and core beta.9 declares. Pending requested receives can lose requested amount/type before actual assignments exist.

Preserve the optional domain field and its units; test null/Any/Fungible cases. This is a core-model completeness issue inherited from RN, not a missing Flutter native method.

### AUD-23: Failed consumer builds can be recorded as passed

Owner: `PKG-016`. Audit priority: P1.

**Reproduced with exact shell functions and stub commands.** [run_step](tool/test_clean_consumer_matrix.sh:38) disables `errexit`; [build_consumer](tool/test_clean_consumer_matrix.sh:217) does not propagate each command failure. Injected exit 41 from pub get, analyze, APK, or iOS build on Darwin was overwritten by later success. Linux APK failure was overwritten by the final false Darwin `if`. All five probes recorded exit 0 and `FAILED=0`.

[Native iOS runner](tool/test_native_ios.sh:59) has the same class of failure masking for setup followed by xcodebuild. Use explicit failure propagation or isolated fail-fast subprocesses and regression-test every stage. These probes do not claim that an actual archive failed this turn; they prove the gate would hide one.

### AUD-24: Required skips can still produce `releaseEligible: true`

Owner: `TEST-012`. Audit priority: P1.

**Reproduced.** [Required-skip handling](tool/test_release_candidate.sh:101) leaves `FAILED=0` with `ALLOW_SKIPPED_RELEASE_GATES=1`, and [eligibility calculation](tool/test_release_candidate.sh:212) then accepts a clean tree. Probe output: `status=passed releaseEligible=true skipped_exit=125`. Consumer archives can also be disabled while the parent accepts the child exit code.

Diagnostic runs may continue after skips, but must never become release-eligible. Require complete child evidence, not exit code alone. TEST-012/TEST-017 claims are stronger than this implementation.

### AUD-25: Evidence attribution is not bound to the final immutable candidate

Owner: `TEST-040`. Audit priority: P1.

**Source-confirmed.** [Release metadata](tool/test_release_candidate.sh:14) records commit and dirtiness only before dependency resolution/generation. [Consumer snapshot](tool/test_clean_consumer_matrix.sh:85) copies working files rather than an immutable commit tree. Subsequent source changes are not rejected at completion.

Execute from an immutable committed snapshot or record/verify the entire source tree at start and end. Bind every child report to that same tree, native artifacts, and baseline. Do not attribute working-file results to an earlier HEAD by convention.

### AUD-26: Log hashes and child report schema are not reliably enforced

Owner: `TEST-041`. Audit priority: P1.

**Source-confirmed with historical report mismatch checks.** [Report hashing](tool/test_release_candidate.sh:217) occurs before final output and `tee` completion. All three inspected August 6 combined reports had final log hashes different from the recorded hashes. Required toolchain/host/device/stack/artifact fields from the evidence schema are also absent or not enforced across child reports.

Finalize logs before hashing, validate the evidence schema, record every relevant binary/tool/device/stack identity, and verify child attribution/completeness. Historical passes remain historical, but their evidence must not be overstated as cryptographically bound.

### AUD-27: Test-matrix labels can pass without executable scenarios

Owner: `TEST-042`. Audit priority: P2.

**Source-confirmed.** [Matrix validation](tool/validate_test_matrix.dart:172) checks test identifiers in some source languages, but shell evidence can pass with file existence alone. Funded HODL/VSS-recovery scenario names are not actually implemented by their referenced shell entrypoints. APay evidence marked platform smoke points to Dart tests. [Bridge-vector validation](tool/validate_bridge_vectors.dart:64) does not enforce required vector coverage per family.

Use explicit executable test IDs and suite types, validate required family/vector membership, and distinguish unit, bridge, live-service, restart, and funded results. A catalog row cannot substitute for a passing scenario.

### AUD-28: Coverage validator accepts incomplete, unattributed LCOV

Owner: `TEST-043`. Audit priority: P2.

**Reproduced using the permanent checkout's old LCOV.** [Coverage policy](tool/validate_coverage_policy.dart:95) trusts supplied source records. August coverage still passes today while omitting 14 current non-generated LSP files, including APay/address/relay/bridge code.

The fresh 223-test run did generate current coverage and passed at 83.5%; this finding does not invalidate that run. Require current source inventory, fresh run/commit attribution, and a deliberate exclusions policy before accepting LCOV as release evidence.

### AUD-29: Production provenance gate trusts status assertions

Owner: `PKG-019`. Audit priority: P2.

**Source-confirmed; not bypassed against a real release.** [Supply-chain validator](tool/validate_supply_chain.dart:256) counts `status: verified` fields for signatures, attestations, and reproducibility instead of independently validating the evidence. Changing the six status fields would satisfy that provenance subgate without cryptographic proof.

Current unverified statuses correctly keep production blocked. The enforcement weakness is distinct from accepted PKG-006: implement trusted-key/signature/attestation verification before this gate can authorize production. Current vulnerability inventory also covers Pub, not every Maven/Rust/native transitive dependency; no specific native vulnerability was established.

### AUD-30: Public README examples do not compile or use actual facade names

Owner: `DOC-010`. Audit priority: P2.

**Source-confirmed.** [README unlock example](README.md:141) passes positional config to a named `config:` API; line 178 similarly miscalls reinit. Password restart must replenish the consumed password. The Lightning section names nonexistent facade methods rather than `createLightningInvoice`, `payLightningInvoice`, and `decodeLnInvoice`.

Compile documentation snippets as tests/examples. Existing documentation validation checks symbol mentions and Dartdoc link/syntax health, not the correctness of the getting-started workflow.

### AUD-31: New LSP/APay/linked success platform scenarios do not exist

Owner: `TEST-036`. Audit priority: P1.

**Test implementation gap, not simply an unexecuted gate.** The two current integration files declare five tests: generic metadata/lifecycle/facade/funded NIA-Lightning behavior plus external-signer restart. The funded path uses one NIA asset, not a linked/canonical conversion. The restart path is BTC. No real LSP fixture is present in the SDK Compose stack.

The beta.9 contract file has 46 deterministic test declarations using fake wallet/client implementations. These are valuable but do not exercise native APay registration/refill/claim, linked/canonical conversion/settlement, external address proofs, and relay payment/status against a real service on Android and iOS. Zero of the 18 core orchestration methods is covered by a real-LSP platform success scenario in the inspected suite; zero of the nine core HTTP methods is exercised against that real service there. This does not mean all native platform tests are absent.

Implement those scenarios and failure/restart/ambiguity cases before collecting qualification evidence. Expand TEST-036; rerunning its existing commands alone cannot close this gap.

### AUD-32: Permanent local iOS artifacts are stale

Owner: `PKG-018`. Audit priority: P2.

**Reproduced local environment gap.** `tool/verify_native_artifacts.sh --ios-only` rejects the installed generated Swift: actual SHA starts `d3d2eea3`, current expected SHA starts `72aee4f1`. The installed XCFramework slices also differ from the current manifest. These are ignored local artifacts; committed pins are current.

Install and verify the entire pinned artifact set before native testing. The downloader correctly verifies before reuse. No local-CocoaPods preparation bug was found: official CocoaPods 1.16.2 runs preparation for local pods. Copying only the current Swift for static parity is not native qualification.

### AUD-33: Exact-current clean native/consumer release evidence remains absent

Owner: `TEST-036`. Audit priority: P1.

**Evidence gap already partly tracked.** The inspected 20 Android and 18 iOS bridge results belong to an earlier dirty September candidate. Clean consumers, funded/unfunded smokes, restart proofs, and combined eligible reports are historical beta.27 evidence, not proof for `a443470`.

After fixing the source and gates, commit one reviewed candidate and run the complete no-skip matrix on it. Include clean path/Git consumers, both bridge suites, four platform funding states, restart proofs, new LSP/APay/linked scenarios, artifact verification, and valid finalized reports. Existing BASE-010/PKG-018/TEST-036 remain open until then.

### AUD-34: Three default indexers differ from the latest core contract

Owner: `API-022`. Audit priority: P2.

**Source-confirmed, Flutter drift despite matching package-version pins.** [Flutter constants](lib/src/crypto/constants.dart:69) use Iris Electrum endpoints for mainnet, testnet, and testnet4. Exact core beta.9 uses `https://esplora-mainnet.utexo.com`, `https://esplora-testnet3.utexo.com`, and `https://esplora-testnet4.utexo.com`. RN consumes the core defaults.

This changes provider, protocol, and connectivity requirements. Align defaults or explicitly justify a supported divergence, and test default resolution by value, not merely export presence. Endpoint availability was not tested during this audit.

### AUD-35: Some valid native UInt64 asset values are unreadable

Owner: `MODEL-015`. Audit priority: P2.

**Source-confirmed range limitation, separate from AUD-20's silent double saturation.** Native serializes upper-half UInt64 values as exact decimal strings, but [raw integer parsing](lib/src/models/rln_models.dart:43) rejects values above Int64.max for many balances/supplies. [Eager asset-list decoding](lib/src/models/rln_models.dart:803) means one such valid asset can fail the whole list.

Signed-int boundaries are documented in part, so this is not undisclosed silent corruption. Full native amount coverage requires BigInt-compatible read models and deliberate consumer semantics, or an explicitly accepted narrower asset range. RN's floating-point loss is not a correctness target. The current policy cannot justify an unrestricted 1:1 value-domain claim.

### AUD-36: Stable network fields are not normalized like RN/core

Owner: `API-010`. Audit priority: P2.

**Source-confirmed.** [Network-info adapter](lib/src/models/utexo_core_models.dart:659), decoded Lightning adapter, and decoded RGB adapter pass native network strings through. RN maps native aliases to canonical names before exposing stable results.

Inputs such as native `Bitcoin` or `SignetCustom` can differ from app-facing `mainnet` or `utexo`. Canonicalize recognized values at the stable adapter, preserving unknown values only according to a documented policy. Keep raw native names available in the advanced API. Internal signed-invoice comparison policy does not automatically normalize public outputs.

### AUD-37: Expanded seed-list input silently wraps invalid byte values

Owner: `SEC-013`. Audit priority: P2.

**Source-confirmed, Dart-specific input extension.** [normalizeSeedInput](lib/src/crypto/keys.dart:123) accepts `List<int>` and calls `Uint8List.fromList` without validating 0..255. Negative/oversized integers wrap, so malformed seed material can become a different wallet identity instead of failing. Core accepts typed byte input, not an arbitrary numeric array.

Validate every element before conversion, or restrict the public contract to typed bytes and documented hex. Add negative/256/large-integer boundary and caller-buffer ownership tests.

### AUD-38: Wallet identity configuration accepts options that are ignored

Owner: `API-045`. Audit priority: P2.

**Source-confirmed.** [UtexoWalletConfig](lib/src/wallet/utexo_wallet_types.dart:24) accepts `xpubVan`, `xpubCol`, and `masterFingerprint`, described as external-signer options. No wallet code consumes them to establish or check identity.

Do not imply that these values validate the supplied signer. Either implement the intended identity checks or remove/reject the inert options with a clear migration note. This is not a claim that RN offers watch-only functionality absent from Flutter.

### AUD-39: Sats-to-msats multiplication can overflow before validation

Owner: `MODEL-031`. Audit priority: P3.

**Source-confirmed defensive boundary defect.** [Invoice creation](lib/src/wallet/utexo_wallet_lightning.dart:13) and [payment](lib/src/wallet/utexo_wallet_lightning.dart:123) validate nonnegativity, multiply by 1000, and validate the already-overflowed result. Under signed-64 arithmetic, `18446744073709552 * 1000` wraps to positive 384.

Check the pre-multiplication limit or use BigInt/exact conversion. The input is far above Bitcoin's total supply; this is not evidence of ordinary payment amounts failing.


### Additional contract and investigation scope

API-046 owns all rows in the audit's additional parity/adaptation table, including
field spellings, node-level local balance, capability carrier signatures, export
placement, constructor adaptation, requested UTXO count and HODL acknowledgement
semantics, raw link metadata and fee defaults. LSP-029 owns the two explicitly
unverified trust/routing questions. These are not silently accepted limitations.

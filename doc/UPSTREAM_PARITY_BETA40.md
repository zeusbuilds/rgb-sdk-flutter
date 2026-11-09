# React Native beta.40 parity and mainnet release disposition

Audit date 2026-11-06. The previous Flutter reference is RN `1.0.0-beta.39`
at `41ff170f794edff2a1822a672ddab37e29505f14`. The registry `latest` tag,
GitHub release, Git tag and default `dev` head identify
`@utexo/rgb-sdk-rn@1.0.0-beta.40` at `5c8b2dfc79844c73e061a3df1ccbfdc1278d3ca7`.
The change comes from [PR 71](https://github.com/UTEXO-Protocol/rgb-sdk-rn/pull/71)
and the subsequent version bump. See the [published release](https://github.com/UTEXO-Protocol/rgb-sdk-rn/releases/tag/v1.0.0-beta.40)
and [pinned changelog](https://github.com/UTEXO-Protocol/rgb-sdk-rn/blob/5c8b2dfc79844c73e061a3df1ccbfdc1278d3ca7/CHANGELOG.md).

```sh
python3 tool/validate_rn_beta40_reference.py --list-changes
```

The verifier checks both source commit archives and the exact published npm
tarball without installing or executing them. The 119 changed paths comprise
67 additions, 22 removals and 30 modifications. A moved file counts as a removal
and an addition. All 76 shared files in the source and npm archives match byte
for byte. The npm tarball also matches its pinned size, SHA-256 and SHA-512
integrity. The archive checks identify the audit inputs. Native publisher
attestations and reproducible consumer-build evidence are separate requirements.
Use the three archive flags for an offline rerun. The previous release baseline
and its parity check still identify the legacy RLN engine.

## Exact dependency boundaries

**November 7 Flutter upgrade:** the released RN identities in this section are
historical immutable parity inputs. Flutter now carries a separately versioned
BFA.7 source overlay, native standalone registration and durable recovery.
See [BFA.7 integration](BFA7_NATIVE_INTEGRATION.md) for current implementation
and qualification limits. The frozen RN/native-reference verifier still checks
the original bytes and separately verifies the Flutter divergence. Earlier
BFA.5 platform tests below do not qualify the new BFA.7 artifacts.

| Reference | Verified identity and applicability |
| --- | --- |
| RN `1.0.0-beta.40` | `RGB_L1` is now the default wallet protocol. `RGB_LN` is optional and disabled at compile time in the distributed configuration. Explicit RLN use retains `0.17.0-beta.3`. |
| RGB_L1 native dependency | `0.3.0-beta.7-upstream-dev-bfa.5-bfa`, source `0a9d352f2690902df2b6fae9bca1a6c13c3354d4`, UniFFI `0.32.2`, bridge contract 4. The library uses RGB `0.11.2-rc.2` and requires proxy protocol 1.0. This remains the newest version in [Maven Central metadata](https://repo.maven.apache.org/maven2/com/utexo/rgb-lib-bfa-android/maven-metadata.xml) on November 7. [Swift BFA.6](https://github.com/UTEXO-Protocol/rgb-lib-swift/releases/tag/0.3.0-beta.7-upstream-dev-bfa.6-bfa) was published on November 6, without a matching published Android archive or standalone genesis registration API. The pinned BFA.5 Swift archive SHA-256 is `44890e57b78935a2c7842d9baeed5172bbd99e9b2b91c6a599fbc2c745760669`; it has not been silently replaced. |
| JS core, WebRGB and WalletConnect | RN still pins core `1.0.0-beta.9` and WalletConnect `0.1.3`. WebRGB peer range is `^0.1.3` with `0.1.3` used to build and test. The behavior changes are in the RN SDK rather than a new core package. |
| RLN PR 212 and prerequisites | [RLN PR 212](https://github.com/UTEXO-Protocol/rgb-lightning-node/pull/212) remains open at `d7802ab8a45b7a072a8c489492ca2152c1c61002`. The RN release explicitly reverted that ABI. The RGB prerequisite branch `98bcbf9973b02fa6e336b6db7c16413825500c85` and LDK prerequisite `44a4d51399036178cd9d4ae2ba539dd47aea691c` are distinct from the BFA.5 archive. Their contract registration, protected sweeps, funding and VSS changes require separate qualification. The rolling RGB branch has advanced beyond BFA.5. |
| Other RN branches | Open [PR 67](https://github.com/UTEXO-Protocol/rgb-sdk-rn/pull/67), [PR 68](https://github.com/UTEXO-Protocol/rgb-sdk-rn/pull/68) and [PR 70](https://github.com/UTEXO-Protocol/rgb-sdk-rn/pull/70) overlap the merged RGB_L1 work and include alternate APIs. [PR 69](https://github.com/UTEXO-Protocol/rgb-sdk-rn/pull/69) closed without merging. `sendrgbinvoice` from the open RLN graph is absent from the released legacy binding. |
| WDK and Iris | `@utexo/wdk-rgb-lightning@0.2.0-beta.5` resolves to `608937d849412a4c25e9b9a66a7571b561396ae0`. The separate `wdk-wallet-rgb` public tag `v2.0.4` is `6d28bc9ff35a7863cd21b21e62a7c03a9b794066`. November 7 [PR 23](https://github.com/UTEXO-Protocol/wdk-wallet-rgb/pull/23) identifies candidate `2.1.0-alpha.12`, BFA.7 source `9ec49c08be2e68f08521281e3efbd760ec989cb9`. Its Bare artifacts and overlays are distinct from Flutter's UniFFI dependencies. Hosted Dev remains disabled; the historical BFA.5 BUSDT is not admitted. Iris public main was `c737bc6939babbfd6720f464841d9b4b1a5a2cb9`. |

## November 7 Dev Signet follow-up

The November 9 team-supplied issuer export and Iris `37003ff` supersede the
unavailable-export finding below. See [the current hosted test profile](PUBLIC_API_REFERENCE.md)
and [NOV-004](RELEASE_READINESS_TRACKER.md) for the current status.

The Iris chat's November 7 configuration and WDK PR 23 superseded the historical
BFA.5 hosted-test preparation. Dev now uses BFA.6 asset
`rgb:A6k89KtR-e3oXqRP-uH3jUrz-LU_sYL3-hMZ0k3O-6u8DXbE` (Bridged USDT / BUSDT).
The issuer-approved contract bytes, SHA-256 and verified precision are absent
from the reviewed inputs. The old export
`rgb:fbkO6B_i-qyLXa6d-x3sAOaX-cx~vZB9-rxNSUle-9lXBTf8` is historical BFA.5
and explicitly unadmitted in Iris. Its precision and digest cannot authenticate
the new asset. See [DevOps 217](https://github.com/UTEXO-Protocol/devops/pull/217)
and [218](https://github.com/UTEXO-Protocol/devops/pull/218).

Dev's block-one checkpoint is
`0000001b808e4ece11c0cd922eaf9eee8d7dfba7e23e90b4f9614248daaf72cb`, distinct
from public Signet. Its current HTTPS Esplora and protocol-1.0 RGB proxy cannot
be substituted for public Signet or an older RLN proxy. Arbitrum chain `42161`
is the separate backing chain. The SDK now rejects the unqualified RGB_L1
`utexo` profile before key reads/native wallet opening and known Dev service
overrides before connection. The legacy RLN `utexo` alias remains usable with
explicit compatible public Signet services. Arbitrary independently configured
endpoints remain a caller-owned qualification responsibility.

The evidence manifest records requirements without admitting an asset. The
new BFA.7 Flutter source implements native genesis registration, checkpoint
guards and durable payment identity/recovery with matching mobile bindings.
Exact-artifact, funded deployment and restored-backup freshness qualification
remain prerequisites for activation. The [latest referenced Dev E2E](https://github.com/UTEXO-Protocol/bridge/actions/runs/42261217049)
failed while waiting for the web UI mint-confirmation button; this does not
prove a native mint or chain-settlement failure. Aster's RGB_L1 gate stays closed.

## Changed behavior and verification

Statuses distinguish the previously shipped legacy behavior, the new RGB_L1
integration and outstanding verification. The release boundary is Aster BTC
and configured USDT transfers on Bitcoin mainnet. SDK-only features still have
explicit dispositions because they affect the SDK's compatibility surface.

| Area | RN beta.40 behavior | Flutter or Aster disposition |
| --- | --- | --- |
| Wallet facade and protocol selection | Options and generic type default to `RGB_L1`. RLN uses an explicit protocol and signer marker. The two-argument legacy constructor still selects RLN. Shared aliases preserve subclass dispatch. | SDK adds an explicit typed `RgbLibWallet` with its own lifecycle. Existing `UtexoWallet` callers retain the established RLN API. Verify absence of hidden backend or storage fallback. |
| Build-time and runtime capability | No RLN download, Maven resolution, native compilation or mandatory module import by default. A requested missing engine fails with `NATIVE_BACKEND_UNAVAILABLE`. | Flutter adds RGB_L1 alongside the legacy plugin for source compatibility. RGB_L1 verifies artifact version, revision and bridge version before reading keys. Host tests cover absent and mismatched modules. A dedicated RGB_L1-only app release still needs packaging and qualification. |
| Native build, ABI and metadata | Version/revision come from native artifact metadata. Kotlin package is `com.utexo` and the binding loads its own library. JNA is explicit, the RGB_L1 AAR omits `libc++_shared.so`, and R8 retains its interface. Swift uses `RGBLib` plus `rgb_libFFI`, handles unknown enum cases and requires iOS 16. RGB_L1 Android ABIs are `arm64-v8a` and `x86_64`. | The SDK pins both archives separately from RLN. The verified BFA.5 AAR contains 16 KiB-aligned ELF segments for both its ABIs. A checksum-verifying installer generated iOS device arm64 and simulator arm64/x86_64 slices. Minified native loading passed on Android 17 with real 16 KiB pages. Final Aster split APK/AAB and signed iOS archive verification remain release gates. |
| Swift install and privacy | Installer checks the published Swift ZIP and builds frameworks. The pod bundles timestamp `C617.1` and disk-space `E174.1` reasons. | Verify platform artifacts and approved required-reason use against the exact Flutter native link and app archive. RN's declaration establishes the reference to inspect. The legacy RLN privacy blocker still applies to a build linking RLN. |
| Lifecycle, ownership and recovery | Serial operations and request snapshots, per-directory leases, profile identity checks, one in-flight init/connect, shutdown draining, safe reinit, terminal dispose, cleanup on rejected native keys. | Flutter RGB_L1 implements serial operations, open and close lifecycle, typed failures and cleanup fences. Both bridges claim a private engine-specific directory. Aster stores the backend with each wallet profile and rejects an unqualified selection before native work. Funded process-kill and restore proof remain open. |
| Key modes | Mnemonic, callback returning optional mnemonic, mnemonic object and validated watch-only xpubs/fingerprint. A failing reader yields `KEYS_UNAVAILABLE`; malformed identity or conflicting keys fails before use. Watch-only reports unsupported signing capabilities. | Flutter exposes mnemonic, reader and validated watch-only modes with sanitized typed failures. Host tests cover wrong native identity, reader errors and refusing signing before connection. Native verifies mnemonic/public key agreement. |
| Network and configuration | Shared defaults for mainnet, public Signet and UTEXO Dev Signet. Electrum, Esplora and authenticated bitcoind configs, normalized proxy URLs, EVM chain-ID map and proxy auth keys. Offline work after init, lazy online connection except regtest, explicit endpoint override, `checkIndexerUrl` on both protocols. Native height remains optional. | Flutter uses separate RGB_L1 and RLN defaults to preserve each protocol's existing endpoints. The on-chain SDK exposes typed indexers, explicit endpoint/EVM/proxy-auth overrides, serialized connection and lazy online access except regtest. RGB_L1 preserves the explicit custom Signet identity for `utexo` and the public Signet identity for `signet`. Aster release still requires deployment identity and supported endpoints. |
| BTC reads, fees and UTXOs | `skipSync` on balances, transactions, UTXOs and createUtxos. `createUtxos` returns native actual count on RGB_L1; legacy bridge counts new colorable UTXOs atomically. Fee estimates round up, malformed native balance throws. | Flutter implements read options, integer fee estimates and serialized counted UTXO creation on both engines. Host tests verify that a timed-out preliminary read cannot authorize late creation. Funded mobile UTXO counts and fee settlement still need qualification. |
| RGB receives, invoices and sends | Assignment kinds include Fungible, NonFungible, InflationRight, MintRight and Any; MintRight requires RGB_L1. Full invoice, expiry, recipient, batch ID and explicit witness output preserved. Invoice amount can supply an omitted fungible send amount. RGB_L1 always synchronizes sends. | Preserve typed recipient checks and exact satoshi output review in Aster. Keep app Receive witness-only and SDK support for blind. Backend-specific `skipSync` semantics must be explicit. Avoid weakening exact request approval or durable send. |
| RGB history and metadata | Schema filtering, `getAssetMetadata`, exact decimal u64 supplies, exact requested transfer amounts and native statuses. Preserve Mint, Link, MintRight, LinkRight, link metadata, batch IDs and nullable confirmation data. | Verify stable public DTOs with signed-64 and u64 boundary vectors. Display Aster transfer status and actual amount without using change allocations or fabricating amounts. Linked issuance and `link` remain unavailable in the reference. |
| Asset issuance and maintenance | CFA and UDA on both engines, native absolute paths and decoded `file://` URIs, NIA and IFA exact supply validation, inflation, `drainTo`, `deleteTransfers`, `failTransfers`, detailed refresh and sync. | SDK-only features require bridge coverage and preflight for exact amounts, paths, storage and destructive authority. Aster only admits configured BTC and USDT. No asset-issuer or wallet-drain UI follows from parity. |
| Backup and restore | RGB_L1 can back up and restore into an empty store before opening. RLN `createBackup` fails in the facade, unused native stubs removed. VSS `allowEmptyRestore` permits starting empty on failure and can lose funds with channels. | Test funded RGB_L1 backup, wrong password, occupied destination, interrupted restore and reopen of the same asset balances. Keep legacy unsupported backup behavior. Aster seed import alone does not establish recovery of RGB state. |
| BFA proof and burn | Capability-aware burn, exact u64 and hash, consignment path and Base64 retrieval, V1 typed route commitment, legacy EVM/Tron route, durable WebRGB journal, and definitive funding/capability errors classified for cancellation. Watch-only never advertises burn. | Flutter adds RGB_L1 WebRGB and WalletConnect support, explicit deployment-owned V1 routes, preflight capability checks and exact approved commitment validation on journal reload. Legacy routes retain the v2 record format. Proof export consent is session-scoped. Unknown results remain fenced. Aster's product scope covers BTC and USDT transfers. |
| Legacy RLN on-chain updates | Integer native range validation, actual UTXO counts, receive/read options, fee normalization, exact metadata, CFA/UDA file upload and explicit external-signer EVM/RGS rules. | Flutter adds these on-chain options and typed media/metadata APIs while preserving raw methods and exact Pigeon integer checks. External-signer EVM configuration and RGS rejection are already covered by the legacy bridge. |
| Legacy RLN Lightning updates | Inbound Android payment lookup, platform-neutral payment type, invoice descriptions, final CLTV, node and HTLC/channel statistics, xpubs. | Flutter adds invoice description and decoded CLTV parity and retains existing inbound lookup, payment normalization and node metadata. Aster releases only on-chain BTC and USDT. |
| BFA.5 underlying protocol | Allocation-aware input selection, PSBT size bound, reject-list checks on operations, minimum expiry margin, refused over-allocation/frozen receive UTXOs, linked metadata, new mint funding/deadline rules. | Use native checks and propagate failures truthfully. Qualify compatible contracts, fresh invoices, chain-backed mint, regular BTC/RGB sends, stale funding and reorg cases on an authorized compatible fixture. Older RLN and proxy 0.2 evidence do not cover these changes. |
| Generated code, tooling and release layout | Generated DTO/spec drift checks, host stubs and exact native smokes, Maven Android instrumentation, published source excludes tests and local bindings, package cleanup removes unused interfaces/constants and moves legacy sources under opt-in configuration. | The immutable verifier covers every upstream path including the TS-only generator, example, docs and test changes. Flutter's bridge and clean consumer checks remain independently runnable. |

## Production gates

The implementation gaps described below were the beta.40/BFA.5 audit state.
The BFA.7 candidate implements native contract registration, a durable
wallet-bound payment outbox and the gated Aster adapter; those implementation
gaps are superseded by [the current integration record](BFA7_NATIVE_INTEGRATION.md).
Funded platform/reorg/backup-freshness, deployment, privacy and final release
qualification remain gates. Restored snapshots deliberately cannot infer
nonexecution or authorize new spending.

1. **SDK and Aster durable sends.** RN's RGB_L1 send wraps a single native send
   call. It cannot by itself preserve Aster's prepare, commit, lookup and cancel
   protocol when the process dies or a response is lost. Keep the app release
   gated until the exact native operation identity and outcome survive process
   restart, canceled preparation, network interruption and an ambiguous commit.
   A successful response may show submission. Never show confirmation early or
   replay an uncertain mutation.
   BFA.5 UniFFI exposes BTC/RGB Begin and End, signing and PSBT inspection, plus
   pending vanilla listing and abort. The public RN bridge omits these. The
   released UniFFI API also lacks an equivalent authoritative RGB reservation
   lookup and abort contract. A reviewed native outbox can combine fixed
   prepared transaction identity, storage-bound submission and exact outcome
   checks. The private WDK reference demonstrates these ideas with its own
   overlays and wallet journal. Aster rejects `ASTER_WALLET_BACKEND=rgb-l1` in
   both its runtime factory and release configuration until that contract is
   available.
2. **SDK native security and distribution.** Confirm the actual packaged native
   binary, signed or independently verified provenance, license and SBOM
   inventory, advisory resolution, Apple required-reason audit, reproducible
   dependency acquisition and Android 16 KiB runtime with compatibility disabled.
   The exact BFA.5 UniFFI lock reports nine RustSec vulnerabilities, below.
   The release must establish platform-feature reachability and qualify a
   remediated artifact graph before approving remote endpoints.
3. **Deployment compatibility.** Approve a matched mainnet indexer, proxy 1.0,
   canonical USDT contract and required auth/EVM parameters. The published mainnet
   proxy responded to `server.info` with protocol 1.0 in a read-only probe. The
   reference Electrum TLS endpoint timed out from this host. That probe cannot
   approve wallet access or funded interoperability. Existing regtest and Signet
   contracts cannot identify the production asset. An independent private WDK
   fixture reported that two legacy Signet USDT exports were rejected by the
   newer strict consignment codec. Require same-generation confirmed proof and
   preserve asset identity throughout deployment. The official BFA.5 UniFFI
   surface lacks Aster's existing genesis-only canonical contract registration
   operation. Validate a released native registration path or an authoritative
   received consignment against the configured asset ID before admission.
4. **Aster integration.** Pin one immutable SDK candidate, wire the supported
   engine into normal create/import, address, balance, fee, transfer and history
   flows, and keep wallet storage disjoint. Qualify app lock, switching,
   restarts, wallet restore and privacy with that exact candidate. The currently
   installed public Signet build and previous RLN regtest qualification do not
   exercise RGB_L1.
5. **Clean end-to-end acceptance.** Funded BTC/USDT on iOS and Android with
   matching endpoint/contract generation, exact balances and transaction IDs,
   insufficient fee/expired invoice handling, restart and idempotency faults,
   backup recovery and signed artifact checks. Use only existing compatible
   qualification infrastructure with dedicated wallet data. Public mainnet
   release approval also requires the Aster release checklist.

## Historical BFA.5 native dependency audit

The current BFA.7 lock resolves the listed vulnerabilities. The exact source
and lock review in `native/rgb_l1/security-review.json` records zero known
vulnerabilities and zero unsound notices at RustSec
`309392b18f6b17022f82c701f300433126901068`, with three disclosed unmaintained
dependencies. This does not clear independent privacy or funds-safety gates.
The following table preserves the historical audit rather than implying it
describes the replacement graph.

`cargo audit --no-fetch --file <pinned UniFFI Cargo.lock> --json` failed on
the 547-package lock at SHA-256
`68a48cc0d37e0c6777871d7c5780e92752a3abdaf5b9cae9b0e16807888bb290`.
This digest matches the native baseline. The RustSec database revision was
`263a4d951a0867d4bddc29dddd6d59427c78f9a7` from 2026-11-02. The scan also
reported three unmaintained dependencies and one yanked dependency.

| Locked package | Vulnerability IDs | Release work |
| --- | --- | --- |
| `ctutils 0.4.3` | `RUSTSEC-2026-0385` | Upgrade to a reviewed version with the constant-time mask and comparison fix. |
| `tokio 1.54.0` | `RUSTSEC-2026-0384` | Upgrade the yanked runtime to a reviewed version with the interval race fix. |
| `rustls 0.21.12` | `RUSTSEC-2026-0346`, `RUSTSEC-2026-0349` | Remove the legacy TLS path or update the dependency graph to the fixed release line. |
| `rustls-webpki 0.101.7` | `RUSTSEC-2026-0098`, `RUSTSEC-2026-0099`, `RUSTSEC-2026-0104`, `RUSTSEC-2026-0382` | Resolve legacy certificate validation and revocation handling through the same native dependency update. |
| `webpki-roots 0.25.4` | `RUSTSEC-2026-0381` | Use the fixed trust-root bundle for supported native TLS paths. |

The lockfile identifies affected versions and may include feature-specific and
build-only dependencies. Compile-path strings from the admitted Android arm64
ELF and assembled iOS arm64 framework independently identify `rustls 0.21.12`,
`rustls-webpki 0.101.7` and `tokio 1.54.0` in both native binaries. Establish
individual advisory reachability for the selected features and targets, then
verify artifact provenance, exact ABI, funded operation behavior and the
resolved SBOM. Obtain a reviewed upstream artifact or a separately versioned
and attested build. Local evidence is in the ignored
`.buildlog/upstream-parity-beta40/reference-evidence/` directory.

## Reference tests

At the exact RN commit, a frozen Yarn lock installation with install scripts
disabled followed by `npm test` passed TypeScript checking, the API contract,
generated DTO drift checks, 68 RGB_L1 host tests, 30 RLN host tests, four
missing-RLN host tests and 50 WebRGB host tests. These suites stub native calls.
The source contains separate iOS native smoke and Android instrumentation
tests for artifact provenance, session ownership, malformed dispatch and
reopen. Host reference results cannot establish Flutter native or funded
release acceptance.

Flutter's focused WebRGB and journal suite passed 69 tests. It includes the
independent Go ABI vectors for direct EVM and routed Tron commitments, a mock
RGB_L1 native channel, exact approved route persistence after reopen, early
rejection of altered commitments, watch-only refusal and proof-sharing consent.
Native smoke, funded delivery and signed release evidence have separate scope.


## Historical BFA.5 Flutter candidate evidence

The SDK passed 658 host tests and static analysis. The test matrix, public
API, source snapshot, legacy RN and beta.40 reference checks pass. The
production iOS preflight rejects the current binary pair. The release
bridge-vector check still requires successful VSS platform evidence.

Separate SDK test wallets passed native open, storage exclusion, address
derivation, empty balances and encrypted backup/restore on iOS 27 and
Android 17. Clean consumers built an unsigned arm64 iOS release and a
minified Android arm64 APK. The Android APK passed ELF and ZIP alignment
checks and loaded both engines in one process. A minified headless consumer
also passed on Android 17.2 with 16,384-byte pages, linker compatibility
set to fatal and package compatibility disabled. The iOS public Signet online
probe did not qualify the indexer. These runs establish local compilation,
runtime loading and offline wallet lifecycle. The funded, interrupted-send,
reorg and distribution gates remain open.

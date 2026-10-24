# API Compatibility and Divergence Policy

This document defines how `rgb-sdk-flutter` decides API parity with
`rgb-sdk-rn`, when a Dart-shaped API is allowed to differ, and how breaking
changes are staged. It is a release gate, not background guidance.

## Source Precedence

The October 15 reference is RN beta.39 (`41ff170f794edff2a1822a672ddab37e29505f14`)
with RLN 0.17.0-beta.3 and WebRGB 0.1.3. OCT-024/025 cover direct LSP
mainnet guarding and exact transfer history. Dart `BigInt` is exact throughout;
WebRGB history omits the JS numeric amount above 2^53 - 1, retaining decimal
base units. Native history with unknown/malformed allocations fails closed,
rather than RN's unknown-type-to-Any fallback. Flutter retains the host
payout-chain allowlist that RN beta.36 removed, as an explicit stricter burn
authorization policy. RLN now implements onchain-only mainnet startup, replacing
the OCT-026 native-version freeze. External unlock uses the request API to
forward ethRpcUrl instead of silently dropping it as RN's flat bridge does.
The WebRGB session router is not full WalletKit transport parity: pairing,
proposal/event handling and live relay qualification remain OCT-031.

RN beta.39's Tron burn recipients are supported for mainnet, Shasta and Nile
with checksum/version/nonzero-account validation and case-preserving consent
and journals. Both EVM and Tron v2 payout records require matching native
recipient commitments. Flutter keeps its host-owned chain allowlist and limits
advertised `burnRecipientNamespaces` to that policy; RN advertises both supported
namespaces. Neither address support nor an allowlist validates a redemption
route. Native integer requests continue to use exact signed-64 Pigeon transport
and overflow guards. RN's new JS-safe-number guards prevent JavaScript bridge
rounding; they do not lower Flutter's exact native transport range.

When RN source, core declarations, and native RLN artifacts disagree, use this
order:

1. Native RLN runtime behavior and artifact capabilities.
2. `@utexo/rgb-sdk-core` declarations and mapper semantics.
3. `rgb-sdk-rn` public TypeScript API shape.
4. Existing Flutter compatibility surface.

The native runtime wins because a wrapper cannot honestly support behavior the
pinned artifact does not implement. Core wins over RN naming when core defines
the domain contract and RN is only adapting that contract to React Native.
Flutter compatibility is last and may only remain through an explicit
compatibility or advanced API boundary.

## Approved Divergence Register

Every intentional divergence needs an owner, a tracker row, a test/evidence
reference, and a reversal trigger. New divergences must be recorded before they
ship.

| Divergence | Owner | Tracker | Current decision | Evidence | Reversal trigger |
| --- | --- | --- | --- | --- | --- |
| Durable on-chain operation protocol | Flutter and native maintainers | `ROOT-01` | Add prepare/commit/status/cancel with a strict wallet-bound command and durable native operation identity. This is unpublished; official artifacts remain unchanged and fail unsupported, with no one-shot fallback. | `test/recoverable_onchain_send_test.dart`; separately retained local iOS qualification. Android source is unbuilt and general production readiness remains blocked. | Publish immutable cross-platform native artifacts and re-audit if RN adopts compatible operation recovery. |
| Canonical public contract import | Flutter maintainer | `OCT-038` | Expose `UtexoWallet.importRgbContract` and `rlnImportRgbContract` using the existing RLN API absent from RN beta.39. Require expected asset identity, canonical Base64 bounded to 16 MiB characters and exact typed metadata. | `test/imported_rgb_contract_test.dart`; existing shared-stack iOS 27 / Android 17 canonical BFA import and idempotence assertions. | RN exposes a reviewed compatible wrapper; re-audit the explicit parity extension instead of silently accepting drift. |
| Stable decoded RGB recipient type | Flutter maintainer | `OCT-042` | Preserve native recipient type through optional `CoreInvoiceData.recipientType`; hosts can review witness Bitcoin output value and reject null/unknown kinds before send. | `test/utexo_wallet_test.dart::decoded RGB recipient kinds survive the stable DTO boundary`. | RN/core expose a compatible typed kind; stage a documented migration if adopting a closed enum. |
| `createBackup` / `rlnBackup` | Native artifact owner plus Flutter maintainer | `API-019`, `G-11` | Keep native-blocked and fail before claiming recovery support. | `test/utexo_wallet_test.dart::keeps local backup explicitly native-blocked`; Android/iOS native backup-blocked bridge cases. | Pinned native RLN exposes a working backup/recovery implementation and cross-platform funded recovery tests pass. |
| `sendRgb(skipSync: true)` | Flutter maintainer | `API-006` | Fail fast instead of accepting and silently discarding the value. | `test/rln_client_contract_test.dart::sendRgb rejects skipSync true before native call`; Android/iOS native skip-sync rejection cases. | Pinned native RLN exposes a real skip-sync request field and RN/core define semantics. |
| `gossipRgsServerUrl` unlock field | Flutter maintainer | `API-030` | Forward for password-backed unlock. Reject non-empty values only for native external signers, whose ABI has no RGS argument. | Password forwarding and external-signer rejection tests in `test/utexo_wallet_test.dart`. | Pinned native external-signer unlock consumes the field end to end. |
| Fractional native fee rates | Flutter maintainer | `MODEL-014` | Require integer-equivalent sats/vbyte and reject fractional values before native execution. RN currently defaults some calls to `1.5`, then truncates through the UInt64 bridge; Flutter does not reproduce that data-loss bug. | Dart wallet validation plus mirrored Android/iOS bridge numeric vectors. | Native/core adopt an exact fractional fee-rate representation end to end. |
| High-level CFA/UDA issuance | Flutter maintainer | `API-017` | Expose only through low-level RN-parity `RlnClient`/`RLNBinding`, not the stable wallet facade. | Wallet matrix excludes `issueAssetCfa`/`issueAssetUda`; low-level matrix keeps the RN methods. | RN adds wallet-level CFA/UDA methods or product approves a Flutter-only extension library. |
| Standalone account-key Schnorr signing default | Flutter maintainer plus release security owner | `SEC-007` | Fail closed by default and require `SchnorrSigningMode.experimentalDart` for the pure-Dart signer, even though RN's top-level core `signMessage` is callable by default. Wallet/node-key signing remains native RLN-backed and RN-aligned. | `test/crypto_bip340_vectors_test.dart::standalone Schnorr signing fails closed without explicit opt in`; `test/utexo_wallet_test.dart::signs and verifies RN-core compatible Schnorr messages`; `tool/validate_codebase_hardening.dart`. | Replace the pure-Dart implementation with a vetted/native signing primitive or complete a formal crypto review proving production suitability, then update public docs and parity tests before changing the default. |
| Durable credential storage | Consuming app owner plus Flutter maintainer | `SEC-009` | App-owned storage boundary; SDK owns only in-memory minimization and diagnostics. | `doc/INTEGRATION_SECURITY_AND_RELEASE.md`; release package validation requires `doc/SECURITY.md`. | SDK product scope expands to include a native secure-storage subsystem. |
| Native builds/regtest in CI | Release owner | `TEST-017`, `G-12` | Keep native builds and funded regtest smokes local-only, but mandatory for release evidence. | `tool/test_release_candidate.sh` fails every skipped required gate; no debug override can make it release-eligible. | CI is provisioned with reliable simulators/emulators and a funded regtest stack. |

## Pre-Release Contract Changes

### October Qualification Follow-Up

`OCT-043`: native unspent maps must include `pendingBlinded` in the UInt32
range. Both bridges now forward the released RLN field; missing or malformed
wire values fail closed instead of making reserved outputs appear free.
Advanced bridge mocks must supply zero explicitly when no reservation exists.
Hand-constructed `RlnUnspent`/`CoreUnspent` DTOs retain their constructor
default for source compatibility. Existing SDK/native package pairs must be
rebuilt together; hot reloading new Dart code over an old bridge is unsupported.

`OCT-038/039/040`: beta.2 adds the explicit public contract-import extension
and support-safe nullable `RgbSdkException.operation` / `nativeCode` getters.
Callers may use the typed allowlisted codes for recovery decisions; raw native
messages remain excluded. Cleanup failure retains native ownership and rejects
all operations except an explicit `destroy()` retry. A successful retry completes
disposal; creating or unlocking the same wallet is unsafe until then. Android 17
hosts targeting API 37 must declare and obtain `ACCESS_LOCAL_NETWORK` before
connecting to LAN services. The example owns its permission UI; the SDK does
not present an implicit prompt. `OCT-042` adds optional `CoreInvoiceData.recipientType`. Native-decoded invoices
forward the exact value; source-compatible hand-built DTOs may leave it null.
Hosts must explicitly accept `Blind` or `Witness` and reject other values before
broadcast. Witness sends need a separately reviewed Bitcoin output amount.
No native artifact or existing success-path
method signature changes in this candidate.

`OCT-035`: the RN beta.39 update adds optional `WebRgbInfo.burnRecipientNamespaces` and
`encodeTronBurnRecipient` in the opt-in WebRGB entrypoint. Existing provider
callers need no constructor change; hosts enabling Tron must add exact supported
chain IDs to their payout policy and independently verify redemption routing.
`normalizeBurnRecord` now rejects missing v2 payout commitments before any new
mutation. Hosts must retain/recover malformed pending records rather than drop
them or replay their burns. The API snapshot records these reviewed changes.

`OCT-017` removes sensitive endpoint path information from policy diagnostics
and redacts identifiers after removing URL credentials/query data. Consumers
must not use serialized diagnostic URLs as request targets. `LspError.cause`
now uses a Dart super-parameter; its optional `Object?` type and public calling
convention are unchanged. The AST snapshot is refreshed for that syntax-only
constructor change; no constructor migration is needed.

`OCT-023` requires `received`, `sent` and `fee` in raw transaction responses to
be exact non-negative satoshi amounts. The actual native serializers already
provide them. Advanced integrations and test doubles must stop omitting these
fields; invalid native data now fails instead of being presented as zero.

`OCT-019` validates decimal text before precision truncation and normalizes
either sign before parsing. Valid forms such as `+.5` still truncate toward
zero. The malformed-input safety divergence is recorded in the amount-helper
row below.

### September Changes

These are intentional pre-release changes to the unpublished `0.1.0` line,
not silent compatibility shims. Consumers must compile against the updated
immutable commit. Tracker: `MODEL-002`, `MODEL-012`, `MODEL-015`, `API-026`,
`API-030`, `API-045`, `API-046`, `CODE-014`, `SEC-004`.

- RGB read balances/supplies/assignments and Lightning RGB amounts now use
  `BigInt`, preserving the native UInt64 range. Requests are still signed-int
  bounded. Compare with `BigInt.zero`/`BigInt.from(value)` and serialize decimal
  strings. Check request limits explicitly before conversion; do not use double.
- `CoreAssetBalance` no longer inherits the Bitcoin `CoreBalance` signed-int
  contract. Missing required RGB balance fields are protocol errors, not zero.
- Core network outputs normalize `Bitcoin` to `mainnet` and `SignetCustom` to
  `utexo`; unknown native networks fail closed. Transfer requested assignments
  and core-compatible block-height/invoice/local-msat aliases are retained.
- Core error subclasses inherit `SDKError`; bad request/not found/conflict have
  HTTP defaults 400/404/409. Native Swift/Kotlin enum identity survives mapping,
  but raw native messages and HTTP response bodies are excluded from serialized
  diagnostics. `LnurlCallbackException.reason` is untrusted business detail,
  available deliberately, not automatically logged.
- `PsbtWalletCarrier` and `BeginEndWalletCarrier` declare typed method contracts.
  `PsbtFeeEstimate` describes sat fees/vbytes/rate. The wallet still returns null
  for these optional capabilities, matching RN; no implementation is fabricated.
- Unsupported wallet identity overrides (`xpubVan`, `xpubCol`,
  `masterFingerprint`) are rejected before native creation instead of ignored.
- `createUtxos()` returns the requested count because native returns void.
  `cancelHodlInvoice()` acknowledges the native call; it does not establish a
  terminal payment transition. Callers must refresh observed state separately.

### Relay Conversion Authority

Automatic `payWith` selection preserves core's first-funded-alternative policy.
That is a provisional quote candidate, not proof of conversion eligibility.
The inspected LSP source (`b859ecbeca06a795e99b18e753c64c6b99f05ef9`,
`internal/lspapi/convertible_asset.go`) authorizes pairs from its operator policy
and checks equal precision. `/get_info` does not expose that pair graph.
Flutter never retries another asset silently and never pays a rejected quote.
A successful quote must bind the caller-selected funding asset and original
target invoice before payment. Deployed-service proof remains a separate local
platform gate under `TEST-036`; this source inspection is not settlement proof.

## API Stability Tiers

The public package is split into root-stable and explicit advanced/parity
entrypoints. Every root-exported symbol must be classified as app-facing,
domain, public error, validation/crypto helper, or documented compatibility
carrier. Raw RN/native parity symbols must live behind
`package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart`.

| Tier | Meaning | Examples today | Compatibility rule |
| --- | --- | --- | --- |
| Stable facade | App-facing APIs intended to survive release. | `RgbSdkFlutter`, `UtexoWallet`, signer config, domain wallet DTOs. | Breaking changes require a tracker row, migration note, API snapshot update, and semver plan. |
| Advanced parity | RN/native-shaped APIs for parity testing, diagnostics, migration tooling, and explicit escape hatches. | `RlnClient`, `RLNBinding`, `RLNManager`, `IRLN*`, raw `Rln*` models, native bridge mapper. | Can change when RN/native changes, but changes must cite the RN baseline and update parity tests. |
| Compatibility shim | A narrowly documented RN spelling kept outside the stable root. | Advanced `decodeRGBInvoice`. | Must remain advanced-only and is removable when migration consumers no longer need it. |
| Unsupported/native-blocked | Public names that exist only to fail honestly. | `createBackup` while native backup is blocked. | Must fail before native side effects and must be documented as not release-ready. |
| Internal | Implementation details. | Native stores, bridge error mapper internals, LSP implementation helpers. | Must not be exported from the stable facade once `CODE-001` is closed. |

## Model and Policy Ownership

The SDK keeps model layers intentionally one-directional:

| Layer | Owner | Allowed dependencies | Must not do |
| --- | --- | --- | --- |
| Raw native wire | `Rln*` models and generated Pigeon carriers | Pigeon JSON/maps, strict required-field decoding, `NativeProtocolException` | Return from stable canonical wallet methods. |
| Stable domain | `Core*`, `Lightning*`, wallet response DTOs | Raw models plus `UtexoDomainPolicy` mapper decisions | Decode platform maps directly or call native clients. |
| Wallet facade | `UtexoWallet` | Stable request/response DTOs, `WalletInputPolicy`, binding owner | Own raw validation constants, duplicate status tables, or expose native handles from stable methods. |
| Compatibility / advanced | `rgb_sdk_flutter_advanced.dart` | Stable root plus raw bridge/client/binding/manager APIs | Leak into `rgb_sdk_flutter.dart` without a tracker row and migration note. |
| Network/LSP | `UtexoLsp` and `UtexoLspClient` | Stable wallet DTOs, LSP wire DTOs, SDK error taxonomy | Throw Dart core exceptions or duplicate wallet/Lightning status normalization. |

`WalletInputPolicy` owns stable facade numeric/string/range validation.
`UtexoDomainPolicy` owns public transaction, transfer, and channel vocabulary
mapping. Network defaults remain in `network_defaults.dart` because they are a
separate environment-resolution policy shared by wallet creation and LSP
bootstrap. Public failures must cross the stable boundary as
`RgbSdkException` subclasses.

## Dart Adaptation Map

Dart may adapt TypeScript-shaped inputs only when it keeps the same domain
semantics and the adaptation is tested.

| Area | RN/core shape | Flutter shape | Accepted adaptation | Required evidence |
| --- | --- | --- | --- | --- |
| Lifecycle credentials | RN methods accept password/mnemonic/native signer params near node lifecycle calls. | `UtexoWallet.init`, `unlock`, `reinit`, and `RlnSigner` strategies. | Flutter may use typed signer strategies, but must not persist credentials implicitly and must fail if required secrets are missing. | `test/utexo_wallet_test.dart::supports RN-style password signer in constructor`; `test/utexo_wallet_test.dart::supports RN-style native external signer lifecycle`; exact local native/platform candidate evidence in the release tracker. |
| Network/default resolution | Core defaults plus native-only `utexo` mapping. | `UtexoWalletConfig`, `UtexoUnlockConfig`, `NetworkDefaults`, and one package-internal signed-invoice policy. | Flutter validates SDK-facing network names and maps aliases to the native invoice identity at the boundary: `utexo` is `signet`, and numeric aliases resolve exactly. This prevents valid native-decoded invoices from failing APay, relay, or bridge verification. | `test/utexo_wallet_test.dart::exports RN-style network defaults and unlock resolution`; `LSP-025`; canonical network vectors in `test/lsp_beta9_contract_test.dart`. |
| Public network-name helpers | Core beta.9 still has an internal `toNetworkName` heuristic, while RN beta.32 root-exports exact `normalizeNetwork` plus callers such as `getNetworkVersions`. | `normalizeNetwork`, `getNetworkVersions`, and derivation-path helpers. | Flutter's stable public network-name path uses exact allowed values only. This is a deliberate safety tightening so malformed strings cannot silently select a real network. Core-only `toNetworkName` is not exported from the stable Flutter root because RN beta.32 does not export it. | `API-035`, `test/utexo_wallet_test.dart::matches RN-core seed derivation and utility behavior`. |
| Amount unit helpers | RN root-exports `toUnitsNumber` and `fromUnitsNumber`; the published core beta.9 package also contains non-root BigInt helpers. | Dart preserves the root surface and validates the complete decimal text before truncation. | `toUnitsNumber` fails above JavaScript `Number.MAX_SAFE_INTEGER`. Empty or malformed values, hexadecimal and exponent notation are rejected instead of inheriting core's loose parsing. Valid extra decimal digits still truncate; negative precision raises typed validation. Core-only BigInt helpers remain outside the stable root. | `API-034`, `OCT-019`, `test/crypto_validation_contract_test.dart`, `test/utexo_wallet_test.dart::matches RN-core seed derivation and utility behavior`. |
| LSP discovery document | RN beta.32/core beta.9 `GET /get_info` returns pubkey, network, optional host/port, supported assets, and u64 policy limits as decimal strings. | `LspGetInfoResponse` and `LspSupportedAsset` use Dart `BigInt` for u64 policy fields and strict required-field decoding. | Flutter maps the beta.9 shape directly. Malformed LSP/APay DTO fields fail closed instead of fabricating empty strings or zeroes. | `API-033`, `MODEL-018`, `MODEL-019`, `test/utexo_wallet_test.dart::createLsp discovers peer host and port from beta.9 get_info`, `test/utexo_wallet_test.dart::LSP get_info parser matches beta.9 shape and preserves u64`, `test/lsp_beta9_contract_test.dart::rejects incomplete relay responses and unknown statuses`. |
| Detailed transfer refresh | RN beta.32 returns `RefreshTransfersResult`, keyed by signed rgb-lib batch-transfer ID, while `refreshWallet()` remains `void`. | Flutter exposes immutable `RefreshTransfersResult`/`RefreshedTransfer`/`RefreshFailure` and retains `refreshWallet()` as the compatibility wrapper. | Pigeon transports rows as typed records because map keys are not a portable generated-bridge contract; Dart reconstructs the signed-Int32 keyed map, rejects duplicates, and normalizes `WaitingBroadcast` through the shared domain policy. | `API-039`, `MODEL-021`, `MODEL-026`, `MODEL-027`, refresh vectors in `test/rln_client_contract_test.dart` and `test/utexo_wallet_test.dart`. |
| Linked/canonical receive | Core beta.9 omits `rgb_invoice.asset_id` by default so the LSP can choose the linked canonical on-chain asset, with an explicit payout compatibility mode. | `ReceiveOnchainAsset.convertible` is the default; `payout` sends the Lightning payout asset ID. `ReceiveAssetResult` returns the resolved on-chain asset and conversion flag. | Dart enums replace TypeScript string unions; omission is preserved as omission, never JSON null. | `LSP-011`, `test/lsp_beta9_contract_test.dart::omits asset_id by default and preserves resolved bridge metadata`, and the payout-mode companion vector. |
| LSP payable-asset selection | Core beta.9 preserves discovery order for `listPayableAssets`, then applies payout-first deduplication only when selecting against largest per-channel local liquidity. | Flutter uses immutable typed menus and `LspAssetSelectionPolicy`. | Selection order, one-channel liquidity, ticker lookup, `rgb:` contract passthrough, ambiguity, and insufficient-liquidity behavior match core. Flutter fixes an initial adapter drift that reordered the discovery menu itself. | `LSP-013`, `LSP-017`, beta.9 asset-policy tests. |
| External LSP HTTP trust | Core beta.9 uses global `fetch` for foreign Lightning Addresses and does not isolate every malformed URL into its SDK taxonomy. | The default `UtexoLspClient` transport rejects implicit proxies and redirects, resolves every destination itself, rejects a DNS answer set containing any non-public address outside true loopback, pins the selected address to the socket, and retains the original host for TLS/SNI verification. It never sends the configured LSP bearer token to a foreign discovery/callback host. Android's `10.0.2.2` alias is accepted only for an explicitly configured LSP base URL. | This is a security tightening with equivalent successful-request semantics. Endpoint diagnostics remove user-info, query, and fragment data. Injected clients remain caller-owned and must enforce an equivalent destination policy. | `LSP-010`, `LSP-018`, `LSP-021`, `LSP-023`, `test/lsp_beta9_contract_test.dart::fails closed on malformed and unsafe LSP URLs`, and the mixed public/private DNS-answer vector. |
| Consuming LNURL/APay callback | Core beta.9 retries a foreign LNURL callback up to three times and resolves discovery separately from the callback result. | `resolveAddressWithDiscovery` and `resolveExternalAddressWithDiscovery` return one coherent discovery/callback exchange. The consuming callback is attempted once. | This is a funds-safety tightening: a timeout is ambiguous because the remote server may already have consumed an APay hash. Retrying can consume additional hashes or return a proof for a different discovery document. Callers receive the typed transport failure and must not infer that the server did nothing. | `LSP-022`, address resolution tests, and `tool/core_lsp_parity_manifest.json`. |
| RGB/Lightning bridge quote verification | Core beta.9 forwards `/lightning_receive` metadata and immediately pays the BOLT11 returned by `/onchain_send` without client-side invoice binding. Its narrow `ILspWallet` therefore has no RGB decoder. | Flutter adds `ILspWallet.decodeRgbInvoice()` and verifies the signed RGB and BOLT11 legs, echoed invoice, wallet network, asset, smallest-unit amount, absolute expiry, conversion metadata, configured LSP payee, and caller overrides before exposing the receive result or paying. Positive receive sats and optional 32-byte hashes/UInt16 CLTV are validated before mutation. | This is a funds-safety tightening. It does not alter valid server responses, and the stable `UtexoLsp.receiveAsset`/`sendAsset` signatures remain core-compatible. | `LSP-024`, `LSP-027`, the receive mismatch matrix, the send no-payment/preflight matrices, and `tool/core_lsp_parity_manifest.json`. |
| APay discovery proofs | Core beta.9/RN beta.32 map `address_sig` and `ApayInvoiceProof` fields but do not cryptographically verify either signature in the client SDK. | Flutter verifies the callback BOLT11 semantics, LNURL metadata description hash, address ownership signature, proof recipient/host/payment-hash bindings, Merkle inclusion, signed batch commitment, validity windows, configured LSP identity, and APay derivation bounds before returning a proved external invoice. Native APay registration results are also host-bound and checked against the exact v1 batch/index/hash invariants. | This is a security tightening. `requestExternalInvoice` requires the full APay proof chain; ordinary `quoteAddress` retains proofless legacy LNURL compatibility. Verification uses the protocol's recoverable secp256k1 Lightning-message signatures and fails closed with `LspAddressQuoteVerificationException`. DNS domain case is canonicalized without changing the signed local part. | `LSP-017`, `LSP-026`, `MODEL-029`, canonical LDK signature vector, native batch decoder vectors, and the APay tamper matrix in `test/lsp_beta9_contract_test.dart`. |
| External relay quote verification | Core beta.9 checks invoice hashes, assets, amounts, fee arithmetic, and conversion state before payment. | Flutter additionally requires both invoices to match the wallet network and valid time window, the HODL invoice to be signed by the configured LSP and not outlive the target, and the quoted expiry to agree with the signed invoice. | This is a safety tightening around fields already signed by BOLT11. It does not alter a valid core relay response. | `LSP-012` and the relay mismatch matrix in `test/lsp_beta9_contract_test.dart`. |
| Channel-ready peer filtering | Core beta.9's `waitForChannel` predicate can accept a ready channel for a different peer while a requested peer filter is present. | Flutter applies the requested peer public key to every readiness poll before accepting a channel. | This is a correctness fix: a caller waiting for one peer must not proceed because an unrelated channel became ready. | `LSP-015`, channel wait vectors, and the core-source audit recorded in the release tracker. |
| RLN 0.13 native-only surface | The pinned UniFFI `SdkNodeProtocol` contains 12 methods RN beta.32 never calls, plus optional IFA `issuanceType` that RN does not populate. | Flutter targets the RN-exposed contract and does not root-export those native-only operations. | This is scope parity, not missing Flutter behavior. The exact method/field exclusions are machine checked against both the pinned Swift protocol and RN bridge source. | `API-042`, `tool/core_lsp_parity_manifest.json`, `tool/validate_rn_parity.dart`. |
| RGB send skip-sync | RN accepts a parameter the pinned native artifact ignores. | `RlnClient.sendRgb` exposes `skipSync`; `UtexoWallet.onchainSend` validates it fail-fast. | Flutter rejects `true` until upstream implements it. | `API-006`; bridge and wallet tests named in the divergence register. |
| Wallet send spelling | Current RN deleted the old generic `send` wallet method and keeps `onchainSend`. | Flutter exposes only `UtexoWallet.onchainSend` at the stable facade. | No decoded-amount fallback; callers must pass `amount`, matching RN's current explicit validation. | `API-014`, `API-016`, `test/utexo_wallet_test.dart::requires explicit onchainSend amount instead of decoded fallback`. |
| Transfer listing | RN beta.32 calls RLN 0.13 `listTransfers(assetId?, txid?)`, using no filters for the canonical full list. | Flutter's stable full list and filtered compatibility methods map to the same native 0.13 entry point. | The obsolete per-asset fallback is gone; unfiltered results can include no-asset transfers without inference or omission. | `API-028`, `API-040`, list/txid vectors in `test/utexo_wallet_test.dart` and native bridge suites. |
| Lightning aliases | RN keeps canonical Lightning status names and removed old RGB-folding request helpers. | Flutter exposes `getLightningReceiveStatus` and `getLightningSendStatus`; old request aliases are removed. | Statuses stay in the Lightning vocabulary instead of being folded into RGB transfer status. | `API-016`, `LSP-006`, and wallet status tests. |
| Message signing identity and crypto posture | RN exports account-key core signing helpers and wallet node-key signing with the same JS method names in different scopes. RN core signing is backed by the JS core package dependency stack and top-level `signMessage` is callable by default. | Flutter keeps top-level account-key helpers and adds explicit wallet `signNodeMessage`/`verifyNodeMessage` aliases. | Wallet `signMessage`/`verifyMessage` remain RN node-key aliases; new Dart app code should use the explicit node-key names when both scopes are imported. Standalone account-key signing fails closed unless callers explicitly opt into `SchnorrSigningMode.experimentalDart`, because the pure-Dart signer is not audited/proven constant-time. This default is an accepted `SEC-007` divergence, not exact RN top-level behavior. Verification remains enabled. | `API-018`, `SEC-007`, `test/utexo_wallet_test.dart::exposes current RLN address, inflation, lookup, signing, and VSS APIs`, `test/utexo_wallet_test.dart::signs and verifies RN-core compatible Schnorr messages`, `test/crypto_bip340_vectors_test.dart::standalone Schnorr signing fails closed without explicit opt in`. |
| Removed root exports | RN no longer exports old `RNSigner`, flat PSBT stubs, or UTEXO bridge/network helper maps from the package root. | Flutter root barrel no longer exports those implementation files. | Direct `src/` imports are unsupported; stable PSBT/begin-end capability is expressed through absent optional carriers. | `API-024`, public API snapshot, public API docs validator. |
| Error aliases | Core error classes carry stable `code`, optional `statusCode`, and serializable fields. | Flutter SDK errors expose the same fields through Dart exceptions plus `toJson()`. | Constructors remain Dart-native but preserve core semantic fields. | `API-026`, `test/utexo_wallet_test.dart::serializes core-compatible SDK errors`. |
| On-chain receive/send requests | Core uses domain request/response models; RN often passes object literals. | Flutter uses typed request classes. | Typed request classes are allowed if units, optionality, defaults, and native field names are documented. | `MODEL-016`, `API-014`, and `test/utexo_wallet_test.dart::documents and preserves timestamp and amount units at model boundaries`. |
| Raw request DTOs | RN/native bridge sends loose JS objects and maps. | Low-level `RlnClient` still exposes raw maps through `rgb_sdk_flutter_advanced.dart`. | Raw map APIs stay advanced-only; stable facade must return domain models. | `CODE-001`, `CODE-005`, and API snapshot gate. |
| Wallet facade return shapes | RN/native names may surface bridge DTOs. | Canonical `UtexoWallet` methods return stable domain DTOs; native `Rln*` models are reachable through explicit `Raw` methods. | Flutter app code should not consume bridge wire shapes by default. Raw access remains available for parity debugging and advanced native integration. | `API-007`, `API-010`, `test/utexo_wallet_test.dart::maps Bitcoin list methods to domain DTOs and raw escape hatches`, `test/utexo_wallet_test.dart::maps Lightning, peer, and channel methods to stable DTOs`. |
| Lightning payment and status DTOs | Core beta.9 defines `LightningPayment`, `LightningSendRequest`, `ListLightningPaymentsResponse`, `SendPaymentResult`, decoded description fields, and canonical string statuses. | Flutter exposes the same domain fields with Dart nullability, immutable list wrappers, and `Rln*StatusValue` string aliases. | Stable methods normalize statuses to PascalCase, preserve optional list status/consignment/description fields, derive `inbound`, and fail closed when required native payment identifiers are absent. Raw bridge responses remain advanced-only. | `API-037`, `MODEL-023`, `CODE-017`, wallet malformed-success and Lightning mapping tests, and the complete wallet return-shape parity gate. |
| Wallet facade input shapes | RN uses request objects for many operations and hides low-level sync/filter controls from canonical reads. | Dart uses typed request DTOs or named parameters with the same units, optionality, defaults, and domain names. | Stable methods do not expose raw bridge-only controls or duplicate sats/msats aliases. Advanced `Raw` methods retain native controls. Channel inputs use core names, and `RgbInvoiceRequest.witness` preserves RN on-chain receive behavior. | `API-038`, stable-wallet API snapshot, high-risk input-contract parity checks, wallet tests, and integration smokes. |
| VSS fence recovery lifecycle | RN documents `vssClearFence` for a locked node before unlock. | Flutter requires `init()` and deliberately does not require `unlock()`. | This is the same lifecycle point expressed through Flutter's explicit state machine. Calling before init or after disposal fails with the SDK taxonomy. | `LIFE-016`, `test/utexo_wallet_test.dart::clears a stale VSS fence after init and before unlock`. |

## Deprecation and Breaking-Change Plan

1. Classify every exported symbol as stable, advanced, compatibility,
   unsupported, or internal.
2. Add Dart `@Deprecated` annotations and README/API docs for compatibility
   shims before removing them.
3. Keep one migration table that maps old symbols to stable replacements.
4. Remove or quarantine stale exports before the first production release.
5. Update `tool/api_snapshot.json` only in the same change as the migration
   note and tracker row.

No breaking public change is considered complete unless `dart run
tool/validate_api_snapshot.dart`, `dart run tool/validate_rn_parity.dart`, and
`dart run tool/validate_release_governance.dart` pass.

## Architecture Decisions

### Bridge Technology

Use Pigeon-generated Swift/Kotlin bridges for this release line.

Alternatives evaluated: Dart FFI, `uniffi-bindgen-dart`, `uniffi-dart`, and a
bespoke C ABI. Pigeon is retained because the current native deliverable is
already platform-specific Swift/Kotlin packaging around RLN artifacts, and the
Dart public API can stay stable while the bridge is swapped later.

Reversal criteria: switch only if a UniFFI/FFI spike proves full compatibility
with the exact RLN UDL/artifacts, async APIs, callbacks/external signer flows,
error mapping, object lifecycle, iOS/Android packaging, and the parity test
matrix.

### Artifact Ownership

The iOS bridge consumes the pinned official RLN release. For OCT-036, the SDK
owns a separately versioned Android build of the exact same source with 16 KiB
linker settings. Canonical Kotlin, FFI exports and non-JNI AAR contents remain
unchanged; the build recipe and per-ABI hashes are recorded. This is a distinct
artifact from RN's official 4 KiB Maven AAR, and its signature does not transfer
to the derived bytes. Checksums/ABIs/slices are verified; production supply-chain
mode remains blocked pending trusted signatures, independent reproduction and
source/builder attestations.

### Stable Layering

The intended production layering is:

1. Stable app facade and domain DTOs through `rgb_sdk_flutter.dart`.
2. Advanced RN/native parity library through `rgb_sdk_flutter_advanced.dart`.
3. Generated Pigeon/native bridge.
4. Native RLN artifacts.

Stable app code must not depend on raw Pigeon maps or native-only lifecycle
handles. Advanced imports are allowed only when the caller intentionally accepts
the RN/native parity contract.

Flutter's old template `PlatformInterface`/method-channel shim was removed.
Native work has a single bridge owner: generated Pigeon `RlnHostApi` wrapped by
`RlnClient` and serialized by `RLNBinding`. The only stable package-level native
diagnostic is `RgbSdkFlutter.nativeArtifactInfo()`, which reads metadata through
the same generated Pigeon host API rather than a second substitutable platform
abstraction.

## Initial mainnet external signer exclusion (2026-10-16)

Intentional release-scoped divergence, linked to `SEC-013` and the current
native P01/P02/external-VSS qualification gates: mainnet permits only the
built-in `PasswordRlnSigner`; external/custom signers (including overriding
password subclasses) fail before facade node creation. Swift/Kotlin plugins
retain immutable create-request network metadata per node and reject external
signer creation, bootstrap, init, attach and unlock on mainnet or unknown
network aliases before native side effects. Regtest behavior remains available
for fixing the upstream implementation. No public method is removed; mainnet
external-mode callers must defer until the native safety gates are resolved,
rather than switch to the advanced raw client. The API/bridge snapshot update
records internal store network accessors/create parameters for this guard.

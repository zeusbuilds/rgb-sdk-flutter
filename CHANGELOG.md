# Changelog

## 0.2.0-beta.3 - Unreleased

- Upgrade the separate RGB_L1 native engine to source-pinned BFA.7 with matching
  UniFFI bridge-5 Android/iOS bindings and exact source/overlay/lock metadata.
  Keep the released RN beta.40 BFA.5 reference independently immutable.
- Add native genesis-only exact-ID contract registration without balance credit,
  explicit per-EVM-chain mint-lock policy and exact received-mint DTOs.
- Add authenticated native prepare/commit/status/cancel recovery, immutable
  consignments, pending-command discovery and accepted-receipt inventory.
  Never replay End or submission during status/restart; quarantine restored
  snapshots that cannot prove freshness. Keep Aster RGB_L1 and Dev activation
  gated pending funded platform/deployment and release qualification.
- Remediate the exact RGB_L1 lock's known TLS, ctutils, Tokio and optional Arrow
  advisories; disclose retained unmaintained dependencies and preserve native
  privacy and independent legacy-RLN release blockers.
- Enforce the initial mainnet password-only signing boundary in Dart and both
  native bridges, including advanced clients. Regtest external signing remains
  available for isolated qualification; mainnet Lightning remains unsupported.
- Default production qualification to the mainnet-onchain profile. Require
  exact-candidate iOS/Android evidence from existing isolated infrastructure;
  never start containers or run successful Lightning cases in that profile.
- Declare source-justified iOS file-timestamp privacy usage and validate its
  contents. Native disk-space justification and final app aggregation stay open.
- Verify signed native archives, source/build statements and independent
  reproduction receipts with separately approved trust roots. Reject alternate
  PEM encodings of the same key as independent reproduction.
- Reject known native RGB reorg, bound-Witness accounting, BFA event-order and
  selected TLS dependency blockers in production independently of Pub auditing.
- Run branch quality checks and native JVM/XCTest CI with immutable dependency
  locks. Guard Flutter implicit/explicit pod installs against lock drift,
  resolve exact headless simulator identity, and fail CI for ineligible reports. Retain current native archives; this does not close upstream defects,
  lost-device recovery, physical-device or signed-distribution qualification.

## 0.2.0-beta.2 - Unreleased

- Add canonical public RGB contract import with expected asset identity,
  bounded canonical Base64 input, typed metadata and exact UInt64 supplies.
- Quarantine failed native cleanup while retaining ownership for explicit
  `destroy()` retry; block reinitialization and ordinary wallet operations
  until cleanup completes.
- Expose redacted native operation/code diagnostics for host recovery UX.
- Preserve native pending blinded-reservation counts in both platform bridges.
  Native unspent maps must supply a UInt32 count; missing or malformed counts
  fail closed instead of being fabricated as zero.
- Preserve decoded blind/witness recipient type in the stable invoice DTO so
  hosts can explicitly review required witness Bitcoin outputs.
- Target Android 17 in the example and request local-network consent before
  connecting to development services. Hosts own the platform permission UI.
- Add an existing-stack wallet qualification runner with separate private
  wallet storage, single-attempt financial requests and closed-fixture backups.
  iOS BTC/BFA/mint/burn/payout evidence spans an initial run and explicit
  pre-burn fixture resume. Android completed native flows through burn but
  stopped on a host payout failure. Separate same-proof payout recovery and
  read-only funded wallet verification pass without another mint or burn; the
  original run remains failed.
- Keep the published beta.1 native AAR and existing iOS archive unchanged.
  Upstream lifecycle/recovery, adverse-chain and release-readiness gates remain.

## 0.2.0-beta.1 - 2026-10-15

- Upgrade the immutable native baseline to RLN `0.17.0-beta.3` and the React
  Native reference to `1.0.0-beta.39`; core remains `1.0.0-beta.9`. Verify the
  exact official iOS ZIP, installed slices and Android Maven AAR independently.
- Qualify development with Flutter `3.47.7` / Dart `3.13.5` for iOS 27 and
  Android 17 consumer builds. Native iOS minimum remains `18.5`.
- Add Tron Base58Check burn recipients, preserve address casing, advertise
  only host-authorized recipient namespaces and reject journal records without
  their approved recipient commitment. WebRGB peer baseline is `0.1.3`.
- Verify Android native archive bytes at every pre-build and use strict native
  dependency constraints. Add ELF/archive checks and an isolated 16 KiB native
  loader/UniFFI health probe.
- This remains an internal beta. An upstream version bump does not close
  native page-size, lifecycle, funded-flow or artifact-provenance gates.

## 0.1.0 - Unreleased

Initial internal-beta Flutter package release.

- Added the stable `rgb_sdk_flutter.dart` entrypoint with the `UtexoWallet`
  facade, typed wallet configuration, signer strategies, domain DTOs, errors,
  validation helpers, and crypto utilities.
- Added the advanced `rgb_sdk_flutter_advanced.dart` entrypoint for explicit
  RN/native parity access to `RlnClient`, `RLNBinding`, `RLNManager`, raw
  `Rln*` models, bridge diagnostics, and migration tooling.
- Targeted `@utexo/rgb-sdk-rn` `1.0.0-beta.37`,
  `@utexo/rgb-sdk-core` `1.0.0-beta.9`, and RGB Lightning Node
  `0.16.0-beta.3`, including onchain-only mainnet native startup.
- Added bridged fungible assets (BFA), signer-aware burn capabilities, exact-u64
  burn requests, saved consignment bytes/path, and password/external-signer
  unlock `ethRpcUrl` through RLN's request-based native API.
- Added durable `BurnOperations` with pending-outcome blocking and explicit
  independent-proof reconciliation; a storage failure never retries a burn.
- Added pre-broadcast funding-failure cancellation and an optional sanitized
  journal error field; unknown outcomes remain pending, never auto-retried.
- Added optional WebRGB receiving/read/burn integration with immutable typed
  requests, per-session revocation, sanitized errors, chain policy, and bounded
  Keccak-256 proof export. Hosts own transport, durable storage and user approval.
- Added WebRGB 0.1.2 witness receiving and exact approved Unicode message
  signing through the native wallet, plus an optional bounded WalletConnect
  session RPC router. Full WalletKit pairing and live relay qualification are
  not implemented or claimed by this router.
- Blocked canonical Lightning methods on mainnet with the upstream error code.
  Native `LightningUnsupportedOnMainnet` remains a typed unsupported failure.
- Implemented iOS and Android Pigeon bridges backed by the pinned native RGB
  Lightning Node artifacts.
- Added wallet workflows for Bitcoin, RGB assets, Lightning payments, peers,
  channels, LSP/APay, on-chain transfers, node lifecycle, and signer-backed
  message signing.
- Added typed detailed-transfer refresh results, merged RLN 0.13 history
  filters, `WaitingBroadcast`, UTXO existence, decoded-invoice descriptions,
  proxy recipient IDs, linked IFA metadata, and deterministic LDK chain-sync
  adaptation on both native platforms.
- Added core beta.9 linked/canonical receive, Lightning Address discovery and
  asset selection, external invoice, and cross-asset relay flows. Relay quotes
  and both RGB/Lightning bridge legs are decoded and checked locally before any
  payment call. APay external
  invoices verify the BOLT11, Lightning Address ownership signature, Merkle
  inclusion, and signed batch commitment. Foreign LNURL hosts never receive
  configured LSP bearer credentials, and the default transport pins approved
  DNS answers through TLS connection establishment.
- Added one canonical LSP network policy for configured aliases and signed
  invoice networks, plus fail-closed APay v1 host/version/status/index/batch
  decoding and mutation preflight for bridge amounts, hashes, and CLTV bounds.
- Added strict model decoding, stable error taxonomy, lifecycle serialization,
  native timeout policy, local storage permission checks, support-safe
  diagnostic redaction, and secret-lifetime minimization guardrails.
- Added local release gates for formatter/analyzer/test/doc/API validation,
  RN parity validation, native artifact checks, supply-chain inventory,
  clean-consumer install/archive checks, Android bridge tests, iOS XCTest,
  funded/unfunded platform smokes, and external-signer process restart proof.
- Documented accepted constraints for native backup/recovery, RGB skip-sync,
  experimental pure-Dart Schnorr signing, app-owned durable credential storage,
  local-only native/regtest gates, Git/path distribution, and upstream
  native artifact provenance.

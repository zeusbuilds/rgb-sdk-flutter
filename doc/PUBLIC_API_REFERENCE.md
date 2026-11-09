# Public API Reference

This document is the release-line public API contract for the current
`rgb-sdk-flutter` package surface. It does not declare production readiness.
The release verdict remains controlled by
`doc/RELEASE_READINESS_TRACKER.md`.

## Durable On-Chain Sends (ROOT-01)

This section describes the existing legacy RLN protocol. RGB_L1's BFA.7
protocol uses the separately bound version-3 envelope described below.

This additive Flutter-only protocol is locally implemented and unpublished.
The official pinned native artifacts do not implement it. An old artifact
returns unsupported, including for status; unsupported is never an absent
operation or permission to retry a payment. No legacy one-shot fallback exists.
The iOS local qualification build requires a separately verified native rebuild
and `RGB_RECOVERABLE_ONCHAIN_SEND`; Android source is updated but unbuilt.
Do not enable the Swift flag against the old binary or bypass artifact checks.

`createRecoverableBtcSendCommand` and `createRecoverableRgbSendCommand` produce
`RecoverableOnchainSendCommand` before app journal dispatch. RGB invoice decoding
is read-only and happens here. Amount and fee rate are positive signed-64 native
integers; fee rate is integer sat/vB, RGB amount uses smallest asset units. RGB
donation/skip-sync are unsupported. RGB commands bind a concrete expiry; invoices
without one receive the pinned native default of 86400 seconds at construction.
Restoring a command never extends that deadline. New SDK envelopes use version 2:
`{version:2,network,walletBinding,request}`. The wallet binding is a
SHA-256 digest of a domain label, canonical network and both full native account
xpubs read through `node_info`; it contains no absolute container path. All
normalized native inputs, operation ID, network and that stable wallet binding
are SHA-256 bound into the command fingerprint. Intact iOS application data can
therefore move to a different container directory during an app update without
changing the operation, fingerprint or saved transaction. The native journal
independently binds the actual wallet keys/network and checks full request equality.

Every recovery operation holds the wallet lifecycle lease, checks the current
physical storage cohort, reads both live native account xpubs and verifies the
stable digest before native outbox access. Missing or changed account identity
fails closed. The digest is not the short master-key fingerprint or a Lightning
node pubkey. Legacy version-1 envelopes preserve their original path-bound
fingerprint and refuse relocation; they are never silently rewritten or migrated.

Before writing the app marker, explicitly call `onchainSendStatus(command)` once.
This non-sending preflight checks native protocol support and native request
validity (including RGB contract identity). A fresh operation must be absent;
unsupported or rejected validation fails before the app creates a pending marker.
Only this fresh command's first status attempt may initialize a missing native
outbox. A first failed attempt is latched too; it cannot be reused to recreate
lost recovery state. Mutating methods always require an existing real outbox.

Persist `command.requestJson` exactly in private wallet storage before native
prepare. It includes destination and wallet identity, and is never log data. Restore
using `RecoverableOnchainSendCommand.fromJson`; canonical encoding, types, bounds,
unknown fields and fingerprint are rechecked. The envelope is not a MAC and must
remain in trusted app storage. A command cannot be dispatched on another
configured wallet or network.

The qualified restore boundary is intact private local storage plus native or
process restart; normal app-update directory relocation additionally requires
the same live native account identity and complete private cohort. Restored commands require the existing real wallet directory
and `durable-onchain-v1` directory before any of the four native calls. Missing,
file-backed or symlinked directories throw
`RecoverableSendStorageException` (`RECOVERABLE_SEND_STORAGE_LOST`) without
recreating them or invoking native. Retain the application's recovery fence.
This existence check cannot prove individual-record continuity if a directory
survives selective deletion or a mixed snapshot; it is not an atomic defense
against concurrent storage tampering. Restore the app intent/receipt journals,
complete native wallet databases and complete native outbox as one matching
private cohort. General zip, VSS and mixed/cohort restore remain unqualified.
Never reconstruct a saved operation with a fresh command factory.

Recoverable APIs reject configured VSS (including VSS restore options) with
`UnsupportedWalletFeatureException`, feature `recoverableOnchainSendVss`, before
dispatch. Native VSS restores only the RGB subdirectory and cannot establish this
outbox's continuity; it must not be advertised as recovery for these operations.

`prepareOnchainSend(command)` builds/signs a durable transaction without granting
broadcast permission. `commitOnchainSend(command)` explicitly authorizes only
that operation, checking the full command under the native journal lock before End.
`onchainSendStatus(command)` never calls End, posts a consignment or broadcasts a
transaction. Under the native journal lock it may create outbox metadata and
durably save an acceptance receipt established from the exact native history.
`cancelOnchainSend(command)` durably revokes a never-authorized operation and
releases its exact held reservations. It sends the full request so native can
also tombstone an absent operation before the app clears its own journal.
Cancellation never authorizes an alternative transaction. Interrupted cleanup
remains fenced until a subsequent explicit cancel reports matched rejection.

`RecoverableOnchainSendStatus` binds operation ID, fingerprint and
`RecoverableOnchainSendKind` (bitcoin/rgb) and exposes
`RecoverableOnchainSendPhase`: absent, preparing, prepared, committing, accepted,
rejected. An absent record has null fingerprint/kind/identity and is not by itself
safe journal clearance. Preparing may contain a known exact transaction identity;
it never authorizes End. A prepared RGB operation may carry invoice_expired
without End authorization; an explicit cancellation can retire it.
Prepared/committing/accepted require txid and the RGB
batch identity; only committing/accepted have endAuthorized=true. Rejected has
no identity and a reason. An accepted result is native submission, not Bitcoin
confirmation. RGB's accepted batch index is authoritative and may differ from
its prepared index after an interrupted SQL transaction; the txid remains exact.

No native exception category, including validation/InvalidRequest, certifies that
a pending operation was never executed. Only the matched durable rejected
status with endAuthorized=false permits that conclusion.

Retain a wallet-wide guard while an operation is unresolved. Block other sends,
legacy one-shot APIs and wallet mutations until the operation is resolved; those
older APIs do not join this operation journal automatically. Aster enforces this
guard around its payment workflow.

No method automatically retries, resumes or commits after a transport failure.
Use an explicit status/cancel/recovery action and retain unknown/malformed
responses as unresolved. Legacy journals without native operation identity
remain fenced; do not match payments by amount, address, time or similar history.
Unit tests and local builds are not published native or mainnet qualification.

## BFA and Irreversible Burns

`CoreAssetBfa` is a bridged fungible asset in `CoreListAssets.bfa`.
`initialSupply` and RGB balances use exact `BigInt` base units, not doubles.
`BfaCapabilities` reports `burn`, `consignment`, and `bfa`. The wallet
intersects native burn support with `RlnSigner.supportsBurn`; the current
password signer supports it, while the native external signer does not.

`getBfaCapabilities()` queries that capability contract. `burn` takes `BurnParams` and
returns `BurnResult` with txid and batch-transfer index. `BurnParams.amount`
is a positive decimal u64 string; fee rate is integer sat/vB and confirmations
are 1..255. `getConsignment(assetId, txid)` reads saved standard Base64 bytes.
`getConsignmentPath(assetId, txid)` is a wallet-local path, never a dApp value.
These methods require an unlocked wallet except the capability query.
`UtexoUnlockConfig.ethRpcUrl` is password-signer-only; external-signer unlock
rejects it instead of ignoring it.

`BurnOperations` serializes burns against one `BurnWallet` and one durable
`BurnOperationStore`. `BurnOperationRecord`, `BurnOperationMetadata`,
`BurnPayout`, and `BurnOperationState` describe its private v2 journal.
`normalizeBurnRecord` validates v2 and legacy RN records without losing
unresolved operations. A pending result blocks new burns until independently
verified; no timer or timeout authorizes another burn. See
[WebRGB and burns](WEBRGB_AND_BURNS.md) for persistence and recovery contracts.

The opt-in `rgb_sdk_flutter_webrgb.dart` entrypoint exports
`encodeEvmBurnRecipient` and `encodeTronBurnRecipient`. They validate nonzero
account addresses and encode the exact 32-byte native burn commitment. Tron
requires Base58Check, version `0x41`, and preserves address casing; the prefix
and checksum are excluded from the commitment. Supported payout chains are
positive EIP-155 IDs and Tron mainnet/Shasta/Nile IDs documented in the
integration guide. `WebRgbInfo.burnRecipientNamespaces` is an optional immutable
list, present only when native burn/proof support is available and limited to
the host payout allowlist. Address support does not prove a redemption route.
`normalizeBurnRecord` rejects a v2 payout record with a missing or mismatched
native commitment; callers must retain malformed pending records for recovery.

Canonical Lightning entrypoints reject mainnet with
`WalletError.code == 'LIGHTNING_DISABLED_ON_MAINNET'`. Native rejections in
advanced calls preserve `LightningUnsupportedOnMainnet` as unsupported.
Direct `UtexoLsp` construction rejects mainnet before allocating a transport;
all orchestration methods recheck the network before starting operations.
Its `http` property and standalone `UtexoLspClient` are low-level transports
without a wallet/network context, not guarded wallet APIs.

`CoreTransfer` implements `TransferAmount`: `amount` is exact `BigInt` smallest
units and `amountBaseUnits` is its decimal string, both absent when history
cannot establish the quantity. `Assignment.amountBaseUnits` is the corresponding
RN `TransferAssignment` extension. Outgoing Send/Burn/Inflation use
`requestedAssignment`; ReceiveBlind/ReceiveWitness/Issuance sum actual fungible
assignments, excluding inflation rights. UInt64 overflow or malformed native
allocations fail closed. WebRGB includes the decimal for the full UInt64 range
and includes its legacy numeric `amount` only through 2^53 - 1.

## Stability Tiers

| Tier | Symbols | Contract |
| --- | --- | --- |
| Stable wallet facade | `package:rgb_sdk_flutter/rgb_sdk_flutter.dart`: `RgbSdkFlutter`, `UtexoWallet`, wallet config/request/response types, signer strategies, domain DTOs, public wallet errors | Intended for app code, subject to documented breaking-change policy. |
| Advanced/native bridge | `package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart`: `RlnClient`, `RLNBinding`, `RLNManager`, `IRLN*`, raw `Rln*` native models, `createAdvancedUtexoWallet`, native bridge error mapper, logger, and RN/raw compatibility extensions | Available for RN/native parity, diagnostics, migration tools, and explicit escape hatches; shape follows the pinned RN/native baseline. |
| Core/domain adapters | Stable domain `Core*`/`Lightning*` DTOs are root-exported; raw mapper extensions remain advanced-only | Flutter domain adaptation of current RN/core concepts. |
| Capability and blocked boundaries | Absent PSBT/begin-end carriers and native-blocked backup/recovery | Optional carriers are `null`; backup fails explicitly while the tracker marks it native-blocked. |

Canonical `UtexoWallet` methods return stable wallet/domain DTOs, not raw
native wire DTOs. Advanced callers that need the pinned native shape for parity
debugging must use the matching explicit `Raw` method, for example
`listChannelsRaw()`, `getBtcBalanceRaw()`, `decodeLnInvoiceRaw()`, or
`listTransfersRaw()`. Those methods are members of the advanced-only
`UtexoWalletRawApi` extension; importing the stable root alone cannot resolve
them. Import `rgb_sdk_flutter_advanced.dart` for raw bridge classes,
dependency-injected test wallets, RN-uppercase compatibility spellings such as
`decodeRGBInvoice`, or RN-style managers. The root import intentionally does
not export those names or expose `RlnClient`/`RLNBinding` in the stable wallet
constructor.

Custom signer strategies implement `RlnSigner` against the stable
`RlnSignerHost` protocol. The wallet supplies that host and retains native
client ownership; signer implementations must not retain it after an
operation. `IUtexoLspClient` is likewise a stable transport protocol because
RN exports that contract and `UtexoLsp` accepts injected implementations. The
stable root also exports `UtexoLspClient`, matching RN's concrete one-off LSP
client. An injected `http.Client` remains caller-owned unless
`closeHttpClient: true` is explicit; an internally created transport is owned
and closed by `UtexoLspClient`. The internally created transport resolves and
pins a public IP address for each connection while retaining the original host
for TLS/SNI validation. An injected client must provide equivalent proxy,
redirect, DNS-rebinding, and destination-policy enforcement; the SDK cannot
inspect or constrain a caller-owned transport. The raw native client remains
advanced-only.

Asset issuance returns `CoreAssetNia`/`CoreAssetIfa`, `inflate()` returns
`InflateAssetIfaResponse`, `estimateFeeRate()` returns
`FeeEstimationResponse`, and `checkIndexerUrl()` returns
`IndexerCheckResponse`. Their native `Rln*` equivalents are available only
through the advanced raw extension.

Canonical wallet inputs follow RN/core semantics with Dart named parameters or
typed requests. Ordinary read/list methods hide raw bridge sync/filter knobs;
`refreshTransfers(skipSync:)` intentionally exposes the beta.32 switch and
returns immutable per-batch `RefreshedTransfer` outcomes. `refreshWallet()`
retains the shared void compatibility contract. Lightning invoice creation accepts sats plus an optional
`LightningAsset`; payment accepts required `lnInvoice` plus optional sats and
asset fields. Channel opening uses `peerPubkey`, `isPublic`, and
`assetLocalAmount`. `RgbInvoiceRequest.witness` selects the `onchainReceive`
mode; the dedicated blind/witness methods enforce their named mode.

Lightning methods use the core beta.9 domain shapes. `listPayments()` returns
`LightningPayment` records with a required canonical PascalCase status and
optional Unix-second timestamps. `listLightningPayments()` wraps
`LightningSendRequest` records, whose status and RGB consignment endpoint are
optional. `keysend()` returns `SendPaymentResult`. Missing required native
identifiers and malformed boolean/string success fields throw
`NativeProtocolException`; the facade never substitutes an empty identifier or
silently treats malformed data as `false`.

## Lifecycle Prerequisites

`UtexoWallet` owns the app-facing lifecycle. Call `init()` once, then
`unlock()` with a network service configuration before wallet operations that
need a running native node. After `shutdown()`, regular operations fail until
`reinit()` succeeds. After `destroy()`, the wallet is disposed and cannot be
reused.

`vssClearFence(password)` is the deliberate exception to the general unlock
rule: call it after `init()` but before `unlock()` when recovering a stale VSS
single-writer fence. It fails before initialization and does not require an
unlocked node. `backupNow()` still requires an unlocked node.

Internally, the wallet facade routes native node operations through its binding
owner so app-facing calls share one serialized lifecycle/operation queue. Signer
strategies may still use the same underlying native client for their private
native signer handles, but each complete signer operation runs inside the
binding queue and its deadline. Disposal also owns signers whose node creation
or reinitialization failed; node IDs are not signer ownership markers.

The advanced `RlnClient` is lower-level and does not protect callers from every
lifecycle mistake; it maps platform failures into SDK errors but still expects a
valid native node ID. `RLNBinding` and `RLNManager` are advanced wrappers around
the same native state and should not be mixed with `UtexoWallet` for the same
node unless a test explicitly owns that interaction.

## Native Operation Deadlines

The wallet/binding layer applies `RlnOperationTimeoutPolicy` deadlines to
serialized native operations. The default deadline is `DEFAULT_API_TIMEOUT`
(`120000` ms), matching the current core default. Categories exist for
lifecycle, unlock, network, channel/payment, send/asset/UTXO, and sync/refresh
operations.

The pinned Pigeon/RLN bridge cannot cancel a Rust call after native execution
has started. When a deadline elapses, Dart throws
`RlnOperationTimeoutException`, marks the binding state unknown for regular
operations, keeps the internal queue waiting for native completion, and allows
`rlnDestroyNode()`/`UtexoWallet.destroy()` to run afterward as the ordered
cleanup gate. Cleanup itself is not timed out by the binding.

LSP HTTP calls use a separate 15-second default, matching core beta.9. Override
it with `LspPeer.timeoutMs` or `LspClientConfig.timeoutMs` when the deployment
requires a different positive deadline. A stalled quote or discovery request
must not inherit the two-minute native operation deadline.

## Units

| Field family | Unit |
| --- | --- |
| Bitcoin on-chain balances, channel capacity, witness amounts | sats |
| Lightning balances, invoice amounts, HTLC limits | msats |
| RGB asset amounts, issuance, inflation, transfers | asset smallest units according to precision |
| Fee rates | sats/vbyte and integer-equivalent for native bridge calls |
| Expiry/duration inputs | seconds |
| Native timestamps from transfer/invoice/block metadata | Unix seconds unless a field is explicitly named `Ms` |
| Ports, counts, indexes, confirmations | integer native units |

Numeric inputs must fit the current signed 64-bit Pigeon bridge boundary.
Native UInt64 outputs that may exceed that boundary use exact domain types; for
example `RlnNodeInfo.channelAssetMaxAmount` is `BigInt?`.

RGB balances, supplies, decoded Lightning asset amounts, payment/channel RGB
amounts, and fungible assignments are `BigInt` (nullable only where genuinely
optional). `CoreAssetBalance` is separate from Bitcoin's signed `CoreBalance`.
Requests remain signed-int bounded by Pigeon: check the request range before
converting a large read value; never call `toInt()` and assume it is lossless.
`CoreTransfer.requestedAssignment` is retained independently of assignments
actually received. `WalletNodeInfo.localBalanceMsat` is an exact `BigInt`
conversion of native local sats. `blockHeight`, `expirySeconds`, `payee`, and
`HodlInvoice.invoice` are core-compatible aliases of their existing fields.

`NetworkEndpoints` and `getNetworkDefaults()` are stable root helpers for
app-facing network defaults. They expose the selected indexer URL and RGB proxy
endpoint after SDK network normalization. Removed UTEXO bridge/network preset
maps are not retained as dead compatibility code.

`UtexoWallet.listTransfers()` calls RLN 0.13's real unfiltered listing path, so
no-asset transfers are retained. `listTransfers(assetId:)` remains available
for an asset-specific view. `refreshTransfers()` preserves signed Int32 batch
IDs, normalized status changes, and typed failures without inventing an update
for unchanged records.

## LSP and Linked Assets

`UtexoLsp` exposes the core beta.9 connection, receive/send bridge, Lightning
Address, APay, and external relay flows. `receiveAsset()` defaults to
`ReceiveOnchainAsset.convertible`, which omits `asset_id` and lets the LSP
resolve the canonical linked on-chain asset; use `.payout` only when both legs
must use the payout contract. The result reports `onchainAssetId` and
`converted` from the locally decoded RGB invoice rather than trusting optional
service metadata.

`ILspWallet.network` is the canonical native invoice network used for signed
payload comparison: configured `utexo` is exposed as `signet`, and numeric
aliases resolve to their native names. `UtexoWallet.getNetwork()` separately
retains the RN-compatible configured value for application display/config
logic.

Both bridge directions are verified before funds can move. `receiveAsset()`
requires the returned RGB invoice to match the wallet network, requested
amount, selected asset policy, created BOLT11, and expiry. `sendAsset()` decodes
the target RGB invoice before contacting the LSP, then requires the returned
BOLT11 to match its asset, amount, network, expiry, caller overrides, and the
configured LSP payee before calling `payLightningInvoice()`. A mismatch throws
`LspBridgeQuoteVerificationException`; payment is never attempted.
Bridge receive amounts must be positive, and caller-supplied BOLT11 hashes and
CLTV overrides are completely validated before the first LSP mutation.

Lightning Address discovery is routed by the address domain. Calls to the
configured LSP may carry its bearer token; foreign discovery and callbacks are
always unauthenticated. `resolveAddressWithDiscovery()` and
`resolveExternalAddressWithDiscovery()` return an immutable
`LspAddressResolution`, keeping the discovery document and its single callback
result together. The convenience resolution methods delegate to that coherent
exchange. A consuming callback is attempted once: the SDK does not silently
retry after a timeout because the server may already have consumed an APay
payment hash. Asset selection uses the largest balance on any one usable
channel and prefers the payout asset before a convertible asset. It does not
sum liquidity across channels because the current flow does not provide
cross-asset multipart payment.

`quoteExternalPayment()` decodes the target and HODL invoices locally and fails
before payment when their hashes, assets, base-unit amounts, millisatoshi
amounts, networks, timestamps, expiries, payees, fee reconciliation, fee
ceiling, or conversion flag disagree. The HODL invoice must be signed by the
configured LSP and cannot outlive the target invoice. `payExternalInvoice()`
pays only a quote that passed those checks.

`quoteAddress()` verifies the callback BOLT11 amount, RGB asset, asset amount,
network, lifetime, recovered payee, and LNURL metadata description hash before
returning an `AddressQuote`. When an `ApayInvoiceProof` is present, Flutter also
verifies its version and lifetime, payment-hash and host binding, Lightning
Address ownership signature, Merkle inclusion path, and signed batch
commitment. DNS domain case is treated canonically without changing the signed
username. Native `apayNew` responses are bound to the requested host and must
contain a coherent APay v1 hash batch within the BIP32 derivation bounds.
`requestExternalInvoice()` requires that complete proof chain;
proofless legacy LNURL is accepted only by the ordinary quote path. Any failed
check throws `LspAddressQuoteVerificationException` before a payment call.

## Error Taxonomy

Public APIs throw `RgbSdkException` subclasses for SDK-owned error domains:
`ValidationError`, `WalletError`, `WalletException`,
`WalletValidationException`, `ConfigurationError`, `BadRequestError`,
`ConflictError`, `NetworkError`, `NotFoundError`, `RgbNodeError`,
`NativeProtocolException`, `RlnOperationTimeoutException`,
`OperationCancelledError`, `CryptoError`, `ExperimentalCryptoException`,
`SDKError`, `RecoverableSendStorageException`, and
`UnsupportedWalletFeatureException`.

Native `PlatformException`s are mapped by the native bridge boundary before they
reach stable wallet calls. The advanced library exports the mapper and
`NativeBridgeFailure` for bridge tests and diagnostics. HTTP/LSP failures use
`LspError` and specialized failures such as
`LspAmountOutOfRangeException`, `LspNoPayableAssetException`,
`LspUnknownPayableAssetException`, `LspAmbiguousPayableAssetException`,
`LspInsufficientAssetLiquidityException`, `LspQuoteMismatchException`, and
`LspBridgeQuoteVerificationException` where the service layer can classify the
failure. Those LSP types also inherit from the SDK taxonomy so callers can
catch `RgbSdkException` at the stable boundary.

## Side Effects

`init()`, `unlock()`, `reinit()`, `shutdown()`, `destroy()`, sync, send,
receive, channel, issuance, signer, and advanced bridge APIs may create or
mutate native node state. LSP APIs perform network I/O through their configured
client. Pure crypto, validation, network-default, and model helpers are
deterministic except for documented secret-buffer wiping.

## Secret Handling

The SDK does not own durable credential storage. Apps must store passwords,
mnemonics, bearer tokens, RPC credentials, and user secrets in their own secure
storage. SDK-owned byte buffers are defensively copied and wiped where Dart can
guarantee access to mutable bytes; Dart strings, VM copies, BIP32 internals, and
app-owned values cannot be reliably zeroized by this package.

## Platform Support

The current native artifacts target Flutter `3.41.x`, Dart `3.11.x`, Android
min SDK `24`, and iOS `18.5+`. The iOS floor is derived from the pinned RLN
artifact object metadata, not from an aspirational support target.

## Unsupported or Native-Blocked Behavior

`sendRgb(skipSync: true)` fails before native execution because the pinned
native artifacts expose no real request field for it. Local backup/recovery is
native-blocked and must not be marketed as ready. PSBT and begin/end flow
carriers are absent on the stable wallet facade until the upstream/native
baseline supports them. Removed RN package exports such as the old `RNSigner`
wrapper, flat PSBT helpers, and UTEXO bridge/network map helpers are not
exported from the root Dart package. Advanced callers should import
`rgb_sdk_flutter_advanced.dart`; importing implementation files under `src/` is
unsupported.

The pinned RLN 0.13 native artifacts expose additional methods that RN beta.32
does not call: `assetLink`, `assetMetadata`, `getAssetMedia`, `getSwap`,
`listSwaps`, `makerexecute`, `makerinit`, `postassetmedia`,
`sendonionmessage`, `taker`, `attachExternalSigner`, and
`unlockWithAttachedExternalSigner`. They are intentionally outside this
release-line parity surface. The same applies to the native-only
`SdkIssueAssetIfaRequest.issuanceType` field. Adding any of these requires a
reviewed public contract in RN/core first; the Flutter package does not expose
speculative wrappers.

## Key Identity

Top-level `signMessage(SignMessageParams)` and
`verifyMessage(VerifyMessageParams)` are account-key helpers compatible with
RN core and verify against an account xpub. `UtexoWallet.signNodeMessage` and
`UtexoWallet.verifyNodeMessage` use the running RLN node identity key. The
wallet keeps RN's `signMessage` and `verifyMessage` spellings as node-key
aliases. New Dart app code should prefer the explicit node-key names when both
helper families are imported.

Standalone account-key signing uses a pure-Dart BIP340 implementation only when
`SignMessageParams.signingMode` or `signSchnorr(..., signingMode: ...)` is set
to `SchnorrSigningMode.experimentalDart`. The default mode fails closed with
`ExperimentalCryptoException` because that implementation is not audited or
proven constant-time. Production wallet message signing should use the native
RLN-backed wallet node-key methods.

`ImportedRgbContract` is the result of `UtexoWallet.importRgbContract`, which
imports a canonical Base64 public RGB contract only into an unlocked wallet.
The caller supplies the expected contract ID and verifies network-specific
public artifact hashes before importing. Native identity verification and strict
typed metadata checks reject mismatches; import alone never credits supply.
Supply fields use exact `BigInt` base units, including full native UInt64 values.

`NativeOperationCause` is the narrow diagnostic interface behind
`RgbSdkException.operation`. Applications can retain a validated SDK operation
token while keeping native messages, credentials, payloads and paths private.
The operation is nullable for exceptions without a structured native cause.
`NativeErrorCodeCause` supplies the allowlisted `RgbSdkException.nativeCode`.
Applications can offer explicit allocation-UTXO setup for `NoAvailableUtxos`
or `InsufficientAllocationSlots` without inspecting private native text. Unknown
codes are redacted; the getter does not classify errors by message substring.

`CoreInvoiceData.recipientType` preserves the decoded native recipient kind
(`Blind` / `Witness` in the pinned runtime). The optional constructor value
defaults to null for compatibility. Hosts must reject unknown/null kinds before
sending and review the witness Bitcoin output amount separately from network
fees; this metadata does not authorize a send.

`CoreUnspent.pendingBlinded` preserves the native blinded-reservation count.
Native responses require a UInt32 value; omission or malformed values fail
closed. A zero count alone does not prove a free allocation slot: hosts must
also check the output and allocation state, and native reservation remains
authoritative.

## RGB_L1 configuration and compatibility

`RgbLibWallet` is the explicit on-chain facade. Construct it with
`RgbLibWalletParams` and `RgbLibKeys`, then call `init` before reading or
mutating wallet state. The parameters bind the Bitcoin network, dedicated
absolute storage directory, witness scheme, allocation limit and address reuse
policy. Storage belongs to one backend and profile. `shutdown` closes a
session; `destroy` and `dispose` close the object permanently.
`init` and `reinit` retain create-or-open behavior for compatibility. For a
provisioned wallet, use `openExisting([onlineParams])`: it requires the existing
profile under the exclusive native lease and never creates a replacement
profile when storage is missing. It requires the strictly typed compiled-wrapper
capability `RgbLibRuntimeInfo.supportsExistingOnlyOpen`; an absent/false
capability fails before reading keys. This capability is separate from native
archive features. Applications should keep SDK files in a stable dedicated
child directory, separate from app ownership markers, and treat missing or
corrupt saved storage as a reconciliation failure.
Operations are serialized and an uncertain payment is never retried by the SDK.
The Aster activation and production gates are described in
[the beta.40 audit](UPSTREAM_PARITY_BETA40.md).

`RgbLibKeys.mnemonic` holds signing material in memory. Prefer
`RgbLibKeys.reader` with an app-owned secure store for persisted secrets.
`RgbLibPublicKeys` contains the vanilla and colored account xpubs and master
fingerprint. `RgbLibKeys.watchOnly` uses those public keys and rejects operations
requiring signing. When both mnemonic and public keys are supplied, native
validates that they describe the same wallet. Keys and read failures must stay
out of logs and user-facing diagnostics.

The logical `utexo` profile represents the hosted UTEXO Dev Signet test network.
Use `RgbLibWalletParams(allowUtexoDevSignet: true, network: 'utexo', ...)` in a
dedicated test build. The default is false. A current Android or iOS wrapper
must advertise `supportsHostedDevSignet` before the SDK reads keys. An admitted
wallet stores its deployment revision in its native profile. The logical name
remains bound to wallet IDs, recovery cohorts and payment commands.

Use Esplora `https://dev.esplora-01.mint.utexo.com`, RGB proxy
`rpcs://dev.rgb-proxy.utexo.com/json-rpc` and Arbitrum RPC
`https://arb1.arbitrum.io/rpc` for chain `42161` with a mint-lock range of 2 to
7,200 backing-chain blocks. The SDK requires this exact tuple and uses the Dev
Esplora block-one checkpoint. Public Signet uses its own checkpoint. The native
`signet` invoice encoding is shared. A Dev durable send requires a locally
registered asset. An open invoice can omit the asset when the sender explicitly
selects the registered asset and enters the amount. Wallet-generated Dev receive
invoices and both send paths require exactly one transport endpoint, the Dev
proxy. A caller cannot activate Dev with `getRgbLibNetworkDefaults` or a legacy
RLN wallet.

The current public BFA genesis, digest and metadata are recorded in
[`tool/dev_signet_deployment_requirements.json`](../tool/dev_signet_deployment_requirements.json).
Register the definition with `importContract` using the exact asset ID before
presenting it. Registration credits no balance. These APIs support a dedicated
Dev wallet. Dev burns are unavailable, including through the optional WebRGB
adapter. Hosted bridge pairing, mint settlement and burn payout have separate
qualification requirements.

`RgbLibIndexer` selects Electrum, Esplora or authenticated bitcoind access.
`RgbLibUnlockParams` supplies an explicit indexer or indexer URL, a proxy
endpoint, EVM RPC endpoints keyed by decimal chain ID and optional proxy auth
keys. BFA.7 uses `RgbLibEvmChain` entries in `evmChains`, each with `rpcUrl`,
`minMintLockBlocks` and `maxMintLockBlocks`. These are explicit deployment-owned
**backing-chain** block counts, with `2 <= min <= max`; they are not Bitcoin
confirmation counts. A bare legacy `evmRpcUrls` map fails before connection;
if retained for source compatibility, every entry must match a typed policy.
`goOnline` applies this configuration. The first network operation can
connect using defaults on supported public networks. Regtest and Dev Signet
require an explicit online configuration. `estimateFeeRate` reports
`FEE_UNAVAILABLE` when the native indexer returns no usable estimate, including
a successfully parsed empty Esplora fee map. Connection and malformed-response
failures remain distinct.

`RgbLibWalletParams.reuseAddresses` reuses the most recently native-derived
address only within one open session. Reopening derives through native again;
previous addresses remain valid. Address text from profile JSON or backups is
never accepted as ownership evidence or used to seed that cache.

`RgbLibWalletIdentity` exposes the persistent profile ID, network and master
fingerprint. `RgbLibRuntimeInfo` describes the native artifact version, sealed
integration tree, overlay patch/source-lock/source-manifest SHA-256 digests,
source revision, bridge version and BFA capabilities. The wallet verifies the pinned
runtime identity before reading keys. `RgbLibWalletException` carries a stable
sanitized failure code for configuration, lifecycle, native availability and
operation failures. `RgbLibBackupRecoveryCapabilities`, available through
`RgbLibRuntimeInfo.backupRecovery`, distinguishes encrypted snapshot creation
and read-only restoration from unsupported restored-wallet spending and
mnemonic-only RGB recovery. These fixed capabilities cannot be upgraded through
runtime JSON. See [the recovery boundary](RGB_LIB_BACKUP_RECOVERY.md).

Profile metadata reads on open and restore are capped at 64 KiB before and
during reading. Only strict UTF-8 flat JSON metadata is admitted; recursive
containers, parser extensions, malformed encodings and over-budget input are
rejected with a stable profile failure, without replacing existing files.

`RgbLibAssetMetadata` preserves exact `BigInt` supplies, schema, precision,
timestamp, optional ticker/details/reject-list URL and linked contract IDs.
`RgbLibMedia` extends the shared media representation with the native content
digest. Media paths belong to the app's private storage.

`RgbLibReceiveData` extends the shared invoice result with the transport public
key. `RgbLibInvoiceData` preserves decoded assignment, expiry and transport
fields together with encryption policy, optional public key and unknown query
parameters. Decode and receive results do not authorize a send. Callers must
validate the requested network, asset, amount, recipient and fees separately.

`blindReceive` and `witnessReceive` retain a `minConfirmations` default of zero
for compatibility. A host requiring confirmed receipts must explicitly choose
its minimum; Aster uses one. Native `Settled` follows the minimum saved with
that request and does not imply any greater chain finality. With a minimum of
one, an observed zero-confirmation incoming transfer remains
`WaitingConfirmations`, outside settled/spendable allocations. Changing host
defaults does not rewrite the policy on an already issued request.

`RgbLibTransfer` preserves shared transfer history plus the complete invoice,
local consignment path and all `changeUtxos` when available. The legacy singular
`changeUtxo` is present only when exactly one change output exists. Transfer amounts remain exact base
units and unresolved amounts remain absent.

`RgbLibWitnessVersion` selects the address derivation scheme for a new
profile. `RgbLibMnemonicReader` reads key material per native session.
`RgbLibIndexerKind` identifies the Electrum, Esplora or bitcoind transport.
`getRgbLibNetworkDefaults` returns backend-specific public endpoints.
Regtest needs an explicit configuration.

`RgbLibAssetSchema` filters asset reads. `RgbLibReceiveAssignment` selects
the exact invoice assignment and `RgbReceiveAssignmentKind` exposes the
supported legacy RLN subset. `RgbLibNetworkInfo` reports the chain with
optional native height. `RgbLibIndexerCheck` describes the protocol
detected by the native engine. `BurnCapabilityWallet` lets a wallet reject
unsupported burn operations before an irreversible journal entry is written.

### BFA.7 contract registration and native recovery

`RgbLibDurableOperations` supplies `importContract`, native `getPublicKeys`,
`hasPendingOnchainSends`, the two recoverable command factories and the explicit
prepare/commit/status/cancel methods plus explicit `revokeOnchainSend`.
Native artifact and Aster activation
qualification remain separate from the capability to call these APIs.

`importContract(contractBase64:, expectedAssetId:)` imports canonical public
genesis bytes and returns `ImportedRgbContract`, including exact supplies and
whether the definition already existed. It does not credit allocations or
funds. A deployment must verify the approved artifact SHA-256 and the returned
asset ID, schema, name, ticker and precision. Import refuses to overtake a
pending native send. `getPublicKeys` returns the actual verified native account
keys, bound to the wallet identity; it never substitutes another derivation.

New BFA.7 storage profiles bind the native source and overlay and carry a random
recovery cohort. Existing BFA.5 directories are not silently upgraded. A native
outbox is created together with a fresh profile; reopening and restored commands
require the existing matching outbox. Version-3 `RecoverableOnchainSendCommand`
binds `RGB_L1`, network, native wallet identity, recovery cohort, native source,
overlay and all exact approved payment inputs. It is incompatible with the
legacy RLN versions 1/2. Monetary values are canonical UInt64 decimal strings;
RGB factories also accept `exactAmount` and `exactWitnessBlinding` to avoid
narrowing. The recipient's native kind, Ed25519 key, encryption policy,
recipient/sender transports, witness output and expiry stay bound. The advanced
`RgbLibRecoverableCodec` implements this serialization; applications should use
the wallet factories and persist their opaque `requestJson` instead.

`prepareOnchainSend` prepares/signs a fixed native transaction and preserves its
identity before returning. `commitOnchainSend` is the explicit authorization
boundary; it never substitutes a new transaction. `onchainSendStatus` and
`cancelOnchainSend` never invoke End, post a consignment or broadcast. Missing
acknowledgements remain fenced until exact native evidence establishes their
outcome. A status of `accepted` means native submission, not chain confirmation.

`revokeOnchainSend` is a separate, explicit value-changing proxy action for a
signing RGB wallet with an online session and verified
`supportsDispatchedRgbRevocation` capability. It reconciles acceptance first,
then requires an affirmative revocation of the exact MAC-bound sender-proxy
operation before durably certifying cancellation and releasing its reservation.
False, unknown, released or unavailable responses retain the fence. Ordinary
Cancel and passive Status never acquire this revocation authority; an already
accepted payment stays accepted. No path creates a replacement payment.
`RgbLibPendingOnchainOperation` from `listPendingOnchainSends` carries the exact
verified command and native status, so a lost app marker can be rebuilt without
a new payment or commit authorization. `hasPendingOnchainSends` audits the whole
native outbox even if an app marker was lost; corrupt or mismatched native state throws instead of returning false.

Use `requireFreshInvoice: false` only to reconstruct a saved RGB command for
read-only recovery validation. Native preparation still checks expiration;
reconstruction must not extend the saved deadline. Status/audit reads remain
available for watch-only sessions, while command creation and sending require
signing authority. Normal mutations cannot overtake a pending operation.

`refreshTransfers` retains per-transfer failures for deliberate inspection.
`refreshWallet` fails with `REFRESH_INCOMPLETE` if any transfer observation failed;
partial refresh is not a current complete portfolio. Generic refresh can
progress pending transfers and is blocked on restored snapshots. Local
inspection and exact read-only Status remain available under the documented
recovery boundary.

`getReceivedMint(recipientId)` returns a nullable `RgbLibReceivedMint` observation
from the native BFA.7 wallet. Its six fields are `opid`, transaction-bound `lockId`,
exact `BigInt` `amount`, backing-EVM `beforeBlock`, `evmChainId`, and
`bridgeContract`. No asset identifier is invented. Null means no native-validated
mint remains available for this recipient (including a failed receive). These
requirements authorize neither an EVM lock nor a completed mint. WebRGB mint
route authorization remains unavailable until its transport policy is qualified.

`listOnchainSendReceipts` returns a `RgbLibOnchainSendReceiptPage` of accepted
`RgbLibOnchainSendReceipt` entries. Gross amounts and approved fee rates remain
exact `BigInt` values, so self-transfers do not lose their amount when an app
journal is missing. A receipt is submission evidence, not a confirmation or a
new send authorization. Pages include wallet/cohort identity and native revision;
never merge pages from different revisions. The native limit is 500 per page.
Historical accepted receipts remain readable on a restored snapshot even while
freshness uncertainty fences new spending.

The complete native outbox is inside the encrypted native backup cohort. Restore
requires matching profile, source, overlay, cohort and outbox; files are not
recreated when missing. A coherent old backup can predate a later authorized
payment on the original installation. It therefore cannot prove that an absent
or merely prepared operation never executed. Native restore records this
freshness uncertainty; ordinary spending and absence/cancellation certificates
remain fenced with `RECOVERY_RESTORE_UNCERTAIN`. SDK pending discovery/audit
throws for a restored snapshot instead of returning a misleading empty list.
Exact previously accepted evidence can still be read without replay. This source-level protocol and host tests alone do not
establish funded process-kill, restored-state or release acceptance. Aster keeps
RGB_L1 gated until its platform and product verification is complete.

## Symbol Coverage Checklist

- `RecoverableOnchainSendCommand`, `RecoverableOnchainSendKind`, `RecoverableOnchainSendPhase`, `RecoverableOnchainSendStatus`
- `RecoverableSendStorageException`

- `ImportedRgbContract`
- `NativeOperationCause`
- `NativeErrorCodeCause`

The documentation validator requires every root-exported stable symbol to appear in
this checklist. Advanced/parity symbols are intentionally excluded from this
root checklist and are snapshotted by `tool/api_snapshot.json`.

- `AccountXpubs`, `ApayHashEntry`, `ApayInvoiceProof`, `ApayMerkleProofElement`
- `ApayNewResponse`, `Assignment`, `BadRequestError`, `BeginEndWalletCarrier`
- `ChannelReadyInfo`, `ClaimResult`, `ConfigurationError`, `ConflictError`
- `CoreAsset`, `CoreAssetBalance`, `CoreAssetCfa`, `CoreAssetIfa`
- `CoreAssetNia`, `CoreAssetToken`, `CoreAssetUda`, `CoreBalance`, `CoreBlockTime`
- `CoreBtcBalance`, `CoreInvoiceData`, `CoreInvoiceReceiveData`, `CoreListAssets`, `CoreMedia`
- `CoreRgbAllocation`, `CoreTokenAttachment`, `CoreTransaction`, `CoreTransfer`
- `CoreTransferStatus`, `CoreTransferStatuses`, `CoreTransferTransportEndpoint`
- `CoreUnspent`, `CoreUtxo`, `CreateHodlInvoiceParams`, `CryptoError`
- `DecodedLightningInvoice`, `GeneratedKeys`, `HodlInvoice`, `HodlInvoiceResult`
- `ExperimentalCryptoException`
- `LnurlCallbackException`, `PsbtFeeEstimate`
- `FeeEstimationResponse`, `IndexerCheckResponse`, `InflateAssetIfaRequest`, `InflateAssetIfaResponse`
- `AddressQuote`, `AssetSelection`, `ExternalInvoice`, `ExternalInvoiceAssetPreference`
- `ExternalPaymentQuote`, `ExternalPaymentResult`, `IUtexoLspClient`, `ILspWallet`
- `LightningAddressInfo`, `LightningAsset`, `LightningChannel`
- `LightningChannelOpenResult`, `LightningPayment`, `LightningPeer`
- `LightningReceiveRequest`, `LightningSendRequest`, `SendPaymentResult`
- `ListLightningPaymentsResponse`, `LspAmbiguousPayableAssetException`, `LspAmountOutOfRangeException`
- `LspAssetLiquidityCandidate`, `LspChannelTimeoutException`
- `LspClientConfig`, `LspError`, `LspGetInfoResponse`, `LspLightningAddressByPubkeyResponse`
- `LspInsufficientAssetLiquidityException`, `LspLightningReceiveRequest`, `LspLightningReceiveResponse`
- `LspLightningSendLeg`, `LspLightningSendRequest`, `LspLightningSendResponse`, `LspLightningSendStatus`
- `LspLightningSendStatuses`, `LspLightningSendStatusResponse`, `LspLiquidityTimeoutException`, `LspLnParams`
- `LspLnurlpCallbackResponse`, `LspOnchainSendRequest`, `LspOnchainSendResponse`
- `LspLnurlpDiscovery`, `LspNoPayableAssetException`, `LspPeer`, `LspQuoteMismatchException`
- `LspAddressQuoteVerificationException`, `LspAddressResolution`, `LspBridgeQuoteVerificationException`
- `LspRgbParams`
- `LspSettlementException`, `LspSupportedAsset`, `LspTransportPolicyException`
- `LspUnknownPayableAssetException`
- `NativeArtifactInfo`, `NativeExternalRlnSigner`, `NativeProtocolException`, `Network`
- `NetworkEndpoints`, `NetworkError`, `NetworkVersions`, `NotFoundError`, `OnchainReceiveResponse`
- `OnchainSendResponse`, `OperationCancelledError`, `Outpoint`, `ParsedLightningAddress`, `PasswordRlnSigner`
- `PayableAssets`, `PayAddressAssetParam`, `PayAddressOptions`, `PayAddressResult`, `PayExternalInvoiceOptions`
- `PsbtType`, `PsbtWalletCarrier`, `ReceiveAssetOptions`, `ReceiveAssetResult`, `ReceiveOnchainAsset`
- `ReceiveSettlementOutcome`, `RefreshFailure`, `RefreshTransfersResult`, `RefreshedTransfer`
- `ReceiveSettlementOutcomes`, `ReceiveStatus`, `ReceiveStatuses`, `RgbInvoiceRequest`
- `RgbNodeError`, `RgbSdkException`, `RgbSdkFlutter`, `RgbSendRequest`
- `RgbLibWallet`, `RgbLibWalletParams`, `RgbLibWalletException`, `RgbLibWalletIdentity`
- `RgbLibKeys`, `RgbLibPublicKeys`, `RgbLibMnemonicReader`, `RgbLibRuntimeInfo`, `RgbLibBackupRecoveryCapabilities`
- `RgbLibIndexer`, `RgbLibIndexerKind`, `RgbLibIndexerCheck`, `RgbLibUnlockParams`
- `RgbLibWitnessVersion`, `RgbLibAssetSchema`, `RgbLibAssetMetadata`, `RgbLibMedia`
- `RgbLibReceiveAssignment`, `RgbLibReceiveData`, `RgbLibInvoiceData`, `RgbLibTransfer`
- `RgbLibNetworkInfo`, `RgbReceiveAssignmentKind`, `getRgbLibNetworkDefaults`
- `BurnCapabilityWallet`
- `RlnInvoiceStatusValue`, `RlnInvoiceStatuses`, `RlnKeyMaterial`, `RlnMnemonicKeyMaterial`
- `RlnOperationTimeoutException`, `RlnOperationTimeoutPolicy`, `RlnPaymentStatusValue`, `RlnPaymentStatuses`
- `RlnSeedBytesKeyMaterial`, `RlnSeedHexKeyMaterial`, `RlnSigner`, `RlnSignerHost`, `SDKError`
- `RequestExternalInvoiceOptions`, `SchnorrSigningMode`, `SelectPaymentAssetOptions`
- `SendAssetOptions`, `SendAssetResult`, `SignMessageParams`
- `UnsupportedWalletFeatureException`
- `UtexoLsp`, `UtexoLspClient`, `UtexoLspConfig`, `UtexoUnlockConfig`, `UtexoWallet`
- `UtexoWalletConfig`, `ValidationError`, `VerifyMessageParams`, `WaitOptions`
- `WalletBackupResponse`, `WalletCapabilities`, `WalletError`, `WalletException`
- `WalletInitParams`, `WalletNetworkInfo`, `WalletNodeInfo`, `WalletValidationException`
- `accountDerivationPath`, `accountXpubsFromMnemonic`, `createWallet`, `deriveKeysFromMnemonic`
- `deriveKeysFromMnemonicOrSeed`, `deriveKeysFromSeed`, `deriveKeysFromXpriv`, `fromUnitsNumber`
- `generateKeys`, `getNetworkDefaults`, `getNetworkVersions`, `getXprivFromMnemonic`, `getXpubFromXpriv`
- `isClaimablePaymentStatus`, `isNetwork`, `isTerminalPaymentStatus`, `isUmaAddress`
- `normalizeInvoiceStatus`, `normalizeLightningAddress`, `normalizeNetwork`, `normalizePaymentStatus`
- `normalizeReceiveStatus`, `normalizeSeedInput`, `parseCoreAssignment`, `parseCoreOutpoint`
- `parseLightningAddress`, `peerUri`
- `resolveUnlockParams`, `restoreKeys`, `seedFromMnemonic`, `signMessage`
- `signSchnorr`, `toUnitsNumber`, `tryNormalizeInvoiceStatus`, `tryNormalizePaymentStatus`
- `validateBase64`, `validateBip39Mnemonic`, `validateHex`, `validateMnemonic`
- `validateNetwork`, `validatePsbt`, `validateString`, `verifyMessage`
- `verifySchnorr`, `wipeSecretBytes`, `xOnlyPointFromPoint`

## Mainnet Signer Support Boundary

For the initial onchain-only mainnet scope, `UtexoWallet.init`/`reinit` accept
only the built-in `PasswordRlnSigner` or an implicit password signer. External
and custom signers, including password-signer subclasses, throw
`UnsupportedWalletFeatureException(feature: 'mainnet.externalSigner')` before
native allocation. This applies with and without VSS. Existing non-mainnet
external-signer compatibility is unchanged and is not a production safety
claim. The Swift/Kotlin bridge enforces the same external-mode exclusion for raw
clients using each node's stored network; unknown network aliases fail closed.
The advanced raw client remains outside the supported production wallet facade.

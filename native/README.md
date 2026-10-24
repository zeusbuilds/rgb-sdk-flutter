# Durable on-chain source overlay

This overlay adds a native operation journal to the SDK's pinned RLN source. It is a local candidate; the published official `v0.17.0-beta.3` binaries do not contain these methods. The source commits, patch hashes and supported scope are recorded in `durable_onchain_manifest.json`. A platform candidate must also carry its actual build inputs, binary hashes and qualification evidence. Do not silently fall back to a one-shot send when this protocol is unavailable.

The patch supports Bitcoin and fungible, non-donation RGB on-chain payments. It does not recover legacy unidentified one-shot sends, enable Lightning, or authorize automatic monetary retries. Keep old unresolved attempts protected.

The qualified storage contract is an intact private local wallet cohort across process/native restarts and coherent app-update directory relocation with SDK envelope version 2. That envelope binds the native network and both full account public keys instead of the installation's absolute path. Unpublished version-1 envelopes keep their strict path binding and are never silently migrated. All four native durable APIs reject configured VSS before accessing or creating outbox state: the existing VSS restore covers the RGB fingerprint child, not this operation journal. The Flutter SDK and Aster also reject a missing or symlinked outbox for persisted requests rather than recreating it to certify absence. Full ZIP restore, selective file loss, manual copies, reconstructed empty directories and mixed-age app/native snapshots are not qualified; ownership markers alone do not prove those journals form one consistent backup. No absent/cancellation certificate may be interpreted as proof across an unsupported restore.

## Protocol

Four UniFFI methods accept or return JSON strings:

- `prepare_onchain_send(request_json)` binds an operation ID to a complete immutable request and the native wallet/network identity. It builds and signs a transaction without calling End. The exact unsigned transaction and RGB metadata are flushed before native input reservations may commit; the signed transaction is then flushed before the method reports Prepared. An interrupted preparation resumes the saved transaction instead of choosing new inputs.
- `commit_onchain_send(request_json)` durably records End authorization, then releases only the saved signed transaction. Repeating this explicit operation never constructs another payment. A known accepted receipt is returned directly. For RGB, progressed or failed batches are never restarted.
- `onchain_send_status(request_json)` reads the operation and may establish native acceptance using the exact saved transaction identity. It validates the complete caller request and stored binding. Before reporting newly observed acceptance, it durably acknowledges the exact native receipt under the outbox lock, so later missing history cannot recreate a hidden fence. This can create the lock/outbox directory and update local metadata; it never broadcasts, posts a consignment or calls payment End. Missing history is not proof that a payment did not happen.
- `cancel_onchain_send(request_json)` is permitted only before End authorization. It durably revokes the operation, releases only its exact native resources, and records Rejected after cleanup is established. If the operation is absent, it writes a permanent request-bound rejection certificate so a delayed prepare cannot resurrect it. Repeating cancellation safely completes interrupted cleanup. Committing and Accepted operations cannot be cancelled by this method.

The request schema is strict and uses camel case. Required fields are `version: 1`, `operationId` (32 lower-case hexadecimal characters), `fingerprint` (64 lower-case hexadecimal characters), `kind` (`bitcoin` or `rgb`), positive integer `amount` and `feeRate`. Bitcoin requires `address`. RGB requires `assetId`, `recipientId`, and `transportEndpoints`, and a concrete positive `expirationTimestamp`, with optional `witnessAmountSat`, `witnessBlinding` and `minConfirmations` (default 1). `donation` defaults to false and true is rejected. The caller's fingerprint should hash its canonical command envelope, including wallet/network identity; native storage additionally checks the full request and a wallet binding derived from both account public keys and network.

Responses contain `version`, `operationId`, `fingerprint`, `kind`, `phase`, `txid`, `batchTransferIndex`, `failureCode` and `endAuthorized`. Phases are `absent`, `preparing`, `prepared`, `committing`, `accepted` and `rejected`. Preparing can have a known unsigned transaction identity. Prepared always has the exact signed transaction identity. Committing and Accepted have End authorization. Rejected has no End authorization and cannot be revived. Signed/unsigned PSBTs and wallet public keys are never returned in status responses.

Preparation rejections expose a finite, payload-free `failureCode`: `insufficient_bitcoins`,
`insufficient_asset_balance`, `insufficient_allocations`, `invalid_recipient`, `invalid_amount`,
`invalid_fee`, `network_unavailable`, `invalid_configuration`, `storage_unavailable` or
`preparation_failed`. Matching uses typed RGB-library variants, never error text. The reason
explains a rejected action; it is not a certificate on its own. Only a bound `rejected` phase
with `endAuthorized: false` establishes non-execution and completed resource cleanup. A
`preparing` response still protects its resources even though payment End was never authorized.
Unknown/internal errors remain generic rather than leaking private destinations or response bodies.

Dart deadlines do not cancel native work. After a timeout, only node identity, pure RGB invoice decoding and exact durable
status inspection can pass the binding's quarantine, and both still wait on the same native
queue. An inspection whose deadline expires before entry never dispatches later. Inspection
cannot authorize a payment or reactivate ordinary operations; explicit lifecycle recovery is
still required before mutation. This handles a late completed native call without racing it,
repeating it, treating timeout as rejection, or silently reopening the wallet.

The per-wallet outbox uses restricted files, atomic replacement, file flush and directory flush. Corrupt, incorrectly bound or unsafe records cause failure; they are never treated as absent. Records and rejection certificates must not be pruned while delayed operation calls could exist.

Consumers must retain a wallet-wide guard while an operation is unresolved, including against legacy one-shot sends and other wallet mutations. Aster enforces this guard. The additive protocol does not make the legacy APIs participate in operation-journal recovery.

## RGB recovery

The pinned RGB library can post a consignment before its SQL transaction commits. The dependency patch handles both legacy error `-101` and error-free `result: false` as a duplicate/occupied recipient response, accepting it only after fetching the existing post and verifying the exact anchor transaction, output index and decoded consignment bytes. A different or unavailable post remains unresolved. This is explicit same-operation completion, not a new transfer or an amount/time/address match.

Non-donation RGB End now saves immutable, checksummed consignment snapshots bound to the exact transaction and asset before the first proxy POST. Explicit replay restores those first bytes even after the RGB stash or chain heights advance. Incomplete staging files are never reused as snapshots; missing or corrupt committed snapshots are a blocking recovery failure.

The dependency also supplies preparation callbacks before SQL commit. Native code flushes the transfer's required metadata and saves its exact unsigned PSBT in that callback. If preparation rolls back after the callback, End can reconstruct the same transfer; its eventual native batch index is authoritative and can differ from the tentative rolled-back index. The transaction ID remains fixed.

## Reproducing the source

Start from the exact RLN commit in the manifest with its pinned Lightning submodule initialized. Materialize the exact RGB library commit at `_recovery-deps/rgb-lib`, apply the RGB patch there, and apply the RLN patch at the RLN root. The included Cargo lock changes remove only the two RGB local-package source entries. Build with that lock file and record the actual toolchain, target and feature set. Regenerate both language bindings from the patched library/UDL. A simulator-only candidate does not establish an Android, device, universal framework or public-release qualification.

Tests cover strict journal identity, lost storage acknowledgements and phase boundaries. Those tests complement, and do not replace, funded interruption tests for native preparation, broadcast, proxy submission, process death and restart on the existing isolated qualification stack.

## Reproducing the local iOS Simulator fixture

`tool/build_durable_onchain_ios_sim.py` builds only arm64 iOS Simulator libraries and
stages a separate SDK copy. It requires an existing patched source checkout prepared
as above, Rust 1.94.0, bindgen and Xcode with its Simulator SDK already installed.
It does not install tools, start services, create containers or change the official
SDK's artifacts, baseline, downloader or verifier.

From the SDK checkout, provide a new ignored output directory and optionally reuse
an existing Cargo target cache to avoid duplicating large build outputs:

```sh
python3 tool/build_durable_onchain_ios_sim.py \
  --source /absolute/path/to/patched-rln-source \
  --output build/durable-onchain-ios-sim-candidate \
  --target-dir /absolute/path/to/existing-cargo-cache
```

The builder checks all three pinned source commits, rejects unrelated source edits,
verifies the checked-in patches, records effective source and toolchain inputs,
builds the native archive and generator, then derives Swift/FFI bindings from the
exact archive and UDL. It checks source stability again before staging. Logs and
hashes remain in the output directory, including failures; reruns require a new
output directory. No previous output or wallet data is deleted.

The resulting `fixture-sdk/fixture-native-manifest.json` binds the archive, generated
bindings, SDK wrappers, source overlay and fixture podspec. Only that separate copy
enables `RGB_RECOVERABLE_ONCHAIN_SEND` and verifies its explicit local manifest during
Pod installation. An ignored app override can use this fixture for local testing.
It does not qualify a clean public dependency restore, iOS devices, Intel Simulators,
Android, release provenance or funds-bearing mainnet production. Production remains
blocked until qualified native artifacts and a corresponding immutable public SDK
revision are available; do not replace that requirement with a one-shot fallback.

Run the host-only admission tests with:

```sh
python3 tool/test_durable_onchain_ios_sim.py
```

## Scoped qualification record

`durable_onchain_qualification.json` records the redacted evidence hashes and remaining
release gates. The earlier stable-wallet-v2 candidate passed 27 native journal unit regressions plus one
host integration fixture containing 11 funded Bitcoin/BFA scenarios on the existing
isolated stacks. Proxy `false`/legacy `-101` exact-match and mismatch probes also passed.
The original eight isolated containers and original chain ancestors were preserved;
no containers were created or reset. The recorded test-only fault hooks are separate
from the native production source.

The arm64 iOS 27 Simulator candidate passed three real Bitcoin scenarios through
Aster's repository, SDK, Pigeon, Swift and native code: normal submission, lost prepare
response with cancellation, and lost commit response with exact receipt recovery.
Two process restarts and an actual pending-operation app-install container relocation
preserved the private file cohort and full account binding. Late prepare/commit calls
could not revive the cancelled operation. Amount, fee debit and confirmation were
checked by exact transaction identity. These response-loss injections and restarts
do not establish physical power-loss or every-instruction SIGKILL coverage.

That candidate's SDK evidence includes 621 Dart tests and 56 focused recovery cases; Aster's 1,424 host tests
include 54 payment-repository and 23 SDK-adapter cases. Aster analysis is clean.
The candidate tooling passed 10 admission tests and the generated verifier passed
four synthetic integrity/path checks. The official iOS native verifier also passed;
its files and baseline remain unchanged. The build-bound manifest and fixture are
immutable; this separately maintained evidence record can receive later receipts.

This qualifies a local arm64 Simulator candidate within the stated storage and test
scope. iOS RGB end-to-end, physical-device, Intel Simulator, Android, approved public
native provenance, clean public dependency restore, backup/restore continuity and
production-mainnet release gates remain open. Retained journal growth and long-history
preparation latency have not been benchmarked: new preparation scans retained records,
and no terminal records or rejection tombstones were pruned.

The later feedback revision preserves the earlier funded receipts under their original source
hashes. Its typed preparation reasons and queue-drained timeout inspection pass 29 native
journal unit tests, 624 SDK Dart tests (80 focused binding/recovery/safety tests), clean SDK
analysis, API/documentation checks and 10 candidate-tooling admission tests. Any new binary
or Aster runtime evidence is recorded separately in `feedbackRevision`; earlier funded cases
are not relabeled as current-revision executions.

Funded requalification subsequently exposed a candidate-specific RGB preparation panic: a
blocking HTTP client owned an internal Tokio runtime but was constructed inside an async
native call. All four durable APIs now run their blocking wallet work on a blocking worker.
An owned unlocked-wallet lifecycle lease travels with that worker and survives loss of its
async waiter. This keeps shutdown serialized until native work actually completes. The
worker-boundary revision and its new binary/test receipts are tracked separately; the prior
Bitcoin/funded receipts must not be relabeled as a pass of an unverified replacement.

The final worker-boundary overlay passed 31 native journal unit regressions and one host
integration fixture containing 12 funded functional cases (8 Bitcoin and 4 BFA), for 32
passing Rust tests. The explicit old-cohort cleanup entry point is intentionally ignored by
the full suite and was run separately only to cancel never-authorized intents. The same
eight existing isolated container identities/images and both baseline chain ancestors were
preserved; existing qualification contracts were reused. All 14 native operation records in
the final fixture ended Accepted or Rejected. A fresh arm64 iOS Simulator archive and its
generated binding/verifier were built from this exact source. No Android build was performed.

The final Dart-inspection fixture (`769f2f81…`) using that unchanged native archive
(`a1fa6d5a…`) subsequently passed four current iOS 27.0 arm64 Simulator cases through
Aster's real repository, runtime, storage, SDK, Pigeon, Swift and native implementation:
typed insufficient-Bitcoin rejection before Commit, normal Bitcoin submission, a dropped
Accepted Commit reply resolved by exact Status inside the original Send, and process
restart with repeated reconciliation/sync preserving the original identity without another
Prepare or Commit. Both 20,000-sat payments confirmed, with exact amount plus 143-sat
fee debits. The fresh wallet's native journal finished with two Accepted records and one
Rejected record, and no unresolved operation. The eight existing container identities and
Bitcoin chain ancestry were preserved; no container lifecycle or shared-stack operation
was performed. The redacted summary hash is `099660c3…`; full hashes and limits are
recorded in `feedbackRevision.iosSimulatorRuntime` in the qualification JSON.

This current iOS runtime pass covers Bitcoin. The dropped reply was controlled App-engine
fault injection after real native acceptance; true SDK deadline recovery and RGB invoice
validation have separate gated queue-test evidence. Current iOS RGB end-to-end, Android,
physical-device, public native artifact/clean dependency restore, backup/restore continuity
and production-mainnet qualification remain open.

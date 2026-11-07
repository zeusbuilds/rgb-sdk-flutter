# BFA.7 Flutter native integration

Candidate reviewed on 2026-11-08. **RGB_L1 remains gated in Aster and in release
qualification.** This document describes implemented mechanisms and their
verification boundaries; it is not mainnet or hosted Dev approval.

## Immutable inputs

Both mobile platforms use upstream BFA.7
`9ec49c08be2e68f08521281e3efbd760ec989cb9`, UniFFI 0.32.2 and Flutter bridge 5.
The separately named native version is
`0.3.0-beta.7-upstream-dev-bfa.7-bfa-flutter.2`; it does not relabel an upstream
binary. `native/rgb_l1/source-manifest.json` pins the base tree, four reviewed
core patches, guarded Esplora dependency, Flutter integration patch, dependency
lock, generator, compiler and platform targets. `tool/build_rgb_lib_bfa7.py`
rejects altered source, external dependencies, target stamps and tool inputs.

The integration tree is `8ac556ee67db70b93abb69b4ebd8fb0e6752dc0e` and the
UniFFI lock SHA-256 is
`81af7c87fac88abbd40b1621ce2fa7655165b6b0c8bdd23faa313d25139330a6`.
Final archives have independent exact size/digest pins. Runtime initialization
compares their actual metadata with the reviewed source/overlay/manifest/lock
identities before reading mnemonic material. Existing BFA.5 directories are
not silently upgraded. Legacy RLN retains its separate native baseline and
version-1/version-2 command behavior.

The released RN beta.40 native reference remains frozen in
`tool/rn_beta40_rgb_lib_reference.json`. Its upstream parity check independently
validates this explicitly recorded Flutter divergence.

## Standalone contract registration

`RgbLibWallet.importContract` calls native genesis-only registration. It accepts
bounded canonical Base64 and an exact expected RGB contract ID. Native code
validates the network, schema and self-contained genesis without transfer
history, witnesses or unresolved claims before an atomic import. Repeating the
same import is idempotent. Registration creates metadata, **not an allocation
or a balance**. Aster additionally checks the approved export SHA-256 and exact
native BFA name, ticker and precision before issuing an asset-bound witness
invoice. A display symbol never authenticates an asset.

BFA.7 online configuration requires an explicit EVM chain ID, RPC endpoint,
and minimum/maximum mint-lock block policy. These bounds describe the **EVM
backing chain's blocks**. They cannot be inferred from a Bitcoin network name
or copied from an unrelated test fixture. `getReceivedMint` exposes the six
actual native mint fields with exact unsigned amounts; it does not invent an
asset identifier absent from the native record.

A full online session validates every configured EVM chain, including finalized
and historical-state access. Removing a host's preliminary chain-ID check does
not remove that native dependency. `init()` and `openExisting()` without unlock
can open local state; local RGB metadata, balances, transfers and receipts are
available. The current BTC balance/history facade still requires an online
session even with `skipSync: true`. A deliberate Bitcoin-only degraded mode
would need separate capability handling, disabled BFA-dependent actions and a
serialized same-cohort reopen before restoring the full online configuration.
It is not implemented by silently omitting EVM validation or changing endpoints.

## Durable send protocol

New RGB_L1 commands use canonical envelope version 3, bound to the wallet,
network, native source/overlay and a randomly created, persisted recovery
cohort. Both Dart and Rust verify the same independently frozen fingerprint
vectors. Native preparation verifies BTC outputs/change or RGB assignments,
recipients, expiry, witness and transport data against the approved command.
For proxy-v1 witness recipients, the approved request omits blinding: native
code derives and verifies the exact value from both parties' keys. It never
substitutes a caller-selected or arbitrary value for that protocol derivation.

The native wallet keeps an HMAC-authenticated private outbox with a SQLite
anchor. Atomic writes, file/directory synchronization, restricted ownership and
permissions, non-symlink opens and an exclusive lock protect it. A narrowly
validated one-write-ahead repair handles interruption between file publication
and the database commit. Missing, stale, foreign, malformed or unauthenticated
state fails closed. Retained terminal receipts have bounded capacity; they are
not evicted to make a replay appear new.

The outbox uses nonblocking platform `flock` on the admitted Unix targets.
Rust 1.94's standard-library lock implementation excludes Android, so its
`Unsupported` error must never be labelled as ordinary contention. Actual
Android qualification found this and the native implementation now classifies
only `WouldBlock` as busy; other lock errors preserve the storage fence. See
[the exact toolchain implementation](https://github.com/rust-lang/rust/blob/1.94.0/library/std/src/sys/fs/unix.rs#L1423-L1481)
and the native two-handle exclusion/release regression.

1. **Prepare** persists exact transaction identity before the native reservation
   commits. It does not submit a payment.
2. **Commit** records authorization, then records entry to the dispatch boundary
   immediately before the first mutating proxy call or Bitcoin broadcast. It
   never replays native End after dispatch could have begun. RGB consignments
   are frozen and hashed before the
   first external mutation; they are never regenerated from a changed stash.
3. **Status** observes the same operation. Local acceptance or exact independent
   transaction/consignment/recipient-ACK evidence can establish submission.
   It never calls Begin, End, broadcast or a mutating RPC. Partial evidence,
   unavailable services and absence remain unknown.
4. **Cancel** releases only the exact certified undispatched reservation and
   retains a tombstone that blocks a late Prepare. A potentially submitted
   operation cannot be canceled by elapsed time or an empty transaction list.
5. **Revoke** is a separate, explicitly authorized operation for dispatched RGB
   payments. It verifies the exact request, original endpoint and signing
   authority. An affirmative signed revocation is durably recorded before
   releasing the local reservation. An ambiguous response leaves it protected.
   Ordinary Cancel and Status never acquire this authority.

Ordinary monetary mutations, including raw Begin/End, maintenance and future
unknown operations, are blocked while the native recovery fence is active.
Only a reviewed observation/recovery allowlist can run. This rule is shared by
the Swift and Kotlin session dispatchers and independently compiled policy
tests. Safe errors are allowlisted; native errors do not echo PSBTs, recovery
words or remote response bodies.

`listPendingOnchainSends` can reconstruct a missing app intent from the exact
authenticated native command. It grants no new Commit authorization. Paginated
accepted receipts retain exact gross amounts and transaction identity without
the signed PSBT. They can repair history enrichment after app-archive loss;
the native transaction history still determines confirmation, fees and status.
Acceptance means submission, never chain confirmation.

## Restart and backup boundaries

A normal process restart reopens the same native outbox/cohort and checks
status without replaying payment submission. An independently lost app marker
does not remove the native mutation fence.

Provisioned wallets use capability-checked `openExisting`; missing storage
cannot become a new wallet. `init` and `reinit` retain their documented
create-or-open semantics. Bounded, strict profile parsing rejects damaged or
substituted metadata before opening a wallet. See the
[backup and recovery boundary](RGB_LIB_BACKUP_RECOVERY.md).

Encrypted backup includes native wallet state, outbox and receipt data. Restore
uses private staging, rejects occupied destinations and publishes only a valid
archive. Every actual restore receives a fresh restore stamp. A valid backup
may be older than a payment sent later, so **a restored snapshot is not trusted
as proof of nonexecution**. It is quarantined with
`RECOVERY_RESTORE_UNCERTAIN`: new spending, cancellation, revocation and generic
transfer refresh are blocked, while
exact historical or positively observed acceptance can still be inspected.
Generic refresh may ACK or broadcast and is not an observation-only operation.
There is no time-based expiry or automatic unquarantine. A reviewed freshness
authority and recovery procedure remain prerequisites for unrestricted
restored-wallet spending. Seed import alone does not reconstruct RGB state.

## Verification and remaining gates

Native targeted tests cover canonical fingerprints/u64 limits, atomic-write
faults, restart/tombstones, wallet/cohort binding, tamper/rollback and filesystem
attacks, exact zero-balance/idempotent contract import, immutable consignment
snapshots, recipient ACK signatures and real encrypted backup restore with
fresh quarantine. These are real native tests, distinct from Dart channel mocks.
Compiled Kotlin and Swift adapters exercise the generated UniFFI surface,
unsigned mint DTOs and the shared mutation policy. The
[qualification record](BFA7_QUALIFICATION.md) identifies the executed funded
and platform cases, exact identities and remaining boundaries separately.

The exact patched dependency lock has zero known vulnerabilities and zero
unsound notices at RustSec
`309392b18f6b17022f82c701f300433126901068`. Three unmaintained dependencies remain;
see `native/rgb_l1/security-review.json`. This audit does not approve funds
safety. The exact `.2` RGB_L1 component has no linked DiskSpace imports across
all six framework/architecture pairs. This does not claim that unreferenced
members of the raw Rust static archive have no such symbols. Final signed-app
API and aggregate privacy evidence remain required. Dual-engine packages also
retain RLN's independent security/privacy blockers.

The SDK completed 20 installed funded/native cases across iOS 27 and Android 17,
followed by 14 separate offline wrapper/storage-opening cases. Host proofs
cover interruptions, partial submission and reorg/reconfirmation under their
recorded source identities; they are not additional mobile cases. Aster's full
funded flow and distinct same-artifact process-cold reopen now pass on both
platforms, with its explicit one-confirmation receive policy verified on Android.
The native-only `.2` beta is published and clean public iOS/Android acquisition
passes. Final immutable consumer pinning, signed release packaging and deployment
approval remain separate gates. An approved
freshness/old-copy retirement authority is still absent, so restored RGB
snapshots remain protected and seed-only RGB recovery is unsupported.
The issuer-approved **current Dev BUSDT export/hash/metadata**, matched backing
contracts, explicit mint-lock policy and hosted funded acceptance remain
missing. The historical BFA.5 contract is never a substitute.

The dual-engine Android sample derives its packaged ABIs from Flutter's
`target-platform` property and intersects them with `arm64-v8a`/`x86_64`.
Explicit JNI exclusions remove every unselected ABI, including the other 64-bit
ABI on a single-target build. Pure 32-bit and unknown targets fail configuration.
The SDK library module retains its legacy RLN capability; this is an example/app
packaging requirement for binaries that include the 64-bit RGB_L1 engine.

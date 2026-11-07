# Flutter RGB_L1 backup and recovery boundary

Encrypted native snapshots preserve the wallet's private RGB state and exact
payment evidence. **Portable restored-wallet spending is unsupported.** No
approved recovery authority currently establishes the freshness of a restored
snapshot or fences a still-active copy. A recovery phrase alone does not recover
RGB consignments, allocations, transfer history or the durable payment outbox.

`RgbLibRuntimeInfo.backupRecovery` exposes this distinction directly:

| Capability | Current value |
| --- | --- |
| `encryptedSnapshotCreation` | `true` |
| `readOnlySnapshotRestoration` | `true` |
| `restoredWalletSpending` | `false` |
| `mnemonicOnlyRgbRecovery` | `false` |

These describe the supported public `RgbLibWallet` API, including its platform
operation policy and exact pinned native implementation. They do not certify the
bundled upstream UniFFI/Rust entry points as a standalone restore-safe API.
Calling raw signing, Begin/End, recipient or asset mutators outside the Flutter
policy bypasses that supported boundary and is unsupported. Generic native
`refresh` additionally enforces quarantine directly because the Flutter API
must otherwise permit it for normal pending-wallet progression.

A successful archive extraction,
empty pending list, successful synchronization or a new local cohort cannot
upgrade them. Do not advertise encrypted export or phrase import as complete,
spend-ready RGB recovery. A cold reopen of the same intact wallet directory is
different: it preserves the current authenticated cohort and its dispatch facts.

## Opening an existing wallet safely

Use `RgbLibWallet.openExisting([onlineParams])` when opening a provisioned wallet.
It requires an existing SDK profile under the platform's exclusive storage
lease before creating a native wallet. Missing or empty storage is rejected
with `WALLET_STORAGE_MISSING`; existing profile/cohort, outbox and SQLite anchors
are still authenticated by the native implementation. A failed existing-only
open never falls back to initialization.

`RgbLibRuntimeInfo.supportsExistingOnlyOpen` describes this compiled platform
wrapper behavior, independently of Rust archive capabilities. Missing or false
support rejects before the Dart key reader or native open call, so an older
wrapper cannot silently ignore the new mode. Malformed capability/flag values
are rejected rather than coerced.

`init` and `reinit` retain their compatible **create-or-open** behavior: they may
initialize a new profile in empty storage. Their names do not prove that a
previous cohort is present. Applications with a ready-wallet registry should
use `openExisting`, retain a stable native subdirectory separate from app-owned
metadata, and treat missing storage as a recovery failure. This mode does not
restore lost RGB state or establish snapshot freshness. A restored snapshot
still retains the same spending and refresh quarantine described below.

## What restore safely does

`RgbLibWallet.restoreFromBackup` requires an empty dedicated private directory.
The archive is decrypted into private staging, checked for the matching SDK
profile/cohort and atomically installed. Native restore creates a fresh
`.flutter-restored-snapshot` marker, excluded from future archives. On open, the
authenticated outbox records that this is a restored snapshot. Repacking or
restoring it again does not remove that restriction.

The matching keys can open the restored wallet for supported observations,
including balances, history and exact retained accepted submission receipts.
Read-only Status may recover a known operation from exact chain/proxy evidence.
An accepted submission receipt does not assert chain confirmation. Unknown or
unavailable observations remain unknown. Indexer synchronization and local
balance/history inspection remain available. Generic transfer `refresh` is
**not** read-only: it may ACK consignments, release or broadcast signed
transactions and progress pending transfers. On a restored snapshot it fails
with `RECOVERY_RESTORE_UNCERTAIN` before online admission or protocol work, even
when the archive contains pending incoming or outgoing transfers. Use the
supported local inspection methods and exact read-only Status instead.

New spends, cancellation, ordinary mutations and absence certificates for
unlisted operations fail with `RECOVERY_RESTORE_UNCERTAIN`. Discovery methods
that could otherwise turn an empty outbox into permission to send also fail
closed. Resolving every operation present in the archive does not release the
wallet-wide restored-snapshot fence.

## Why local checks cannot release the fence

1. Snapshot A contains revision N and no pending payment.
2. The original wallet later authorizes payment P at revision N+1. A proxy may
   hold the signed transaction while its reply is lost and Bitcoin has not seen
   it yet.
3. Restoring A produces a correctly authenticated outbox and matching SQLite
   anchor. It contains neither P's command nor its transaction/proxy secrets.
4. A chain sync or a lookup of the operations listed in A cannot prove P absent.
   Allowing a replacement payment from different remaining inputs could pay
   twice when P later progresses.

The local HMAC and SQLite anchor detect selective corruption and rollback. They
cannot detect a coherent older copy of both files. Local file locks protect one
physical directory, not another device or a copied directory. Manually copying,
editing or rolling back the entire private wallet directory outside the restore
API is not covered by the restore marker or the supported freshness contract. Device-only secure
storage could support a separately specified same-device transfer; it cannot
prove freshness for an arbitrary portable archive. A new same-seed wallet also
does not recover missing RGB client-side state or the old cohort's authority.

The existing indexer supplies chain observations, not an off-chain wallet
operation ledger. Current RGB proxy `ack.get`/`consignment.get` calls are bound to
known transfer IDs and operation keys. They do not enumerate a wallet's latest
cohort/revision, certify that unknown operations do not exist, or revoke another
copy's future authorizations. The shared stack consumer contract explicitly
does not supply VSS; no recovery service is created by this SDK.

## Required team-owned authority contract

An implementation proposal must establish all of the following before removing
the portable-restore restriction. This is a requirement, not a claim that such a
service or API already exists.

1. **Latest state and exclusive ownership.** A durable, authenticated,
   linearizable register binds network/checkpoint, derivation/account identity,
   cohort, ownership epoch, native source/schema, revision and snapshot digest.
   Ownership transfer must atomically fence the old copy from every new
   value-changing operation. A local timestamp, lease expiry or user assurance
   that the other device was deleted is insufficient.
2. **Persist before dispatch.** Before any first monetary RPC or signed
   transaction release, the authority durably stores the exact immutable
   operation identity and a recoverable encrypted native cohort containing its
   command, plan, RGB state/consignments and dispatch facts. The writer uses
   compare-and-swap against the current epoch/revision. An ambiguous authority
   response is recovered using that same operation ID; it never creates a second
   payment. The service must not receive the recovery phrase or plaintext keys.
3. **Fresh retrieval and pending authority.** Restore obtains the latest
   complete encrypted cohort plus a fresh challenge-bound proof from an approved
   pinned authority. A signed older blob alone is not enough. Every potentially
   authorized operation is retained and resolved using exact positive evidence
   or an authoritative pre-dispatch cancellation certificate. Changing epochs
   does not revoke a transaction already released to a proxy or recipient; those
   operations remain fenced until their existing authority is resolved.
4. **Recovery, outages and qualification.** Specify key recovery, authority key
   rotation/trust, conflict/replay handling, corruption, permanent service loss,
   restart atomicity and a non-destructive incident path. During an outage or an
   unverifiable epoch/state gap, observations may remain available but new
   spending stays blocked. Test old/new/concurrent copies, interrupted writes
   and ownership transfers, lost replies, all monetary entry points, independent
   BTC/RGB reconciliation and chain reorgs on the existing isolated fixture.

The team must supply the approved service/protocol, trust and deployment policy,
durability/availability guarantees, and a reviewed lifecycle for the complete
encrypted RGB cohort. A generic blob store, per-transfer proxy lookup or partial
VSS backup that omits the native outbox does not meet this contract.

## Successor restore-input hardening

The unpublished successor adds strict admission before expensive work: exact
19-byte nonces; bounded scrypt parameters; a two-file encrypted envelope with
at most 4 KiB public metadata; ZIP central-directory/count checks before parser
allocation; 16,384 entries, 1,024-byte paths and 32 path components; 512 MiB per
wallet file and 2 GiB aggregate/archive limits. It rejects traversal, path aliases,
symlinks/special files, duplicate outputs and unsupported ZIP64/multi-disk input.
Creation preflights the same wallet tree, path/count/size and KDF budgets before
compression or encryption, then checks its final archives. It rejects recursive
exports inside the source wallet and never overwrites an existing export.
Common admission rejects ASCII case-fold collisions in every path prefix;
filesystem-specific Unicode aliases fail safely through exclusive file creation
without overwriting a prior target. Arbitrary Unicode names are not silently
renamed or normalized. Extraction uses new private files and bounded copies. An authenticated final
encryption chunk is mandatory, including at an exact plaintext block boundary.
Malformed or over-budget input returns `RECOVERY_BACKUP_INVALID`; it never
silently adjusts attacker-supplied KDF costs or activates a partial wallet.

These changes improve safe snapshot inspection. They do **not** establish
portable freshness or authorize restored-wallet spending. Published
`native-bfa7-flutter.1` archives retain their original identities; successor
verification and distribution must use a new independently sealed candidate.

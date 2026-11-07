# BFA.7 qualification evidence

Reviewed on 2026-11-07. **RGB_L1 remains gated.** These are executed host-native, iOS and Android consumer
checks against the existing isolated regtest fixture, not approval of a hosted
Dev asset or a public release. Mechanism and release boundaries are described in
[BFA7_NATIVE_INTEGRATION.md](BFA7_NATIVE_INTEGRATION.md).

## Source and dependency identity

The native upstream source is BFA.7
`9ec49c08be2e68f08521281e3efbd760ec989cb9`, with Flutter's
`flutter-bfa7-durable-v1` integration. The native candidate version is
`0.3.0-beta.7-upstream-dev-bfa.7-bfa-flutter.1`, bridge 5. The host consumer uses
the exact prepared native source as a path dependency outside that source tree;
it does not edit or replace the source under test.

The host consumer's lock derives from the sealed UniFFI lock, SHA-256
`4b675f6187e069e6236033415ff157379b039717b387a1dd596669ec52f6a21f`.
All **507 shared packages** match name, version, source and checksum. Only the
qualification root package is added; 37 unused UniFFI/CLI packages are pruned.
The consumer lock SHA-256 is
`f00a1998e7ae33b4589e92751b7e956259295f667d2fc9406a2cfc3200566765`.
An initial unexecuted build used the core lock; its two version differences were
detected and the consumer was rebuilt from the UniFFI lock before wallet
creation or funding. It is not counted as qualification evidence.

The initial funded run used integration tree
`a67d84e821ccbe466702754a1cf711ac8c4cf204`. The discovered witness-plan problem
below was fixed before the original RGB command was committed. That funded
continuation used `durable_onchain.rs` SHA-256
`9803f5236a1c29eaef7b7c776f47cc840a7754113429342b0d59dd982ac07569`.
Its record explicitly marks the source as awaiting reseal. These initial host
runs used the installed default compiler, Rust 1.99.0; they are not relabeled as
compiler-identical mobile evidence. The final sealed/pinned-compiler run below
was executed separately from the same preserved wallet state.

The full funded host and iOS run used integration tree
`9ec9827a3b9cc5962f93e04932c441be1b3a0a71`, integration-patch SHA-256
`01074399f8af246c703b4e182a85951baf7535a76ba3e132f86e617f55ee83d3`,
and source-manifest SHA-256
`d4023246d13bc798343e6d49a964d939c4db02923e4890505044979f32ea14fb`.
That verified host client used the manifest-pinned **Rust 1.94.0**
(`4a4ef493e`, 2026-03-02), unchanged dependency graph, and binary SHA-256
`5256dd3e444c2696e3d6530cf28996c5e61d84ff7ff6a6828e49d9cd046b6188`.
The final Android-compatible locking seal is integration tree
`c06ffffce1f0fd5273113132295fce3e6be25052`, patch SHA-256
`3ae6c65184ef6a4ea534100dac82e3c532192482cbd0229c2aa0238d1cf044c7`,
and manifest SHA-256
`d274d1ae7c23f7a27175a94dda5266be11912c23ce95f56c5ca993e2bd3f373f`.
It replaces unsupported Android standard-library file locking with explicit
nonblocking native `flock`, preserving single-writer exclusion and distinguishing
contention from storage errors. It does not change monetary recovery semantics.
The same pinned compiler/dependency graph produced host binary SHA-256
`704793be5fbbd22cfdb5d80c417336035b7815578e19e815de9f34a5b4810eab`.
That client reopened the preserved funded state and read nine exact accepted
receipts, two cancellation tombstones and empty pending inventory without any
new financial call. Full host monetary execution on the preceding tree and that dedicated
read-only compatibility check on the final locking tree are separate evidence.
The subsequent actual Android roundtrip and its host funding below exercised
new RGB commands on the final locking tree as a further distinct stage.

The builder checks source/lock identities before and after compilation, and
runners reject an old binary or changed seal.

## Preserved infrastructure and test storage

The existing Docker project `utexo_wdk_onchain_bfa7_fixture` was admitted by its
owner helper before actions. No containers, chains, contracts or existing wallets
were created, reset, replaced or deleted. The fixture's Core, Esplora, Fulcrum,
RGB proxy and backing EVM endpoints are respectively 49743, 49794, 49702, 49790
and 49745 on host loopback. The proxy reports protocol 1.0/version 0.4.0. The
backing EVM is **31337**, not the separate WebRGB burn destination route 42161.

Two fresh, separately stored native test wallets were created below:

`.buildlog/bfa7-native/qualification-wallets/newrun-20261107T094436Z/`

The run directory is 0700 and key/intent/receipt files are 0600. This ignored
folder contains private wallet and signing material; it must not be published.
Only redacted result summaries and their digests are listed here.

The existing public fixture contract is:

- Asset: `rgb:kOryemwN-I8Iutl8-otIPmDa-rn1cPTq-7VuhGvS-oe6oiMc`.
- Native metadata: `WDK L1 Qualification BFA`, ticker `QBFA`, precision 6.
- Public export: 444 bytes, SHA-256
  `189674bd83baa0a74c06f86d4652d896e7725f33285b9e25c8006b2087044cb0`.
- Fixture issuer source: the same upstream BFA.7 revision.

This is a qualification asset, **not Dev USDT**. The shared stack's consumer
registry and the fixture owner's runbook were read before configuration.

## Executed funded BTC and registration checks

1. Both new wallets imported the exact standalone public contract and returned
   the expected ID, BFA schema, native metadata and precision. Registration did
   not credit a balance.
2. The sender received exactly 200,000 regtest satoshis and three confirmations.
   Native balance readback observed the complete funding.
3. A 1,000-sat BTC plan was prepared without broadcast. A separate process
   reopened the same keys, native storage and recovery cohort and observed the
   same prepared transaction identity.
4. Native cancellation returned a durable rejection. A late Commit of that
   canceled command stayed rejected; the Bitcoin mempool remained empty.
5. A new 1,000-sat command was prepared, reopened, committed once and observed
   as accepted after another process restart. A deliberate call on the already
   accepted command returned the identical receipt without creating another
   transaction. Core observed exactly the one expected payment in its mempool.
6. Three blocks confirmed the payment, and the receiver's native settled BTC
   balance was exactly 1,000 sats. The native receipt remained submission
   evidence; chain confirmation came from the independent chain/native history.
7. Four 20,000-sat RGB change outputs were created and confirmed. An initial
   witness invoice bound the exact asset and requested amount. Native send
   inventory contained no unresolved operation at the end of this BTC scope.

BTC transaction:
`bb74ba0259e71f3f8f5ee024d3405145e31482998fcb3d40fb696bbc284147d2`.

A Python orchestration argument-name collision stopped the first runner after
funding and before its first payment command. It was a harness defect, not a
native failure. The funded wallet and original evidence were retained. Resume
was restricted to that exact pre-command checkpoint, with empty outbox and the
unchanged 200,000-sat balance verified first; funding was not repeated. The
bespoke repair path was removed from the public runner after use, and its
executed source is retained privately with the run.

## Executed mint and witness RGB delivery

The existing issuer had zero spendable QBFA. A separately authorized tiny mint
therefore used the **existing asset, issuer, test token and backing contract**;
no deployment or reset occurred. Exactly 1,000 QBFA base units were minted to
the SDK sender. The fixture helper requires a blinded mint recipient, so this
exercised an SDK-only receive capability; Aster's witness-only UI was unchanged.

Before backing funds were locked, the recipient's native pending-mint record
matched the issuer's exact operation ID, Bitcoin-witness-derived lock ID,
amount, EVM chain 31337 and block deadline. One authorized settle call funded
the existing EVM lock and completed the mint. Bounded recipient refreshes
progressed that existing proxy handoff; no mint Begin or End was repeated.
The mint's Bitcoin witness was confirmed three times and the native recipient
reported exactly 1,000 settled/spendable QBFA units.

Mint witness:
`b1266bb2df67dd491f61e993c65b20f57969fce239f0742cefdb2f2efcbfd25c`.

A 100-unit RGB payment then targeted an asset/amount-bound witness invoice in
the second new wallet. Its first durable Prepare exposed the defect below and
stopped safely before signing or Commit. The exact native files, command and
unsigned transaction were preserved.

After the targeted fix, a fresh process observed the original operation as
Preparing. Explicitly preparing that **same command** resumed the saved unsigned
plan, skipping Begin: the unsigned PSBT digest, approved command bytes and
transaction ID remained identical. It became Prepared, survived another process
restart and was committed **once**. Accepted status survived another restart.
The recipient progressed the proxy handoff, Core observed the exact Bitcoin
witness, and three confirmations produced exactly **100 settled QBFA units in
the receiver and 900 in the sender**. Final native inventory was empty and the
native accepted-receipt page contained the two expected BTC/RGB receipts.

RGB witness:
`5f0c03af8793f5423e1d0403555048f5b5750535b786b22f2d6b498ec14f0852`.

### Defect found and fixed by the funded run

Proxy-v1 witness sends derive a blinding value from the native operation secret
and the recipient's public key. The approved caller request correctly leaves
that field absent. The original native plan validator compared the generated
value directly with that absent caller field and returned
`RECOVERY_REQUEST_MISMATCH`. The persisted unsigned plan then failed the same
validation on reopen. The payment was never committed or broadcast.

The fix validates the **exact deterministic native derivation**, including its
counterparty binding. It does not remove blinding validation or allow a caller
to choose a proxy witness blinding. All other tested request/plan comparisons
matched: wallet/source/cohort, asset, recipient/key, amount, encryption, expiry,
transport endpoints and Bitcoin witness amount. A native regression test covers
correct derivation, missing/changed blinding, wrong operation/recipient keys,
invalid key length and forbidden caller-supplied blinding. The preserved funded
operation completed after that fix with the same transaction, not a replacement
payment.

## Sealed, pinned-compiler live run

The final Rust 1.94.0 client first reopened the **same** wallet storage/cohort.
It read back both original accepted BTC/RGB receipts unchanged, the original
cancellation tombstone, empty native pending inventory, and the exact 900/100
QBFA balances. It did not recreate wallet storage or infer an outcome from a
similar transaction.

With new unique commands and the existing balances, it then performed:

- BTC: fresh 1,000-sat Prepare/restart/Cancel without broadcast, followed by a
  distinct 1,000-sat Prepare/restart/one Commit/accepted restart. Independent
  Core observation established three confirmations.
- RGB: a fresh 50-unit witness invoice, Prepare without broadcast, process
  restart with the same plan, one Commit, accepted restart, actual recipient
  proxy handoff/broadcast and three independent Core confirmations. The
  original witness-blinding path passed on the final sealed source.

The final native balances were **850 QBFA units in the sender and 150 in the
receiver**. The receiver's vanilla BTC balance reflected exactly its two
1,000-sat BTC receipts; RGB witness BTC remained separately accounted. Native
pending inventory was empty and four immutable accepted receipts were present.
No new mint, funding, container, contract or wallet was needed for this final
run. Every monetary operation had its own exclusive intent and one Commit;
status checks and process restarts did not create another send.

Final-seal BTC transaction:
`25a0a6863f3b19e38bfc9d292f7f8259db1b1acde87d50a2cfddb5593c2d5c72`.

Final-seal RGB transaction:
`83a70c6176ec00e98e67cc6fc83aa3fc7350961b204506d6d0c827f9c786ffdf`.

These are host-core proofs. Swift/UniFFI submission has separate installed
consumer evidence below; these host results are not substituted for it.

## Actual interrupted external submissions

Two additional tests used a local ephemeral forwarding fault harness against the
existing services. Each had a unique approved command and an exclusive intent
record; the forwarder recorded real upstream acceptance. No container, chain,
contract or proxy service was created or reset.

### BTC broadcast reply and observation loss

The harness forwarded the exact signed transaction to real Esplora **once**, then
returned an error instead of its successful response. Exact transaction reads
were temporarily unavailable as well; they returned unavailable, not fabricated
absence. Commit returned `Committing`, leaving the native fence in place. After
read availability returned, a new process called only Status on the original
command. That read repaired the native accepted receipt from the already-recorded
signed transaction and positive chain evidence. Repeating Status returned the
same receipt. Three blocks independently confirmed it.

The recorded counts were one broadcast attempt, one forwarded broadcast, four
temporarily unavailable exact-transaction reads, and no blocked replay attempt.
No second Begin, End, Commit or broadcast occurred. Transaction:
`35e119c569a6f5c8b098dcdd3e9517e8269b55de9eb4be31d92a6c6bb5530af2`.
An earlier, less severe reply-loss case repaired immediately within the original
End call because its positive chain lookup remained available. The harness had
expected `Committing` and stopped on that already-accepted result; its failed
assertion is retained, not counted as a native failure or silently replaced.

### RGB consignment reply loss

A distinct one-unit QBFA witness send forwarded the final exact consignment write
to the real proxy **once**, then replaced the successful reply with malformed
JSON. Commit returned `Committing`. Before any recipient refresh or Bitcoin
broadcast, a new-process Status call repaired acceptance through only
`server.info`, `ack.get` and `consignment.get`, once each. Mutating proxy calls
were prohibited during this recovery observation; none were attempted. The
original ACK and retrieved consignment were bound to the exact transfer and
request, not to a similar amount or history row.

The full run recorded one `consignment.post`, one forwarded write and zero
blocked write replays. Only after read-only recovery did ordinary recipient
refresh progress the existing protocol handoff and Bitcoin broadcast. Three
blocks confirmed the exact witness. Transaction:
`1f7f6ebb6d8d9c1067d18f49a3420997948da3669875384fd760327a76bb435c`.
These two real failures qualify the tested successful-external-write/lost-reply
paths. They do not establish every partial-dispatch or reorg outcome.

## Installed iOS consumer proof

A separate Flutter consumer app exercised the actual Dart → Swift → UniFFI
boundary on the existing iPhone simulator, with fresh private test storage. Its
full funded run used integration tree
`9ec9827a3b9cc5962f93e04932c441be1b3a0a71` and iOS archive SHA-256
`9550622c28540d6086e9bf2c16fb4edefd426f3b184de875d02af0e298f9b153`.
This is a simulator runtime proof, not a physical-device claim.

The consumer completed the baseline ABI/runtime checks, exact standalone contract
registration without credit, prepare/cancel/reopen fencing, accepted receipt
access and encrypted-backup restore quarantine. A forged cached address could
not replace the signing or watch-only wallet's own derived identity. One fresh
100,000-sat funding was confirmed, and three explicitly requested owned RGB
change outputs were prepared at the reviewed fixture fee rate and confirmed.

The host sent exactly 100 QBFA units to the consumer's fresh witness invoice,
once, and confirmed the transfer. The consumer then prepared a 50-unit return,
reopened the native state, committed once through the actual Dart/native API and
reconciled it to settled. The host receiver independently obtained the exact
50-unit transfer and three chain confirmations. The mobile wallet retained 50
settled QBFA units. Incoming witness transaction:
`23682ae3fa5fdde711bf775b930b9bd13ba3981d124d15db71c2c9a875facf72`.
Mobile return:
`c94c14dfd5042e97d75db65120218ff14541e5f194697b3456c2bb28b4c32035`.

An earlier disposable iOS run received 100 units but had not prepared an RGB
change output. Its send Prepare returned known `insufficient_allocations` before
Commit. That wallet and transfer were preserved. The harness was corrected to
review/prepare change outputs explicitly and retain its test key privately;
there was no blind receive UI added, duplicate Commit, or replay of that failed
attempt. This finding also requires explicit first-send preparation in Aster;
a witness receive does not itself guarantee an RGB change output for a later
partial send.

The post-locking-seal iOS consumer then reopened the exact same persisted keys,
native directory and recovery cohort under the final `c06ffff…` runtime. The
installed app's embedded native metadata was checked, and the actual read-only
consumer observed the same accepted 50-unit receipt, settled/spendable balance
50 and empty pending inventory. No monetary call occurred. Reinstallation moved
the Simulator data-container UUID, so only the private harness's persisted path
was rebased; wallet files and cohort were unchanged. This is an installed final
runtime compatibility check, not a relabeled second funded test.

## Installed Android final-seal consumer proof

The actual release/R8 Flutter consumer ran on Android API 37, arm64-v8a,
16,384-byte pages with page-size compatibility fallback disabled. Its APK
SHA-256 is
`491ce81a25d8ce6e917d6000679967450a17bbe4685b4f8618b0825bb1aea9ca`.
It used the **final `c06ffff…` integration** and native AAR SHA-256
`4ebd513f0559b28b2b76334ad9cecd343b6c5414f4627e0ba4c13e3d2d43186d`.
The package has exactly the complete arm64 runtime: Flutter engine, app, JNA,
RLN and RGB_L1 libraries; it does not expose partial foreign ABI directories.
Native ELF and installed page-size execution are separate recorded checks.

All **nine actual consumer cases passed**: both native engines loading; Dev
admission closed before keys/storage; exact idempotent zero-credit contract
registration; derived-address ownership for signing/watch-only sessions;
authoritative cancellation surviving reopen and rejecting late Prepare; native
witness/received-mint observation; a prepared command surviving restart while
fencing ordinary mutations; a funded RGB prepare/reopen/one Commit/accepted
receipt; and encrypted backup/cohort preservation with restore quarantine.

Exactly 100,000 fresh regtest sats were funded once and confirmed three times.
The BTC durable plan was prepared, reopened, fenced competing mutation and
canceled; **no mobile BTC payment was broadcast**. Three explicitly requested
owned RGB change outputs were created once and confirmed before the RGB send.
The host then sent 100 existing QBFA units to the exact mobile-generated witness
invoice, once. After three confirmations, the consumer prepared its 50-unit
return, reopened the same native plan and committed **once through Dart → JNI**.
The host performed recipient refresh only and mined three confirming blocks;
it did not submit or retry the mobile payment. The consumer observed the exact
accepted receipt and retained 50 settled units before backup qualification.

Incoming witness transaction:
`b9aec014a72a394325a1e49ca6b8b51334343eddfaed240ebe2777d292900ce9`.
Mobile return:
`f18322589dc70e12a5f9781ddc3551fd41ee84a1ee2749aaf92fbe2da1337e0b`.
A final ordinary host protocol refresh and readback observed **549 settled and
spendable QBFA units in the host sender, 251 settled in the host receiver, ten
accepted native sender receipts and empty pending inventories**. No additional
mint or monetary dispatch was used for that final inventory.

The initial Android installation had exposed unsupported standard-library file
locking before funding. The native nonblocking `flock` fix and regression test
produced the final seal, and the complete funded run above used that seal. A
separate early fixture configuration failure used emulator host-alias URLs;
those were corrected to actual loopback with owned `adb reverse` mappings before
any funding. Failed stages remain separate evidence; neither is presented as
passing the final runtime.

These are native consumer and fixture proofs, not a fresh final Aster package,
a physical-device qualification, a hosted Dev deployment or release admission.

## Native automated evidence

Completed native tests on the full-funded tree report **18 core tests and 2 UniFFI tests**:

- 15 durable recovery/observation tests: canonical u64 fingerprints,
  filesystem/permission/lock attacks, wallet/cohort binding, corruption and
  rollback, pending inventory, compact accepted amounts, cancellation
  tombstones, exact zero-balance contract registration, atomic-write faults,
  consignment snapshots, signed recipient ACK proofs and exact witness derivation.
- One custom-Dev checkpoint validation test and one Dev indexer admission test.
- One actual encrypted-backup restore test that preserved the outbox and applied
  fresh restore quarantine.
- Two UniFFI profile tests covering explicit Dev checkpoint selection and
  preventing an ordinary profile from silently becoming Dev Signet.

The final locking seal repeated and passed **19 core tests and 2 UniFFI tests**:
16 durable recovery tests, including direct nonblocking `flock` exclusion and
error classification; both Dev checkpoint/admission tests; the actual encrypted
backup/restore quarantine test; and both UniFFI profile tests. Immutable copies
of the completed logs are retained with the private run and hashed below. These
targeted counts do not claim every upstream test or every mobile flow executed.

## Redacted evidence digests

Paths below are relative to the private run directory unless otherwise stated.
These files are immutable records of their respective stage; a failed stage is
retained even when its original operation is later safely completed.

| Evidence | SHA-256 |
| --- | --- |
| `scope.json` | `5b43fed2dd79b8847e95b98504296efa867104eb05b59b16cb38c1b97e05e1ed` |
| `BTC_RESULT.json` | `5ae39326c64a09d2ae85cd9912bf0bf54f4739dd1e7c43e5852e2d05431e877e` |
| `RGB_PREPARE_DIAGNOSIS.json` | `58930bf5a5552dc616aa2b1da26cc68b587a0ac31342493f1ba8470ad5042ad2` |
| `PRESEAL_REMEDIATION_BUILD.receipt.json` | `31341c3b91c251cfe4923850220f0b10db4812b6e44cdbd51dd4e7a241dbab30` |
| `RGB_REMEDIATION_RESULT.json` | `1c68a407b6be885004be91fce9726347abcbc4386aebbea4d2cf4a8f292318ea` |
| `mint-new-settle-once.receipt.json` | `71f01389e53ebd94538254ebf95246de5d143d280447a9482d58241970e61b56` |
| `FINAL_SEALED_SCOPE.json` | `2f42034b607f907d8dd5ab594ed8a4e72c4decfb7da183d364750df5c6517e8f` |
| `FINAL_SEALED_RESULT.json` | `2e81c938b3ac3ca19887016c2e7a66a4c46b22e60c66e24b3ffced268a8da501` |
| `native-final-recovery-tests.log` | `eb99a2b98a3417b5359db6eac71d1e83c50eb4849993abfdc5d66006a6ef13b5` |
| `native-final-dev-checkpoint-tests.log` | `c73a9ceb94b032e10fc18b6ce7fd20bfdbdefff5f69e4aa46a4da067e6ea15b4` |
| `native-final-dev-admission-tests.log` | `e46dbdf4f703f3bff575b1a0564bfd1ec0ec36ff8c063b55e76a86aa94a1f7f5` |
| `native-final-backup-tests.log` | `75047d445a8d057ab0f497ea6b56a0ee81c6db34ff9fcd3ec8107b452d52587b` |
| `native-final-uniffi-profile-tests.log` | `66e0c0bd82b6c9adce82e168003bfd3e442bff17707f6fecf97fa2c137bf61b2` |
| `btc-reply-loss-deferred/RESULT.json` | `a0b2f604409bb87d565926eacb6cbd59962102a1418d2efa4ef553b74d36938c` |
| `btc-reply-loss-deferred/rpc-counts.json` | `9a8ed922ea6ece275b7e2c2e5c0bce401d64f1773c1370290c985606cab9c8c6` |
| `rgb-consignment-reply-loss/RESULT.json` | `c76e4fbd0593b2d85f0eeec49cff35dadd0a5349aa501cf059544bcccb5d6d45` |
| `rgb-consignment-reply-loss/rpc-counts.json` | `dd5f7645fbad51a840900f211247f66868df5b1d4c76ada37a4ca981ed3b78e3` |
| `native-c06-final-21-tests.log` | `84468a6ae6d43d1fd3c04a7648f80406c7090387dcd4ab3382f172a08022620c` |
| `flock-final-readback/RESULT.json` | `bd0ee726a6c7cdf93101a6859643b52ac8e0453555a5eb8a3631ae02b9b977e7` |
| `mobile-ios-rgb-6f0c93e9/FUNDING_RESULT.json` | `5fdd6dfd4614bb115d78eb5ffe04fc72e9c8da5fa963a8205a81ce950b665ded` |
| `mobile-ios-return-c94c14df/RETURN_RESULT.json` | `a18750aa1229be9c626e7a6b51e7cce4d3945bb3093743ae120909c3a95c1cc0` |
| `mobile-android-rgb-e90e88cc/FUNDING_RESULT.json` | `5ad9a1cc4255f120e856c2c9178634fc855d1a74d8d0f86d8064e755454e55f3` |
| `mobile-android-return-f1832258/RETURN_RESULT.json` | `72fd30dc881bfd0c2f1ab60e8b9c85b4e0626e6a9e0801aae2dfd701c7a1ecdc` |
| `final-funded-inventory/RESULT.json` | `6466c2570ec8ddf1b2819ae2b643949755af4ede6ed62ff223cd1e6a29f9257b` |

The following paths are relative to `.buildlog/bfa7-ios-consumer/`:

| Evidence | SHA-256 |
| --- | --- |
| `readonly-ios-c06-proof/bfa7-smoke-final.json` | `16942e3fb583667e81bd97cbf51b9d164888433ef90a8c62c8b2458bb07e726b` |
| `readonly-ios-c06-proof/native-runtime-metadata.json` | `ef02f72c4fcc1c42df739558244382e2bc3f47abba742c89d29a14e65e561b1e` |

The following paths are relative to `.buildlog/bfa7-native/evidence/android/`:

| Evidence | SHA-256 |
| --- | --- |
| `final.json` | `2d7d3ad97cf0eb8186f09d4773df06f8268baeb373e5c5ef56b55a3666859b61` |
| `consumer-build.json` | `09a647675ba056ef9a6fab8fde415d00b04e97a3c181d03f959fb56e680c5194` |
| `device.json` | `95c19ce971fb8ed045cfbbd5e437128a920beb1c148c40e1de0fcfb1ff2f0687` |

## Remaining qualification boundaries

Clean acquisition and final Aster release artifact checks remain pending until
their actual results are recorded.
Compiling Kotlin/Swift bindings alone is not an installed-runtime test. No
physical-device or public Dev/mainnet funded proof is claimed here.

Aster's Android packaging now selects the complete supported 64-bit intersection
from Flutter's actual target-platform and excludes every unselected transitive
JNI directory, including the other 64-bit ABI in a single-target build. Its
release archive gate requires Flutter, RLN and RGB_L1 in each declared ABI and
rejects partial/32-bit directories. The legacy SDK's additional armv7 runtime
does not establish Aster/RGB_L1 32-bit support. Actual final Aster artifacts still
need inspection after the final SDK pin; source policy alone is not artifact proof.

Additional partial-dispatch boundaries, reorg/reconfirmation, backup
freshness authority and unrestricted restored-wallet spending, clean consumer
acquisition and final release packaging/privacy evidence remain separate gates.
An old but coherent restored snapshot stays quarantined; these tests did not
invent authority to spend from it. The team must still supply and approve the
current Dev BUSDT public export, digest, exact metadata and matching backing
deployment/policy before that asset is admitted.

# BFA.7 qualification evidence

Reviewed on 2026-11-08. **RGB_L1 and Dev remain gated.** The current `.2`
successor, integration `8ac556ee67db70b93abb69b4ebd8fb0e6752dc0e`, passed all
10 installed SDK consumer cases on each of iOS 27 and Android 17, including
explicit revocation and the restored-snapshot refresh fence. Its 48 focused
native checks and the subsequent 47 maintained Android bridge tests also pass. The earlier
`.1` evidence below is retained with its original identities; the final
[successor section](#successor-2-explicit-revocation-reorganization-and-restore-boundary)
records the new source, artifacts, failures, fixes and platform results.

These are executed checks against the existing isolated regtest fixture, not
approval of a hosted Dev asset, unrestricted portable RGB recovery or a public
production release. Mechanism and release boundaries are described in
[BFA7_NATIVE_INTEGRATION.md](BFA7_NATIVE_INTEGRATION.md).

## Final Aster consumer acceptance, November 8

Aster completed the existing-fixture BTC/RGB flow on both platforms: 100,000
satoshi funding, one 1,000 satoshi BTC payment, receipt of 100 QBFA base units,
one 50-unit RGB return, confirmed gross history and 50 settled/spendable RGB
units remaining. These are **isolated QBFA base units, not public USDT**.
Both wallets then passed a distinct process-stop/relaunch of the same installed
artifact with the same identity/cohort, balances, confirmed references and no
native/app pending fence. The cold branch does not mount UI sync owners, invoke
generic transfer refresh, run maintenance bootstrap or create another payment.

iOS evidence composes original `g` onboarding/lifecycle/bootstrap, `h` BTC and
incoming RGB, and final `k` same-wallet RGB return/cold reopen. The original
incoming invoice used the previous zero-confirmation policy and was independently
confirmed three times; it is not relabeled as evidence of the new policy.
Android `k` runs the final fresh flow: a new one-confirmation invoice first
produced `WaitingConfirmations`, future 100, settled 0 and spendable 0. Exactly
one mined block then settled the same transfer. Aster explicitly requests one
confirmation for amountful and amountless witness requests. The SDK's documented
zero default remains compatible; adapter regressions cover both variants and
pending/mature balance mapping.

| Evidence | SHA-256 |
| --- | --- |
| ios full-flow report | `05edf2c76d243e1c25edb5b945654ee0a85207d640ac317edd1bb17a40347e01` |
| ios distinct cold-process report | `b92d33a4ea4309332294cd56f6718be652ebedafe6a922e1b913ab09fcd4bfa2` |
| ios owner allowlist | `35b8edff61803a5903be19ef6bc9f68df4a7ee8fd59b68c2dee9b997db4d1f2c` |
| ios independent acceptance | `65719361bcbe0e71fa0a89a6f8bccb5d9e8dbc745916416f30e4033f36675027` |
| android full-flow report | `ae0efabf463cbe1379fd14981658b3384e79370134c09cc9e782aff532cad97c` |
| android distinct cold-process report | `69543e1e4ca011df75c71aae56e9bf0b9b6b105da20f0af2e2c94fa7072c803a` |
| android owner allowlist | `cc75ef23e5921c3f0f536c19de0c0ad00f8f5436bbc43172320bc467c5d3adf7` |
| android independent acceptance | `d3fdfef052771516e112adaa473794ab8b700829e074220fe17a5a0aa2d55a24` |

Owner reports are below Aster's
`.buildlog/rgb-l1-full-flow/aster-l1-{ios,android}-20261107-k/`.
Independent acceptance and read-only chain observations are below the SDK's
`.buildlog/bfa7-finalize/evidence/ASTER_{IOS,ANDROID}_{ACCEPTANCE,CHAIN_OBSERVATIONS}.json`.
Each platform's 28 admitted source files match its built artifact. Runtime
events verify the final `8ac556ee...` seal and all four registration, durable
recovery, revocation and existing-only capabilities. Android APK SHA-256 is
`82f84f7d14fc243019e8e69bde572befbdc63670c3431f517d46c3f2c27650aa`;
the iOS Runner file-tree SHA-256 is
`eff129c88465347ac09a0e1612ff20df6a7d938fe6304d74e317e3f1e1f5fa25`.
Android ran on actual 16,384-byte pages with compatibility fallback disabled;
all ten APK ELFs/30 load segments and ZIP placement meet 16 KiB alignment.

Independent Esplora reads confirmed all four named transactions on each
platform and preserved original baseline block 270. Approved witness values
and observed fees reconcile each final BTC total exactly:
`100000 + 1000 - 1000 - 1000 - (155 + 284 + 256) = 98305` satoshis.
Vanilla spendable BTC is 18,561; protected RGB outputs are not silently treated
as vanilla spendable value.

Failed QA runs remain distinct. An old launcher uninstalled its own disposable
QA package; pre-existing user Aster/Iris wallets were untouched. Later runs keep
the app and keys installed. Test-only lifecycle, text-input focus, stale prose
and SDK-file observer fixes do not weaken production authentication. Android
host funding first failed definitively before dispatch because the issuer's
cache was stale. That rejected command was preserved and never committed.
After observing the exact prior transfer and refreshed spendable change, a
separately authorized new command funded the same unused invoice once. No
automatic monetary retry, new mint, container creation or reset is claimed.

This closes executed Aster storage/full-flow/cold-reopen qualification, not
production activation. Public native acquisition is verified below; the exact
SDK/App source pin is recorded separately after the SDK commit. Portable restored spending, Dev
contract/deployment approval, EVM-degraded operation, terminal-journal capacity
disposition and final signed-app/independent legacy RLN privacy remain gated.

## Published native beta and clean acquisition

The native-only qualification prerelease is
[native-bfa7-flutter.2](https://github.com/UTEXO-Protocol/flutter-sdk/releases/tag/native-bfa7-flutter.2).
The public tag points to existing distribution commit
`7c44506fdfe1dae6f3a6fe884f849c7ca2ad028b`, not a private SDK/app commit.
All seven server asset digests/sizes match their admitted local bytes. Fresh
anonymous HTTPS downloads of all seven assets match those same pins.

An unmodified iOS installer ran in a new empty consumer/cache with no local
archive or offline override, producing and verifying 47 framework files. A
fresh linked scan of all six framework/architecture pairs again found zero
DiskSpace imports while retaining durability calls and isolated FFI exports.
The actual Android consumer Gradle `verifyRgbLibNativeArtifact` task passed
with refreshed dependency resolution, the public release URL and neither
native artifact-directory override. This is `.2` acquisition evidence, not
reused `.1` evidence.

| Acquisition evidence under `.buildlog/bfa7-finalize/evidence/` | SHA-256 |
| --- | --- |
| `FRESH_PUBLIC_DOWNLOADS.json` | `606f6e870b690ccd1725ac252455bda50a3672c7290903a02d5b4a3067effd1c` |
| `FRESH_PUBLIC_IOS_INSTALLER.json` | `2bf135dce8f691a4c74e4b0c7fb39a86c096b839324417ca51bbc44b82b9f78b` |
| `FRESH_PUBLIC_IOS_LINKED_PRIVACY.json` | `0bcfe2e811b414247209d29040e99e5325f55372c613cafe7792d689154c2c1c` |
| `FRESH_PUBLIC_ANDROID_RESOLVER.json` | `778cde3c9aa9e9c85e143f4c7745fac5b20f83e3fc2cc483ae7fe1df02e91930` |

The final private SDK commit and its immutable Aster consumer pin are created
after this component evidence. Aster records the post-pin source and final
full-suite verification separately. Beta publication/acquisition does not lift
production, restored-spending, Dev or final signed-app/legacy privacy gates.

## Historical .1 source and dependency identity

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

## Historical .1 qualification boundaries

At the `.1` stage, clean acquisition and final Aster release artifact checks
remained pending until their actual results were recorded.
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
acquisition and final release packaging/privacy evidence were separate gates.
The successor results below close the executed mechanism cases, while retaining
the stated deployment, freshness-authority and release-artifact boundaries.
An old but coherent restored snapshot stays quarantined; these tests did not
invent authority to spend from it. The team must still supply and approve the
current Dev BUSDT public export, digest, exact metadata and matching backing
deployment/policy before that asset is admitted.

## Successor .2: explicit revocation, reorganization and restore boundary

The successor version is
`0.3.0-beta.7-upstream-dev-bfa.7-bfa-flutter.2`, bridge 5. The durable protocol
domain remains `flutter-bfa7-durable-v1` and the exact approved-command envelope
remains version 3. Changing implementation identity did not invalidate old
outbox authentication or turn an existing command into a new payment.

| Current identity | Value |
| --- | --- |
| BFA.7 upstream | `9ec49c08be2e68f08521281e3efbd760ec989cb9` |
| Integration tree | `8ac556ee67db70b93abb69b4ebd8fb0e6752dc0e` |
| Overlay patch SHA-256 | `d3369ff9d4dfd5638781b259688ee9bd9f43e52464b61e6408ea7a75c81bc273` |
| Source manifest SHA-256 | `cf769ed49356e49a914dff638a4bddee9fd57fc6ebecf4b0193d8dd53aec2897` |
| Sealed UniFFI lock SHA-256 | `81af7c87fac88abbd40b1621ce2fa7655165b6b0c8bdd23faa313d25139330a6` |
| Host consumer lock SHA-256 | `99341b92d4b80b0cba681a3cdc6b9d80633f109a0c0cd96a1fb14013745ca51c` |
| Rust compiler | `1.94.0 (4a4ef493e, 2026-03-02)` |
| Host executable SHA-256 | `0876686e441b882213d0ef0df57606a24100ae5cb635c319a336bb36b257b304` |
| Android AAR, 51,476,045 bytes | `73301c7c7e7d3844aa30c0ff8ccc78b3ebd360327c652e7718b252877761fc42` |
| iOS ZIP, 164,553,560 bytes | `60c33914222a62a822440bf155babd0b030a74f4fc166f7bd5c5955e6f49932c` |
| Portable consumer Dart source SHA-256 | `34643c57a1d60263d51e9f96c384919a2752db38ced3890ebd47e7d26a17c7f2` |

The host consumer again matches all 507 shared dependency packages. The only
additional root is the qualification client. SQLite is the sealed local source
admitted by this successor manifest; the earlier `.1` lock and source hashes
above are historical and are not substituted for the new tuple.

### Failures reproduced and corrected

1. **Partial RGB dispatch:** the sender proxy accepted ACK registration, but no
   consignment was uploaded. Published `.1` could not safely release it. The
   successor adds explicit `revokeOnchainSend` / `revoke_onchain_send`; an ordinary
   Cancel or passive Status never acquires this authority. Exact native request,
   recipient, operation secret and original sender endpoint are checked before
   signed `ack.clean`. Only affirmative revocation permits a durable certificate
   followed by local release. Unknown, released, false, malformed and unavailable
   replies retain protection. Accepted submission takes precedence.
2. **Confirmation loss:** old settled native rows were not reliably revalidated.
   Positive confirmation loss now demotes the affected transfer and descendants,
   retains the accepted submission receipt, and removes unsafe spendability.
   Reconsidering only owned new blocks restores the same rows and allocations.
3. **Active observation outage:** the first `.2` candidate
   `08f7ac7b8a357ae09716bf11144f327ec9f9e559` incorrectly projected 547 units as
   5,995 after demoting historical generations. Recovery then admitted one
   generation per refresh. The corrected c1 source preserves last-known SQL
   history/balances when observations are unavailable, reports refresh failure,
   and fails closed before Begin/End. One authoritative refresh recovered all
   eight previously waiting historical rows from the same preserved files.
4. **Partial refresh reported as current:** a detailed native refresh can contain
   both successful and failed entries. The SDK convenience `refreshWallet` now
   throws payload-free `REFRESH_INCOMPLETE` if any entry failed. Detailed
   `refreshTransfers` remains available without discarding its typed results.
   Aster explicitly inspects those results before publishing a fresh portfolio.
5. **Restored-snapshot refresh bypass:** generic native refresh can ACK, broadcast
   or rebroadcast pending transfers. Allowing it on a restored snapshot could
   bypass the spending quarantine. The current seal checks the restore marker,
   authenticated outbox state and managed-journal presence before Online
   admission. Restored generic refresh rejects with `RECOVERY_RESTORE_UNCERTAIN`;
   supported local metadata and historical accepted receipt/Status remain readable.

The c1 integration `c1be7c60249188b5b86974cb2c09466afa6843e4` passed actual
normal-wallet outage, partial-dispatch revocation and reorg/reconfirmation
campaigns before the final restore-refresh finding. Their records remain c1
records with release admission explicitly false. A source comparison against the
current seal proves that the complete `durable_observation.rs`,
`settled_revalidation.rs`, `database/mod.rs` and `wallet/core.rs` files are
unchanged. The production differences are the restore-marker helper, authenticated
refresh-authority helper, online guard invocation and singlesig delegation.
Existing exact observation, revocation, revalidation and balance-accounting
algorithms are retained. The current installed mobile campaigns verify the added
supported boundary; no new final-seal live reorg or partial-dispatch campaign is
claimed or inferred by renaming the earlier evidence.

The c1 outage intentionally called one previously prepared RGB Commit while a
read-only proxy gateway would reject any mutation. It returned
Prepared/submission_not_started with no End authorization; the gateway observed
**zero attempted external mutations**. A new BTC Prepare was also rejected.
Ordinary Cancel then released only that known-unsubmitted plan. The temporary
prepared reservation restricted spendability; unavailable observation alone did
not fabricate a zero balance. Service restoration recovered the same native
projection and accepted receipt without a payment retry.

The corrected live one-unit reorg used only owned blocks 277–279 above preserved
baseline 276. Both transfer rows returned to their original unconfirmed state,
including sender row 14 and receiver row 11. The original blocks were reconsidered,
the same submission receipt survived, and final sender/receiver balances were
546/254. This establishes conservation of scoped fungible QBFA allocations, not
inflation or mint-right conservation. Esplora service failures were recorded
separately; infrastructure recovery reused its existing container and index data.

### Executed current native and bridge checks

The exact frozen native source passed 27 durable/recovery checks, 10 backup
admission checks, 10 reorganization/accounting checks and one iOS storage guard
check: **48** focused checks. The four snapshot-boundary checks are a subset of
the durable checks, not four additional cases. They include actual encrypted
pending incoming/outgoing snapshots and cover cold reopen, persisted quarantine
after marker removal, missing managed journals, marker aliases and preservation
of normal current-wallet refresh. No general upstream test suite that could
create containers was run.

An additional eight offline mock-HTTP observation cases passed against a separate
test-only copy of the exact current seal. The production body was unchanged;
only a cfg(test) module was included. This establishes exact loss-of-response
observation behavior with controlled HTTP fixtures, not another live reorg or
payment campaign. The proof records current source and test-module digests and
retains all earlier mock evidence separately.

The maintained Android Gradle task `:rgb_sdk_flutter:testDebugUnitTest` passed
**42 tests** with both artifact checksum tasks executed against the final local
AAR. This includes real runtime-metadata type preservation, absence-default-false
capability behavior, explicit revocation authority, unknown-operation rejection
and sanitized backup errors. Swift wire/pending-policy/type regressions also
passed and are invoked by the quality workflow. These host checks are separate
from the actual installed JNI/Swift results below.

### Installed iOS 27 and Android 17 consumers

Both fresh consumer campaigns passed all ten cases using the current native
identity. Each report persists the actual `getRuntimeInfo` result: native version,
source revision, bridge version, integration tree, patch/lock/manifest digests
and explicit revocation capability. The previous test wallets and keys were
preserved; no application wallet was reset. Before Android package replacement,
its old owned test cache was also retained in an ignored owner-only archive.

| Case | Installed verification on both platforms |
| --- | --- |
| 1 | Both wallet engines load; the actual RLN and RGB_L1 artifact identities match. No Lightning payment is exercised. |
| 2 | Raw Dev open is rejected before parsing supplied keys or creating storage. |
| 3 | Exact BFA contract/metadata registration is idempotent and credits zero assets. |
| 4 | A forged persisted address cannot seed signing or watch-only address caches; native derivation owns each reopened session. |
| 5 | An absence cancellation survives reopen and rejects delayed Prepare. |
| 6 | Native witness recipient parsing/public-key width and nullable received-mint observation remain accurate. |
| 7 | A funded BTC plan survives reopen, preserves its exact command and fences ordinary mutations; cancellation spends no BTC. |
| 8 | Receive 100 QBFA, prepare 50, reopen, Commit exactly once, retain the accepted gross receipt across another reopen, settle after three confirmations and retain exactly 50. |
| 9 | Invoke the new explicit Revoke on the original accepted command, obtaining the unchanged receipt; prepare a fresh own one-unit request without Commit, explicitly revoke, reopen and verify rejection/no pending/no broadcast/no balance or fee change. |
| 10 | Encrypted snapshot preserves cohort and accepted receipts; restored refreshTransfers, refreshWallet, Prepare and explicit Revoke all reject with RECOVERY_RESTORE_UNCERTAIN while supported local metadata and historical receipt/Status remain readable. |

The post-dispatch signed revocation protocol is established by the separate live
host proof. Mobile case 9 establishes actual additive JNI/Swift API invocation,
accepted fast-path behavior and pre-dispatch cancellation; it does not claim a
second mobile post-dispatch fault campaign.

The iOS consumer ran on the existing iPhone 18 Pro Max simulator with iOS 27.0,
bundle `com.utexo.bfa7AbiSmoke`. It linked the reviewed frameworks installed from
the exact `.2` ZIP. The Android consumer was a release/R8 arm64 build on API 37,
Android 17, with actual `getconf PAGESIZE=16384`. Both linker and package-manager
16 KiB compatibility fallback switches were disabled. The complete APK's five
native ELF files and `zipalign -c -P 16 4` passed. The installed APK's SHA-256
matches the built APK:
`718805cd628d5bbec99dbe3d06d59acd3b7999b59739d22ca0d589fb5b90600e`
(142,887,895 bytes). Iris's separate emulator and wallet were untouched.

| Platform | 100 QBFA incoming transaction | 50 QBFA return transaction | Confirmed remaining units |
| --- | --- | --- | --- |
| iOS | `356ab5752394bbb29dc76108cf1d01014bb5ebed823b9f70dfd8959b95592949` | `0e11addca89cbbcdcf5dc76d4ab165ccc2d1ceb24ca25e24c8942b509485d670` | 50 |
| Android | `79de8a4a00080316f51bb1b8e83752c0248f013301d06b6c066879ad2a9e8e4f` | `9929bdebfc28a3e3296c087cd79db24ac48a57062585edebe8e36af9f59c65d5` | 50 |

Each monetary leg was dispatched once and confirmed with three blocks. Each
fresh mobile wallet received exactly 100,000 test sats and explicitly created
three 1,000-sat prepared outputs before its RGB transfer. Host funding used
existing QBFA; no new mint, backing deployment or container was created. For each
return, the host only refreshed the existing recipient and mined confirmation;
it never called Commit on the mobile payment.

A final current-seal readback found sender 346, receiver 354, 15 immutable accepted
host receipts and no pending operation. Those two preserved host wallets plus
the two fresh 50-unit mobile wallets conserve the original scoped 800 fungible
units. Core was height 303, tip
`57b45987e7935ca450d84978b93cd2e85d5b3c9753308fb4c4b0587093b649c3`,
with an empty mempool. The temporary public descriptor server was stopped and
only the campaign's four adb reverse mappings were removed before the Aster
verification handoff.

### Successor evidence digests

Paths in this table are relative to `.buildlog/bfa7-finalize/`. Wallets, mnemonics,
PSBTs and detailed native stdout remain private and are not publication assets.

| Evidence | SHA-256 |
| --- | --- |
| `evidence/SEALED_SOURCE.json` | `2b94d81585e47645bb5a1aa22ef7db138b93540832768d300edb108cd504e4af` |
| `evidence/SOURCE_ALGORITHM_RETENTION.json` | `aac685fc8f720485416eaa5c9c411fe5470145e11520d221171eb8c26c4693bd` |
| `evidence/ACTIVE_OUTAGE_FAILURE_08F7.json` | `2c6e0e40f9ae1a27b98e90526276db26a5241414b7674c574beed5d4787ca5b2` |
| `evidence/PRESERVED_WALLET_RECOVERY_C1.json` | `f1e059974c94671ffb9992e27cb176b00c19a282da5ed46786831d8e23ca2c50` |
| `evidence/ACTIVE_OUTAGE_C1.json` | `814bc34f70ed7df2845c3aec8def8d73e61aac47c576548a37ec5af09aecdf20` |
| `evidence/REORG_C1.json` | `400244b33d95e88cc3befd81d09db88205158182fd67548fbc888869402e69b6` |
| `evidence/REVOCATION_C1.json` | `a6f5d8fe8226ff95d320b0efe152d2d191ea8fca091a3986dff2222db14b63cb` |
| `evidence/FINAL_HEALTHY_WALLET_8AC.json` | `9b1318d32a2f46c478023a609cbab7e7d4faa66b250755b5d945e4a9e8c9680c` |
| `evidence/FINAL_POST_MOBILE_WALLETS_8AC.json` | `0d853ecac2f34ac952b6264ef16abd5f6372f0a9b5fa5af50658840e9872bd89` |
| `evidence/ANDROID_GRADLE_JUNIT.json` | `5b267786c95b3e8da198fc02002a7e7a3c815fc1dc4ab037eca7225ca1219fd6` |
| `evidence/ANDROID_FINAL_APK_ELF.json` | `607a6e980899b311a2dc25a3ca1dae09562489bf199b19be3c2f61aa36934709` |
| `mobile-campaign-ios/IOS_FINAL_10_CASES.json` | `87e64da7ace5f21e01954a684b58232b74a4ab9991978c68a89106bd2d94d1b8` |
| `mobile-campaign-ios/completed-public-reports/bfa7-smoke-final.json` | `170957f8cb84a9502b6ab13afbcf3b316a1ea44f6b5a74024a50716c7af4c167` |
| `mobile-campaign-ios/completed-public-reports/bfa7-smoke-runtime.json` | `47f61bf973c6734423dc84096943871230902bb57722e13402ffc2a35924f4ae` |
| `mobile-campaign-ios/completed-public-reports/bfa7-smoke-rgb-explicit-revocation.json` | `ad2d44f8d8738e539c62e958606789c25a414b9dadd0fb2588ccde3fcec3e856` |
| `mobile-campaign-ios/RETURN_RESULT.json` | `f6c6996a9a47d3c77c0c806ffdecd0c7b91f773c951bf8c41e528d2af69f63f7` |
| `mobile-campaign-android/ANDROID_FINAL_10_CASES.json` | `52c4e94135cd6441696b6552ea781ae8adaee35b766927f661892a20866d4b6c` |
| `mobile-campaign-android/DEVICE_BUILD.json` | `7428f11a8b4ef60b6f70372d306ec61b88b602789a676e9e84f0e38ad8169afe` |
| `mobile-campaign-android/completed-public-reports/bfa7-smoke-final.json` | `abdb86682432ba2b5fb48360cfe73c51cd0f064ae65bfac258a8a15c6156396d` |
| `mobile-campaign-android/completed-public-reports/bfa7-smoke-runtime.json` | `3708af32b6bbdb8a8cda9d79193112003a81099f33657ad26df305bde72e343e` |
| `mobile-campaign-android/completed-public-reports/bfa7-smoke-rgb-explicit-revocation.json` | `4755b43e9e352bdbbc75c9d67415266171afa4e6dad026698714249fc0deeae6` |
| `mobile-campaign-android/RETURN_RESULT.json` | `ece4c98bdbfe77b7f42129538618e77cb10a454e53a81e1f7d7cd42f0800af4f` |
| `restored-refresh-durable-regression.log` | `b9412edfa8406d717c6d0ff41a92b0e6fbdc8c649a1fe9984f8e50546aabf81e` |
| `restored-refresh-reorg-regression.log` | `dd3528cad24b1f3392d559faa135f84321de8c424c3246630fc0fa7107e43472` |
| `restored-refresh-backup-regression.log` | `2cc99ffda56ce04bf622124a4d9a416d62958737198348edcf3ca83bb663473d` |
| `restored-refresh-ios-regression.log` | `9007efce5fd11d9344c11bad1b46c3a15cdc7a71e8a21cecbee2cd2105a1f43d` |
| `fault-observation-host-8ac556ee67db-proof.json` | `7746302729b147006202e0f92f5d7a50c7166873b5e1e53506bae3b4cdcf0cae` |
| `fault-observation-host-8ac556ee67db.log` | `9dfc027acb9d74e4de44584d02df45198de7d0e8b6ed074449871c254b4fa4e7` |

### Boundaries that these results do not close

- No approved service currently establishes portable snapshot freshness or
  excludes a later spend by another copy. Restored spending therefore remains
  quarantined and mnemonic-only RGB recovery is not advertised. This remains a
  production release-policy blocker, not permission to clear unknown operations.
- The real fixture is isolated regtest QBFA, not team-approved Dev USDT or
  mainnet USDT. Dev contract export/digest/metadata, backing deployment and mint
  lock policy still require explicit team approval and deployment qualification.
- The separately recorded Aster installed full/cold flows and clean public `.2`
  acquisition now pass. Final immutable consumer pinning, signed release artifacts
  and deployment/privacy acceptance remain distinct; earlier `.1` download proofs
  are never relabeled as `.2` evidence.
- No physical-device, public mainnet funded, inflation-right conservation or
  unrestricted cross-copy recovery result is claimed. Lightning remains outside
  this release's functional scope.

See [BFA7_RECOVERY_QUALIFICATION_MATRIX.md](BFA7_RECOVERY_QUALIFICATION_MATRIX.md)
for the mechanism-by-mechanism status and maintained executable checks.

## Additive wrapper guard verification, 2026-11-08

The installed Aster campaign exposed an integration issue that the standalone
SDK consumer could not establish: Aster placed `.aster-storage-owner` in the
native storage root before SDK initialization. The SDK correctly rejected that
nonempty new root with `WALLET_STORAGE_NOT_EMPTY`, before native wallet creation
or any transfer. Aster now separates its token-owned parent from a fixed
`rgb-l1` native child; unexpected old native files in the parent are rejected
rather than bypassed. Independent source review and the app's focused tests
cover the parent/child, reopen and recursive deletion boundaries. The app's
restarted installed campaign remains its own acceptance record.

That review also identified the need for an explicit existing-only SDK entry
point. `openExisting([onlineParams])` is additive; `init` and `reinit` retain their
legacy create-or-open semantics. The new call requires the strictly typed
`supportsExistingOnlyOpen` capability from the **compiled platform wrapper**
before reading keys. An old wrapper with the same Rust archive cannot silently
ignore `requireExisting:true`. Under its exclusive lease, the current wrapper
requires an existing native root profile before constructing a native Wallet or
initializing recovery. Missing storage returns `WALLET_STORAGE_MISSING`, without
falling back to a new cohort. Existing profile, outbox and SQL authentication
remain native responsibilities.

Open and encrypted restore now share a profile reader with a 65,536-byte limit
checked before and during reading. It accepts only regular files, strict UTF-8
and the legitimate format-2 flat object/scalar grammar, with bounded finite
numeric tokens. It rejects comments, single/unquoted strings, nested containers,
malformed escapes/surrogates, raw NUL and other encodings before invoking a
platform JSON parser. This is necessary because Android JSONTokener accepts
nonstandard comments and strings, and Foundation can autodetect UTF-16/32.
A quote-only depth scan would not establish the same grammar on either platform.
Malformed/unreadable/over-budget profile metadata becomes the existing typed
profile-mismatch code for its operation. The scoped reader does not catch or
remap native wallet/recovery/monetary failures.

The frozen wrapper passed **47 maintained Gradle tests**, the Swift wire/policy
suite including 33 invalid profile fixtures, and real generated-API compilation
for Kotlin and all three supported Swift targets. Four additional Dart recovery
tests verify missing/false/malformed wrapper capabilities, pre-key rejection,
strict-mode forwarding, typed missing-storage behavior, lifecycle protection
and unchanged legacy open behavior.

Two separate consumer identifiers then exercised the exact final wrapper:
`com.utexo.bfa7ExistingSmoke` on iOS 27 and
`com.utexo.bfa7_existing_smoke` on Android 17/API 37 with actual 16 KiB pages and
compatibility fallback disabled. Each passed these seven offline cases:

1. A new instance opens the existing profile with the same binding and cohort;
   an already-open instance cannot acquire another session.
2. Missing storage is rejected without creating its directory or a profile.
3. Empty storage is rejected without native state; subsequent normal init in
   that same test directory succeeds, proving the failed-open lease released.
4. Structurally invalid existing metadata is rejected and retained unchanged.
5. Malformed JSON, root arrays, unreadable files, 65,537-byte files, the exact
   comment/quote/deep-container bypass, UTF-16 and invalid UTF-8 all fail with
   typed profile errors and no native wallet creation.
6. Removing only an unfunded test wallet's native child state cannot replace its
   original root profile/cohort with a fresh same-seed wallet.
7. Raw string, integer and explicit-null `requireExisting` arguments reject
   before native key parsing or storage access. Missing flags retain false for
   compatibility. Kotlin preserves original map-key presence because
   JSONObject(Map) otherwise drops explicit null.

These are **14 new offline, unfunded platform checks**, subsequent to the earlier
20 funded/native checks. No indexer/proxy connection, funding, transfer or Rust
archive change occurred. The microconsumer Dart source SHA-256 is
`e295fc1e93efdb9082ead897e7eb3a076aaa6394f8d1d65765ec7be5755a369f`;
its Android release/R8 APK SHA-256 is
`2939101ea8451143e61e85e7a1465d32825d3a556c360b78bb6e9607b1db1705`.
The existing Android AVD was cold-booted without snapshot save, wipe or creation
after storage capacity recovered; its original userdata remained in place.
Only the previously owned Aster reverse mappings were restored before device
ownership returned to the app campaign. Funded SDK and application wallets were
not reset or opened by this microconsumer.

| Additional evidence, relative to `.buildlog/bfa7-finalize/` | SHA-256 |
| --- | --- |
| `existing-open-mobile-proof/RESULT.json` | `4723cef4a29f352a55e7ea81bf72d9ada123a4dd240c45a674c74df50a0a0476` |
| `existing-open-mobile-proof/ios.json` | `5d6f3a205dac49b4ebfcea81f4a8a0da60143d6a3e0a04a5a21b9d61b8817164` |
| `existing-open-mobile-proof/android.json` | `2ba845ddb16f74bf28a12bcc9be807da9d97526a9041750805e1c9f6fc02e5bb` |
| `evidence/EXISTING_OPEN_PROFILE_JUNIT.json` | `d15e18eb7d1350ca649ab547ab5bad5c6da8c20a559e837ebe022793e4b63a89` |
| `existing-open-profile-final-junit.log` | `896486220db653f6e37f11549f9cd5d8bc4c512431d18b2b2ad2e0d12f4f2052` |
| `final-profile-swift-review.log` | `2c0d7a77500e7490c49e6a2760ee1f8f5a3ffb8c02a25a0e6fe08dd67f0fcc38` |
| `adapter-qualification/PROOF.json` | `0a6ca1e24c437fe7c44821720041c6efc40788b7438e39635a3d79de24ab9d42` |

Existing-only admission does not restore lost RGB state, prove portable snapshot
freshness or remove the restored-wallet mutation fence. The deployment and
recovery-authority boundaries above remain unchanged.

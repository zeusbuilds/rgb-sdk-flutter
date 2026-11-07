# RGB_L1 recovery verification matrix

This matrix separates executed native behavior from unverified deployment and
recovery policy. RGB_L1 and Dev remain gated. The fixture asset is fungible QBFA
on isolated regtest, not Dev USDT, mainnet USDT or an inflation/mint-right claim.
No container, chain, contract or existing application wallet was created or reset.

The first `.2` candidate used native integration
`08f7ac7b8a357ae09716bf11144f327ec9f9e559`. Its explicit revocation and single
witness reorg checks passed, but the subsequent active-session outage exposed
multi-generation accounting and reconfirmation defects. That candidate is
superseded; its successful cases do not override the later failure. The corrected
`c1be7c60249188b5b86974cb2c09466afa6843e4` source recovered the same files in one
refresh and passed a repeated active-session outage, explicit revocation and
owned-block reorg/reconfirmation. Independent review then found that a restored
snapshot could still mutate pending transfers through generic refresh. That
candidate is also superseded for release admission.

The current seal is `8ac556ee67db70b93abb69b4ebd8fb0e6752dc0e`, with manifest
SHA-256 `cf769ed49356e49a914dff638a4bddee9fd57fc6ebecf4b0193d8dd53aec2897`.
Its 48 focused native checks include the restored-snapshot boundary. A current-seal
host readback retained the same five historical accepted/cancelled outcomes,
13 accepted receipts, no pending operation and exact 546/254 QBFA balances. The
chain stayed at height 279 with an empty mempool. Historical fault proofs retain
their actual source identities; they are not relabelled as current-seal runs.
Both current-seal installed SDK consumers subsequently passed all ten cases:
iOS 27.0 and Android 17/API 37, the latter with actual 16 KiB pages and
compatibility fallback disabled. These include the explicit new native Revoke
API and restored refresh/Prepare/Revoke rejection. Final Aster and deployment
acceptance remain separate from this SDK result.

| Case | Boundary | Evidence and current outcome | What establishes completion |
|---|---|---|---|
| Q01 | Wrong wallet, request, cohort, source or corrupted storage | Native and Dart tests reject identity/fingerprint mismatch, missing/truncated/modified journals and mixed SQLite anchors. | Fail before mutation; never turn invalid storage into an absent operation. |
| Q02 | Crash during journal/SQLite reservation writes | Four native atomic writer fault points and one-write-ahead reservation rollback tests pass. | Retain the old or new authenticated state and exact unsigned plan, never a replacement payment. |
| Q03 | Cancel before external submission, including delayed Prepare | Native/actual mobile tests preserve cancellation tombstones after reopen and reject delayed preparation. | A durable rejection with no submission authority and no transaction broadcast. |
| Q04 | BTC broadcast accepted but response and observation lost | Existing real forwarding proof sent one exact transaction once; a new-process Status repaired acceptance after reads returned. | Exact signed transaction proof, no second Begin/End/broadcast; chain confirmation remains independent. |
| Q05 | Final RGB consignment accepted but reply lost | Existing real proxy forwarding proof recovered through only server.info/ack.get/consignment.get before recipient progression. | Exact immutable consignment or recipient signature proof; no submission replay. |
| Q06 | ACK registration accepted before any consignment upload | Reproduced on published `.1`: Status and old Cancel stayed Committing. Final first `.2` candidate registered one exact ACK, then explicit revocation safely cancelled it. | Affirmative exact sender-proxy revocation, durable certificate before local release, restart-stable rejection. |
| Q07 | Routine Check sees Prepared but Commit dispatches before queued Cancel | First `.2` live interleaving passed: ordinary Cancel remained a protected no-op with no ack.clean. | Separate explicit revokeOnchainSend/native revoke_onchain_send; ordinary Cancel never acquires that authority. |
| Q08 | Revocation unavailable, operation unknown, already released or false success | Four explicitly injected negative replies retained the fence on first `.2`; only one real affirmative ack.clean was forwarded afterward. Native strict-response tests also pass. | Unknown/error/false/null/released cannot release allocations. Clearly distinguish simulated negative replies from real proxy revocation. |
| Q09 | Watch-only session or missing native revocation capability | Native signer and non-RGB rejection tests, typed archive capability tests and actual Kotlin/Swift adapter compilation pass. Current-seal iOS/Android consumers invoke both the accepted fast path and fresh prepared-plan Revoke; all ten platform cases pass. | Capability comes from verified artifact metadata; signing wallet and online session required. Passive Status/Check and ordinary Cancel never acquire dispatched-revocation authority. |
| Q10 | Confirmed witness loses confirmations | First `.2` live one-unit transfer demoted both native histories and restricted spendability at zero confirmations. | Preserve exact row IDs and accepted submission receipt; do not represent unconfirmed allocations as spendable. |
| Q11 | Reconfirmation of that witness | Original owned blocks were reconsidered, preserving all earlier blocks. Both balances returned to their exact confirmed values. | Same canonical rows and submission identity, no duplicate consumption, no new send. |
| Q12 | Active indexer session loses reads after opening | First `.2` failed with settled 547 becoming 5995. **Corrected c1 proof passed:** explicit refresh failure preserves last-known balances. New BTC Prepare is rejected; one already-prepared RGB Commit returns Prepared/submission_not_started without End authorization. The blocking proxy observed zero attempted mutations. | Unknown observations must not inflate balances or authorize Begin/End. A retained last-known balance is not independent authorization to spend. |
| Q13 | Read service returns after a multi-generation outage | First `.2` recovered only one generation per refresh. **Corrected c1 proof passed:** one healthy refresh recovered all eight previously waiting rows and exact 547 units from the same files; restored active-session observations retained canonical history and receipt identity. | Recover the confirmed graph in one bounded refresh without database edits or payment replay. Later current-seal readback retained the subsequent exact 546/254 balances. |
| Q14 | Encrypted backup/restore and old snapshots | Historical real mobile checks preserve exact cohort/receipts and quarantine restored snapshot spending. Hardened backup admission rejects invalid resource/cryptographic inputs. Current native tests cover pending incoming/outgoing snapshots, cold reopen and missing/aliased markers or journals. | Read-only snapshot restoration is supported. An approved freshness/cross-copy recovery authority remains required before unrestricted restored-wallet spending or mnemonic-only RGB recovery can be claimed. |
| Q15 | Generic refresh on a restored snapshot | Review found that refresh could ACK/broadcast/rebroadcast pending native transfers despite the spending quarantine. **Fixed and verified:** native generic refresh fails with RECOVERY_RESTORE_UNCERTAIN before Online admission; supported local receipt/metadata observations remain available. | Both detailed refreshTransfers and convenience refreshWallet reject in the actual current-seal JNI/Swift consumers. Encrypted native pending incoming/outgoing tests cover the raw restored boundary; all ten platform cases pass. |
| Q16 | A partial transfer-refresh failure is presented as fresh | Detailed native refresh can return successful entries alongside failed entries. **Fixed:** SDK refreshWallet throws typed payload-free REFRESH_INCOMPLETE if any entry failed; detailed refreshTransfers preserves its typed results. Aster explicitly checks detailed failures before publishing a fresh portfolio. | One refresh call, no automatic monetary retry, no retained last-known portfolio falsely marked current. SDK and Aster regressions cover a historical witness failure mixed with newer successful rows. |
| Q17 | Aster ownership marker occupies the SDK's fresh native root | Actual Aster provisioning stopped with WALLET_STORAGE_NOT_EMPTY before native wallet creation: the app had already written .aster-storage-owner into the directory it supplied to the SDK. **App fix:** retain ownership metadata in the parent and use one stable rgb-l1 child for native storage. | Preserve the parent token/deletion boundary; reject unexpected old parent-level native data. App focused tests and independent source review pass; the restarted Aster installed campaign owns final integration acceptance. |
| Q18 | Missing ready-wallet storage silently becomes a fresh same-seed profile | Legacy SDK init/reinit intentionally create or open. **Fixed additively:** openExisting requires a current wrapper capability before keys and an existing native profile under the exclusive lease. Aster READY activation uses that method after pre-key child/presence checks. | Actual offline iOS/Android cases verify unchanged binding/cohort on cold reopen, missing/empty storage rejection, no leaked failed-open lease, and partial native loss remaining fenced. No fallback initialization or new cohort. |
| Q19 | Untrusted SDK profile metadata causes generic errors, allocation or recursive parser work | Open and restore now share a regular-file reader bounded to 64 KiB before and during reading. Strict UTF-8 and flat JSON scalar grammar run before platform parsing, preventing Android lenient-comment and Swift encoding/depth bypasses. | Maintained JVM/Swift tests plus actual iOS/Android microcases reject malformed/unreadable/oversized/comment-deep/UTF16/invalidUTF8 profiles with typed storage errors and unchanged files. No Core/monetary error is blanket-remapped. |

The corrected c1 reorg proof established conservation of **fungible QBFA
allocations**: total settled and future units across the two SDK test wallets
stayed 800. Its exact row identities stayed sender 14/receiver 11. Spendability
fell from 800 to 253 while the witness was unconfirmed, then returned to 800 after
reconfirmation. The earlier 08f7 proof separately retained sender 12/receiver 9
and 252 spendable units while unconfirmed. Neither establishes mint/inflation-right
conservation.

The earlier Esplora timeout was preserved as a fixture failure. Mining had
succeeded, so its exact blocks were reconciled from Core without mining again.
The reorg observation used the actual native Electrum indexer and independent
Core. Esplora was later recovered in place by the infrastructure owner, preserving
its container and index data.

## Maintained executable checks

- `test_fault_observation.py`: offline mock-HTTP observation logic; no live reorg
  or monetary execution is claimed. All eight cases also passed against an
  isolated cfg(test)-only copy of the current 8ac seal; prior source proofs are
  retained separately.
- `check_bridge_adapters.py`: generated Kotlin/Swift API shape compilation plus
  JVM capability/error/pending-policy execution. It is not device ABI evidence.
- `qualify_revocation.py`: final-source new partial ACK operation, legacy-Cancel
  race, negative response protection and explicit actual signed revocation.
- `reorg_rgb.py`: one unique small witness transfer and only its newly mined
  blocks, under the existing issuer lock.
- `reorg_observe_owned.py`: observation-only continuation of an exactly recorded
  owned transaction/block set; no Prepare/Commit/funding/mint methods are callable.
- `active_indexer_outage.py`: read-only forwarding outage of an already-open
  native session, new BTC Prepare rejection, offline receipt observation and
  restored-session verification. It intentionally invokes one healthy-prepared
  RGB Commit while a proxy gateway blocks all mutating requests. The proof
  requires zero attempted external mutations and a Prepared/submission_not_started
  result, then ordinary cancellation of that known-unsubmitted plan. No chain
  mutation or monetary retry is permitted.
- `verify_sealed.py`: current-seal readback of existing owned wallets, historical
  outcomes and receipt inventory, with one healthy refresh per wallet and exact
  expected balances. No payment, preparation, cancellation, revocation, mining or
  restoration operation is exposed by this helper.

Private wallet keys, PSBTs, signatures and detailed native diagnostics stay in
ignored owner-only test storage. Redacted evidence summaries and source/binary
hashes are retained separately. See [BFA7_QUALIFICATION.md](BFA7_QUALIFICATION.md)
for historical platform and funded-source identities.

The additive wrapper checks were executed after the 20 funded/native cases,
using seven additional **offline, unfunded** cases on each OS and unique app
identifiers. They do not relabel the earlier consumers' source hashes or claim
another monetary campaign. Rust/UniFFI artifacts remained unchanged.

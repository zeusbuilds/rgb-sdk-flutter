# Existing-fixture native qualification

This host Rust consumer tests the sealed Flutter BFA.7 core against the already
running, separately owned BFA.7 regtest fixture. It does not qualify the mobile
ABI, public-chain connectivity, a hosted USDT deployment or production release.
RGB_L1 product/release admission must remain closed until those checks pass.

The tool never starts, creates, resets or deletes a container, chain, contract or
existing wallet. It creates two fresh native test wallets only below the SDK's
ignored `.buildlog/bfa7-native/qualification-wallets/`. Their parent directory is
0700 and key/intent/receipt files are 0600. Do not commit or share that directory:
it contains recovery phrases and native transaction/signing material.

The fixture owner is
`/Users/hardik/Projects/utexo-wdk-onchain-candidate/sdk-alpha12-funded-android`.
Read its `QUALIFICATION.md`, and the shared stack's `AGENTS.md`, consumer docs
and registry, before configuring or operating a new consumer. Coordinate use
with Iris and any other qualification client first. The fixture's backing EVM
is **31337**, while its WebRGB burn destination route is **42161**.

## Build and provenance

Prepare the SDK's sealed native source with its owned builder. The consumer
manifest points at that exact prepared source; do not edit the source checkout.
Its lock derives from the sealed UniFFI lock. Every common package must match
name, version, source and checksum; only the qualification root is added. The
consumer prunes unused UniFFI/CLI dependencies rather than selecting newer ones.
The runner verifies this, the source integration tree and sealed lock digest
before creating a wallet or funding it.

Build from the SDK root with:

```sh
python3.13 tool/bfa7_native_qualification/build.py
```

The wrapper uses the manifest-pinned Rust compiler and Cargo `--offline --locked`
with at most two build jobs. It
verifies source/lock identities before and after compilation and records the
binary digest. The runner rejects a binary left over from an older seal.

## Execution

`python3.13 tool/bfa7_native_qualification/run.py --execute` performs real local
actions: fresh wallet creation, exact approved public contract import, 200,000
regtest-sat funding, 1,000-sat BTC prepare/cancel/restart/commit/status checks,
confirmation mining, four RGB change outputs and an asset/amount-bound witness
invoice. If the existing fixture issuer has sufficient QBFA, it additionally
uses a tiny existing-asset transfer and a 100-unit witness RGB send. Otherwise
it records that funded RGB qualification was not performed.

`complete_rgb.py --root ABSOLUTE_COMPLETED_BTC_RUN --allow-fixture-mint` requires
separate explicit authorization to mint **1,000 base units of the existing QBFA**
using the existing fixture issuer, token and backing contract. It never issues
or deploys a new asset or contract. The fixture's mint helper requires a blinded
recipient; that exercises an SDK API only and does not change Aster's
witness-only receive policy. It then sends 100 QBFA units to a witness recipient.

Each action writes an exclusive intent before invocation. The monetary calls
have no automatic retry. A timeout or error stops the run and preserves its
exact operation identity and receipts. Never rerun an uncertain step. Receive
refreshes and exact status reads can progress or observe the already authorized
transfer without creating another send. Process restarts reuse the same wallet
keys, storage and native recovery cohort.

Redacted result files identify the source, graph, native transaction IDs and
actual confirmed balances. Private stdout/stderr remain local. A successful
submission receipt never substitutes for independent chain confirmation.

## Additional bounded checks

`verify_sealed.py --root RUN --authorize-small-transfers` is a separate explicitly
scoped host BTC/RGB send proof from an owned, completed baseline. It does not
fund or mint again. Its stage has exclusive output filenames; it is not a generic
resume tool and must never overwrite or replay a previous attempt.

`fault_btc_reply.py --root RUN --authorize-one-broadcast` forwards one exact
1,000-sat real transaction to Esplora, drops the successful reply, temporarily
makes exact transaction reads unavailable, and requires new-process Status to
recover acceptance without another broadcast. `--reply-only` instead allows
immediate positive-presence recovery. `fault_rgb_reply.py --root RUN
--authorize-one-unit-send` forwards one exact one-unit existing-QBFA consignment
write, drops its successful reply, and permits only exact read RPCs during Status
recovery before ordinary recipient protocol progression. Both local ephemeral
forwarders close at the end, retain exact call counts, block a second mutation
and preserve any inconclusive original operation. They do not emulate success.

`fund_mobile_rgb.py --root RUN --platform ios|android --public-marker FILE` is
only for a separately authorized actual mobile consumer's unique 100-unit witness
invoice. It refuses an invoice already recorded in a prior funding scope and
never retries Commit. Public return invoices and private wallet files are kept
separate. Every helper rechecks the current source seal, pinned dependency graph
and compiler-bound binary digest before any fixture action.

Executed results and source-stage distinctions are in
[`doc/BFA7_QUALIFICATION.md`](../../doc/BFA7_QUALIFICATION.md). These host helpers
do not grant Dev/mainnet release admission or restored-wallet spending authority.

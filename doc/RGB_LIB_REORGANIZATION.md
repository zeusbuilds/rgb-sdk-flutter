# RGB_L1 confirmation and reorganization handling

Submission acceptance is immutable evidence that a particular native payment
was submitted. It is not a promise that its transaction remains confirmed.
History, settled balances and spend eligibility must follow current chain and
RGB ancestry observations independently of the durable accepted receipt.

The published `native-bfa7-flutter.1` candidate did not revalidate settled wallet
transfers during normal `refresh`. A real isolated-fixture reorganization left
an orphaned transfer classified as Settled after refresh and process reopen.
Pending witness values could also be counted twice once actual receive
allocations existed. The original candidate and its qualification evidence are
preserved; the fix belongs to a separately sealed successor.

## Successor behavior

- Normal refresh invokes the existing native RGB witness revalidation engine.
  It updates canonical witness observations and invalidates/restores dependent
  operations in the consensus store. It does not call Begin, End or create a
  replacement payment.
- Settled history rows are checked against their exact transaction IDs and
  configured confirmation threshold. The canonical RGB operation-input graph
  is also traversed: a blinded allocation can reference a pre-existing Bitcoin
  output, so Bitcoin transaction ancestry alone cannot establish RGB ancestry.
  Local coloring dependencies additionally fence unsettled descendants.
- Insufficient or absent confirmation demotes affected rows to
  WaitingConfirmations. An unavailable observation remains unknown; it is never
  a rejection or proof that a payment did not happen. Unresolved observations
  preserve the last-known history and balance projection and explicitly fail the
  refresh. They do not label every historical payment unconfirmed. Separately
  proven insufficient confirmations still demote that root and its descendants;
  an unrelated outage does not hide positive reorganization evidence. Begin and End
  independently require current ancestry observations, so a cached balance does
  not grant spending permission. Structural/storage errors also abort refresh;
  callers must not present the previous cached result as newly verified data.
- Original payment timestamps, raw consignments, assignment rights and accepted
  durable receipts are retained. A previously consumed witness is not destroyed
  by an old proxy-expiration deadline after a reorganization. On reconfirmation,
  the exact original consignment is validated and merged through the canonical
  native store; it does not produce a second payment or replay End. Exact
  witness and complete RGB ancestry proofs release all confirmed generations
  in the same refresh; stale pending history cannot force one refresh per
  ancestor.
- Pending witness estimates contribute only while no actual Receive allocation
  exists for the corresponding asset transfer. A retained receive allocation
  and its original request therefore cannot count the same value twice.
  Settled amounts use the confirmed producer allocation frontier, retaining a
  spent producer only while its consuming transfer awaits confirmation.
  Historical inputs across several pending descendants never count the same
  value repeatedly. Future amounts use the current unspent allocation frontier
  minus unbroadcast reservations.
- All RGB Begin input-selection paths revalidate before constructing a plan.
  All RGB End paths check the plan's input producers again before the first
  dispatch, covering a reorganization that happens after preparation. Unknown
  ancestry stops the action. No amount, recipient or transaction is replaced.

An explicit zero-confirmation policy remains explicit: an observed mempool
transaction can satisfy a threshold of zero; an absent or unavailable
transaction cannot. The successor does not silently turn zero into one.

Revalidation shares observations by transaction ID and bounds witness count,
operation traversal and read admission time. Exceeding a bound stops new spending
with a failure; it does not fabricate a height, confirmation or successful state.

## Qualification boundary

Focused native regressions cover confirmation-threshold semantics, transitive
dependency fencing, witness amount conservation before/after materialization,
outgoing gross/future/spendable balance conservation, ten-generation reorgs at
all depths, independent and split/merge branches, mixed confirmation policies,
mixed positive-reorg/unavailable observations, whole-chain proof admission in
one pass, unbroadcast reservation cancellation and read-deadline uncertainty.
They do not replace a funded successor test. Before activation, the exact final
binary must repeat the isolated-fixture reorg, endpoint-outage and reconfirmation
cases, inspect actual history/balance changes and canonical allocation/rights
rows, and prove unchanged accepted receipts and no extra monetary invocation.
Portable restored-wallet spending remains separately blocked as described in
[the backup recovery contract](RGB_LIB_BACKUP_RECOVERY.md).

# RGB_L1 upstream compatibility

The RGB_L1 comparison uses [React Native 1.0.0-beta.41](https://github.com/UTEXO-Protocol/rgb-sdk-rn/releases/tag/v1.0.0-beta.41)
at `e0a680729c53c8772cc0792c212c09146f5f983b` and its [Core 1.0.0-beta.10](https://www.npmjs.com/package/@utexo/rgb-sdk-core/v/1.0.0-beta.10)
contract. The release verifier checks the source, registry packages and changed
paths. The legacy RLN and beta.40 references remain independently pinned.

| Component | Verified upstream release | Flutter integration |
| --- | --- | --- |
| React Native engine | 1.0.0-beta.41 | `RgbLibWallet` implements the on-chain engine in Dart. |
| Shared Core | 1.0.0-beta.10 | The RGB_L1 wallet exposes the shared engine capability flags. Core's LSP code is unchanged from beta.9. |
| RGB Lib BFA | RN uses BFA.6. [BFA.8 Swift](https://github.com/UTEXO-Protocol/rgb-lib-swift/releases/tag/0.3.0-beta.7-upstream-dev-bfa.8-bfa) and [Android](https://repo.maven.apache.org/maven2/com/utexo/rgb-lib-bfa-android/) are published independently. | The default Flutter pin remains BFA.7. The [local BFA.8 candidate](BFA8_NATIVE_CANDIDATE.md) carries forward contract registration, the durable outbox and storage-bound recovery. |
| Legacy RLN | [0.17.0-beta.3](https://github.com/UTEXO-Protocol/rgb-lightning-node/releases/tag/v0.17.0-beta.3) | Flutter pins the same RLN source and retains its 16 KiB Android rebuild. |

## Wallet behavior

- `init` opens offline. Constructor settings supply the first online call,
  including an explicitly configured regtest wallet. `goOnline` and `unlock`
  share configuration and avoid reconnecting with the same resolved settings.
  Unconfigured regtest requires explicit endpoints. Stored BTC, UTXO and
  transaction reads can skip synchronization and run offline.
- A configured EVM RPC uses the shared 1,200 to 28,800 block window unless
  overridden per chain. BFA.7 requires a minimum of two blocks. The hosted Dev
  Signet profile requires its reviewed endpoint and lock policy.
- `exportBackup` returns native encrypted bytes offline. File export and
  restore are available through the canonical methods and compatibility aliases.
  Restored snapshots still require freshness authority before spending.
- `refresh` returns per-transfer results. `refreshWallet` still reports
  incomplete observations. RGB sends reject requests to skip synchronization.
- BFA asset lists retain the exact known circulating supply. Transfer history
  retains every change output in order. The deprecated singular getter returns
  the first output, or null for an empty list.

## Compatibility boundaries

Flutter retains dual-engine packaging for existing consumers. The RN package
contains only RGB_L1 and delegates its optional generic facade to the separate
[`@utexo/rgb-sdk`](https://www.npmjs.com/package/@utexo/rgb-sdk/v/1.0.0-beta.10)
package. Flutter applications select `RgbLibWallet` or `UtexoWallet` directly.

The Flutter-hosted bridge has its own deployment and authorization contract.
[`@utexo/webrgb` 0.1.6](https://www.npmjs.com/package/@utexo/webrgb/v/0.1.6)
introduces maintenance calls and a new burn destination request. The shared
facade and [WalletConnect adapter 0.1.5](https://www.npmjs.com/package/@utexo/webrgb-walletconnect/v/0.1.5)
still reference the earlier burn contract. Moving Aster to the new wire contract
requires aligned dApp, session-grant and wallet changes. Invoice-scoped mint
lookup requires an authenticated invoice and matching native evidence in
addition to recipient-ID lookup. Production RGB_L1 eligibility still depends on
[native qualification and release gates](RELEASE_READINESS_TRACKER.md).

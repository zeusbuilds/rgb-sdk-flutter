# React Native beta.42 Reference Audit

Verified 2026-11-25 against the published npm archives and their exact upstream
Git commits. This records source and native-base identity. It does not certify
full API parity, funded settlement, or production RGB_L1 admission.

## Exact references

| Reference | Identity |
| --- | --- |
| React Native package | `@utexo/rgb-sdk-rn@1.0.0-beta.42` |
| RN source | [`11d6c1a97adbc637bd45f1525134a914c272098e`](https://github.com/UTEXO-Protocol/rgb-sdk-rn/tree/11d6c1a97adbc637bd45f1525134a914c272098e) |
| RN npm archive SHA-256 | `bb26c8b660e5977da370209dc9d43212c169771502b906ab1f5bf24b72fd3207` |
| RN source/npm evidence | 70 Git source files; 133 npm files; all 43 common shipped source files match byte-for-byte |
| Core package | `@utexo/rgb-sdk-core@1.0.0-beta.11` |
| Core npm gitHead | `1ed3d61c0d887d6d77c5f417b2162b2ab5a89658` |
| Core npm archive SHA-256 | `827b2465625ec72c67a4e963d9e705a17c265a05902939348e127364dbeb98b1` |
| Native base tag/revision | `v0.3.0-beta.7-upstream-dev-bfa.8` / `cafe66e49d58038a69dd05f8065e3fe96a9d1601` |
| RN native version / wrapper bridge | `0.3.0-beta.7-upstream-dev-bfa.8-bfa` / `7` |
| Flutter native version / wrapper bridge | `0.3.0-beta.7-upstream-dev-bfa.8-bfa-flutter.1` / `6` |
| UniFFI | `0.32.2` |

`tool/rn_beta42_reference.json` locks npm archive size, SHA-256, registry SHA-512
integrity, source-tree digest, source-delta digest and exact Core files.
`tool/rn_beta42_rgb_lib_reference.json` separately preserves the released RN
native manifest, Android Maven coordinate and checksum. These references do
not replace Flutter's archive/provenance baseline.

Flutter's sealed BFA.8 overlay already uses the same native base source as
beta.42. The default now loads that exact overlay through
`tool/rgb_lib_native_baseline.json`, not only a staged candidate. The separate
Flutter bridge identity protects its additional contract registration and
durable-operation contract. RN bridge 7 must not be substituted for Flutter
bridge 6 merely because the upstream base is equal. The original BFA.7 and RN
beta.40/beta.41 locks remain immutable historical evidence.

## Reviewed behavior changes

| Change in RN beta.42 | Flutter handling and boundary |
| --- | --- |
| BFA.8 replaces the BFA.6 base used by beta.41. | Default BFA.8 native pins and wrapper ABI are promoted together. The pinned Flutter overlay, source reconstruction and native smoke evidence are tracked separately in [BFA.8 integration](BFA8_NATIVE_CANDIDATE.md). |
| `getReceivedMint` supplies the received asset identity. | Resolve the receipt's operation ID to the recipient's unique local consignment, inspect terminal operations, and require the operation and asset identity to agree. Do not infer the asset from host configuration or merely trust another transfer with a similar amount. |
| `getReceivedMint(recipientId, { refreshIncoming: true })` supports an explicit incoming refresh. | Default lookup remains read-only/offline. Opt-in refresh requires an online session, refreshes incoming transfers in the four pending states, propagates a matching refresh failure, then performs receipt lookup. It does not advance outgoing transactions or replay a mint. |
| Native wallet configuration and online ABI add explicit policy arguments. | Preserve restrictive schema/contract checks when adapting the ABI; absence of a matching bridge must fail before a wallet operation. |
| RN adds PSBT signing/fee inspection and generic begin/end operations. | **Known remaining contract gap:** Flutter's optional `psbt` and `beginEnd` carriers remain absent and capabilities false. No raw payment lifecycle is enabled by this update. See the divergence register below. |

Core beta.11 declares received-mint `assetId` optional for engines that cannot
supply it. The RN RGB_L1 bridge itself requires a verified asset ID or rejects
the lookup. Flutter's RGB_L1 receipt uses that stricter engine contract. A
missing receipt still means no receipt was observed; it does not prove failure,
authorize a retry, or provide restored-wallet freshness authority.

The incoming refresh scope is `waitingCounterparty`, `waitingSafeHeight`,
`waitingBroadcast` and `waitingConfirmations`, all with `incoming: true` and
`skipSync: false`. A failed check is an error, not a successful `null` result.
Offline lookup remains available without network access.

The new upstream PSBT and begin/end support is larger than a version bump or
mint getter. It includes signing capability differences for watch-only wallets,
fee inspection, and `CannotEndTransfer` recovery using the exact signed-PSBT
transaction identity, transaction kind and submitted status. Exposing those
methods in Flutter requires integration with the existing durable authorization
and recovery boundary. Existing absent-capability tests are not parity evidence
for these new methods. See [the divergence register](API_COMPATIBILITY_AND_DIVERGENCE.md)
under `API-015` / `NOV-002`; production RGB_L1 remains gated.

## Complete beta.41 to beta.42 source delta

The verified delta is 26 paths: one added, none removed, 25 modified. The paths
digest is `dbf7377a220a278cb13d296d6aeaa2e33ceb9fe5b421be5ecd045879b0fc9f3f`.
The validator compares exact file contents as well as this delta inventory.

```text
+ src/wallet/rgb-lib/psbt.ts
~ CHANGELOG.md
~ Readme.md
~ android/src/androidTest/java/com/utexo/rgblibrn/RgbLibSessionStoreInstrumentationTest.kt
~ android/src/main/java/com/utexo/rgblibrn/RgbLibDtos.kt
~ android/src/main/java/com/utexo/rgblibrn/RgbLibModule.kt
~ android/src/main/java/com/utexo/rgblibrn/RgbLibSessionStore.kt
~ ios/RgbLib.mm
~ ios/RgbLibDtos.swift
~ ios/RgbLibSwiftHelper.swift
~ package.json
~ scripts/check-contract.mjs
~ scripts/generate-rgb-lib-dtos.mjs
~ src/bindings/rgb-lib/manifest.json
~ src/index.ts
~ src/native/NativeRgbLib.ts
~ src/wallet/rgb-lib/backend.ts
~ src/wallet/rgb-lib/config.ts
~ src/wallet/rgb-lib/errors.ts
~ src/wallet/rgb-lib/mappers.ts
~ src/wallet/rgb-lib/rgb-lib-rn.ts
~ src/wallet/types.ts
~ src/wallet/wallet-api.ts
~ tests/native/rgb-lib-smoke.m
~ tests/rgb-lib.test.mjs
~ yarn.lock
```

## Reproduce verification

```sh
python3 tool/validate_rn_beta40_reference.py
python3 tool/validate_rn_beta41_reference.py
python3 tool/validate_rn_beta42_reference.py --check-latest --list-changes
python3 -B -m unittest tool/test_rn_beta40_native_divergence.py
```

The first two commands verify their frozen historical releases. Only beta.42
checks the current npm latest tag; a newer publication requires another review.
The beta.42 validator rejects a default still pinned to BFA.7 even if BFA.8
candidate artifacts exist. Eight native-divergence tests cover reviewed BFA.7
and BFA.8 identity, patch tampering and archive metadata admission. Exact mobile
archive validation, security/privacy review and funded qualification are
separate release checks; this reference audit does not replace them.

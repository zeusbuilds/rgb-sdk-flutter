# Flutter BFA.7 native candidate

This source build is distinct from upstream BFA.5/BFA.6 mobile releases. The
candidate version is `0.3.0-beta.7-upstream-dev-bfa.7-bfa-flutter.1`, bridge 5.
Never label an upstream archive with that version without building this overlay.

`source-manifest.json` pins BFA.7 commit
`9ec49c08be2e68f08521281e3efbd760ec989cb9`, its base tree, each safeguard patch,
the Flutter integration patch/tree and the exact UniFFI Cargo lock. The four
core safeguards were carried from the WDK BFA.7 candidate: standalone genesis
registration, guarded native HTTP transport, distinct Signet checkpoints and
embedded process lifecycle cleanup. The Esplora crate is separately pinned by
its published crate digest and guarded overlay tree. Original upstream license
notices remain in the source/package. The implementation extensions and
generated bindings do not include application wallet data.

Normal builds are immutable and use `Cargo --locked`. They reject unsealed
source, changed patches, dirty prepared checkouts and stale generated bindings.
Preparation uses a fresh disposable directory. It never resets a source mirror,
application wallet, chain, container or service.

## Rebuild

Run from the SDK repository on macOS with Rust 1.94.0 and its admitted targets,
Xcode, JDK 17 and Android NDK `28.2.13676358` installed:

```sh
python3 tool/build_rgb_lib_bfa7.py prepare --source /path/to/exact/local/source/mirror
python3 tool/build_rgb_lib_bfa7.py verify
python3 tool/build_rgb_lib_bfa7.py generate
python3 tool/build_rgb_lib_bfa7.py build
python3 tool/build_rgb_lib_bfa7.py package
python3 tool/test_build_rgb_lib_bfa7.py
```

Without `--source`, preparation fetches the exact commit from the source
repository using the caller's existing Git credential mechanism. Credentials
are never placed in the manifest, URL or artifact. The local mirror still has
to match the exact commit and base tree.

All output belongs to the ignored `.buildlog/bfa7-native/` directory. Mobile
builds run sequentially against one target cache. A selected target can be
rebuilt with `build --target <target>`; supported targets are listed in the
manifest. Packaging can use `--platform android` or `--platform ios`.

Kotlin compiler 2.2.20 matches the SDK's minimum host toolchain. Compiler/runtime
inputs are SHA-256 pinned; packaging rejects altered cached jars. Android
libraries link with 16 KiB page sizes and RELRO/NOW/non-executable-stack flags.
The AAR preserves the SDK's Android API 24 minimum and includes both admitted
ABIs and generated `com.utexo` bindings, with no
bundled `libc++_shared.so`. The Swift archive includes device arm64 and arm64/
x86_64 simulator static libraries plus generated Swift/header bindings. The
existing checksum-verifying installer turns those libraries into frameworks
with isolated UniFFI exports so the app can continue to link legacy RLN.

`artifacts/build-record.json` records exact source/overlay/tool identities and
artifact sizes/digests. Archive entry order, permissions and timestamps are
stable. A build record is not a publisher attestation or funded qualification.
Each target also records its source/tool identity and binary digest. Packaging
rejects missing, altered or stale targets, so slices from different overlay
generations cannot be combined after a source change.
Supply the Android directory through `RGB_LIB_ANDROID_ARTIFACT_DIR` and the
Swift ZIP through `RGB_LIB_IOS_ARCHIVE_PATH` only after the SDK's artifact pin
has the exact corresponding size and SHA-256. Overrides do not bypass checks.

## Changing the integration overlay

`seal` is an explicit developer operation, never part of consumer installation
or a normal build. Starting with exactly the four core patches staged in the
disposable source index, edit/review the Flutter extension, update its lockfile,
then run:

```sh
python3 tool/build_rgb_lib_bfa7.py seal
```

This captures the extension, including new source files, and records its patch
digest, full integration tree and lock digest. Re-review the resulting tracked
diff and rebuild both platforms after any change. The base source commit is
preserved. Aster's RGB_L1 gate remains closed until the exact candidate passes
its required registration, durable-send, restore and platform acceptance tests.

`security-review.json` records the reviewed lockfile and RustSec database
revision, the narrowly updated dependency versions, and retained unmaintained
dependency notices with their actual reachability. It does not replace funded
recovery qualification or the final linked iOS privacy/API review.

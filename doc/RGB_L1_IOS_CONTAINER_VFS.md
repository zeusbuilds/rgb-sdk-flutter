# RGB_L1 iOS private-container SQLite VFS

The successor native candidate removes unnecessary disk-space API imports from
its bundled SQLite component. This is an explicit source/build change, not a
new privacy reason. It does not approve the independent legacy RLN component or
replace final application archive and privacy-manifest verification.

## Actual call paths

The locked `libsqlite3-sys` 0.37.0 source uses Apple `statfs` to choose a desktop
filesystem locking style, and `fstatfs` to identify FAT/exFAT for the empty-file
inode workaround. These paths do not check available capacity. Apple's
`E174.1` reason therefore does not describe their use. The existing native
privacy policy correctly remains blocked for the published `.1` archives.

## Supported storage and source change

The iOS successor uses the ordinary POSIX SQLite VFS on private application
storage. It does not support external, network or file-provider database paths.
The exact crate archive is admitted by SHA-256
`b1f111c8c41e7c61a49cd34e44c7619462967221a6443b0ec299e0ac30cfb9b1`.
The additional patch, overlay tree and build flags are recorded in
`native/rgb_l1/source-manifest.json`, independently of the RGB/Esplora overlays.
Both Cargo lockfiles retain every original dependency version, checksum and
edge except this explicitly substituted SQLite source.

Only iOS device/simulator targets receive these reviewed flags:

```
SQLITE_ENABLE_LOCKING_STYLE=0 RGB_SQLITE_IOS_CONTAINER_ONLY=1
```

The first selects POSIX `fcntl` locking. The small source guard omits the
desktop FAT/exFAT probe under the second flag. It does not undefine `__APPLE__`,
change transaction or journal semantics, remove fsync, or disable Apple's
`F_FULLFSYNC` implementation. Android and host/macOS builds retain their
ordinary platform behavior.

`RgbLibStorageDirectoryPolicy` checks private-container ancestry and existing
path components before the Flutter adapter creates storage. It rejects
relative/dot/NUL paths, root/sibling prefixes and symlink escapes, including a
symlink whose final child does not exist. The native core independently checks
canonical data-directory ancestry against the iOS sandbox's `HOME` before any
wallet subdirectory, logger or database is opened. This also constrains raw
UniFFI wallet constructors; the Swift check is not the sole enforcement point.
RLN's existing storage policy is unchanged.

## Verification boundary

The component probe compiles for arm64 iOS Simulator with no `statfs`, `fstatfs`,
`statvfs` or `fstatvfs` imports while retaining `fcntl` and `fsync`. Swift and
Rust tests cover valid contained paths, root/prefix rejection and symlink
escapes. The Swift adversarial fixture is part of the iOS CI job. Compiler flags
are exact, target-specific and cannot inherit `LIBSQLITE3_FLAGS` from the shell.

These component checks are not a final binary claim. The successor's sealed
native archives, all Apple slices, actual mobile runtime and the final app must
be inspected separately. An archive with another source/overlay identity does
not inherit this review. The legacy RLN disk-space disposition and overall
signed-app/privacy release gates remain independent. No native privacy policy
is set production-ready merely because this component probe passes.

## Sealed successor linked-component result

The `.2` source seal `8ac556ee67db70b93abb69b4ebd8fb0e6752dc0e` and Swift
archive SHA-256
`60c33914222a62a822440bf155babd0b030a74f4fc166f7bd5c5955e6f49932c`
were installed with the SDK's verified framework converter. All six
framework/architecture pairs (FFI and Swift on device arm64, simulator arm64 and
simulator x86_64) have no `statfs`, `fstatfs`, `statvfs` or `fstatvfs` imports.
The FFI framework retains `fcntl`/`fsync`, isolated UniFFI exports and the exact
source/license notices. The recorded binary hashes and architecture results
are in `native/rgb_l1/ios-privacy-review.json`.

The static Rust archive still contains unreferenced Rustix `fstatfs`/`fstatvfs`
object code. The reviewed converter's symbol isolation and dead stripping omit
it from the linked frameworks. Another embedding/linking configuration must
perform its own scan; it cannot inherit this framework result from the ZIP's
name or source revision alone. The production policy records this exact
successor as `blocked-final-app-review`, preserves the published `.1` native
DiskSpace blocker and still rejects unknown archive/source pairs. The legacy
RLN review and final signed-app API/aggregate privacy evidence remain open.

Primary references:

- [SQLite compile-time locking styles](https://www.sqlite.org/compile.html#enable_locking_style)
- [Apple required-reason API categories and approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Apple TN3183 privacy manifest guidance](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)

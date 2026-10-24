#!/usr/bin/env python3
"""Export the reviewed local native overlay as pinned, reproducible source patches."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def git(root, *args, diff=False):
    result = subprocess.run(["git", *args], cwd=root, check=False, capture_output=True)
    if result.returncode not in ([0, 1] if diff else [0]):
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    sdk = Path(__file__).resolve().parent.parent
    source = args.source.resolve()
    manifest_path = sdk / "native/durable_onchain_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    vendor = source / manifest["rgbLib"]["checkoutPath"]
    for root, expected in [(source, manifest["rln"]["commit"]), (vendor, manifest["rgbLib"]["commit"]), (source / "rust-lightning", manifest["lightningCommit"])]:
        if git(root, "rev-parse", "HEAD").decode().strip() != expected:
            raise RuntimeError("Native source checkout does not match the pinned overlay commit")
    native = git(source, "diff", "--", "Cargo.toml", "Cargo.lock", "bindings/rgb_lightning_node.udl", "src/lib.rs", "src/sdk/mod.rs", "src/uniffi_api/mod.rs")
    for name in ["src/durable_payment.rs", "src/durable_payment_fault_tests.rs"]:
        native += git(source, "diff", "--no-index", "--", "/dev/null", name, diff=True)
    dependency = git(vendor, "diff", "--", "src/wallet/online.rs", "src/wallet/singlesig.rs", "src/wallet/offline.rs")
    if not native or not dependency:
        raise RuntimeError("The source overlay or its dependency patch is empty")
    for key, content in [("rln", native), ("rgbLib", dependency)]:
        target = sdk / "native" / manifest[key]["patch"]
        digest = hashlib.sha256(content).hexdigest()
        if args.check:
            if target.read_bytes() != content or manifest[key]["patchSha256"] != digest:
                raise RuntimeError("Checked-in native overlay does not match the reviewed source")
        else:
            target.write_bytes(content)
            manifest[key]["patchSha256"] = digest
    if not args.check:
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print("Native overlay patches and source pins match." if args.check else "Native overlay patches refreshed.")


if __name__ == "__main__":
    main()

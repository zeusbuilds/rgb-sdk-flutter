#!/usr/bin/env python3
"""Execute the real Android example ABI selector in isolated, offline Gradle."""
import os
from pathlib import Path
import re
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parent.parent
    source = (root / "example/android/app/build.gradle.kts").read_text()
    match = re.search(r"(fun selectRgbExampleNativeAbis\(.*?\n\})", source, re.S)
    if match is None:
        raise SystemExit("Android example ABI selector is missing")
    if 'orElse("android-arm64,android-x64")' not in source:
        raise SystemExit("The default dual-engine target set is missing")
    if 'abiFilters.addAll(rgbExampleSelectedNativeAbis)' not in source:
        raise SystemExit("The example does not apply its selected ABI filter")
    if 'excludes.addAll(rgbExampleExcludedNativeAbis.map { "**/$it/**" })' not in source:
        raise SystemExit("The example must exclude every unselected JNI ABI")
    vectors = '''
        check(selectRgbExampleNativeAbis("android-arm64") == setOf("arm64-v8a"))
        check(selectRgbExampleNativeAbis("android-x64") == setOf("x86_64"))
        check(selectRgbExampleNativeAbis("android-arm64,android-x64") == setOf("arm64-v8a", "x86_64"))
        check(selectRgbExampleNativeAbis("android-arm,android-arm64,android-x64") == setOf("arm64-v8a", "x86_64"))
        check(selectRgbExampleNativeAbis("android-arm,android-arm64") == setOf("arm64-v8a"))
        for (invalid in listOf("android-arm", "android-x86", "unknown", "", "android-arm64,unknown")) {
            var rejected = false
            try { selectRgbExampleNativeAbis(invalid) } catch (_: IllegalArgumentException) { rejected = true }
            check(rejected) { "Unsupported target was accepted" }
        }
        println("Actual example ABI policy: 5 supported selections and 5 invalid selections passed")
    '''
    with tempfile.TemporaryDirectory(prefix="rgb-example-abi-policy-") as directory:
        work = Path(directory)
        (work / "settings.gradle.kts").write_text('rootProject.name="rgb-abi-policy"\n')
        (work / "build.gradle.kts").write_text(
            match.group(1) + '\ntasks.register("verifyAbiPolicy") { doLast {\n' + vectors + '\n} }\n'
        )
        subprocess.run(
            [str(root / "example/android/gradlew"), "-p", str(work), "--offline", "--no-daemon",
             "--console=plain", "-q", "verifyAbiPolicy"],
            env=os.environ.copy(), check=True,
        )


if __name__ == "__main__":
    main()

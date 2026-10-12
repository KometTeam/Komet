import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
BUILD_SCRIPT = ROOT / "scripts/build_ios_share.sh"


class ShareTransportBuildTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="komet share build ")
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name)
        self.bin = self.path / "cargo/bin"
        self.bin.mkdir(parents=True)
        tool = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with open(os.environ["SHARE_TEST_LOG"], "a") as output:
    output.write(json.dumps([Path(sys.argv[0]).name, *args]) + "\\n")
if os.environ.get("SHARE_TEST_FAIL") == "1":
    sys.exit(1)
if Path(sys.argv[0]).name == "cargo":
    target = args[args.index("--target") + 1]
    directory = Path(args[args.index("--target-dir") + 1]) / target / "release"
    directory.mkdir(parents=True)
    (directory / "libkomet_share.a").write_text(target)
else:
    output = Path(args[args.index("-output") + 1])
    libraries = args[2:args.index("-output")]
    output.write_text("\\n".join(Path(library).read_text() for library in libraries))
'''
        for name in ["cargo", "xcrun"]:
            executable = self.bin / name
            executable.write_text(tool)
            executable.chmod(0o755)
        self.env = {
            **os.environ,
            "CARGO_HOME": str(self.path / "cargo"),
            "CARGO_TARGET_DIR": str(self.path / "rust target"),
            "BUILT_PRODUCTS_DIR": str(self.path / "products"),
            "SHARE_TEST_LOG": str(self.path / "calls.jsonl"),
        }
        self.output = self.path / "products/KometShareTransport/libkomet_share.a"

    def run_build(self, platform, architectures, **environment):
        return subprocess.run(
            ["/bin/bash", str(BUILD_SCRIPT)],
            env={**self.env, "PLATFORM_NAME": platform, "ARCHS": architectures, **environment},
            capture_output=True,
            text=True,
        )

    def calls(self):
        return [json.loads(line) for line in (self.path / "calls.jsonl").read_text().splitlines()]

    def test_device_uses_locked_release_library_and_paths_with_spaces(self):
        result = self.run_build("iphoneos", "arm64")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), "aarch64-apple-ios")
        call, = self.calls()
        self.assertEqual(call[:4], ["cargo", "build", "--locked", "--release"])
        self.assertEqual(call[call.index("--manifest-path") + 1], str(ROOT / "native/komet_share/Cargo.toml"))

    def test_simulator_combines_arm_and_intel_libraries(self):
        result = self.run_build("iphonesimulator", "arm64 x86_64")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text().splitlines(), ["aarch64-apple-ios-sim", "x86_64-apple-ios"])
        self.assertEqual(self.calls()[-1][:3], ["xcrun", "lipo", "-create"])

    def test_unknown_architecture_fails_before_publishing_library(self):
        result = self.run_build("iphoneos", "x86_64")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unsupported", result.stderr)
        self.assertFalse(self.output.exists())

    def test_failed_cargo_build_does_not_replace_previous_library(self):
        self.output.parent.mkdir(parents=True)
        self.output.write_text("previous synthetic library")
        result = self.run_build("iphoneos", "arm64", SHARE_TEST_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_text(), "previous synthetic library")


class ShareProjectWiringTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(
            ["/usr/bin/plutil", "-convert", "json", "-o", "-", str(ROOT / "ios/Runner.xcodeproj/project.pbxproj")],
            check=True,
            capture_output=True,
            text=True,
        )
        cls.objects = json.loads(result.stdout)["objects"]
        cls.targets = {
            item["name"]: item
            for item in cls.objects.values()
            if item["isa"] == "PBXNativeTarget"
        }

    def sources(self, target):
        phases = [self.objects[key] for key in self.targets[target]["buildPhases"]]
        source_phase = next(phase for phase in phases if phase["isa"] == "PBXSourcesBuildPhase")
        return {self.objects[self.objects[key]["fileRef"]]["path"] for key in source_phase["files"]}

    def test_shared_accounts_compile_in_both_targets_and_sender_only_in_extension(self):
        for target in ["Runner", "ShareExtension"]:
            self.assertIn("KometShareAccounts.swift", self.sources(target))
        self.assertIn("KometShareSender.swift", self.sources("ShareExtension"))
        self.assertNotIn("KometShareSender.swift", self.sources("Runner"))

    def test_library_build_precedes_swift_and_declares_linker_output(self):
        phases = [self.objects[key] for key in self.targets["ShareExtension"]["buildPhases"]]
        self.assertEqual(phases[0]["name"], "Build Komet Share Transport")
        self.assertEqual(phases[0]["alwaysOutOfDate"], "1")
        self.assertEqual(phases[0]["outputPaths"], ["$(BUILT_PRODUCTS_DIR)/KometShareTransport/libkomet_share.a"])
        configs = self.objects[self.targets["ShareExtension"]["buildConfigurationList"]]["buildConfigurations"]
        for key in configs:
            settings = self.objects[key]["buildSettings"]
            self.assertEqual(settings["SWIFT_OBJC_BRIDGING_HEADER"], "ShareExtension/ShareExtension-Bridging-Header.h")
            self.assertIn("-force_load", settings["OTHER_LDFLAGS"])
            self.assertIn('"$(BUILT_PRODUCTS_DIR)/KometShareTransport/libkomet_share.a"', settings["OTHER_LDFLAGS"])


if __name__ == "__main__":
    unittest.main()

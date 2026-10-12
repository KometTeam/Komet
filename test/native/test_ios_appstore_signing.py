import importlib.util
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("komet_appstore_signing", ROOT / "scripts/sign_ios_appstore.py")
SIGNING = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = SIGNING
SPEC.loader.exec_module(SIGNING)


def profile(bundle_id="example.synthetic.app", groups=None, team="SYNTH12345"):
    entitlements = {
        "application-identifier": f"{team}.{bundle_id}",
        "com.apple.developer.team-identifier": team,
        "keychain-access-groups": [f"{team}.{bundle_id}"],
        "get-task-allow": False,
    }
    if groups is not None:
        entitlements["com.apple.security.application-groups"] = groups
    return {
        "ApplicationIdentifierPrefix": [team],
        "TeamIdentifier": [team],
        "Entitlements": entitlements,
    }


class AppStoreSigningPlanTest(unittest.TestCase):
    def setUp(self):
        self.app_profile = profile(groups=["group.synthetic.second", "group.synthetic.shared"])
        self.share_profile = profile("example.synthetic.app.ShareExtension", ["group.synthetic.shared", "group.synthetic.second"])

    def test_uses_profiles_own_identifiers_and_entitlements(self):
        plan = SIGNING.create_plan(self.app_profile, self.share_profile, "group.synthetic.shared")
        self.assertEqual(plan.app.bundle_id, "example.synthetic.app")
        self.assertEqual(plan.share.bundle_id, "example.synthetic.app.ShareExtension")
        self.assertEqual(plan.group, "group.synthetic.shared")
        self.assertEqual(plan.app.entitlements, self.app_profile["Entitlements"])
        self.assertEqual(plan.share.entitlements, self.share_profile["Entitlements"])
        self.assertNotEqual(plan.app.entitlements["application-identifier"], plan.share.entitlements["application-identifier"])

    def test_selects_a_common_authorized_group_when_default_is_unavailable(self):
        self.share_profile["Entitlements"]["com.apple.security.application-groups"] = ["group.synthetic.shared"]
        plan = SIGNING.create_plan(self.app_profile, self.share_profile, "group.synthetic.unavailable")
        self.assertEqual(plan.group, "group.synthetic.shared")

    def test_app_only_profile_needs_no_shared_capabilities(self):
        app_profile = profile()
        plan = SIGNING.create_plan(app_profile)
        self.assertIsNone(plan.share)
        self.assertIsNone(plan.group)
        self.assertEqual(plan.app.entitlements, app_profile["Entitlements"])

    def test_rejects_unrelated_or_wildcard_extension_identifier(self):
        for bundle in ["example.synthetic.appOther.Extension", "example.synthetic.app", "example.synthetic.app.*"]:
            with self.subTest(bundle=bundle), self.assertRaises(SIGNING.SigningPlanError):
                SIGNING.create_plan(self.app_profile, profile(bundle, ["group.synthetic.shared"]))

    def test_rejects_profiles_from_different_teams(self):
        with self.assertRaises(SIGNING.SigningPlanError):
            SIGNING.create_plan(self.app_profile, profile("example.synthetic.app.ShareExtension", ["group.synthetic.shared"], "OTHER12345"))

    def test_rejects_missing_or_wildcard_shared_group(self):
        for groups in [[], ["group.synthetic.other"], ["group.*"]]:
            with self.subTest(groups=groups), self.assertRaises(SIGNING.SigningPlanError):
                SIGNING.create_plan(self.app_profile, profile("example.synthetic.app.ShareExtension", groups))

    def test_rejects_inconsistent_profile_prefix(self):
        self.app_profile["ApplicationIdentifierPrefix"] = ["OTHER12345"]
        with self.assertRaises(SIGNING.SigningPlanError):
            SIGNING.create_plan(self.app_profile)


class AppStoreBundlePreparationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="synthetic signing ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.app = self.root / "Runner.app"
        self.share = self.app / "PlugIns/ShareExtension.appex"
        self.other = self.app / "PlugIns/Unrelated.appex"
        self.share.mkdir(parents=True)
        self.other.mkdir()
        SIGNING.write_plist(self.app / "Info.plist", {
            "CFBundleIdentifier": "example.previous.app",
            "CFBundleVersion": "22",
            "KometShareAppGroup": "group.previous.app",
            "CFBundleURLTypes": [
                {"CFBundleURLName": "example.previous.app", "CFBundleURLSchemes": ["synthetic"]},
                {"CFBundleURLName": "unrelated", "CFBundleURLSchemes": ["other"]},
            ],
        })
        SIGNING.write_plist(self.share / "Info.plist", {
            "CFBundleIdentifier": "example.previous.app.ShareExtension",
            "KometShareAppGroup": "group.previous.app",
        })
        self.app_profile_path = self.root / "app.mobileprovision"
        self.app_profile_path.write_bytes(b"synthetic app profile")
        self.share_profile_path = self.root / "share.mobileprovision"
        self.share_profile_path.write_bytes(b"synthetic extension profile")

    def test_app_only_removes_generated_extension_and_disables_shared_storage(self):
        plan = SIGNING.create_plan(profile())
        result = SIGNING.prepare_app(self.app, plan, self.app_profile_path)
        self.assertIsNone(result)
        self.assertFalse(self.share.exists())
        self.assertTrue(self.other.exists())
        info = SIGNING.read_plist(self.app / "Info.plist")
        self.assertNotIn("KometShareAppGroup", info)
        self.assertFalse(info["KometShareExtensionEnabled"])
        self.assertEqual(info["CFBundleIdentifier"], plan.app.bundle_id)
        self.assertEqual(info["CFBundleURLTypes"][0]["CFBundleURLName"], plan.app.bundle_id)
        self.assertEqual(info["CFBundleURLTypes"][1]["CFBundleURLName"], "unrelated")
        self.assertEqual(info["CFBundleVersion"], "22")
        self.assertEqual((self.app / "embedded.mobileprovision").read_bytes(), b"synthetic app profile")

    def test_enabled_extension_uses_separate_profile_and_matching_group(self):
        plan = SIGNING.create_plan(profile(groups=["group.synthetic.shared"]), profile("example.synthetic.app.ShareExtension", ["group.synthetic.shared"]))
        result = SIGNING.prepare_app(self.app, plan, self.app_profile_path, self.share_profile_path)
        self.assertEqual(result, self.share)
        self.assertTrue(self.other.exists())
        app_info = SIGNING.read_plist(self.app / "Info.plist")
        share_info = SIGNING.read_plist(self.share / "Info.plist")
        self.assertTrue(app_info["KometShareExtensionEnabled"])
        self.assertEqual(app_info["KometShareAppGroup"], plan.group)
        self.assertEqual(share_info["KometShareAppGroup"], plan.group)
        self.assertEqual(share_info["CFBundleIdentifier"], plan.share.bundle_id)
        self.assertEqual((self.share / "embedded.mobileprovision").read_bytes(), b"synthetic extension profile")

    def test_signs_nested_binaries_then_extension_then_app_with_distinct_entitlements(self):
        framework = self.app / "Frameworks/Synthetic.framework"
        framework.mkdir(parents=True)
        nested = self.share / "Frameworks/Synthetic.dylib"
        nested.parent.mkdir()
        nested.write_bytes(b"synthetic binary")
        plan = SIGNING.create_plan(profile(groups=["group.synthetic.shared"]), profile("example.synthetic.app.ShareExtension", ["group.synthetic.shared"]))
        calls = []
        entitlements = {}

        def capture(command, **options):
            calls.append(command)
            self.assertTrue(options["check"])
            if "--entitlements" in command:
                path = command[command.index("--entitlements") + 1]
                entitlements[command[-1]] = SIGNING.read_plist(path)

        SIGNING.sign_bundles(self.app, self.share, plan, "Synthetic Identity With Spaces", self.root / "synthetic.keychain", run=capture)
        self.assertEqual(calls[-3][-1], str(self.share))
        self.assertEqual(calls[-2][-1], str(self.app))
        self.assertEqual(calls[-1], ["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(self.app)])
        self.assertEqual(entitlements[str(self.share)], plan.share.entitlements)
        self.assertEqual(entitlements[str(self.app)], plan.app.entitlements)
        self.assertEqual({command[-1] for command in calls[:-3]}, {str(framework), str(nested)})
        for command in calls[:-1]:
            self.assertEqual(command[command.index("--sign") + 1], "Synthetic Identity With Spaces")

    def test_missing_extension_fails_before_modifying_host(self):
        plan = SIGNING.create_plan(profile(groups=["group.synthetic.shared"]), profile("example.synthetic.app.ShareExtension", ["group.synthetic.shared"]))
        (self.share / "Info.plist").unlink()
        self.share.rmdir()
        before = (self.app / "Info.plist").read_bytes()
        with self.assertRaises(SIGNING.SigningPlanError):
            SIGNING.prepare_app(self.app, plan, self.app_profile_path, self.share_profile_path)
        self.assertEqual((self.app / "Info.plist").read_bytes(), before)


if __name__ == "__main__":
    unittest.main()

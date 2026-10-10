import argparse
from dataclasses import dataclass
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


class SigningPlanError(ValueError):
    pass


@dataclass(frozen=True)
class ProfileIdentity:
    bundle_id: str
    team_id: str
    entitlements: dict


@dataclass(frozen=True)
class SigningPlan:
    app: ProfileIdentity
    share: ProfileIdentity | None
    group: str | None


def profile_identity(profile):
    entitlements = profile.get("Entitlements")
    if not isinstance(entitlements, dict):
        raise SigningPlanError("Provisioning profile has no entitlements")
    identifier = entitlements.get("application-identifier")
    if not isinstance(identifier, str) or "." not in identifier or "*" in identifier:
        raise SigningPlanError("App Store signing requires an explicit application identifier")
    prefix, bundle_id = identifier.split(".", 1)
    prefixes = profile.get("ApplicationIdentifierPrefix", [])
    if not prefix or not bundle_id or prefix not in prefixes:
        raise SigningPlanError("Application identifier does not match its profile prefix")
    team = entitlements.get("com.apple.developer.team-identifier")
    if not isinstance(team, str) or team not in profile.get("TeamIdentifier", []):
        raise SigningPlanError("Provisioning profile has an inconsistent development team")
    return ProfileIdentity(bundle_id, team, dict(entitlements))


def profile_groups(identity):
    values = identity.entitlements.get("com.apple.security.application-groups", [])
    if not isinstance(values, list):
        raise SigningPlanError("Provisioning profile has invalid App Groups")
    return {value for value in values if isinstance(value, str) and value.startswith("group.") and "*" not in value}


def create_plan(app_profile, share_profile=None, preferred_group=None):
    app = profile_identity(app_profile)
    if share_profile is None:
        return SigningPlan(app, None, None)
    share = profile_identity(share_profile)
    if app.team_id != share.team_id:
        raise SigningPlanError("App and Share Extension profiles must belong to the same team")
    if not share.bundle_id.startswith(app.bundle_id + "."):
        raise SigningPlanError("Share Extension bundle identifier must be nested under the app identifier")
    groups = profile_groups(app) & profile_groups(share)
    if not groups:
        raise SigningPlanError("App and Share Extension profiles must allow a common explicit App Group")
    group = preferred_group if preferred_group in groups else sorted(groups)[0]
    return SigningPlan(app, share, group)


def read_plist(path):
    with Path(path).open("rb") as source:
        return plistlib.load(source)


def write_plist(path, value):
    with Path(path).open("wb") as output:
        plistlib.dump(value, output, sort_keys=False)


def prepare_app(app_path, plan, app_profile_path, share_profile_path=None):
    app_path = Path(app_path)
    app_info_path = app_path / "Info.plist"
    app_info = read_plist(app_info_path)
    share_path = app_path / "PlugIns" / "ShareExtension.appex"
    if plan.share is not None:
        if not share_path.is_dir() or share_profile_path is None:
            raise SigningPlanError("The app does not contain the configured Share Extension")
        share_info_path = share_path / "Info.plist"
        share_info = read_plist(share_info_path)
        share_info["CFBundleIdentifier"] = plan.share.bundle_id
        share_info["KometShareAppGroup"] = plan.group
        write_plist(share_info_path, share_info)
        shutil.copyfile(share_profile_path, share_path / "embedded.mobileprovision")
        app_info["KometShareAppGroup"] = plan.group
        app_info["KometShareExtensionEnabled"] = True
    else:
        if share_path.is_dir():
            shutil.rmtree(share_path)
        app_info.pop("KometShareAppGroup", None)
        app_info["KometShareExtensionEnabled"] = False
    previous_id = app_info.get("CFBundleIdentifier")
    app_info["CFBundleIdentifier"] = plan.app.bundle_id
    for url_type in app_info.get("CFBundleURLTypes", []):
        if url_type.get("CFBundleURLName") in {previous_id, "$(PRODUCT_BUNDLE_IDENTIFIER)"}:
            url_type["CFBundleURLName"] = plan.app.bundle_id
    write_plist(app_info_path, app_info)
    shutil.copyfile(app_profile_path, app_path / "embedded.mobileprovision")
    return share_path if plan.share else None


def load_profile(path):
    result = subprocess.run(["security", "cms", "-D", "-i", str(path)], check=True, capture_output=True)
    return plistlib.loads(result.stdout)


def sign_bundles(app_path, share_path, plan, identity, keychain, run=subprocess.run):
    app_path = Path(app_path)
    with tempfile.TemporaryDirectory(prefix="komet-appstore-signing-") as directory:
        directory = Path(directory)
        common = ["codesign", "--force", "--sign", identity, "--keychain", str(keychain)]
        roots = [app_path / "Frameworks"]
        if share_path is not None:
            roots.append(Path(share_path) / "Frameworks")
        nested = set()
        for root in roots:
            if root.is_dir():
                nested.update(root.rglob("*.framework"))
                nested.update(root.rglob("*.dylib"))
        for bundle in sorted(nested, key=lambda path: (-len(path.parts), str(path))):
            run([*common, str(bundle)], check=True)
        if plan.share is not None:
            share_entitlements = directory / "share.entitlements"
            write_plist(share_entitlements, plan.share.entitlements)
            run([*common, "--entitlements", str(share_entitlements), str(share_path)], check=True)
        app_entitlements = directory / "app.entitlements"
        write_plist(app_entitlements, plan.app.entitlements)
        run([*common, "--entitlements", str(app_entitlements), str(app_path)], check=True)
        run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app_path)], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("app", type=Path)
    parser.add_argument("--app-profile", type=Path, required=True)
    parser.add_argument("--share-profile", type=Path)
    parser.add_argument("--identity", required=True)
    parser.add_argument("--keychain", type=Path, required=True)
    args = parser.parse_args()
    app_profile = load_profile(args.app_profile)
    share_profile = load_profile(args.share_profile) if args.share_profile else None
    plan = create_plan(app_profile, share_profile, read_plist(args.app / "Info.plist").get("KometShareAppGroup"))
    share_path = prepare_app(args.app, plan, args.app_profile, args.share_profile)
    if plan.share is None:
        print("::notice::APPSTORE_SHARE_PROVISION_PROFILE_BASE64 is not set; building the app without Share Extension")
    sign_bundles(args.app, share_path, plan, args.identity, args.keychain)


if __name__ == "__main__":
    main()

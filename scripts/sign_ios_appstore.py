import argparse
from dataclasses import dataclass
from fnmatch import fnmatchcase
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile


PROFILE_KEYS = (
    "application-identifier",
    "com.apple.developer.team-identifier",
    "get-task-allow",
    "beta-reports-active",
)
APP_GROUPS = "com.apple.security.application-groups"
BUILD_VARIABLE = re.compile(r"\$\(([A-Za-z0-9_]+)\)")


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
    app_entitlements: dict
    share_entitlements: dict | None


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


def expand(value, variables):
    if isinstance(value, str):
        def resolve(match):
            name = match.group(1)
            if name not in variables:
                raise SigningPlanError(f"Unknown build variable $({name}) in entitlements")
            return variables[name]
        return BUILD_VARIABLE.sub(resolve, value)
    if isinstance(value, list):
        return [expand(item, variables) for item in value]
    if isinstance(value, dict):
        return {key: expand(item, variables) for key, item in value.items()}
    return value


def granted_by(value, granted):
    if granted == "*":
        return True
    if isinstance(value, list):
        return all(granted_by(item, granted) for item in value)
    if isinstance(granted, list):
        return any(granted_by(value, item) for item in granted)
    if isinstance(value, str) and isinstance(granted, str):
        return fnmatchcase(value, granted)
    return value == granted


def contains_wildcard(value):
    if isinstance(value, str):
        return "*" in value
    if isinstance(value, list):
        return any(contains_wildcard(item) for item in value)
    if isinstance(value, dict):
        return any(contains_wildcard(item) for item in value.values())
    return False


def signing_entitlements(identity, requested, group):
    granted = identity.entitlements
    variables = {
        "AppIdentifierPrefix": f"{identity.team_id}.",
        "TeamIdentifierPrefix": f"{identity.team_id}.",
        "PRODUCT_BUNDLE_IDENTIFIER": identity.bundle_id,
        "KOMET_SHARE_APP_GROUP": group or "",
    }
    result = {key: granted[key] for key in PROFILE_KEYS if key in granted}
    for key, value in expand(requested, variables).items():
        if key in PROFILE_KEYS:
            continue
        if key == APP_GROUPS and group is None:
            continue
        if key not in granted or not granted_by(value, granted[key]):
            raise SigningPlanError(f"Provisioning profile does not allow entitlement {key}={value!r}")
        if contains_wildcard(value):
            raise SigningPlanError(f"Entitlement {key} must not contain a wildcard")
        result[key] = value
    return result


def create_plan(app_profile, share_profile=None, preferred_group=None, app_requested=None, share_requested=None):
    app = profile_identity(app_profile)
    if share_profile is None:
        return SigningPlan(app, None, None, signing_entitlements(app, app_requested or {}, None), None)
    share = profile_identity(share_profile)
    if app.team_id != share.team_id:
        raise SigningPlanError("App and Share Extension profiles must belong to the same team")
    if not share.bundle_id.startswith(app.bundle_id + "."):
        raise SigningPlanError("Share Extension bundle identifier must be nested under the app identifier")
    groups = profile_groups(app) & profile_groups(share)
    if not groups:
        raise SigningPlanError("App and Share Extension profiles must allow a common explicit App Group")
    group = preferred_group if preferred_group in groups else sorted(groups)[0]
    return SigningPlan(
        app,
        share,
        group,
        signing_entitlements(app, app_requested or {}, group),
        signing_entitlements(share, share_requested or {}, group),
    )


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
            write_plist(share_entitlements, plan.share_entitlements)
            run([*common, "--entitlements", str(share_entitlements), str(share_path)], check=True)
        app_entitlements = directory / "app.entitlements"
        write_plist(app_entitlements, plan.app_entitlements)
        run([*common, "--entitlements", str(app_entitlements), str(app_path)], check=True)
        run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app_path)], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("app", type=Path)
    parser.add_argument("--app-profile", type=Path, required=True)
    parser.add_argument("--share-profile", type=Path)
    parser.add_argument("--app-entitlements", type=Path, required=True)
    parser.add_argument("--share-entitlements", type=Path)
    parser.add_argument("--identity", required=True)
    parser.add_argument("--keychain", type=Path, required=True)
    args = parser.parse_args()
    app_profile = load_profile(args.app_profile)
    share_profile = load_profile(args.share_profile) if args.share_profile else None
    plan = create_plan(
        app_profile,
        share_profile,
        read_plist(args.app / "Info.plist").get("KometShareAppGroup"),
        read_plist(args.app_entitlements),
        read_plist(args.share_entitlements) if args.share_entitlements else None,
    )
    share_path = prepare_app(args.app, plan, args.app_profile, args.share_profile)
    if plan.share is None:
        print("::notice::APPSTORE_SHARE_PROVISION_PROFILE_BASE64 is not set; building the app without Share Extension")
    sign_bundles(args.app, share_path, plan, args.identity, args.keychain)


if __name__ == "__main__":
    main()

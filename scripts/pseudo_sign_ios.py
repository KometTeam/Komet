import pathlib
import plistlib
import subprocess
import sys
import tempfile

app = pathlib.Path(sys.argv[1]).resolve()
with (app / "Info.plist").open("rb") as source:
    app_info = plistlib.load(source)
group = app_info["KometShareAppGroup"]


def sign_bundle(bundle, entitlements):
    with (bundle / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    entitlements["application-identifier"] = info["CFBundleIdentifier"]
    with tempfile.NamedTemporaryFile(suffix=".plist") as target:
        plistlib.dump(entitlements, target)
        target.flush()
        subprocess.run(
            ["ldid", "-S" + target.name, str(bundle / info["CFBundleExecutable"])],
            check=True,
        )


for dylib in app.rglob("*.dylib"):
    subprocess.run(["ldid", "-S", str(dylib)], check=True)
for framework in app.rglob("*.framework"):
    binary = framework / framework.stem
    if binary.is_file():
        subprocess.run(["ldid", "-S", str(binary)], check=True)
for extension in (app / "PlugIns").glob("*.appex"):
    sign_bundle(extension, {"com.apple.security.application-groups": [group]})
sign_bundle(app, {
    "get-task-allow": True,
    "keychain-access-groups": [app_info["CFBundleIdentifier"]],
    "com.apple.security.application-groups": [group],
})

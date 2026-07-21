project    := "iPadAudio.xcodeproj"
scheme     := "iPadAudio"
bundle_id  := "com.dantanner.iPadAudio"
sim        := "iPad (A16)"
ipad       := env_var_or_default("IPAD", "")

# App Store Connect API key for `just release`. The key ID matches the
# AuthKey_<id>.p8 file in ~/.appstoreconnect/private_keys/; the issuer ID is
# shown at App Store Connect → Users & Access → Integrations. Neither is secret.
asc_key_id    := "22G36YCBG2"
asc_issuer_id := "b3f91fba-032a-4b10-b703-41d2ff812b78"

# List available recipes
default:
    @just --list

# Regenerate the Xcode project from project.yml
generate:
    xcodegen generate

# Print the UDID of the first paired iPad (or IPAD=<name-or-udid> override)
_udid:
    #!/usr/bin/env bash
    set -euo pipefail
    dev="{{ipad}}"
    if [ -z "$dev" ]; then
        json=$(mktemp)
        xcrun devicectl list devices --json-output "$json" >/dev/null
        # First paired iPad whose tunnel isn't unavailable — devicectl brings
        # the tunnel up on demand, so "disconnected" still deploys over Wi-Fi.
        dev=$(python3 -c "import json; ds=json.load(open('$json'))['result']['devices']; ok=lambda d: d.get('hardwareProperties',{}).get('productType','').startswith('iPad') and d.get('connectionProperties',{}).get('pairingState')=='paired' and d.get('connectionProperties',{}).get('tunnelState')!='unavailable'; print(next((d['hardwareProperties']['udid'] for d in ds if ok(d)), ''))")
        rm -f "$json"
    fi
    if [ -z "$dev" ]; then
        echo "No paired iPad reachable. Is the iPad awake and on the same Wi-Fi? Run 'just devices' to inspect, or IPAD=<name-or-udid> just deploy" >&2
        exit 1
    fi
    echo "$dev"

# Build for the connected iPad
build: generate
    xcodebuild -project {{project}} -scheme {{scheme}} \
        -destination "generic/platform=iOS" \
        -derivedDataPath build/dd-device \
        -allowProvisioningUpdates \
        build

# Install the built app on the connected iPad
install:
    #!/usr/bin/env bash
    set -euo pipefail
    dev=$(just _udid)
    xcrun devicectl device install app --device "$dev" \
        "build/dd-device/Build/Products/Debug-iphoneos/{{scheme}}.app"

# Launch the app on the connected iPad
launch:
    #!/usr/bin/env bash
    set -euo pipefail
    dev=$(just _udid)
    xcrun devicectl device process launch --device "$dev" {{bundle_id}}

# Build, install, and launch on the connected iPad (auto-discovers it; or IPAD=<name-or-udid> just deploy)
deploy: build install launch

# Build, install, and launch in the simulator (mic input is limited — use `just deploy` for real audio testing)
run: generate
    #!/usr/bin/env bash
    set -euo pipefail
    xcodebuild -project {{project}} -scheme {{scheme}} \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath build/dd-sim \
        build
    open -a Simulator
    xcrun simctl boot "{{sim}}" 2>/dev/null || true
    app="build/dd-sim/Build/Products/Debug-iphonesimulator/{{scheme}}.app"
    xcrun simctl install booted "$app"
    xcrun simctl launch booted {{bundle_id}}

# Stream the app's logs from the booted simulator
logs:
    xcrun simctl spawn booted log stream --level debug \
        --predicate 'subsystem CONTAINS "{{bundle_id}}"'

# Run the test suite on the simulator
test: generate
    xcodebuild -project {{project}} -scheme {{scheme}} \
        -destination "platform=iOS Simulator,name={{sim}}" \
        test

# List connected physical devices and their UDIDs
devices:
    xcrun devicectl list devices

# Screenshot the booted simulator into screenshots/<name>.png
shot name:
    @mkdir -p screenshots
    xcrun simctl io booted screenshot screenshots/{{name}}.png

# Bump the version, archive, and upload to App Store Connect, then commit and tag
release kind: test
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{kind}}" in major|minor|bugfix) ;; *)
        echo "usage: just release <major|minor|bugfix>"; exit 1 ;;
    esac
    if [ -z "{{asc_issuer_id}}" ]; then
        echo "Missing App Store Connect issuer ID: set asc_issuer_id in the justfile"
        echo "or ASC_ISSUER_ID in the environment. It's shown at App Store Connect →"
        echo "Users & Access → Integrations → App Store Connect API."
        exit 1
    fi
    key_path="$HOME/.appstoreconnect/private_keys/AuthKey_{{asc_key_id}}.p8"
    if [ ! -f "$key_path" ]; then
        echo "API key not found at $key_path"; exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
        echo "Working tree is dirty — commit or stash before releasing."; exit 1
    fi
    version=$(python3 - {{kind}} <<'EOF'
    import re, sys
    kind = sys.argv[1]
    yml = open("project.yml").read()
    major, minor, patch = (int(x) for x in re.search(r'MARKETING_VERSION: "([\d.]+)"', yml).group(1).split("."))
    if kind == "major": major, minor, patch = major + 1, 0, 0
    elif kind == "minor": minor, patch = minor + 1, 0
    else: patch += 1
    version = f"{major}.{minor}.{patch}"
    build = int(re.search(r'CURRENT_PROJECT_VERSION: "(\d+)"', yml).group(1)) + 1
    yml = re.sub(r'MARKETING_VERSION: "[\d.]+"', f'MARKETING_VERSION: "{version}"', yml)
    yml = re.sub(r'CURRENT_PROJECT_VERSION: "\d+"', f'CURRENT_PROJECT_VERSION: "{build}"', yml)
    open("project.yml", "w").write(yml)
    print(version)
    EOF
    )
    echo "Releasing $version"
    xcodegen generate
    xcodebuild -project {{project}} -scheme {{scheme}} \
        -destination "generic/platform=iOS" \
        -archivePath build/release/{{scheme}}.xcarchive \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$key_path" \
        -authenticationKeyID {{asc_key_id}} \
        -authenticationKeyIssuerID {{asc_issuer_id}} \
        archive
    xcodebuild -exportArchive \
        -archivePath build/release/{{scheme}}.xcarchive \
        -exportOptionsPlist ExportOptions.plist \
        -exportPath build/release/export \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$key_path" \
        -authenticationKeyID {{asc_key_id}} \
        -authenticationKeyIssuerID {{asc_issuer_id}}
    git commit -am "Release $version"
    git tag "v$version"
    git push origin HEAD "v$version"
    echo "Uploaded $version to App Store Connect; committed, tagged, and pushed v$version."

# Open the project in Xcode
open: generate
    open {{project}}

# Remove build artifacts
clean:
    rm -rf build

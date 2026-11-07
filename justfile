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
        # First physical, paired iPad whose tunnel isn't unavailable — devicectl
        # also lists simulators (reality "simulated"), and brings the tunnel up on
        # demand, so "disconnected" still deploys over Wi-Fi.
        dev=$(python3 -c "import json; ds=json.load(open('$json'))['result']['devices']; ok=lambda d: d.get('hardwareProperties',{}).get('productType','').startswith('iPad') and d.get('hardwareProperties',{}).get('reality')!='simulated' and d.get('connectionProperties',{}).get('pairingState')=='paired' and d.get('connectionProperties',{}).get('tunnelState')!='unavailable'; print(next((d['hardwareProperties']['udid'] for d in ds if ok(d)), ''))")
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
    # DeviceHub (Xcode 27+) is the app that shows simulators.
    open -b com.apple.dt.Devices
    xcrun simctl boot "{{sim}}" 2>/dev/null || true
    app="build/dd-sim/Build/Products/Debug-iphonesimulator/{{scheme}}.app"
    # Target {{sim}} by name, not "booted", so another running simulator
    # can't catch the install.
    xcrun simctl install "{{sim}}" "$app"
    xcrun simctl launch "{{sim}}" {{bundle_id}}

# Stream the app's logs from the simulator
logs:
    xcrun simctl spawn "{{sim}}" log stream --level debug \
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

# Run SwiftLint (strict: warnings fail too)
lint:
    swiftlint lint --strict --quiet

# Run tests, lint, and build — the same checks the pre-commit hook runs
check: test lint build

# Install a git pre-commit hook that runs `just check` before each commit
install-hooks:
    #!/usr/bin/env bash
    set -euo pipefail
    # --git-path resolves the hooks dir from a worktree too.
    hook="$(git rev-parse --git-path hooks)/pre-commit"
    mkdir -p "$(dirname "$hook")"
    printf '#!/bin/sh\nexec just check\n' > "$hook"
    chmod +x "$hook"
    echo "Installed pre-commit hook: $hook"

# Bump the version, archive, and upload to App Store Connect, then commit and tag
release kind: test lint
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
    # A release must be cut from an up-to-date main; anything else (an unmerged
    # branch, a stale checkout) would ship and tag code that main doesn't have.
    git fetch origin main --tags --quiet
    if ! git merge-base --is-ancestor origin/main HEAD; then
        echo "HEAD is not a fast-forward of origin/main; a release must be cut from main." >&2
        echo "  HEAD:        $(git rev-parse --short HEAD)" >&2
        echo "  origin/main: $(git rev-parse --short origin/main)" >&2
        exit 1
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

    # Release notes from the commits since the last release go in the tag's
    # annotation (read them with `git show v<version>`).
    prev_tag=$(git describe --tags --abbrev=0 --match 'v*' HEAD~1 2>/dev/null || echo "")
    if [ -n "$prev_tag" ]; then
        commit_log=$(git log "${prev_tag}..HEAD~1" --oneline --no-merges)
    else
        commit_log=$(git log HEAD~1 --oneline --no-merges -20)
    fi
    notes_file=$(mktemp)
    trap 'rm -f "$notes_file"' EXIT
    prompt="Generate concise release notes for version $version of iPad Audio (an iPad app for visualizing pitch and sound).
    Here are the commits since ${prev_tag:-the beginning}:

    ${commit_log}

    Guidelines:
    - Group related commits into a single bullet point
    - Focus on user-facing changes, not implementation details
    - Skip version bumps, tooling changes, and purely internal refactors
    - Keep each bullet to one line, use past tense
    - Output only a bullet list (- item), nothing else"
    if command -v claude &>/dev/null && claude -p "$prompt" > "$notes_file" 2>/dev/null && [ -s "$notes_file" ]; then
        echo "Release notes (generated by Claude):"
    else
        echo "$commit_log" | sed 's/^[0-9a-f]* /- /' > "$notes_file"
        echo "Release notes (from commit log):"
    fi
    cat "$notes_file"

    git tag -a "v$version" -F "$notes_file"
    # Named refs rather than the branch's upstream, so this behaves the same
    # from the main checkout, a worktree, or any branch name.
    git push origin HEAD:main
    git push origin "refs/tags/v$version"
    echo "Uploaded $version to App Store Connect; committed, tagged, and pushed v$version."

# Open the project in Xcode
open: generate
    open {{project}}

# Remove build artifacts
clean:
    rm -rf build

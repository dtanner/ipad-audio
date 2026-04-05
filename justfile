# iPadAudio project commands
# Requires: Xcode, just (https://github.com/casey/just)

scheme := "iPadAudio"
bundle_id := "com.dantanner.iPadAudio"

# Auto-detect the first connected physical iPad device ID
device_id := `xcrun xctrace list devices 2>/dev/null | grep -i 'ipad.*(' | grep -v Simulator | head -1 | sed 's/.*(\([^)]*\))$/\1/' || echo "NO_DEVICE_FOUND"`

# List available commands
default:
    @just --list

# Open project in Xcode
open:
    open iPadAudio.xcodeproj

# List connected devices
devices:
    xcrun xctrace list devices

# Build for connected iPad
build:
    xcodebuild -scheme {{ scheme }} -destination 'id={{ device_id }}' build

# Install the built app on connected iPad
install:
    #!/usr/bin/env bash
    set -euo pipefail
    APP_PATH=$(xcodebuild -scheme {{ scheme }} -showBuildSettings 2>/dev/null | grep -m1 'CODESIGNING_FOLDER_PATH' | awk '{print $3}')
    xcrun devicectl device install app --device {{ device_id }} "$APP_PATH"

# Launch the app on connected iPad
launch:
    xcrun devicectl device process launch --device {{ device_id }} {{ bundle_id }}

# Build, install, and launch on connected iPad
deploy: build install launch

# Run tests in simulator
test:
    xcodebuild -scheme {{ scheme }} -destination 'platform=iOS Simulator,name=iPad Air' test

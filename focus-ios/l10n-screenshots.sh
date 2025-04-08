#!/bin/bash

set -ex


function get_abs_path {
    local file_path="$1"
    echo "$( cd "$(dirname "$file_path")" >/dev/null 2>&1 ; pwd -P )"
}

CURRENT_DIR="$(get_abs_path $0)"
PROJECT_DIR="$(get_abs_path $CURRENT_DIR/../../../..)"

if [ -d l10n-screenshots ]; then
    echo "The l10n-screenshots directory already exists. You decide."
    exit 1
fi


mkdir -p l10n-screenshots

if [ "$1" = '--test-without-building' ]; then
    EXTRA_FAST_LANE_ARGS='--test_without_building'
    shift
fi

LOCALES=$*
if [ $# -eq 0 ]; then
    echo "Please provide locales to test. Available locales live in 'l10n-screenshots-config.yml'. E.g.: $0 af an anp ar"
    exit 1
fi

DEVICE="iPhone 16"
IOS_VERSION="iOS 18.3.1"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-18-3"

# Create and boot the simulator
SIMULATOR_ID=$(xcrun simctl create "$DEVICE $IOS_VERSION" "$DEVICE" "$RUNTIME")
xcrun simctl boot "$SIMULATOR_ID"

for lang in $LOCALES; do
    # start simple with Focus only
    echo "Snapshotting on $DEVICE $IOS_VERSION"
    mkdir -p "l10n-screenshots/$lang"
    fastlane snapshot --project focus-ios/Blockzilla.xcodeproj --scheme "FocusSnapshotTests" \
      --derived_data_path l10n-screenshots-dd \
      --number_of_retries 0 \
      --concurrent_simulators false \
      --skip_open_summary \
      --xcargs "-maximum-parallel-testing-workers 1" \
      --erase_simulator --localize_simulator \
      --devices "$SIMULATOR_ID" \
      --languages "$lang" \
      --output_directory "l10n-screenshots/$lang" \
      $EXTRA_FAST_LANE_ARGS
    echo "Fastlane exited with code: $?"
done

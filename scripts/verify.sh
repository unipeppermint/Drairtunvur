#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift test --package-path Packages/LightworksCore --scratch-path /tmp/lightworks-core-build
xcodebuild -project Drairtunvur.xcodeproj -scheme Drairtunvur \
  -destination "${LIGHTWORKS_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}" \
  -derivedDataPath /tmp/lightworks-verification CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO test

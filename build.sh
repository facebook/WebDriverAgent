if [ -z $1 ]; then
  echo "usage: build.sh <subcommand>"
  echo "available subcommands:"
  echo "  ci"
  exit
fi

set -eu

MODE=$1

function ci() {
  xctool \
      -workspace WebDriverAgent.xcworkspace \
      -scheme $1 \
      -sdk $2 \
      $3 \
      CODE_SIGN_IDENTITY="" \
      CODE_SIGNING_REQUIRED=NO
}

if [ "$MODE" = "ci" ]; then
  ci WebDriverAgent iphonesimulator build
  ci XCTStubAppIOS iphonesimulator build-tests
  ci XCTStubAppIOS iphoneos build-tests
  ci XCTStubAppOSX macosx build-tests
  ci XCTStubAppTV appletvsimulator build-tests
  ci XCTStubAppTV appletvos build-tests
fi

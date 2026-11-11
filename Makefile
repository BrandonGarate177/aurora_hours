# Build, test and run Hours. Each target regenerates the Xcode project first,
# so a new file under Hours/ or HoursTests/ is picked up without editing anything.

PROJECT  := Hours.xcodeproj
SCHEME   := Hours
DERIVED  := build
APP      := $(DERIVED)/Build/Products/Debug/Hours.app
XCB      := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
            -derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=$(shell uname -m)' \
            CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO

.PHONY: project build test run clean

project:
	xcodegen generate --quiet

build: project
	$(XCB) build -quiet

test: project
	$(XCB) test -quiet

run: build
	@pkill -x Hours || true
	open $(APP)

clean:
	rm -rf $(DERIVED) $(PROJECT)

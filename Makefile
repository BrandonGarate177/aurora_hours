# Build, test and run Hours. Each target regenerates the Xcode project first,
# so a new file under Hours/ or HoursTests/ is picked up without editing anything.

PROJECT  := Hours.xcodeproj
SCHEME   := Hours
DERIVED  := build
APP      := $(DERIVED)/Build/Products/Debug/Hours.app
BIN      := $(CURDIR)/$(APP)/Contents/MacOS/Hours
PIDFILE  := $(DERIVED)/hours.pid
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

# Stops only the copy this checkout's last `make run` started (its pid is in
# build/hours.pid), so copies other checkouts run keep running. The binary is
# started directly so HOURS_STORE reaches it. Its output goes to build/hours.log.
run: build
	@pid=$$(cat $(PIDFILE) 2>/dev/null); \
	if [ -n "$$pid" ] && ps -p $$pid -o command= | grep -qF '$(BIN)'; then \
		kill $$pid; while kill -0 $$pid 2>/dev/null; do sleep 0.1; done; \
	fi
	@nohup '$(BIN)' > $(DERIVED)/hours.log 2>&1 & echo $$! > $(PIDFILE)

clean:
	rm -rf $(DERIVED) $(PROJECT)

# Build, test and run Hours. Each target regenerates the Xcode project first,
# so a new file under Hours/ or HoursTests/ is picked up without editing anything.

PROJECT  := Hours.xcodeproj
SCHEME   := Hours
DERIVED  := build
APP      := $(DERIVED)/Build/Products/Debug/Hours.app
BIN      := $(CURDIR)/$(APP)/Contents/MacOS/Hours
PIDFILE  := $(DERIVED)/hours.pid

# Signing. Ad hoc by default, with the app group group.com.hoursapp.Hours.
# macOS won't let an ad hoc signed widget read that group's container, so the
# widget draws an empty map. TEAM=<team id> signs with that team's Apple
# Development identity and the group <team id>.com.hoursapp.Hours, which
# macOS allows without a provisioning profile:
#   make run TEAM=<your team id>
ifeq ($(TEAM),)
SIGNING  := CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
ENTITLEMENTS :=
else
SIGNING  := CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=$(TEAM) \
            HOURS_ENTITLEMENTS=$(CURDIR)/$(DERIVED)/entitlements
ENTITLEMENTS := entitlements
endif

XCB      := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
            -derivedDataPath $(DERIVED) -destination 'platform=macOS,arch=$(shell uname -m)' \
            $(SIGNING)

.PHONY: project entitlements build test run seed clean

project:
	xcodegen generate --quiet

# Team-prefixed copies of Entitlements/, for TEAM builds.
entitlements:
	@mkdir -p $(DERIVED)/entitlements
	@for f in Entitlements/*.entitlements; do \
		sed 's/group\.com\.hoursapp\.Hours/$(TEAM).com.hoursapp.Hours/' $$f > $(DERIVED)/entitlements/$$(basename $$f); \
	done

build: project $(ENTITLEMENTS)
	$(XCB) build -quiet

test: project $(ENTITLEMENTS)
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

# A year of made-up sessions in the store at HOURS_STORE, to see the map:
#   HOURS_STORE=/tmp/hours-seed.json make seed run
seed:
	@test -n "$(HOURS_STORE)" || { echo "seed: set HOURS_STORE=/path/store.json"; exit 2; }
	swift scripts/seed.swift "$(HOURS_STORE)"

clean:
	rm -rf $(DERIVED) $(PROJECT)

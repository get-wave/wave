APP_NAME := Wave
PROJECT := Wave.xcodeproj
SCHEME := Wave
CONFIGURATION := Release
DERIVED_DATA := $(CURDIR)/build
PRODUCTS_DIR := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)
APP_BUNDLE := $(PRODUCTS_DIR)/$(APP_NAME).app
DEBUG_PRODUCTS_DIR := $(DERIVED_DATA)/Build/Products/Debug
DEBUG_APP_BUNDLE := $(DEBUG_PRODUCTS_DIR)/$(APP_NAME).app
STAGING_DIR := $(CURDIR)/dmg-staging
DMG_NAME ?= Wave-Installer
DMG_PATH := $(CURDIR)/$(DMG_NAME).dmg
UPDATES_DIR := $(CURDIR)/updates/releases
APP_ZIP := $(UPDATES_DIR)/$(APP_NAME).zip
LOCAL_SIGN_IDENTITY ?= Wave Local Dev
GENERATE_APPCAST := $(shell command -v generate_appcast 2>/dev/null || find "$(HOME)/Library/Developer/Xcode/DerivedData" -type f -name generate_appcast 2>/dev/null | head -n 1)

.PHONY: all build build-debug run run-cli install-local release dmg zip appcast clean clean-dmg

all: build

build: $(APP_BUNDLE)

$(APP_BUNDLE):
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		build

## build-debug: build the app with the Debug configuration
build-debug:
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		-derivedDataPath "$(DERIVED_DATA)" \
		build

## run: build (Debug) and launch the app
run: build-debug
	open "$(DEBUG_APP_BUNDLE)"

## run-cli: build (Debug) and run the binary in the terminal (logs to stdout, Ctrl+C to quit)
run-cli: build-debug
	"$(DEBUG_APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"

## install-local: build Release, sign with the local certificate, install to /Applications and launch
## Signing with a stable certificate keeps Accessibility and Microphone permissions across rebuilds.
install-local:
	@security find-identity -p codesigning | grep -q "$(LOCAL_SIGN_IDENTITY)" || { \
		echo "error: signing identity '$(LOCAL_SIGN_IDENTITY)' not found. See CONTRIBUTING.md."; \
		exit 1; \
	}
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Release \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" \
		build
	-osascript -e 'tell application id "io.monawwar.wave" to quit'
	@sleep 1
	rm -rf "/Applications/$(APP_NAME).app"
	ditto "$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	codesign --force --deep --sign "$(LOCAL_SIGN_IDENTITY)" --preserve-metadata=entitlements "/Applications/$(APP_NAME).app"
	open "/Applications/$(APP_NAME).app"

dmg: build
	@command -v create-dmg >/dev/null 2>&1 || { \
		echo "error: create-dmg not found. Install it (e.g. brew install create-dmg)."; \
		exit 1; \
	}
	rm -rf "$(STAGING_DIR)"
	mkdir -p "$(STAGING_DIR)"
	cp -R "$(APP_BUNDLE)" "$(STAGING_DIR)/"
	rm -f "$(DMG_PATH)"
	create-dmg \
		--volname "$(APP_NAME)" \
		--window-pos 200 120 \
		--window-size 640 360 \
		--icon-size 96 \
		--icon "$(APP_NAME).app" 180 170 \
		--hide-extension "$(APP_NAME).app" \
		--app-drop-link 460 170 \
		"$(DMG_PATH)" \
		"$(STAGING_DIR)"

zip: build
	mkdir -p "$(UPDATES_DIR)"
	rm -f "$(APP_ZIP)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP_BUNDLE)" "$(APP_ZIP)"

appcast: zip
	@test -n "$(GENERATE_APPCAST)" || { \
		echo "error: generate_appcast not found. Build once in Xcode after adding Sparkle, or install Sparkle tools."; \
		exit 1; \
	}
	"$(GENERATE_APPCAST)" "$(UPDATES_DIR)"

release:
	./scripts/release.sh

clean:
	rm -rf "$(DERIVED_DATA)"

clean-dmg:
	rm -rf "$(STAGING_DIR)" "$(DMG_PATH)"

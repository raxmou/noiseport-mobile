.DEFAULT_GOAL := help

PI_HOST := pi@100.64.0.4
SITE_DIR := /media/pi/8da2011b-a75c-40e1-a026-82c182a7fafd5/headscale/site/dist
APK_PATH := build/app/outputs/flutter-apk/app-release.apk

.PHONY: help install dev build-apk build-ios run run-emulator devices codegen analyze clean deploy

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# === Setup ===

install: ## Install Flutter dependencies
	flutter pub get

# === Development ===

dev: ## Run app on connected device
	flutter run

run-emulator: ## Launch Android emulator (Pixel_6_API_34)
	emulator -avd Pixel_6_API_34

devices: ## List connected devices
	adb devices

# === Build ===

build-apk: ## Build Android release APK
	flutter build apk --release

build-ios: ## Build iOS release (no codesign)
	flutter build ios --release --no-codesign

# === Code Generation ===

codegen: ## Run build_runner (required after model changes)
	dart run build_runner build --delete-conflicting-outputs

# === Quality ===

analyze: ## Run Dart static analysis
	flutter analyze

# === Cleanup ===

clean: ## Clean Flutter build artifacts
	flutter clean

# === Deploy ===

deploy: build-apk ## Build release APK and deploy to noiseport website
	scp $(APK_PATH) $(PI_HOST):/tmp/noiseport.apk
	ssh $(PI_HOST) "sudo cp /tmp/noiseport.apk $(SITE_DIR)/noiseport.apk && rm /tmp/noiseport.apk"
	@echo "APK deployed to noiseport website"

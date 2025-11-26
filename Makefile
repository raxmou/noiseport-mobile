run-emulator:
    emulator -avd Pixel_6_API_34

confirm-devices:
	adb devices

run:
	flutter run
	
build-apk:
	flutter build apk --release
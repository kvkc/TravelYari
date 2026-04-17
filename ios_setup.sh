#!/bin/bash
# iOS Setup Script for TravelYari
# Run this on a Mac after cloning the repository

set -e

echo "=========================================="
echo "TravelYari iOS Setup Script"
echo "=========================================="

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script must be run on macOS"
    exit 1
fi

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed. Install it from the App Store."
    exit 1
fi

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not installed. Install it from https://flutter.dev"
    exit 1
fi

# Check for CocoaPods
if ! command -v pod &> /dev/null; then
    echo "Installing CocoaPods..."
    sudo gem install cocoapods
fi

echo ""
echo "Step 1: Getting Flutter dependencies..."
flutter pub get

echo ""
echo "Step 2: Regenerating iOS project files..."
# Backup existing config files
cp ios/Runner/Info.plist ios/Runner/Info.plist.backup 2>/dev/null || true
cp ios/GoogleService-Info.plist ios/GoogleService-Info.plist.backup 2>/dev/null || true
cp ios/Podfile ios/Podfile.backup 2>/dev/null || true
cp ios/Runner/AppDelegate.swift ios/Runner/AppDelegate.swift.backup 2>/dev/null || true

# Regenerate iOS folder structure (creates missing xcodeproj, etc.)
# Only if Runner.xcodeproj doesn't exist
if [ ! -d "ios/Runner.xcodeproj" ]; then
    echo "Runner.xcodeproj not found, regenerating..."
    flutter create --platforms=ios .

    # Restore our custom files
    cp ios/Runner/Info.plist.backup ios/Runner/Info.plist 2>/dev/null || true
    cp ios/GoogleService-Info.plist.backup ios/GoogleService-Info.plist 2>/dev/null || true
    cp ios/Podfile.backup ios/Podfile 2>/dev/null || true
    cp ios/Runner/AppDelegate.swift.backup ios/Runner/AppDelegate.swift 2>/dev/null || true
fi

echo ""
echo "Step 3: Moving GoogleService-Info.plist to Runner folder..."
if [ -f "ios/GoogleService-Info.plist" ] && [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
    cp ios/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
    echo "Copied GoogleService-Info.plist to ios/Runner/"
fi

echo ""
echo "Step 4: Installing CocoaPods dependencies..."
cd ios
pod install --repo-update
cd ..

echo ""
echo "Step 5: Opening Xcode..."
open ios/Runner.xcworkspace

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps in Xcode:"
echo "1. Select 'Runner' target in the project navigator"
echo "2. Go to 'Signing & Capabilities' tab"
echo "3. Set your Team (Apple Developer account)"
echo "4. Set Bundle Identifier to: com.travelyari.app"
echo "5. Add capabilities: Push Notifications, Associated Domains"
echo ""
echo "To build:"
echo "  Debug:   flutter build ios --debug"
echo "  Release: flutter build ios --release"
echo "  IPA:     flutter build ipa --release"
echo ""
echo "IMPORTANT: Update GoogleService-Info.plist from Firebase Console"
echo "with bundle ID: com.travelyari.app"
echo ""

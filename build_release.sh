#!/bin/bash
# Yatra Planner - Release Build Script
# Reads API keys from .env file and builds with them

# Load .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Check if GOOGLE_MAPS_API_KEY is set
if [ -z "$GOOGLE_MAPS_API_KEY" ]; then
    echo "Warning: GOOGLE_MAPS_API_KEY not set. Building without Google Maps."
    echo "The app will use free OpenStreetMap instead."
    echo ""
fi

# Build command based on argument
case "$1" in
    "apk")
        echo "Building Android APK..."
        flutter build apk --release \
            --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY"
        ;;
    "appbundle"|"aab")
        echo "Building Android App Bundle..."
        flutter build appbundle --release \
            --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY"
        ;;
    "ios")
        echo "Building iOS..."
        flutter build ios --release \
            --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY"
        ;;
    "web")
        echo "Building Web..."
        flutter build web --release \
            --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY"
        ;;
    "run")
        echo "Running debug build..."
        flutter run \
            --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY"
        ;;
    *)
        echo "Usage: ./build_release.sh [apk|appbundle|ios|web|run]"
        echo ""
        echo "Make sure to create a .env file with your API keys."
        echo "See .env.example for the format."
        exit 1
        ;;
esac

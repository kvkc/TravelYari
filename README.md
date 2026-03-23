# Yatra Planner

A smart road trip planning app built with Flutter. Plan multi-location trips with optimized routes, day-by-day itineraries, and find amenities along the way.

## Features

- **Multi-location trips**: Add unlimited destinations with drag-to-reorder
- **Route optimization**: TSP algorithm finds the most efficient path
- **Day-by-day planning**: Automatic multi-day splitting with realistic driving limits
- **Smart stops**:
  - Break stops every ~125 km
  - Fuel/EV charging stations
  - Restaurant recommendations
  - Hotel suggestions for overnight stays
- **Hybrid map service**: Google Maps + OpenStreetMap for cost optimization
- **Share trips**: Export to Google Maps, WhatsApp, or any app
- **Washroom quality**: Prioritize stops with clean facilities

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter 3.2+ |
| State Management | Riverpod |
| Maps | Google Maps + OSM (hybrid) |
| Routing | OSRM (free) |
| Storage | Hive |

## Quick Start

### Prerequisites

- Flutter SDK 3.2.0+
- Android Studio / VS Code
- Google Maps API key (optional but recommended)

### Installation

```bash
# Clone the repository
git clone https://github.com/kvkc/TravelYari.git
cd TravelYari

# Install dependencies
flutter pub get
```

### Running the App

```bash
# Without Google Maps key (uses OSM only)
flutter run

# With Google Maps key (recommended)
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### Building for Release

```bash
# APK
flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# App Bundle (Play Store)
flutter build appbundle --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

## API Key Setup (Optional)

The app works without any API keys using free OpenStreetMap services. For better search/autocomplete, add a Google Maps key:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project and enable:
   - Maps SDK for Android
   - Places API
   - Directions API (optional)
   - Geocoding API
3. Create an API key with Android restrictions:
   - Package: `com.yatraplanner.app`
   - SHA-1 fingerprints (see below)

### Getting SHA-1 Fingerprints

```bash
# Debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android

# Release
keytool -list -v -keystore android/yatra-release.jks -alias yatra
```

## Cost Optimization

The app uses a hybrid approach to minimize API costs:

| Service | Provider | Cost |
|---------|----------|------|
| Search/Autocomplete | Google (if key) or OSM | $2.83/1000 or Free |
| Routing | OSRM | Free |
| Distance Matrix | OSRM | Free |
| Nearby Search | OSM | Free |
| Reverse Geocode | OSM | Free |

**Estimated monthly cost**: ~$25-50 for 100 users/day (vs $500+ with Google only)

## Project Structure

```
lib/
├── app/                    # App entry point
├── core/
│   ├── router/             # Navigation
│   ├── services/
│   │   ├── api_keys.dart   # Secure key injection
│   │   ├── amenities/      # Hotels, fuel, restaurants
│   │   ├── map/            # Google, OSM, unified service
│   │   ├── route/          # TSP optimization
│   │   ├── share/          # Share to WhatsApp, Maps
│   │   └── trip/           # Day planning logic
│   └── theme/              # App theming
└── features/
    ├── home/               # Trip list
    ├── location_search/    # Place autocomplete
    ├── settings/           # API keys config
    ├── shared_location/    # Deep link handling
    └── trip_planning/      # Main planning UI
        ├── models/         # Trip, Location, DayPlan
        ├── screens/        # Planning & route view
        └── widgets/        # Cards, lists, maps
```

## Key Components

### Hybrid Map Service
- **Search**: Google Places (if key) → OSM Photon fallback
- **Routing**: Always OSRM (free)
- **Nearby**: Always OSM Overpass (free)

### Route Optimization
- Nearest Neighbor heuristic for initial solution
- 2-opt optimization for improvement
- Road distance matrix via OSRM

### Day Planning
- Splits long trips into realistic daily segments
- Adds break stops every ~125 km
- Finds hotels for overnight stays
- Supports fuel and EV charging stops

## Trip Preferences

| Setting | Default | Range |
|---------|---------|-------|
| Max daily distance | 450 km | 200-700 km |
| Break interval | 125 km | 50-200 km |
| Break duration | 10 min | 5-30 min |
| Min hotel rating | 3.5 | 1-5 |
| Prefer better routes | Off | Uses Google Directions |

## Documentation

See [BUILD_GUIDE.md](BUILD_GUIDE.md) for detailed implementation guide.

## License

MIT License

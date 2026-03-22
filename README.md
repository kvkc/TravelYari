# Yatra Planner

A smart trip planning app built with Flutter for Android and iOS. Plan multi-location trips with optimized routes, find amenities along the way, and get recommendations for places with good facilities.

## Features

- **Multi-location trips**: Add as many destinations as you want
- **Shared location support**: Accept locations shared from WhatsApp, Google Maps, and other apps
- **Multiple map providers**: Google Maps, Mappls (MapMyIndia), and Bhuvan (ISRO)
- **Route optimization**: Automatically find the most efficient path through all locations
- **Smart amenity suggestions**:
  - Petrol stations and EV charging points
  - Restaurants with ratings above 4.0
  - Hotels and stay options
  - Tea/coffee stalls for short breaks
- **Washroom quality ratings**: Prioritize stops with clean facilities, especially female-friendly ones
- **Daily trip planning**:
  - 400-500 km daily driving limits
  - Break suggestions every 100-150 km
  - Overnight stay recommendations for long trips

## Setup

### Prerequisites

1. Install Flutter SDK (3.2.0 or higher)
2. Set up Android Studio / Xcode for mobile development

### API Keys

You need to obtain API keys for the following services:

1. **Google Maps Platform**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Enable Maps SDK for Android, Maps SDK for iOS, Places API, Directions API
   - Create an API key

2. **Mappls (MapMyIndia)**
   - Register at [Mappls API](https://about.mappls.com/api/)
   - Get your API key, Client ID, and Client Secret

3. **Bhuvan (ISRO)** (Optional)
   - Register at [Bhuvan Portal](https://bhuvan.nrsc.gov.in/)
   - Request API access

### Configuration

1. Update API keys in `lib/core/services/api_keys.dart`:

```dart
class ApiKeys {
  static const String googleMaps = 'YOUR_GOOGLE_MAPS_API_KEY';
  static const String mappls = 'YOUR_MAPPLS_API_KEY';
  static const String mapplsClientId = 'YOUR_MAPPLS_CLIENT_ID';
  static const String mapplsClientSecret = 'YOUR_MAPPLS_CLIENT_SECRET';
  static const String bhuvan = 'YOUR_BHUVAN_API_KEY';
}
```

2. Update Android manifest (`android/app/src/main/AndroidManifest.xml`):
   - Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual key

3. Update iOS Info.plist (`ios/Runner/Info.plist`):
   - Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual key

### Running the App

```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release
```

## Project Structure

```
lib/
├── app/                    # App configuration
├── core/
│   ├── router/            # Navigation
│   ├── services/
│   │   ├── amenities/     # Amenity finding services
│   │   ├── map/           # Map provider integrations
│   │   ├── route/         # Route optimization
│   │   └── trip/          # Trip planning logic
│   └── theme/             # App theming
└── features/
    ├── amenities/         # Amenity browsing screens
    ├── home/              # Home screen
    ├── location_search/   # Location search UI
    ├── settings/          # App settings
    ├── shared_location/   # Handle shared locations
    └── trip_planning/     # Trip planning screens & models
```

## Key Components

### Map Services
- `UnifiedMapService`: Unified interface to switch between Google Maps, Mappls, and Bhuvan
- Automatic fallback if one provider fails

### Route Optimization
- Uses Nearest Neighbor algorithm for initial solution
- 2-opt optimization for route improvement
- Considers road distances when available

### Amenity Finding
- Searches along the route at regular intervals
- Filters by rating and washroom quality
- Analyzes reviews for washroom-related feedback

### Shared Location Handling
- Parses Google Maps URLs, coordinates, place names
- Handles WhatsApp location shares
- Supports geo: URIs

## Customization

### Trip Preferences
Users can customize:
- Maximum daily driving distance (200-700 km)
- Break interval (50-200 km)
- Break duration (5-30 minutes)
- Minimum restaurant rating
- Washroom quality preference

### Vehicle Types
- Car
- Bike
- EV (auto-enables EV charging station search)

## License

MIT License

/// API Keys configuration
/// The app works without any API keys using OpenStreetMap (free)
/// Optionally configure Google Maps API key for additional features
class ApiKeys {
  // Google Maps API Key (optional)
  // Get from: https://console.cloud.google.com/google/maps-apis
  // App works fine without this - uses free OpenStreetMap instead
  static const String googleMaps = 'YOUR_GOOGLE_MAPS_API_KEY';

  // Google Places API Key (usually same as Google Maps)
  static const String googlePlaces = googleMaps;
}

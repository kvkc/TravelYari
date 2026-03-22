/// API Keys configuration
/// IMPORTANT: Replace these with your actual API keys
/// For production, use environment variables or secure storage
class ApiKeys {
  // Google Maps API Key
  // Get from: https://console.cloud.google.com/google/maps-apis
  static const String googleMaps = 'YOUR_GOOGLE_MAPS_API_KEY';

  // Mappls (MapMyIndia) API Keys
  // Get from: https://about.mappls.com/api/
  static const String mappls = 'YOUR_MAPPLS_API_KEY';
  static const String mapplsClientId = 'YOUR_MAPPLS_CLIENT_ID';
  static const String mapplsClientSecret = 'YOUR_MAPPLS_CLIENT_SECRET';

  // Bhuvan (ISRO) API Key
  // Get from: https://bhuvan.nrsc.gov.in/
  static const String bhuvan = 'YOUR_BHUVAN_API_KEY';

  // Zomato API Key (for restaurant data)
  // Note: Zomato public API is deprecated, using alternatives
  static const String zomato = 'YOUR_ZOMATO_API_KEY';

  // Google Places API Key (usually same as Google Maps)
  static const String googlePlaces = googleMaps;
}

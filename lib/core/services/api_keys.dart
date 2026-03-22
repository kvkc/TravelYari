/// API Keys configuration
///
/// SECURE KEY INJECTION:
/// Keys are injected at compile time via --dart-define flags.
/// They are NOT stored in source code.
///
/// Build commands:
/// Debug:   flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
/// Release: flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
///
/// Or create a .env file and use a script to read it (see README)
class ApiKeys {
  // Google Maps API Key - injected at compile time
  // DO NOT hardcode your key here!
  static const String googleMaps = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // Google Places API Key (usually same as Google Maps)
  static const String googlePlaces = googleMaps;

  /// Check if Google Maps key is configured
  static bool get hasGoogleMapsKey =>
      googleMaps.isNotEmpty &&
      !googleMaps.startsWith('YOUR_') &&
      googleMaps != 'YOUR_GOOGLE_MAPS_API_KEY';
}

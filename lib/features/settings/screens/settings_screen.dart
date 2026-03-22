import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/api_key_storage.dart';
import '../../../core/services/map/unified_map_service.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  MapProvider _defaultMapProvider = MapProvider.google;
  bool _darkMode = false;
  bool _offlineMaps = false;
  String _distanceUnit = 'km';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _defaultMapProvider = MapProvider.values[
          StorageService.getSetting<int>('defaultMapProvider', defaultValue: 0) ?? 0];
      _darkMode = StorageService.getSetting<bool>('darkMode', defaultValue: false) ?? false;
      _offlineMaps = StorageService.getSetting<bool>('offlineMaps', defaultValue: false) ?? false;
      _distanceUnit = StorageService.getSetting<String>('distanceUnit', defaultValue: 'km') ?? 'km';
    });
  }

  Future<void> _saveSettings() async {
    await StorageService.setSetting('defaultMapProvider', _defaultMapProvider.index);
    await StorageService.setSetting('darkMode', _darkMode);
    await StorageService.setSetting('offlineMaps', _offlineMaps);
    await StorageService.setSetting('distanceUnit', _distanceUnit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Map Settings'),
          _buildMapProviderTile(),
          _buildSwitchTile(
            title: 'Offline Maps',
            subtitle: 'Download maps for offline use',
            icon: Icons.download,
            value: _offlineMaps,
            onChanged: (value) {
              setState(() => _offlineMaps = value);
              _saveSettings();
            },
          ),

          _buildSectionHeader('Display'),
          _buildSwitchTile(
            title: 'Dark Mode',
            subtitle: 'Use dark theme',
            icon: Icons.dark_mode,
            value: _darkMode,
            onChanged: (value) {
              setState(() => _darkMode = value);
              _saveSettings();
            },
          ),
          _buildDistanceUnitTile(),

          _buildSectionHeader('API Keys'),
          _buildApiKeysTile(),

          _buildSectionHeader('Data'),
          _buildActionTile(
            title: 'Clear Cache',
            subtitle: 'Free up storage space',
            icon: Icons.cleaning_services,
            onTap: _clearCache,
          ),
          _buildActionTile(
            title: 'Export Trips',
            subtitle: 'Save your trips as a file',
            icon: Icons.file_download,
            onTap: _exportTrips,
          ),

          _buildSectionHeader('About'),
          _buildInfoTile(
            title: 'Version',
            subtitle: '1.0.0',
            icon: Icons.info_outline,
          ),
          _buildActionTile(
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            icon: Icons.privacy_tip,
            onTap: _openPrivacyPolicy,
          ),
          _buildActionTile(
            title: 'Terms of Service',
            subtitle: 'Read our terms of service',
            icon: Icons.description,
            onTap: _openTermsOfService,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildMapProviderTile() {
    return ListTile(
      leading: const Icon(Icons.map),
      title: const Text('Default Map Provider'),
      subtitle: Text(_getProviderName(_defaultMapProvider)),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showMapProviderDialog,
    );
  }

  String _getProviderName(MapProvider provider) {
    switch (provider) {
      case MapProvider.google:
        return 'Google Maps';
      case MapProvider.mappls:
        return 'Mappls (MapMyIndia)';
      case MapProvider.bhuvan:
        return 'Bhuvan (ISRO)';
      case MapProvider.openStreetMap:
        return 'OpenStreetMap (Free)';
    }
  }

  void _showMapProviderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Map Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MapProvider.values.map((provider) {
            return RadioListTile<MapProvider>(
              title: Text(_getProviderName(provider)),
              value: provider,
              groupValue: _defaultMapProvider,
              onChanged: (value) {
                setState(() => _defaultMapProvider = value!);
                _saveSettings();
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDistanceUnitTile() {
    return ListTile(
      leading: const Icon(Icons.straighten),
      title: const Text('Distance Unit'),
      subtitle: Text(_distanceUnit == 'km' ? 'Kilometers' : 'Miles'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Unit'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Kilometers'),
                  value: 'km',
                  groupValue: _distanceUnit,
                  onChanged: (value) {
                    setState(() => _distanceUnit = value!);
                    _saveSettings();
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Miles'),
                  value: 'mi',
                  groupValue: _distanceUnit,
                  onChanged: (value) {
                    setState(() => _distanceUnit = value!);
                    _saveSettings();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildApiKeysTile() {
    final keyStatus = ref.watch(apiKeyStatusProvider);

    return keyStatus.when(
      data: (status) {
        final configuredCount = status.values.where((v) => v).length;
        final subtitle = configuredCount > 0
            ? '$configuredCount API key${configuredCount > 1 ? 's' : ''} configured'
            : 'Using free OpenStreetMap (no keys needed)';

        return ListTile(
          leading: const Icon(Icons.key),
          title: const Text('Manage API Keys'),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (configuredCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () {
            Navigator.pushNamed(context, AppRouter.apiKeys).then((_) {
              ref.invalidate(apiKeyStatusProvider);
            });
          },
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.key),
        title: Text('Manage API Keys'),
        subtitle: Text('Loading...'),
      ),
      error: (_, __) => ListTile(
        leading: const Icon(Icons.key),
        title: const Text('Manage API Keys'),
        subtitle: const Text('Using free OpenStreetMap'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRouter.apiKeys),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  void _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear cached location data and maps. Your trips will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared')),
      );
    }
  }

  void _exportTrips() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon!')),
    );
  }

  void _openPrivacyPolicy() {
    // Open privacy policy URL
  }

  void _openTermsOfService() {
    // Open terms of service URL
  }
}

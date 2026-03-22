import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_key_storage.dart';
import '../../../core/theme/app_theme.dart';

class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  final _googleMapsController = TextEditingController();
  final _mapplsKeyController = TextEditingController();
  final _mapplsClientIdController = TextEditingController();
  final _mapplsSecretController = TextEditingController();
  final _openRouteServiceController = TextEditingController();
  final _foursquareController = TextEditingController();

  bool _isLoading = true;
  bool _obscureKeys = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final googleMaps = await ApiKeyStorage.getGoogleMapsKey();
    final mappls = await ApiKeyStorage.getMapplsKey();
    final mapplsClientId = await ApiKeyStorage.getMapplsClientId();
    final mapplsSecret = await ApiKeyStorage.getMapplsClientSecret();
    final openRouteService = await ApiKeyStorage.getOpenRouteServiceKey();
    final foursquare = await ApiKeyStorage.getFoursquareKey();

    setState(() {
      _googleMapsController.text = googleMaps ?? '';
      _mapplsKeyController.text = mappls ?? '';
      _mapplsClientIdController.text = mapplsClientId ?? '';
      _mapplsSecretController.text = mapplsSecret ?? '';
      _openRouteServiceController.text = openRouteService ?? '';
      _foursquareController.text = foursquare ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveKey(String name, Future<void> Function(String?) saveFn, String value) async {
    await saveFn(value.isEmpty ? null : value);
    ref.invalidate(apiKeyStatusProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name ${value.isEmpty ? "removed" : "saved"}'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  void dispose() {
    _googleMapsController.dispose();
    _mapplsKeyController.dispose();
    _mapplsClientIdController.dispose();
    _mapplsSecretController.dispose();
    _openRouteServiceController.dispose();
    _foursquareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
        actions: [
          IconButton(
            icon: Icon(_obscureKeys ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscureKeys = !_obscureKeys),
            tooltip: _obscureKeys ? 'Show keys' : 'Hide keys',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 24),

                _buildSectionHeader('Google Maps', 'Best coverage worldwide'),
                _buildKeyField(
                  controller: _googleMapsController,
                  label: 'Google Maps API Key',
                  hint: 'AIza...',
                  helpUrl: 'https://console.cloud.google.com/google/maps-apis',
                  onSave: (value) => _saveKey(
                    'Google Maps key',
                    ApiKeyStorage.setGoogleMapsKey,
                    value,
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('Mappls (MapMyIndia)', 'Best for India'),
                _buildKeyField(
                  controller: _mapplsKeyController,
                  label: 'Mappls API Key',
                  hint: 'Your Mappls API key',
                  helpUrl: 'https://about.mappls.com/api/',
                  onSave: (value) => _saveKey(
                    'Mappls key',
                    ApiKeyStorage.setMapplsKey,
                    value,
                  ),
                ),
                const SizedBox(height: 8),
                _buildKeyField(
                  controller: _mapplsClientIdController,
                  label: 'Mappls Client ID',
                  hint: 'Your client ID',
                  onSave: (value) => _saveKey(
                    'Mappls Client ID',
                    ApiKeyStorage.setMapplsClientId,
                    value,
                  ),
                ),
                const SizedBox(height: 8),
                _buildKeyField(
                  controller: _mapplsSecretController,
                  label: 'Mappls Client Secret',
                  hint: 'Your client secret',
                  onSave: (value) => _saveKey(
                    'Mappls Client Secret',
                    ApiKeyStorage.setMapplsClientSecret,
                    value,
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('OpenRouteService', 'Free with higher limits'),
                _buildKeyField(
                  controller: _openRouteServiceController,
                  label: 'OpenRouteService API Key',
                  hint: 'Your ORS key (optional)',
                  helpUrl: 'https://openrouteservice.org/dev/#/signup',
                  onSave: (value) => _saveKey(
                    'OpenRouteService key',
                    ApiKeyStorage.setOpenRouteServiceKey,
                    value,
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('Foursquare', 'For restaurant & POI data'),
                _buildKeyField(
                  controller: _foursquareController,
                  label: 'Foursquare API Key',
                  hint: 'fsq3...',
                  helpUrl: 'https://location.foursquare.com/developer/',
                  onSave: (value) => _saveKey(
                    'Foursquare key',
                    ApiKeyStorage.setFoursquareKey,
                    value,
                  ),
                ),

                const SizedBox(height: 32),
                _buildClearAllButton(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Bring Your Own Keys',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'The app works without API keys using free OpenStreetMap data. '
              'Add your own keys for better accuracy, higher limits, and premium features.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keys are stored securely on your device and never shared.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? helpUrl,
    required Future<void> Function(String) onSave,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: _obscureKeys,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        controller.clear();
                        onSave('');
                      },
                    )
                  : null,
            ),
            onSubmitted: onSave,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: () => onSave(controller.text),
          tooltip: 'Save',
        ),
        if (helpUrl != null)
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _openUrl(helpUrl),
            tooltip: 'Get API key',
          ),
      ],
    );
  }

  Widget _buildClearAllButton() {
    return OutlinedButton.icon(
      onPressed: _showClearAllDialog,
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      label: const Text('Clear All Keys', style: TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All API Keys?'),
        content: const Text(
          'This will remove all stored API keys. '
          'The app will fall back to free OpenStreetMap data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ApiKeyStorage.clearAllKeys();
              ref.invalidate(apiKeyStatusProvider);
              await _loadKeys();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All keys cleared')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

import 'package:flutter/material.dart';
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

  bool _isLoading = true;
  bool _obscureKeys = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final googleMaps = await ApiKeyStorage.getGoogleMapsKey();

    setState(() {
      _googleMapsController.text = googleMaps ?? '';
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

                _buildSectionHeader('Google Maps (Optional)', 'For additional map features'),
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
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'No API Keys Required!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This app uses free OpenStreetMap data by default. '
              'Everything works without any API keys!',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Optionally add a Google Maps key for additional features. '
              'Keys are stored securely on your device.',
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
          'The app will use free OpenStreetMap data.',
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

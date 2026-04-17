import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/trip.dart';
import '../services/invite_service.dart';

class InviteParticipantsScreen extends ConsumerStatefulWidget {
  final Trip trip;

  const InviteParticipantsScreen({
    super.key,
    required this.trip,
  });

  @override
  ConsumerState<InviteParticipantsScreen> createState() =>
      _InviteParticipantsScreenState();
}

class _InviteParticipantsScreenState
    extends ConsumerState<InviteParticipantsScreen> {
  String? _shareCode;
  String? _shareLink;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // Check if trip already has share code
    if (widget.trip.shareCode != null && widget.trip.shareCode!.isNotEmpty) {
      _shareCode = widget.trip.shareCode;
      _shareLink = 'https://yatraplanner-50f70.web.app/join?code=$_shareCode';
    }
  }

  Future<void> _generateShareCode() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // Prompt for name if not set (first time sharing)
    final savedName = StorageService.getSetting<String>('user_name');
    if ((savedName == null || savedName.isEmpty) && mounted) {
      final name = await _promptForName();
      if (name != null && name.isNotEmpty) {
        StorageService.setSetting('user_name', name);
      }
    }

    try {
      final inviteService = ref.read(inviteServiceProvider);
      final code = await inviteService.getShareCode(widget.trip).timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
      if (code != null && mounted) {
        setState(() {
          _shareCode = code;
          _shareLink = inviteService.generateInviteLink(code);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Failed to generate code. Check your internet connection.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Error: $e';
        });
      }
    }
  }

  Future<String?> _promptForName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Your Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _shareInvite() {
    if (_shareCode == null) return;
    final inviteService = ref.read(inviteServiceProvider);
    final message = inviteService.generateInviteMessage(widget.trip, _shareCode!);
    Share.share(message, subject: 'Join my trip: ${widget.trip.name}');
  }

  void _copyLink() {
    if (_shareLink == null) return;
    Clipboard.setData(ClipboardData(text: _shareLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyCode() {
    if (_shareCode == null) return;
    Clipboard.setData(ClipboardData(text: _shareCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Members'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.group_add,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Invite to "${widget.trip.name}"',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Share this invite link with your travel partners.\nThey can join the trip from the app.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Share code
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating share code...'),
                  ],
                )
              else if (_errorMsg != null)
                Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _generateShareCode,
                      child: const Text('Try Again'),
                    ),
                  ],
                )
              else if (_shareCode == null)
                ElevatedButton.icon(
                  onPressed: _generateShareCode,
                  icon: const Icon(Icons.link),
                  label: const Text('Generate Invite Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                )
              else if (_shareCode != null) ...[
                // Code display
                GestureDetector(
                  onTap: _copyCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'INVITE CODE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _shareCode!,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.copy,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap code to copy',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),

                // Share button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _shareInvite,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Invite Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Copy link button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.link),
                    label: const Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else
                const Text('Failed to generate invite code. Try again.'),
            ],
          ),
        ),
      ),
    );
  }
}

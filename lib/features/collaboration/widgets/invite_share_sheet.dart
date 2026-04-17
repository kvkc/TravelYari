import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/trip.dart';
import '../services/invite_service.dart';

/// WhatsApp-style share sheet for trip invitations
class InviteShareSheet extends ConsumerStatefulWidget {
  final Trip trip;

  const InviteShareSheet({super.key, required this.trip});

  static Future<void> show(BuildContext context, Trip trip) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteShareSheet(trip: trip),
    );
  }

  @override
  ConsumerState<InviteShareSheet> createState() => _InviteShareSheetState();
}

class _InviteShareSheetState extends ConsumerState<InviteShareSheet> {
  String? _shareCode;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initShareCode();
  }

  void _initShareCode() {
    // Check if trip already has a share code - instant, no network
    if (widget.trip.shareCode != null && widget.trip.shareCode!.isNotEmpty) {
      setState(() {
        _shareCode = widget.trip.shareCode;
        _isLoading = false;
      });
    } else {
      // Need to generate - do in background
      _generateShareCode();
    }
  }

  Future<void> _generateShareCode() async {
    final inviteService = ref.read(inviteServiceProvider);
    final code = await inviteService.getShareCode(widget.trip);

    if (mounted) {
      setState(() {
        _shareCode = code;
        _isLoading = false;
      });
    }
  }

  void _copyCode() {
    if (_shareCode == null) return;

    Clipboard.setData(ClipboardData(text: _shareCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Text('Code copied!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _shareViaWhatsApp() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    final inviteService = ref.read(inviteServiceProvider);
    await inviteService.shareInvite(widget.trip);

    if (mounted) {
      setState(() => _isSending = false);
      Navigator.pop(context);
    }
  }

  Future<void> _shareGeneral() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    final inviteService = ref.read(inviteServiceProvider);
    await inviteService.shareInvite(widget.trip);

    if (mounted) {
      setState(() => _isSending = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.group_add,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invite to Trip',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.trip.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Share Code Display
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_shareCode != null) ...[
              // Code Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'INVITE CODE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _shareCode!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy, color: Colors.white70),
                          tooltip: 'Copy code',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this code with your travel partners',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Share Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickShareButton(
                        icon: Icons.content_copy,
                        label: 'Copy Code',
                        color: Colors.grey[700]!,
                        onTap: _copyCode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickShareButton(
                        icon: Icons.chat,
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        onTap: _shareViaWhatsApp,
                        isLoading: _isSending,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickShareButton(
                        icon: Icons.share,
                        label: 'More',
                        color: AppTheme.primaryColor,
                        onTap: _shareGeneral,
                        isLoading: _isSending,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _QuickShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _QuickShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )
              else
                Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

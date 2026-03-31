import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../services/contacts_service.dart';

class ContactListItem extends StatelessWidget {
  final ContactInfo contact;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onInviteViaSms;
  final VoidCallback? onInviteViaWhatsApp;

  const ContactListItem({
    super.key,
    required this.contact,
    this.isSelected = false,
    this.onTap,
    this.onInviteViaSms,
    this.onInviteViaWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAvatar(),
      title: Text(
        contact.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        contact.phone ?? contact.email ?? '',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
          : _buildInviteButtons(),
      onTap: onTap,
    );
  }

  Widget _buildAvatar() {
    if (contact.photo != null && contact.photo!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: MemoryImage(contact.photo!),
        backgroundColor: Colors.grey[200],
      );
    }

    return CircleAvatar(
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      child: Text(
        _getInitials(contact.name),
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget? _buildInviteButtons() {
    if (onInviteViaSms == null && onInviteViaWhatsApp == null) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (contact.phone != null && onInviteViaWhatsApp != null)
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.green),
            onPressed: onInviteViaWhatsApp,
            tooltip: 'Send via WhatsApp',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        if (contact.phone != null && onInviteViaSms != null)
          IconButton(
            icon: Icon(Icons.sms, color: Colors.blue[700]),
            onPressed: onInviteViaSms,
            tooltip: 'Send via SMS',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

/// Chip widget showing a selected participant
class ParticipantChip extends StatelessWidget {
  final ContactInfo contact;
  final VoidCallback? onRemove;

  const ParticipantChip({
    super.key,
    required this.contact,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: contact.photo != null && contact.photo!.isNotEmpty
          ? CircleAvatar(backgroundImage: MemoryImage(contact.photo!))
          : CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      label: Text(contact.name),
      deleteIcon: onRemove != null ? const Icon(Icons.close, size: 18) : null,
      onDeleted: onRemove,
    );
  }
}

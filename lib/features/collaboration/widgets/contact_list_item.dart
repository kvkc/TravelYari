import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../services/contacts_service.dart';

class ContactListItem extends StatelessWidget {
  final ContactInfo contact;
  final bool isSelected;
  final VoidCallback? onTap;

  const ContactListItem({
    super.key,
    required this.contact,
    this.isSelected = false,
    this.onTap,
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
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? AppTheme.primaryColor : Colors.grey[400],
      ),
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

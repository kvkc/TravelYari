import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContactInfo {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final Uint8List? photo;

  ContactInfo({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.photo,
  });
}

class ContactsService {
  /// Check if contacts permission is granted
  Future<bool> hasPermission() async {
    return await FlutterContacts.requestPermission(readonly: true);
  }

  /// Request contacts permission
  Future<bool> requestPermission() async {
    return await FlutterContacts.requestPermission(readonly: true);
  }

  /// Get all contacts with phone numbers
  Future<List<ContactInfo>> getContacts({String? searchQuery}) async {
    final hasAccess = await hasPermission();
    if (!hasAccess) return [];

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      final contactList = contacts
          .where((c) => c.phones.isNotEmpty || c.emails.isNotEmpty)
          .map((c) => ContactInfo(
                id: c.id,
                name: c.displayName,
                phone: c.phones.isNotEmpty ? c.phones.first.number : null,
                email: c.emails.isNotEmpty ? c.emails.first.address : null,
                photo: c.photo,
              ))
          .toList();

      // Sort alphabetically
      contactList.sort((a, b) => a.name.compareTo(b.name));

      // Filter by search query if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return contactList.where((c) {
          return c.name.toLowerCase().contains(query) ||
              (c.phone?.contains(query) ?? false) ||
              (c.email?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      return contactList;
    } catch (e) {
      debugPrint('Failed to get contacts: $e');
      return [];
    }
  }

  /// Get a single contact by ID
  Future<ContactInfo?> getContact(String id) async {
    final hasAccess = await hasPermission();
    if (!hasAccess) return null;

    try {
      final contact = await FlutterContacts.getContact(
        id,
        withProperties: true,
        withPhoto: true,
      );

      if (contact != null) {
        return ContactInfo(
          id: contact.id,
          name: contact.displayName,
          phone: contact.phones.isNotEmpty ? contact.phones.first.number : null,
          email: contact.emails.isNotEmpty ? contact.emails.first.address : null,
          photo: contact.photo,
        );
      }
    } catch (e) {
      debugPrint('Failed to get contact: $e');
    }
    return null;
  }
}

// Provider
final contactsServiceProvider = Provider<ContactsService>((ref) {
  return ContactsService();
});

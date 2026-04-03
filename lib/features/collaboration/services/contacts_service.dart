import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContactInfo {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  Uint8List? photo;

  ContactInfo({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.photo,
  });
}

class ContactsServiceException implements Exception {
  final String message;
  final Object? originalError;

  ContactsServiceException(this.message, [this.originalError]);

  @override
  String toString() => message;
}

class ContactsService {
  bool _permissionDenied = false;

  /// Check if contacts permission was previously denied
  bool get wasPermissionDenied => _permissionDenied;

  /// Check if contacts permission is granted
  Future<bool> hasPermission() async {
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (e) {
      debugPrint('Error checking contacts permission: $e');
      return false;
    }
  }

  /// Request contacts permission
  Future<bool> requestPermission() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      _permissionDenied = !granted;
      return granted;
    } catch (e) {
      debugPrint('Error requesting contacts permission: $e');
      _permissionDenied = true;
      return false;
    }
  }

  /// Get all contacts with phone numbers or emails
  /// Loads contacts without photos first for speed, photos can be loaded separately
  Future<List<ContactInfo>> getContacts({String? searchQuery}) async {
    try {
      final hasAccess = await requestPermission();
      if (!hasAccess) {
        debugPrint('Contacts permission not granted');
        return [];
      }

      // Load contacts WITHOUT photos first - much faster
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      debugPrint('Loaded ${contacts.length} raw contacts');

      final contactList = contacts
          .where((c) => c.phones.isNotEmpty || c.emails.isNotEmpty)
          .where((c) => c.displayName.isNotEmpty)
          .map((c) => ContactInfo(
                id: c.id,
                name: c.displayName,
                phone: c.phones.isNotEmpty ? c.phones.first.number : null,
                email: c.emails.isNotEmpty ? c.emails.first.address : null,
                photo: null, // Load lazily
              ))
          .toList();

      debugPrint('Filtered to ${contactList.length} contacts with phone/email');

      // Sort alphabetically
      contactList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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
    } catch (e, stackTrace) {
      debugPrint('Failed to get contacts: $e');
      debugPrint('Stack trace: $stackTrace');
      throw ContactsServiceException('Failed to load contacts', e);
    }
  }

  /// Load photo for a specific contact (call this lazily)
  Future<Uint8List?> loadContactPhoto(String contactId) async {
    try {
      final contact = await FlutterContacts.getContact(
        contactId,
        withPhoto: true,
        withProperties: false,
      );
      return contact?.photo;
    } catch (e) {
      debugPrint('Failed to load photo for contact $contactId: $e');
      return null;
    }
  }

  /// Get a single contact by ID
  Future<ContactInfo?> getContact(String id) async {
    try {
      final hasAccess = await requestPermission();
      if (!hasAccess) return null;

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

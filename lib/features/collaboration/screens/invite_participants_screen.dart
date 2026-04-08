import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/trip.dart';
import '../services/contacts_service.dart';
import '../services/invite_service.dart';
import '../widgets/contact_list_item.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedContactIds = {};

  List<ContactInfo> _contacts = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isAdding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contactsService = ref.read(contactsServiceProvider);

    try {
      final hasAccess = await contactsService.requestPermission();
      setState(() {
        _hasPermission = hasAccess;
        _error = null;
      });

      if (hasAccess) {
        final contacts = await contactsService.getContacts();
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } on ContactsServiceException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load contacts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchContacts(String query) async {
    if (!_hasPermission) return;

    try {
      final contactsService = ref.read(contactsServiceProvider);
      final contacts = await contactsService.getContacts(searchQuery: query);
      setState(() => _contacts = contacts);
    } catch (e) {
      debugPrint('Search failed: $e');
    }
  }

  List<ContactInfo> get _selectedContacts {
    return _contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();
  }

  Future<void> _addSelectedContacts() async {
    if (_selectedContactIds.isEmpty) return;

    setState(() => _isAdding = true);

    try {
      final inviteService = ref.read(inviteServiceProvider);
      final selected = _selectedContacts;
      final updatedTrip = await inviteService.addContactsAsParticipants(
        widget.trip,
        selected,
      );

      if (mounted) {
        if (updatedTrip != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${selected.length} member${selected.length > 1 ? 's' : ''} to trip',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, updatedTrip);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add members. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _shareInviteCode() {
    final inviteService = ref.read(inviteServiceProvider);
    inviteService.shareInvite(widget.trip);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedContactIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Trip Members'),
        actions: [
          TextButton.icon(
            onPressed: _shareInviteCode,
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Code'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selected contacts chips
          if (_selectedContactIds.isNotEmpty) _buildSelectedChips(),

          // Search bar
          if (_hasPermission) _buildSearchBar(),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      // Add Members button
      bottomNavigationBar: selectedCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isAdding ? null : _addSelectedContacts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isAdding
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Add $selectedCount Member${selectedCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSelectedChips() {
    final selected = _selectedContacts;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: selected.map((contact) {
          return Chip(
            avatar: CircleAvatar(
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
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                _selectedContactIds.remove(contact.id);
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: _searchContacts,
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (!_hasPermission) {
      return _buildPermissionRequest();
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No contacts match your search'
                  : 'No contacts found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _contacts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final isSelected = _selectedContactIds.contains(contact.id);

        return ContactListItem(
          contact: contact,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedContactIds.remove(contact.id);
              } else {
                _selectedContactIds.add(contact.id);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            const Text(
              'Could not load contacts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadContacts();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'Contacts Access Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To add trip members from your contacts, please grant contacts permission.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadContacts,
              icon: const Icon(Icons.security),
              label: const Text('Grant Permission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _shareInviteCode,
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Or share invite code'),
            ),
          ],
        ),
      ),
    );
  }
}

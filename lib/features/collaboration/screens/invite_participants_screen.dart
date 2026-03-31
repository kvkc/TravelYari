import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _shareLink;
  String? _shareCode;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _generateShareLink();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contactsService = ref.read(contactsServiceProvider);

    final hasAccess = await contactsService.requestPermission();
    setState(() => _hasPermission = hasAccess);

    if (hasAccess) {
      final contacts = await contactsService.getContacts();
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateShareLink() async {
    final inviteService = ref.read(inviteServiceProvider);
    final link = await inviteService.generateInviteLink(widget.trip);
    final code = inviteService.parseShareCodeFromLink(link ?? '');

    setState(() {
      _shareLink = link;
      _shareCode = code;
    });
  }

  Future<void> _searchContacts(String query) async {
    if (!_hasPermission) return;

    final contactsService = ref.read(contactsServiceProvider);
    final contacts = await contactsService.getContacts(searchQuery: query);
    setState(() => _contacts = contacts);
  }

  void _sendInviteViaWhatsApp(ContactInfo contact) async {
    if (contact.phone == null) return;

    final inviteService = ref.read(inviteServiceProvider);
    final success =
        await inviteService.sendWhatsAppInvite(widget.trip, contact.phone!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Opening WhatsApp...'
              : 'Could not open WhatsApp'),
        ),
      );
    }
  }

  void _sendInviteViaSms(ContactInfo contact) async {
    if (contact.phone == null) return;

    final inviteService = ref.read(inviteServiceProvider);
    final success =
        await inviteService.sendSmsInvite(widget.trip, contact.phone!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Opening Messages...' : 'Could not open Messages'),
        ),
      );
    }
  }

  void _shareViaSheet() {
    final inviteService = ref.read(inviteServiceProvider);
    inviteService.shareInvite(widget.trip);
  }

  void _copyShareLink() {
    if (_shareLink == null) return;

    Clipboard.setData(ClipboardData(text: _shareLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Participants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareViaSheet,
            tooltip: 'Share invite link',
          ),
        ],
      ),
      body: Column(
        children: [
          // Share code card
          _buildShareCodeCard(),

          // Search bar
          if (_hasPermission) _buildSearchBar(),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildShareCodeCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Share Link',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_shareCode != null) ...[
              Text(
                'Share this code with your trip partners:',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryColor),
                    ),
                    child: Text(
                      _shareCode!,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: _copyShareLink,
                    tooltip: 'Copy link',
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _shareViaSheet,
                icon: const Icon(Icons.share),
                label: const Text('Share via...'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              'No contacts found',
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
      padding: const EdgeInsets.only(top: 16),
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
          onInviteViaWhatsApp: contact.phone != null
              ? () => _sendInviteViaWhatsApp(contact)
              : null,
          onInviteViaSms: contact.phone != null
              ? () => _sendInviteViaSms(contact)
              : null,
        );
      },
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
              'To invite trip participants from your contacts, please grant contacts permission.',
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
            TextButton(
              onPressed: _shareViaSheet,
              child: const Text('Or share link directly'),
            ),
          ],
        ),
      ),
    );
  }
}

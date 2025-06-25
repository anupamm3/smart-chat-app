import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/constants.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  bool _loading = true;
  List<UserModel> _matchedUsers = [];
  Map<String, String> _contactNameByPhone = {};
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _fetchContactsAndUsers();
  }

  Future<void> _fetchContactsAndUsers() async {
    setState(() => _loading = true);

    // Request permission
    final permission = await Permission.contacts.request();
    if (!permission.isGranted) {
      setState(() => _loading = false);
      return;
    }

    // Fetch contacts
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final Set<String> contactPhones = {};
    final Map<String, String> contactNameByPhone = {};
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final normalized = _normalizePhone(phone.number);
        if (normalized.isNotEmpty) {
          contactPhones.add(normalized);
          if (contact.displayName.isNotEmpty) {
            contactNameByPhone[normalized] = contact.displayName;
          }
          // Also add without leading +
          if (normalized.startsWith('+')) {
            final noPlus = normalized.substring(1);
            contactPhones.add(noPlus);
            if (contact.displayName.isNotEmpty) {
              contactNameByPhone[noPlus] = contact.displayName;
            }
          }
          // Also add last 10 digits for local numbers
          if (normalized.length >= 10) {
            final last10 = normalized.substring(normalized.length - 10);
            contactPhones.add(last10);
            if (contact.displayName.isNotEmpty) {
              contactNameByPhone[last10] = contact.displayName;
            }
          }
        }
      }
    }

    // Fetch all users from Firestore
    final usersSnap = await FirebaseFirestore.instance.collection('users').get();
    final List<UserModel> matched = [];
    for (final doc in usersSnap.docs) {
      final user = UserModel.fromMap(doc.data());
      if (user.uid == _currentUserId) continue;
      final normalizedUserPhone = _normalizePhone(user.phoneNumber);
      final normalizedUserPhoneNoPlus = normalizedUserPhone.startsWith('+')
          ? normalizedUserPhone.substring(1)
          : normalizedUserPhone;
      final last10 = normalizedUserPhone.length >= 10
          ? normalizedUserPhone.substring(normalizedUserPhone.length - 10)
          : normalizedUserPhone;
      if (contactPhones.contains(normalizedUserPhone) ||
          contactPhones.contains(normalizedUserPhoneNoPlus) ||
          contactPhones.contains(last10)) {
        matched.add(user);
      }
    }

    setState(() {
      _matchedUsers = matched;
      _loading = false;
      _contactNameByPhone = contactNameByPhone;
    });
  }

  String _normalizePhone(String phone) {
    var normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.startsWith('00')) {
      normalized = '+${normalized.substring(2)}';
    }
    if (!normalized.startsWith('+') && normalized.length >= 10) {
      normalized = '+$normalized';
    }
    return normalized;
  }

  List<UserModel> get _filteredUsers {
    List<UserModel> filtered;
    if (_search.trim().isEmpty) {
      filtered = List<UserModel>.from(_matchedUsers);
    } else {
      final query = _search.trim().toLowerCase();
      filtered = _matchedUsers.where((user) {
        final normalizedPhone = _normalizePhone(user.phoneNumber);
        final normalizedPhoneNoPlus = normalizedPhone.startsWith('+')
            ? normalizedPhone.substring(1)
            : normalizedPhone;
        final last10 = normalizedPhone.length >= 10
            ? normalizedPhone.substring(normalizedPhone.length - 10)
            : normalizedPhone;
        final contactName =
            _contactNameByPhone[normalizedPhone] ??
            _contactNameByPhone[normalizedPhoneNoPlus] ??
            _contactNameByPhone[last10] ??
            "";
        return contactName.toLowerCase().contains(query) ||
            user.phoneNumber.contains(query) ||
            user.name.toLowerCase().contains(query);
      }).toList();
    }

    // Sort alphabetically by contact name (or phone number if no contact name)
    filtered.sort((a, b) {
      final aNorm = _normalizePhone(a.phoneNumber);
      final bNorm = _normalizePhone(b.phoneNumber);
      final aName = _contactNameByPhone[aNorm] ??
          _contactNameByPhone[aNorm.startsWith('+') ? aNorm.substring(1) : aNorm] ??
          _contactNameByPhone[aNorm.length >= 10 ? aNorm.substring(aNorm.length - 10) : aNorm] ??
          a.phoneNumber;
      final bName = _contactNameByPhone[bNorm] ??
          _contactNameByPhone[bNorm.startsWith('+') ? bNorm.substring(1) : bNorm] ??
          _contactNameByPhone[bNorm.length >= 10 ? bNorm.substring(bNorm.length - 10) : bNorm] ??
          b.phoneNumber;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Start New Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(
          "Invite",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          // TODO: Implement invite/share logic
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invite feature coming soon!")),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _fetchContactsAndUsers,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(16),
                child: TextField(
                  onChanged: (val) => setState(() => _search = val),
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "Search contacts...",
                    hintStyle: GoogleFonts.poppins(
                      color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                    ),
                    prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                    filled: true,
                    fillColor: colorScheme.surface.withAlpha(230),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_outlined,
                                  size: 64,
                                  color: colorScheme.primary.withAlpha(80)),
                              const SizedBox(height: 16),
                              Text(
                                "No contacts found using SmartChat",
                                style: GoogleFonts.poppins(
                                  color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filteredUsers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final normalizedPhone = _normalizePhone(user.phoneNumber);
                            final normalizedPhoneNoPlus = normalizedPhone.startsWith('+')
                                ? normalizedPhone.substring(1)
                                : normalizedPhone;
                            final last10 = normalizedPhone.length >= 10
                                ? normalizedPhone.substring(normalizedPhone.length - 10)
                                : normalizedPhone;

                            final contactName =
                                _contactNameByPhone[normalizedPhone] ??
                                _contactNameByPhone[normalizedPhoneNoPlus] ??
                                _contactNameByPhone[last10];

                            return Card(
                              elevation: 1,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: colorScheme.surface.withAlpha(
                                  Theme.of(context).brightness == Brightness.dark ? 180 : 240),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundImage: user.photoUrl.isNotEmpty
                                      ? NetworkImage(user.photoUrl)
                                      : null,
                                  backgroundColor: colorScheme.primaryContainer,
                                  child: user.photoUrl.isEmpty
                                      ? Text(
                                          (contactName != null && contactName.isNotEmpty)
                                              ? contactName[0].toUpperCase()
                                              : user.phoneNumber[0],
                                          style: GoogleFonts.poppins(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  (contactName != null && contactName.isNotEmpty)
                                      ? contactName
                                      : user.phoneNumber,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  (contactName != null && contactName.isNotEmpty)
                                      ? "In your contacts"
                                      : "SmartChat user",
                                  style: GoogleFonts.poppins(
                                    color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Icon(Icons.arrow_forward_ios_rounded,
                                    color: colorScheme.primary, size: 22),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.chat,
                                    arguments: user,
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
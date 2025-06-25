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
    // Remove spaces, dashes, parentheses, and leading zeros
    var normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    // If starts with 00, replace with +
    if (normalized.startsWith('00')) {
      normalized = '+${normalized.substring(2)}';
    }
    // If doesn't start with + and is long enough, add +
    if (!normalized.startsWith('+') && normalized.length >= 10) {
      normalized = '+$normalized';
    }
    return normalized;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _matchedUsers.isEmpty
              ? Center(
                  child: Text(
                    "No contacts using SmartChat yet",
                    style: GoogleFonts.poppins(
                      color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _matchedUsers.length,
                  separatorBuilder: (_, __) => Divider(
                    color: colorScheme.outline.withAlpha((0.08 * 255).toInt()),
                    height: 0,
                  ),
                  itemBuilder: (context, index) {
                    final user = _matchedUsers[index];
                    final normalizedPhone = _normalizePhone(user.phoneNumber);
                    final normalizedPhoneNoPlus = normalizedPhone.startsWith('+')
                        ? normalizedPhone.substring(1)
                        : normalizedPhone;
                    final last10 = normalizedPhone.length >= 10
                        ? normalizedPhone.substring(normalizedPhone.length - 10)
                        : normalizedPhone;

                    // Try all possible keys for contact name
                    final contactName =
                        _contactNameByPhone[normalizedPhone] ??
                        _contactNameByPhone[normalizedPhoneNoPlus] ??
                        _contactNameByPhone[last10];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? NetworkImage(user.photoUrl)
                            : null,
                        backgroundColor: colorScheme.primaryContainer,
                        child: user.photoUrl.isEmpty
                            ? Icon(Icons.person, color: colorScheme.primary)
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
                      subtitle: user.email.isNotEmpty
                          ? Text(
                              user.email,
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.chat,
                          arguments: {
                            'otherUserId': user.uid,
                            'otherUserName': contactName ?? user.phoneNumber,
                          },
                        );
                      },
                    );
                  }
                ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/models/contact_model.dart';
import 'package:smart_chat_app/widgets/gradient_scaffold.dart';

class GroupContactPickerScreen extends StatefulWidget {
  final List<ContactModel> contacts;
  const GroupContactPickerScreen({super.key, required this.contacts});

  @override
  State<GroupContactPickerScreen> createState() => _GroupContactPickerScreenState();
}

class _GroupContactPickerScreenState extends State<GroupContactPickerScreen> {
  final Set<String> _selectedContactIds = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: Text('Select Contacts', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
      ),
      body: widget.contacts.isEmpty
          ? Center(
              child: Text(
                "No contacts found.",
                style: GoogleFonts.poppins(fontSize: 16, color: colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              itemCount: widget.contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final contact = widget.contacts[index];
                final isSelected = _selectedContactIds.contains(contact.id);
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (contact.displayName?.isNotEmpty == true
                          ? contact.displayName![0]
                          : contact.phoneNumber[0]
                      ).toUpperCase(),
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  title: Text(
                    contact.displayName?.isNotEmpty == true
                        ? contact.displayName!
                        : contact.phoneNumber,
                    style: GoogleFonts.poppins(),
                  ),
                  subtitle: contact.displayName?.isNotEmpty == true
                      ? Text(contact.phoneNumber, style: GoogleFonts.poppins(fontSize: 12))
                      : null,
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedContactIds.add(contact.id);
                        } else {
                          _selectedContactIds.remove(contact.id);
                        }
                      });
                    },
                  ),
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
            ),
      floatingActionButton: _selectedContactIds.isEmpty
          ? null
          : FloatingActionButton(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 4,
              onPressed: () async {
                final navigator = Navigator.of(context);
                final selectedContacts = widget.contacts
                    .where((c) => _selectedContactIds.contains(c.id))
                    .toList();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupCreateScreen(selectedContacts: selectedContacts),
                  ),
                );
                if (result == true && mounted) {
                  navigator.pop(true);
                }
              },
              child: const Icon(Icons.arrow_forward),
            ),
    );
  }
}

class GroupCreateScreen extends StatefulWidget {
  final List<ContactModel> selectedContacts;
  const GroupCreateScreen({super.key, required this.selectedContacts});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a group name', style: GoogleFonts.poppins())),
      );
      return;
    }
    setState(() => _creating = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("Not logged in");

      // Collect all member UIDs (including current user)
      final memberUids = widget.selectedContacts.map((c) => c.id).toSet().toList();
      memberUids.add(currentUser.uid);

      // Create group in Firestore
      await FirebaseFirestore.instance.collection('groups').add({
        'name': groupName,
        'photoUrl': null,
        'members': memberUids,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
      });

      if (mounted) {
        setState(() => _creating = false);
        Navigator.pop(context, true); // Pops GroupCreateScreen
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Group', style: GoogleFonts.poppins()),
        backgroundColor: colorScheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _groupNameController,
              style: GoogleFonts.poppins(),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: GoogleFonts.poppins(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Members:',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.selectedContacts.map((c) {
                return Chip(
                  label: Text(
                    c.displayName?.isNotEmpty == true ? c.displayName! : c.phoneNumber,
                    style: GoogleFonts.poppins(),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text('Create Group', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _creating ? null : _createGroup,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
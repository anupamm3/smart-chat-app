import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_chat_app/models/user_model.dart';

class MatchedContact {
  final UserModel user;
  final String? contactName;
  MatchedContact({required this.user, this.contactName});
}

String normalizePhone(String phone) {
  var normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (normalized.startsWith('00')) {
    normalized = '+${normalized.substring(2)}';
  }
  if (!normalized.startsWith('+') && normalized.length >= 10) {
    normalized = '+$normalized';
  }
  return normalized;
}

Future<List<MatchedContact>> fetchMatchedContacts(String? currentUserId) async {
  // Request permission
  final permission = await Permission.contacts.request();
  if (!permission.isGranted) return [];

  // Fetch contacts
  final contacts = await FlutterContacts.getContacts(withProperties: true);
  final Set<String> contactPhones = {};
  final Map<String, String> contactNameByPhone = {};
  for (final contact in contacts) {
    for (final phone in contact.phones) {
      final normalized = normalizePhone(phone.number);
      if (normalized.isNotEmpty) {
        contactPhones.add(normalized);
        if (contact.displayName.isNotEmpty) {
          contactNameByPhone[normalized] = contact.displayName;
        }
        if (normalized.startsWith('+')) {
          final noPlus = normalized.substring(1);
          contactPhones.add(noPlus);
          if (contact.displayName.isNotEmpty) {
            contactNameByPhone[noPlus] = contact.displayName;
          }
        }
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
  final List<MatchedContact> matched = [];
  for (final doc in usersSnap.docs) {
    final user = UserModel.fromMap(doc.data());
    if (user.uid == currentUserId) continue;
    final normalizedUserPhone = normalizePhone(user.phoneNumber);
    final normalizedUserPhoneNoPlus = normalizedUserPhone.startsWith('+')
        ? normalizedUserPhone.substring(1)
        : normalizedUserPhone;
    final last10 = normalizedUserPhone.length >= 10
        ? normalizedUserPhone.substring(normalizedUserPhone.length - 10)
        : normalizedUserPhone;
    final contactName = contactNameByPhone[normalizedUserPhone] ??
        contactNameByPhone[normalizedUserPhoneNoPlus] ??
        contactNameByPhone[last10];
    if (contactName != null ||
        contactPhones.contains(normalizedUserPhone) ||
        contactPhones.contains(normalizedUserPhoneNoPlus) ||
        contactPhones.contains(last10)) {
      matched.add(MatchedContact(user: user, contactName: contactName));
    }
  }
  return matched;
}
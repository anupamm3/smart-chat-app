import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_chat_app/models/user_model.dart';

class MatchedContact {
  final UserModel user;
  final String? contactName;
  final String localPhoneNumber;
  
  MatchedContact({
    required this.user, 
    this.contactName,
    required this.localPhoneNumber,
  });
}

class PhoneUtils {
  // Common country codes to strip
  static const List<String> commonCountryCodes = [
    '+91',  // India
    '+1',   // US/Canada
    '+44',  // UK
    '+61',  // Australia
    '+49',  // Germany
    '+33',  // France
    '+81',  // Japan
    '+86',  // China
    '+92',  // Pakistan
    '+880', // Bangladesh
    '+94',  // Sri Lanka
    '+977', // Nepal
    // Add more as needed
  ];

  /// Convert full international number to local number
  static String toLocalNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return phoneNumber;
    
    String cleaned = phoneNumber.trim();
    
    // Remove any spaces, dashes, parentheses
    cleaned = cleaned.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Try to strip known country codes
    for (String countryCode in commonCountryCodes) {
      if (cleaned.startsWith(countryCode)) {
        return cleaned.substring(countryCode.length);
      }
    }
    
    // If starts with +, try to strip it and common prefixes
    if (cleaned.startsWith('+')) {
      // Remove + and try to get last 10 digits for most countries
      String withoutPlus = cleaned.substring(1);
      if (withoutPlus.length >= 10) {
        return withoutPlus.substring(withoutPlus.length - 10);
      }
      return withoutPlus;
    }
    
    // If no country code detected, return as it is (already local)
    return cleaned;
  }

  /// Convert local number to full international format
  static String toInternationalNumber(String localNumber, [String countryCode = '+91']) {
    if (localNumber.isEmpty) return localNumber;
    
    String cleaned = toLocalNumber(localNumber);
    
    // If already has country code, return as is
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    
    // Add default country code
    return '$countryCode$cleaned';
  }

  /// Normalize phone number for consistent comparison (returns local number)
  static String normalizeForComparison(String phoneNumber) {
    return toLocalNumber(phoneNumber);
  }

  /// Check if two phone numbers are the same (comparing local numbers)
  static bool areNumbersEqual(String number1, String number2) {
    if (number1.isEmpty || number2.isEmpty) return false;
    
    String local1 = toLocalNumber(number1);
    String local2 = toLocalNumber(number2);
    
    return local1 == local2;
  }

  /// Format phone number for display (local format)
  static String formatForDisplay(String phoneNumber) {
    String local = toLocalNumber(phoneNumber);
    
    // Format as per your preference (e.g., 98765 43210)
    if (local.length == 10) {
      return '${local.substring(0, 5)} ${local.substring(5)}';
    }
    
    return local;
  }

  /// Get last N digits for fallback matching
  static String getLastDigits(String phoneNumber, [int count = 10]) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (cleaned.length >= count) {
      return cleaned.substring(cleaned.length - count);
    }
    return cleaned;
  }

  /// Check if string looks like a phone number
  static bool isPhoneNumber(String value) {
    final phoneRegex = RegExp(r'^[\+\d\s\-\(\)]+$');
    return phoneRegex.hasMatch(value) && value.replaceAll(RegExp(r'[\+\s\-\(\)]'), '').length >= 10;
  }
}

String normalizePhone(String phone) {
  return PhoneUtils.toInternationalNumber(phone);
}

Future<List<MatchedContact>> fetchMatchedContacts(String? currentUserId) async {
  if (currentUserId == null) return [];

  try {
    // Request permission
    final permission = await Permission.contacts.request();
    if (!permission.isGranted) {
      print('Contacts permission not granted');
      return [];
    }

    // Fetch contacts
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    print('Found ${contacts.length} device contacts');
    
    // Build contact mapping using local phone numbers as keys
    final Map<String, String> contactNameByLocalPhone = {};
    final Set<String> allContactLocalPhones = {};
    
    for (final contact in contacts) {
      if (contact.displayName.isEmpty) continue;
      
      for (final phone in contact.phones) {
        final localPhone = PhoneUtils.toLocalNumber(phone.number);
        if (localPhone.isNotEmpty && localPhone.length >= 10) {
          contactNameByLocalPhone[localPhone] = contact.displayName;
          allContactLocalPhones.add(localPhone);
          
          // Also add last 10 digits as fallback
          final last10 = PhoneUtils.getLastDigits(localPhone, 10);
          if (last10 != localPhone) {
            contactNameByLocalPhone[last10] = contact.displayName;
            allContactLocalPhones.add(last10);
          }
        }
      }
    }

    print('Processed contact phone mappings: ${contactNameByLocalPhone.length}');

    // Fetch all users from Firestore
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .get();
    
    print('Found ${usersSnap.docs.length} users in Firestore');

    final List<MatchedContact> matched = [];
    
    for (final doc in usersSnap.docs) {
      try {
        final user = UserModel.fromMap(doc.data());
        if (user.phoneNumber.isEmpty) continue;
        
        final userLocalPhone = PhoneUtils.toLocalNumber(user.phoneNumber);
        if (userLocalPhone.isEmpty) continue;
        
        // Try multiple matching strategies
        String? foundContactName;
        bool isMatched = false;
        
        // Strategy 1: Direct local phone match
        if (contactNameByLocalPhone.containsKey(userLocalPhone)) {
          foundContactName = contactNameByLocalPhone[userLocalPhone];
          isMatched = true;
        }
        
        // Strategy 2: Last 10 digits match
        if (!isMatched && userLocalPhone.length >= 10) {
          final last10 = userLocalPhone.substring(userLocalPhone.length - 10);
          if (contactNameByLocalPhone.containsKey(last10)) {
            foundContactName = contactNameByLocalPhone[last10];
            isMatched = true;
          }
        }
        
        // Strategy 3: Check if any contact phone matches this user
        if (!isMatched) {
          for (final contactPhone in allContactLocalPhones) {
            if (PhoneUtils.areNumbersEqual(contactPhone, userLocalPhone)) {
              foundContactName = contactNameByLocalPhone[contactPhone];
              isMatched = true;
              break;
            }
          }
        }
        
        // Add to matched list if found in contacts OR if you want to show all users
        // Currently only showing users found in contacts
        if (isMatched) {
          matched.add(MatchedContact(
            user: user,
            contactName: foundContactName,
            localPhoneNumber: userLocalPhone,
          ));
          print('Matched: ${user.name} (${foundContactName ?? 'No contact name'}) - $userLocalPhone');
        }
        
      } catch (e) {
        print('Error processing user ${doc.id}: $e');
        continue;
      }
    }

    print('Total matched contacts: ${matched.length}');
    
    // Sort by contact name, then by user name
    matched.sort((a, b) {
      final aName = a.contactName ?? a.user.name;
      final bName = b.contactName ?? b.user.name;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    
    return matched;
    
  } catch (e) {
    print('Error in fetchMatchedContacts: $e');
    return [];
  }
}

// Helper function to get contact name by phone number
Future<String?> getContactNameByPhone(String phoneNumber, String currentUserId) async {
  try {
    final matchedContacts = await fetchMatchedContacts(currentUserId);
    final localPhone = PhoneUtils.toLocalNumber(phoneNumber);
    
    for (final contact in matchedContacts) {
      if (PhoneUtils.areNumbersEqual(contact.localPhoneNumber, localPhone)) {
        return contact.contactName;
      }
    }
    
    return null;
  } catch (e) {
    print('Error getting contact name: $e');
    return null;
  }
}

// Helper function to check if phone number exists in contacts
Future<bool> isPhoneInContacts(String phoneNumber, String currentUserId) async {
  try {
    final contactName = await getContactNameByPhone(phoneNumber, currentUserId);
    return contactName != null;
  } catch (e) {
    print('Error checking if phone in contacts: $e');
    return false;
  }
}
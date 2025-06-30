import 'package:smart_chat_app/utils/contact_utils.dart';
import 'package:smart_chat_app/models/user_model.dart';

class ContactService {
  static ContactService? _instance;
  ContactService._internal();
  factory ContactService() => _instance ??= ContactService._internal();

  // Cache contact mappings
  Map<String, String> _contactNameByLocalPhone = {};
  bool _contactsLoaded = false;
  String? _lastUserId;

  // Get contact mapping (cached)
  Future<Map<String, String>> getContactMapping(String currentUserId) async {
    // Reload if different user or not loaded
    if (!_contactsLoaded || _lastUserId != currentUserId) {
      await _loadContacts(currentUserId);
    }
    return Map.from(_contactNameByLocalPhone);
  }

  // Load contacts from device
  Future<void> _loadContacts(String currentUserId) async {
    try {
      final matchedContacts = await fetchMatchedContacts(currentUserId);
      _contactNameByLocalPhone = {
        for (final mc in matchedContacts)
          if (mc.contactName != null && mc.contactName!.isNotEmpty)
            mc.localPhoneNumber: mc.contactName!
      };
      _contactsLoaded = true;
      _lastUserId = currentUserId;
    } catch (e) {
      _contactsLoaded = true; // Set to true to avoid infinite loading
    }
  }

  // Force refresh contacts
  Future<void> refreshContacts(String currentUserId) async {
    _contactsLoaded = false;
    await _loadContacts(currentUserId);
  }

  // Get display name with fallback priority
  String getDisplayName(String phoneNumber, String registeredName, [Map<String, String>? customMapping]) {
    final mapping = customMapping ?? _contactNameByLocalPhone;
    
    if (phoneNumber.isEmpty) {
      return registeredName.isNotEmpty ? registeredName : 'Unknown';
    }

    final localPhone = PhoneUtils.toLocalNumber(phoneNumber);
    
    // Priority: Contact Name > Formatted Phone > Registered Name > "Unknown"
    final contactName = mapping[localPhone];
    
    if (contactName != null && contactName.isNotEmpty) {
      return contactName; // Contact name from device (highest priority)
    } else if (localPhone.isNotEmpty) {
      return PhoneUtils.formatForDisplay(phoneNumber); // Formatted phone number
    } else if (registeredName.isNotEmpty) {
      return registeredName; // Registered name (third priority)
    }
    
    return 'Unknown';
  }

  // Check if user has contact name
  bool hasContactName(String phoneNumber, [Map<String, String>? customMapping]) {
    final mapping = customMapping ?? _contactNameByLocalPhone;
    if (phoneNumber.isEmpty) return false;
    final localPhone = PhoneUtils.toLocalNumber(phoneNumber);
    return mapping.containsKey(localPhone);
  }

  // Get initials for avatar
  String getInitials(String displayName, String phoneNumber) {
    if (displayName.isNotEmpty && !PhoneUtils.isPhoneNumber(displayName)) {
      // It's a contact name, get initials from name
      final words = displayName.trim().split(' ');
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else if (words[0].isNotEmpty) {
        return words[0][0].toUpperCase();
      }
    }
    
    // It's a phone number or unknown, use last digit or ?
    if (phoneNumber.isNotEmpty) {
      final localPhone = PhoneUtils.toLocalNumber(phoneNumber);
      return localPhone.isNotEmpty ? localPhone.substring(localPhone.length - 1) : '?';
    }
    
    return '?';
  }

  // Get contact name by phone number
  String? getContactNameByPhone(String phoneNumber, [Map<String, String>? customMapping]) {
    final mapping = customMapping ?? _contactNameByLocalPhone;
    final localPhone = PhoneUtils.toLocalNumber(phoneNumber);
    return mapping[localPhone];
  }

  // Filter users by search query
  List<UserModel> filterUsers(List<UserModel> users, String searchQuery, [Map<String, String>? customMapping]) {
    if (searchQuery.trim().isEmpty) return users;
    
    final mapping = customMapping ?? _contactNameByLocalPhone;
    final query = searchQuery.trim().toLowerCase();
    
    return users.where((user) {
      final displayName = getDisplayName(user.phoneNumber, user.name, mapping).toLowerCase();
      final localPhone = user.localPhoneNumber.toLowerCase();
      final userName = user.name.toLowerCase();
      
      return displayName.contains(query) ||
             localPhone.contains(query) ||
             userName.contains(query);
    }).toList();
  }

  // Sort users by display name
  List<UserModel> sortUsers(List<UserModel> users, [Map<String, String>? customMapping]) {
    final mapping = customMapping ?? _contactNameByLocalPhone;
    
    users.sort((a, b) {
      final aName = getDisplayName(a.phoneNumber, a.name, mapping);
      final bName = getDisplayName(b.phoneNumber, b.name, mapping);
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    
    return users;
  }

  // Clear cache (useful for logout)
  void clearCache() {
    _contactNameByLocalPhone.clear();
    _contactsLoaded = false;
    _lastUserId = null;
  }
}
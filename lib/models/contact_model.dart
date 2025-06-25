class ContactModel {
  final String id;
  final String phoneNumber;
  final String? displayName;

  ContactModel({
    required this.id,
    required this.phoneNumber,
    this.displayName,
  });

  // Optionally, add fromMap/toMap if you fetch from Firestore or other sources
  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      displayName: map['displayName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
    };
  }
}
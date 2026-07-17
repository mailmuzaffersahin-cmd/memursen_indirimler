import 'package:cloud_firestore/cloud_firestore.dart';

/// 'authorized_users' koleksiyonundaki bir kullaniciyi temsil eder.
///
/// Geriye donuk uyumluluk icin ESKI alanlar (role, city, district,
/// branchName) da okunur/yazilir; YENI alanlar (roleId, organizationId) ise
/// mevcutsa kullanilir, yoksa null doner. Bkz. FIRESTORE_SCHEMA_TR.md
/// bolum 3 (migration stratejisi).
class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String status; // 'pending' | 'active' | 'suspended' | 'rejected' vb.

  // Eski (legacy) alanlar - hala yaziliyor, henuz kaldirilmiyor.
  final String legacyRole;
  final String city;
  final String district;
  final String branchName;
  final String unionName;

  // Yeni RBAC alanlari - null olabilir (henuz migrate edilmemis kullanicilar icin).
  final String? roleId;
  final String? organizationId;

  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.status,
    required this.legacyRole,
    required this.city,
    required this.district,
    required this.branchName,
    required this.unionName,
    required this.roleId,
    required this.organizationId,
  });

  /// Etkin rol anahtarini dondurur: yeni 'roleId' varsa onu, yoksa eski
  /// 'role' metnini kullanir. Ikisi de yoksa 'guest' doner.
  String get effectiveRoleKey {
    if (roleId != null && roleId!.trim().isNotEmpty) return roleId!;
    if (legacyRole.trim().isNotEmpty) return legacyRole;
    return 'guest';
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      fullName: (data['fullName'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      legacyRole: (data['role'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      district: (data['district'] ?? '').toString(),
      branchName: (data['branchName'] ?? '').toString(),
      unionName: (data['unionName'] ?? '').toString(),
      roleId: data['roleId'] as String?,
      organizationId: data['organizationId'] as String?,
    );
  }

  factory UserProfile.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserProfile.fromMap(doc.id, doc.data() ?? const {});
  }
}

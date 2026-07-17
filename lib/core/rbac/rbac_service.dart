import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:memursen_indirimler/core/models/user_profile.dart';
import 'package:memursen_indirimler/core/rbac/app_role.dart';
import 'package:memursen_indirimler/core/rbac/permission.dart';

/// Rol/yetki kontrolu icin merkezi servis.
///
/// Onemli guvenlik notu: bu servis yalnizca UYGULAMA ICI (UI) kontrol
/// icindir - "bu butonu goster/gizle" gibi kararlar icin kullanilir.
/// GERCEK guvenlik her zaman Firestore/Storage Rules tarafinda saglanmalidir
/// (istemci tarafi kontrolu tek basina yeterli degildir, bkz.
/// SECURITY_RULES_TR.md). Bu servis suistimal degil, sadece kullanici
/// deneyimi icindir.
class RbacService {
  RbacService._();
  static final RbacService instance = RbacService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Firestore 'roles' koleksiyonundan yetki listesini getirir; orada yoksa
  /// veya erisilemezse kod tarafindaki (AppRole) guvenli varsayilana doner.
  Future<List<String>> _permissionsForRoleKey(String roleKey) async {
    try {
      final doc = await _firestore.collection('roles').doc(roleKey).get();
      if (doc.exists) {
        final data = doc.data();
        final perms = data?['permissions'];
        if (perms is List) {
          return perms.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {
      // Firestore'a erisilemezse (offline vb.) kod tarafindaki varsayilana
      // sessizce dus - kullanici deneyimini bozma, gercek yetki kontrolu
      // zaten sunucu tarafinda (Rules) yapiliyor.
    }
    return AppRole.byKey(roleKey).permissions;
  }

  Future<UserProfile?> currentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('authorized_users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserProfile.fromSnapshot(doc);
  }

  /// Mevcut kullanicinin belirtilen yetkiye sahip olup olmadigini kontrol eder.
  Future<bool> hasPermission(String permissionKey) async {
    final profile = await currentUserProfile();
    if (profile == null) return false;
    if (profile.status != 'active') return false;

    final permissions = await _permissionsForRoleKey(profile.effectiveRoleKey);
    return permissions.contains(permissionKey);
  }

  /// Mevcut kullanicinin, belirtilen organizasyon (il/sube) kapsaminda
  /// islem yapip yapamayacagini kontrol eder. super_admin (global kapsam)
  /// her zaman true doner.
  Future<bool> canActOnOrganization(String? targetOrganizationId) async {
    final profile = await currentUserProfile();
    if (profile == null) return false;

    final role = AppRole.byKey(profile.effectiveRoleKey);
    if (role.scope == OrganizationScope.global) return true;
    if (targetOrganizationId == null) return false;

    return profile.organizationId == targetOrganizationId;
  }

  /// Kisayol: hem yetki hem organizasyon kapsami kontrolu birlikte.
  Future<bool> canPerform(String permissionKey, {String? organizationId}) async {
    final hasPerm = await hasPermission(permissionKey);
    if (!hasPerm) return false;
    if (organizationId == null) return true;
    return canActOnOrganization(organizationId);
  }
}

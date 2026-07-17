import 'package:memursen_indirimler/core/rbac/permission.dart';

/// Kod tarafindaki varsayilan (tohum) rol tanimlari.
///
/// Bunlar Firestore 'roles' koleksiyonu henuz olusturulmamissa veya bir rol
/// orada bulunamazsa kullanilan GUVENLI VARSAYILANLARDIR. Yonetim panelinden
/// Firestore'daki karsiliklari duzenlenebilir/genisletilebilir; kod
/// tarafindaki bu liste yalnizca baslangic/geri dusme (fallback) degeridir.
class AppRole {
  final String key;
  final String displayNameTr;
  final bool isSystemRole;
  final OrganizationScope scope;
  final List<String> permissions;

  const AppRole({
    required this.key,
    required this.displayNameTr,
    required this.isSystemRole,
    required this.scope,
    required this.permissions,
  });

  static const superAdmin = AppRole(
    key: 'super_admin',
    displayNameTr: 'Genel Merkez Süper Admin',
    isSystemRole: true,
    scope: OrganizationScope.global,
    permissions: Permission.all,
  );

  static const provinceRep = AppRole(
    key: 'province_rep',
    displayNameTr: 'İl Temsilcisi',
    isSystemRole: true,
    scope: OrganizationScope.province,
    permissions: [
      Permission.view, Permission.create, Permission.edit,
      Permission.deactivate, Permission.submitForApproval,
      Permission.approve, Permission.reject, Permission.requestCorrection,
      Permission.generateReport, Permission.exportExcel,
      Permission.sendNotification,
    ],
  );

  static const branchRep = AppRole(
    key: 'branch_rep',
    displayNameTr: 'Şube Temsilcisi',
    isSystemRole: true,
    scope: OrganizationScope.branch,
    permissions: [
      Permission.view, Permission.create, Permission.edit,
      Permission.submitForApproval, Permission.requestCorrection,
      Permission.generateReport,
    ],
  );

  static const businessOwner = AppRole(
    key: 'business_owner',
    displayNameTr: 'Anlaşmalı İşyeri Yetkilisi',
    isSystemRole: true,
    scope: OrganizationScope.business,
    permissions: [
      Permission.view, Permission.create, Permission.edit,
      Permission.submitForApproval,
    ],
  );

  static const member = AppRole(
    key: 'member',
    displayNameTr: 'Üye',
    isSystemRole: true,
    scope: OrganizationScope.self,
    permissions: [Permission.view],
  );

  static const guest = AppRole(
    key: 'guest',
    displayNameTr: 'Misafir',
    isSystemRole: true,
    scope: OrganizationScope.self,
    permissions: [Permission.view],
  );

  static const contentEditor = AppRole(
    key: 'content_editor',
    displayNameTr: 'İçerik Editörü',
    isSystemRole: false,
    scope: OrganizationScope.province,
    permissions: [Permission.view, Permission.create, Permission.edit],
  );

  static const auditor = AppRole(
    key: 'auditor',
    displayNameTr: 'Denetçi',
    isSystemRole: false,
    scope: OrganizationScope.global,
    permissions: [Permission.view, Permission.viewLogs, Permission.generateReport],
  );

  static const legal = AppRole(
    key: 'legal',
    displayNameTr: 'Hukuk Birimi',
    isSystemRole: false,
    scope: OrganizationScope.global,
    permissions: [Permission.view, Permission.viewLogs],
  );

  static const finance = AppRole(
    key: 'finance',
    displayNameTr: 'Mali İşler',
    isSystemRole: false,
    scope: OrganizationScope.global,
    permissions: [Permission.view, Permission.generateReport, Permission.exportExcel],
  );

  static const communications = AppRole(
    key: 'communications',
    displayNameTr: 'İletişim Birimi',
    isSystemRole: false,
    scope: OrganizationScope.global,
    permissions: [Permission.view, Permission.sendNotification, Permission.publish],
  );

  static const eventManager = AppRole(
    key: 'event_manager',
    displayNameTr: 'Etkinlik Sorumlusu',
    isSystemRole: false,
    scope: OrganizationScope.province,
    permissions: [Permission.view, Permission.create, Permission.edit, Permission.publish],
  );

  static const viewerOnly = AppRole(
    key: 'viewer',
    displayNameTr: 'Sadece Görüntüleme Yetkilisi',
    isSystemRole: false,
    scope: OrganizationScope.province,
    permissions: [Permission.view],
  );

  static const approver = AppRole(
    key: 'approver',
    displayNameTr: 'Onay Yetkilisi',
    isSystemRole: false,
    scope: OrganizationScope.province,
    permissions: [Permission.view, Permission.approve, Permission.reject, Permission.requestCorrection],
  );

  static const support = AppRole(
    key: 'support',
    displayNameTr: 'Destek Personeli',
    isSystemRole: false,
    scope: OrganizationScope.global,
    permissions: [Permission.view],
  );

  static const List<AppRole> seedRoles = [
    superAdmin, provinceRep, branchRep, businessOwner, member, guest,
    contentEditor, auditor, legal, finance, communications, eventManager,
    viewerOnly, approver, support,
  ];

  static AppRole byKey(String? key) {
    return seedRoles.firstWhere(
      (r) => r.key == key,
      orElse: () => guest,
    );
  }
}

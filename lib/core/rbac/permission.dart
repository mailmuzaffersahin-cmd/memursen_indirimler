/// RBAC (rol tabanli erisim kontrolu) sisteminde kullanilan yetki anahtarlari.
///
/// Bu sabitler kod tarafinda referans olarak kullanilir; gercek rol->yetki
/// eslesmesi Firestore 'roles' koleksiyonunda tutulur ve yonetim panelinden
/// duzenlenebilir (bkz. FIRESTORE_SCHEMA_TR.md). Yani yetkiler kodda sabit
/// KODLANMAZ, sadece yetki ISIMLERI burada sabit tanimlanir.
class Permission {
  Permission._();

  static const String view = 'view';
  static const String create = 'create';
  static const String edit = 'edit';
  static const String delete = 'delete';
  static const String deactivate = 'deactivate';
  static const String submitForApproval = 'submit_for_approval';
  static const String approve = 'approve';
  static const String reject = 'reject';
  static const String requestCorrection = 'request_correction';
  static const String publish = 'publish';
  static const String archive = 'archive';
  static const String generateReport = 'generate_report';
  static const String exportExcel = 'export_excel';
  static const String generatePdf = 'generate_pdf';
  static const String sendNotification = 'send_notification';
  static const String manageUsers = 'manage_users';
  static const String grantPermission = 'grant_permission';
  static const String viewLogs = 'view_logs';

  static const List<String> all = [
    view, create, edit, delete, deactivate, submitForApproval, approve,
    reject, requestCorrection, publish, archive, generateReport,
    exportExcel, generatePdf, sendNotification, manageUsers,
    grantPermission, viewLogs,
  ];
}

/// Bir rolun yetkilerinin hangi organizasyon kapsaminda gecerli oldugunu
/// belirtir. Ornegin 'province' -> kullanici yalnizca kendi iline ait
/// kayitlar uzerinde islem yapabilir.
enum OrganizationScope { global, province, branch, business, self }

OrganizationScope organizationScopeFromString(String? value) {
  switch (value) {
    case 'global':
      return OrganizationScope.global;
    case 'province':
      return OrganizationScope.province;
    case 'branch':
      return OrganizationScope.branch;
    case 'business':
      return OrganizationScope.business;
    case 'self':
    default:
      return OrganizationScope.self;
  }
}

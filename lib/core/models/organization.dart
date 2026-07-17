import 'package:cloud_firestore/cloud_firestore.dart';

enum OrganizationType { headquarters, province, branch, district }

OrganizationType organizationTypeFromString(String? value) {
  switch (value) {
    case 'headquarters':
      return OrganizationType.headquarters;
    case 'province':
      return OrganizationType.province;
    case 'branch':
      return OrganizationType.branch;
    case 'district':
      return OrganizationType.district;
    default:
      return OrganizationType.branch;
  }
}

String organizationTypeToString(OrganizationType type) {
  switch (type) {
    case OrganizationType.headquarters:
      return 'headquarters';
    case OrganizationType.province:
      return 'province';
    case OrganizationType.branch:
      return 'branch';
    case OrganizationType.district:
      return 'district';
  }
}

/// 'organizations' koleksiyonundaki bir dokumani temsil eder.
/// Bkz. FIRESTORE_SCHEMA_TR.md bolum 2.
class Organization {
  final String id;
  final String name;
  final OrganizationType type;
  final String? parentId;
  final String? code;
  final bool isActive;

  const Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.parentId,
    required this.code,
    required this.isActive,
  });

  factory Organization.fromMap(String id, Map<String, dynamic> data) {
    return Organization(
      id: id,
      name: (data['name'] ?? '').toString(),
      type: organizationTypeFromString(data['type'] as String?),
      parentId: data['parentId'] as String?,
      code: data['code'] as String?,
      isActive: data['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': organizationTypeToString(type),
      'parentId': parentId,
      'code': code,
      'isActive': isActive,
    };
  }

  factory Organization.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Organization.fromMap(doc.id, doc.data() ?? const {});
  }
}

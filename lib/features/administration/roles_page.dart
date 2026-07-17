import 'package:firebase_storage/firebase_storage.dart';

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:excel/excel.dart' hide Border;

import 'package:file_picker/file_picker.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';

import 'package:geocoding/geocoding.dart';

import 'package:hive/hive.dart';

import 'package:hive_flutter/adapters.dart';


import 'package:memursen_indirimler/firebase_options.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:memursen_indirimler/core/rbac/app_role.dart';
import 'package:memursen_indirimler/core/rbac/permission.dart';

/// Rol ve yetki yönetimi ekranı.
///
/// Kod tarafındaki (AppRole.seedRoles) tanımlar GÜVENLİ VARSAYILAN olarak
/// gösterilir. Bir rolün yetkilerini değiştirmek, Firestore 'roles'
/// koleksiyonunda o rol için bir override dokümanı oluşturur/günceller.
/// Firestore'da override yoksa, kod tarafındaki varsayılan geçerlidir
/// (bkz. RbacService._permissionsForRoleKey). Bu sayede uygulama, hiç
/// Firestore 'roles' dokümanı olmasa bile güvenli çalışmaya devam eder.
class RolesPage extends StatelessWidget {
  const RolesPage({super.key});

  static const Map<String, String> _permissionLabelsTr = {
    Permission.view: 'Görüntüleme',
    Permission.create: 'Ekleme',
    Permission.edit: 'Düzenleme',
    Permission.delete: 'Silme',
    Permission.deactivate: 'Pasife Alma',
    Permission.submitForApproval: 'Onaya Gönderme',
    Permission.approve: 'Onaylama',
    Permission.reject: 'Reddetme',
    Permission.requestCorrection: 'Düzeltme İsteme',
    Permission.publish: 'Yayınlama',
    Permission.archive: 'Arşivleme',
    Permission.generateReport: 'Rapor Alma',
    Permission.exportExcel: 'Excel Aktarma',
    Permission.generatePdf: 'PDF Oluşturma',
    Permission.sendNotification: 'Bildirim Gönderme',
    Permission.manageUsers: 'Kullanıcı Yönetme',
    Permission.grantPermission: 'Yetki Verme',
    Permission.viewLogs: 'Log Görüntüleme',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rol ve Yetki Yönetimi')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: AppRole.seedRoles.length,
        itemBuilder: (context, index) {
          final role = AppRole.seedRoles[index];
          return Card(
            child: ExpansionTile(
              leading: Icon(
                role.isSystemRole ? Icons.verified_user : Icons.badge_outlined,
                color: const Color(0xFF0D1B52),
              ),
              title: Text(role.displayNameTr),
              subtitle: Text(
                '${role.key} • Kapsam: ${_scopeLabelTr(role.scope)}'
                '${role.isSystemRole ? ' • Sistem rolü' : ''}',
              ),
              children: [
                _RolePermissionEditor(role: role, labels: _permissionLabelsTr),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _scopeLabelTr(OrganizationScope scope) {
    switch (scope) {
      case OrganizationScope.global:
        return 'Türkiye Geneli';
      case OrganizationScope.province:
        return 'İl';
      case OrganizationScope.branch:
        return 'Şube';
      case OrganizationScope.business:
        return 'İşyeri';
      case OrganizationScope.self:
        return 'Kendi Hesabı';
    }
  }
}

class _RolePermissionEditor extends StatefulWidget {
  final AppRole role;
  final Map<String, String> labels;

  const _RolePermissionEditor({required this.role, required this.labels});

  @override
  State<_RolePermissionEditor> createState() => _RolePermissionEditorState();
}

class _RolePermissionEditorState extends State<_RolePermissionEditor> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _overrideFuture;

  @override
  void initState() {
    super.initState();
    _overrideFuture = FirebaseFirestore.instance
        .collection('roles')
        .doc(widget.role.key)
        .get();
  }

  Future<void> _save(Set<String> selected) async {
    await FirebaseFirestore.instance.collection('roles').doc(widget.role.key).set({
      'name': widget.role.displayNameTr,
      'key': widget.role.key,
      'isSystemRole': widget.role.isSystemRole,
      'permissions': selected.toList(),
      'scopeType': widget.role.scope.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yetkiler kaydedildi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _overrideFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final overrideData = snapshot.data!.data();
        final currentPermissions = <String>{
          if (overrideData != null && overrideData['permissions'] is List)
            ...List<String>.from(
              (overrideData['permissions'] as List).map((e) => e.toString()),
            )
          else
            ...widget.role.permissions,
        };

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 4,
                    children: Permission.all.map((permKey) {
                      final isSelected = currentPermissions.contains(permKey);
                      return FilterChip(
                        label: Text(widget.labels[permKey] ?? permKey),
                        selected: isSelected,
                        onSelected: widget.role.key == 'super_admin'
                            ? null // super_admin her zaman tam yetkili, degistirilemez
                            : (value) {
                                setInnerState(() {
                                  if (value) {
                                    currentPermissions.add(permKey);
                                  } else {
                                    currentPermissions.remove(permKey);
                                  }
                                });
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  if (widget.role.key != 'super_admin')
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => _save(currentPermissions),
                        child: const Text('Kaydet'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

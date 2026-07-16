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
import 'package:memursen_indirimler/core/utils/app_helpers.dart';
import 'package:memursen_indirimler/core/app_pages.dart';



class UnionOfficerApplicationsPage extends StatelessWidget {
  const UnionOfficerApplicationsPage({super.key});

  String text(Map<String, dynamic> data, String key) => (data[key] ?? '').toString();

  Future<void> updateStatus({
    required String uid,
    required String status,
    bool canCreate = true,
    bool canEdit = true,
    bool canDelete = false,
  }) async {
    await FirebaseFirestore.instance.collection('authorized_users').doc(uid).update({
      'status': status,
      'canCreateAgreement': status == 'active' && canCreate,
      'canEditAgreement': status == 'active' && canEdit,
      'canDeleteAgreement': status == 'active' && canDelete,
      'approvedByUid': FirebaseAuth.instance.currentUser?.uid,
      'approvedByEmail': FirebaseAuth.instance.currentUser?.email,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> openEditDialog(BuildContext context, QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String role = text(data, 'role').isEmpty ? 'Şube Başkanı' : text(data, 'role');
    String status = text(data, 'status').isEmpty ? 'pending' : text(data, 'status');
    bool canCreate = data['canCreateAgreement'] == true;
    bool canEdit = data['canEditAgreement'] == true;
    bool canDelete = data['canDeleteAgreement'] == true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Yetki Düzenle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: unionOfficerRoles.contains(role) ? role : unionOfficerRoles.first,
                      decoration: const InputDecoration(labelText: 'Görev'),
                      items: unionOfficerRoles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (value) => setDialogState(() => role = value ?? role),
                    ),
                    DropdownButtonFormField<String>(
                      value: ['pending', 'active', 'passive'].contains(status) ? status : 'pending',
                      decoration: const InputDecoration(labelText: 'Durum'),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Onay Bekliyor')),
                        DropdownMenuItem(value: 'active', child: Text('Aktif')),
                        DropdownMenuItem(value: 'passive', child: Text('Pasif')),
                      ],
                      onChanged: (value) => setDialogState(() => status = value ?? status),
                    ),
                    CheckboxListTile(
                      value: canCreate,
                      title: const Text('Anlaşma ekleyebilir'),
                      onChanged: (value) => setDialogState(() => canCreate = value ?? false),
                    ),
                    CheckboxListTile(
                      value: canEdit,
                      title: const Text('Anlaşma düzenleyebilir'),
                      onChanged: (value) => setDialogState(() => canEdit = value ?? false),
                    ),
                    CheckboxListTile(
                      value: canDelete,
                      title: const Text('Anlaşma silebilir'),
                      onChanged: (value) => setDialogState(() => canDelete = value ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('authorized_users').doc(doc.id).update({
                      'role': role,
                      'status': status,
                      'canCreateAgreement': status == 'active' && canCreate,
                      'canEditAgreement': status == 'active' && canEdit,
                      'canDeleteAgreement': status == 'active' && canDelete,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color statusColor(String status) {
    if (status == 'active') return Colors.green.shade50;
    if (status == 'passive') return Colors.red.shade50;
    return Colors.orange.shade50;
  }

  String statusText(String status) {
    if (status == 'active') return 'Aktif';
    if (status == 'passive') return 'Pasif';
    return 'Onay bekliyor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sendika Yetkilisi Başvuruları')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('authorized_users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Henüz başvuru yok.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = text(data, 'status');

              return Card(
                color: statusColor(status),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.verified_user, color: Color(0xFF0D1B52)),
                  title: Text(text(data, 'fullName')),
                  subtitle: Text(
                    '${text(data, 'unionName')} • ${text(data, 'city')} • ${text(data, 'branchName')}\n${text(data, 'role')} • ${statusText(status)}\n${text(data, 'email')} • ${text(data, 'phone')}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'approve') {
                        await updateStatus(uid: doc.id, status: 'active');
                      } else if (value == 'passive') {
                        await updateStatus(uid: doc.id, status: 'passive', canCreate: false, canEdit: false, canDelete: false);
                      } else if (value == 'edit') {
                        await openEditDialog(context, doc);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'approve', child: Text('Onayla / Aktif Yap')),
                      PopupMenuItem(value: 'passive', child: Text('Pasif Yap')),
                      PopupMenuItem(value: 'edit', child: Text('Yetki Düzenle')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

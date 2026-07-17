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
import 'package:memursen_indirimler/core/models/organization.dart';

/// Genel Merkez / İl / Şube / İlçe Temsilciliği hiyerarşisini yöneten ekran.
/// Bkz. FIRESTORE_SCHEMA_TR.md bölüm 2 ('organizations' koleksiyonu).
///
/// Not: Bu ekrana erişim şu an mevcut tek admin girişi (AdminGate) ile aynı
/// seviyede korunuyor. İleride RbacService ile daha ince taneli (örn.
/// yalnızca super_admin) kısıtlama eklenebilir.
class OrganizationsPage extends StatefulWidget {
  const OrganizationsPage({super.key});

  @override
  State<OrganizationsPage> createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('organizations');

  Future<void> _seedHeadquarters() async {
    await _collection.add({
      'name': 'Memur-Sen Genel Merkez',
      'type': 'headquarters',
      'parentId': null,
      'code': null,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _openForm({Organization? existing, List<Organization> all = const []}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    OrganizationType selectedType = existing?.type ?? OrganizationType.branch;
    String? selectedParentId = existing?.parentId;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Yeni Organizasyon' : 'Organizasyonu Düzenle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Ad'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<OrganizationType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Tür'),
                      items: OrganizationType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_typeLabel(type)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedParentId,
                      decoration: const InputDecoration(labelText: 'Üst Organizasyon (opsiyonel)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('(Yok - en üst seviye)')),
                        ...all.where((o) => o.id != existing?.id).map((o) {
                          return DropdownMenuItem<String?>(value: o.id, child: Text(o.name));
                        }),
                      ],
                      onChanged: (value) {
                        setDialogState(() => selectedParentId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(labelText: 'Kısa Kod (opsiyonel, ör. plaka kodu)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final data = {
                      'name': name,
                      'type': organizationTypeToString(selectedType),
                      'parentId': selectedParentId,
                      'code': codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                      'isActive': existing?.isActive ?? true,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (existing == null) {
                      data['createdAt'] = FieldValue.serverTimestamp();
                      await _collection.add(data);
                    } else {
                      await _collection.doc(existing.id).update(data);
                    }

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

  String _typeLabel(OrganizationType type) {
    switch (type) {
      case OrganizationType.headquarters:
        return 'Genel Merkez';
      case OrganizationType.province:
        return 'İl';
      case OrganizationType.branch:
        return 'Şube';
      case OrganizationType.district:
        return 'İlçe Temsilciliği';
    }
  }

  Future<void> _toggleActive(Organization org) async {
    await _collection.doc(org.id).update({
      'isActive': !org.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organizasyon Yönetimi')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Yeni'),
        onPressed: () async {
          final snapshot = await _collection.get();
          final all = snapshot.docs.map(Organization.fromSnapshot).toList();
          if (!context.mounted) return;
          _openForm(all: all);
        },
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _collection.orderBy('type').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Veri alınamadı.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final all = docs.map(Organization.fromSnapshot).toList();

          if (all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Henüz organizasyon tanımlanmamış.\nÖnce Genel Merkez kaydını oluşturun.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_business),
                      label: const Text('Genel Merkez Oluştur'),
                      onPressed: _seedHeadquarters,
                    ),
                  ],
                ),
              ),
            );
          }

          String parentName(String? parentId) {
            if (parentId == null) return '';
            final match = all.where((o) => o.id == parentId);
            return match.isEmpty ? '' : match.first.name;
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: all.length,
            itemBuilder: (context, index) {
              final org = all[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    org.isActive ? Icons.apartment : Icons.apartment_outlined,
                    color: org.isActive ? const Color(0xFF0D1B52) : Colors.grey,
                  ),
                  title: Text(org.name),
                  subtitle: Text(
                    '${_typeLabel(org.type)}'
                    '${org.parentId != null ? ' • Üst: ${parentName(org.parentId)}' : ''}'
                    '${org.code != null ? ' • Kod: ${org.code}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: org.isActive,
                        onChanged: (_) => _toggleActive(org),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openForm(existing: org, all: all),
                      ),
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

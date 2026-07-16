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



class AdminAgreementsPage extends StatefulWidget {
  const AdminAgreementsPage({super.key});

  @override
  State<AdminAgreementsPage> createState() => _AdminAgreementsPageState();
}



class _AdminAgreementsPageState extends State<AdminAgreementsPage> {
  final Set<String> selectedDocIds = {};
  String searchText = '';
  bool showOnlyNoLocation = false;
  bool showOnlyExpired = false;

  String getText(Map<String, dynamic> data, String key) {
    return (data[key] ?? '').toString();
  }

  bool hasNoLocation(Map<String, dynamic> data) {
    final latitude = parseDoubleValue(data['latitude']);
    final longitude = parseDoubleValue(data['longitude']);
    return latitude == null || longitude == null;
  }

  bool matchesAdminFilter(Map<String, dynamic> data) {
    final query = searchText.trim().toLowerCase();
    final companyName = getText(data, 'companyName').toLowerCase();
    final phone = getText(data, 'businessPhone').toLowerCase();
    final authorizedPhone = getText(data, 'authorizedPersonPhone').toLowerCase();
    final address = getText(data, 'address').toLowerCase();

    final matchesSearch = query.isEmpty ||
        companyName.contains(query) ||
        phone.contains(query) ||
        authorizedPhone.contains(query) ||
        address.contains(query);

    final matchesLocation = !showOnlyNoLocation || hasNoLocation(data);
    final matchesExpired = !showOnlyExpired || isExpired(data);

    return matchesSearch && matchesLocation && matchesExpired;
  }

  Future<bool> confirmAction(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> deleteAgreement(String docId) async {
    await FirebaseFirestore.instance.collection('agreements').doc(docId).delete();
  }

  Future<void> toggleActive(String docId, bool value) async {
    await FirebaseFirestore.instance.collection('agreements').doc(docId).update({
      'isActive': !value,
      'expiredAutomatically': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> autoExpireAgreement(String docId, Map<String, dynamic> data) async {
    if (data['isActive'] == true && isExpired(data)) {
      await FirebaseFirestore.instance.collection('agreements').doc(docId).update({
        'isActive': false,
        'expiredAutomatically': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> deleteSelected() async {
    if (selectedDocIds.isEmpty) return;

    final confirmed = await confirmAction(
      context,
      title: 'Toplu Silme Onayı',
      message:
          '${selectedDocIds.length} anlaşma kalıcı olarak silinecek. Devam etmek istiyor musunuz?',
    );

    if (!confirmed) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final docId in selectedDocIds) {
      final ref = FirebaseFirestore.instance.collection('agreements').doc(docId);
      batch.delete(ref);
    }

    await batch.commit();

    if (!mounted) return;
    setState(() => selectedDocIds.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seçilen anlaşmalar silindi.')),
    );
  }

  Future<void> passiveSelected() async {
    if (selectedDocIds.isEmpty) return;

    final confirmed = await confirmAction(
      context,
      title: 'Toplu Pasif Yapma',
      message:
          '${selectedDocIds.length} anlaşma pasif hale getirilecek. Devam etmek istiyor musunuz?',
    );

    if (!confirmed) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final docId in selectedDocIds) {
      final ref = FirebaseFirestore.instance.collection('agreements').doc(docId);
      batch.update(ref, {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    if (!mounted) return;
    setState(() => selectedDocIds.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seçilen anlaşmalar pasif yapıldı.')),
    );
  }

  Future<void> extendExpiredOneMonth(List<QueryDocumentSnapshot> docs) async {
    final expiredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return isExpired(data);
    }).toList();

    if (expiredDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Süresi biten anlaşma bulunamadı.')),
      );
      return;
    }

    final confirmed = await confirmAction(
      context,
      title: 'Süresi Bitenleri Uzat',
      message:
          '${expiredDocs.length} süresi biten anlaşma 1 ay uzatılacak ve aktif yapılacak. Devam etmek istiyor musunuz?',
    );

    if (!confirmed) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in expiredDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final oldEndDate = parseDateValue(data['endDate']) ?? DateTime.now();
      final newEndDate = DateTime(
        oldEndDate.year,
        oldEndDate.month + 1,
        oldEndDate.day,
      );

      batch.update(doc.reference, {
        'endDate': Timestamp.fromDate(newEndDate),
        'isActive': true,
        'expiredAutomatically': false,
        'extendedAutomatically': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Süresi biten anlaşmalar 1 ay uzatıldı.')),
    );
  }

  void toggleSelection(String docId) {
    setState(() {
      if (selectedDocIds.contains(docId)) {
        selectedDocIds.remove(docId);
      } else {
        selectedDocIds.add(docId);
      }
    });
  }

  void selectAll(List<QueryDocumentSnapshot> docs) {
    setState(() {
      selectedDocIds
        ..clear()
        ..addAll(docs.map((doc) => doc.id));
    });
  }

  void clearSelection() {
    setState(() => selectedDocIds.clear());
  }

  Widget topActionBar(List<QueryDocumentSnapshot> visibleDocs) {
    final selectedCount = selectedDocIds.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            onChanged: (value) => setState(() => searchText = value),
            decoration: InputDecoration(
              hintText: 'İşyeri adı, telefon veya adres ara...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: const Text('Konumu Olmayanlar'),
                  selected: showOnlyNoLocation,
                  onSelected: (value) {
                    setState(() {
                      showOnlyNoLocation = value;
                      selectedDocIds.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('Süresi Bitenler'),
                  selected: showOnlyExpired,
                  onSelected: (value) {
                    setState(() {
                      showOnlyExpired = value;
                      selectedDocIds.clear();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: visibleDocs.isEmpty ? null : () => selectAll(visibleDocs),
                icon: const Icon(Icons.select_all),
                label: const Text('Tümünü Seç'),
              ),
              OutlinedButton.icon(
                onPressed: selectedCount == 0 ? null : clearSelection,
                icon: const Icon(Icons.clear),
                label: Text('Seçimi Temizle ($selectedCount)'),
              ),
              ElevatedButton.icon(
                onPressed: selectedCount == 0 ? null : passiveSelected,
                icon: const Icon(Icons.visibility_off),
                label: const Text('Pasif Yap'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: selectedCount == 0 ? null : deleteSelected,
                icon: const Icon(Icons.delete),
                label: const Text('Seçilenleri Sil'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => extendExpiredOneMonth(visibleDocs),
                icon: const Icon(Icons.update),
                label: const Text('Süresi Bitenleri 1 Ay Uzat'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anlaşmaları Yönet'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('agreements').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;

          final visibleDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return matchesAdminFilter(data);
          }).toList();

          visibleDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            return getText(dataA, 'companyName')
                .toLowerCase()
                .compareTo(getText(dataB, 'companyName').toLowerCase());
          });

          return Column(
            children: [
              topActionBar(visibleDocs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Toplam: ${visibleDocs.length} | Seçilen: ${selectedDocIds.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleDocs.isEmpty
                    ? const Center(child: Text('Bu filtreye uygun anlaşma bulunamadı.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleDocs.length,
                        itemBuilder: (context, index) {
                          final doc = visibleDocs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          Future.microtask(() => autoExpireAgreement(doc.id, data));

                          final expired = isExpired(data);
                          final isActive = data['isActive'] == true && !expired;
                          final selected = selectedDocIds.contains(doc.id);
                          final noLocation = hasNoLocation(data);

                          return Card(
                            color: selected
                                ? Colors.blue.shade50
                                : expired
                                    ? Colors.red.shade50
                                    : noLocation
                                        ? Colors.orange.shade50
                                        : null,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onLongPress: () => toggleSelection(doc.id),
                              onTap: selectedDocIds.isNotEmpty
                                  ? () => toggleSelection(doc.id)
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditAgreementPage(
                                            docId: doc.id,
                                            data: data,
                                          ),
                                        ),
                                      );
                                    },
                              leading: Checkbox(
                                value: selected,
                                onChanged: (_) => toggleSelection(doc.id),
                              ),
                              title: Text(getText(data, 'companyName')),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${getText(data, 'discountRate')} • ${isActive ? 'Aktif' : 'Pasif'} • Bitiş: ${formatDate(data['endDate'])}',
                                  ),
                                  if (noLocation)
                                    const Text(
                                      'Konum bilgisi eksik',
                                      style: TextStyle(
                                        color: Colors.deepOrange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: isActive ? 'Pasif yap' : 'Aktif yap',
                                    icon: Icon(
                                      isActive ? Icons.toggle_on : Icons.toggle_off,
                                      color: isActive ? Colors.green : Colors.grey,
                                    ),
                                    onPressed: () => toggleActive(doc.id, isActive),
                                  ),
                                  IconButton(
                                    tooltip: 'Sil',
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final confirmed = await confirmAction(
                                        context,
                                        title: 'Silme Onayı',
                                        message:
                                            '${getText(data, 'companyName')} kaydı silinecek. Devam etmek istiyor musunuz?',
                                      );
                                      if (confirmed) {
                                        await deleteAgreement(doc.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

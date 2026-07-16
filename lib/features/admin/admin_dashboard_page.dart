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



class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  Future<void> importRepresentativesExcel(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    final excel = Excel.decodeBytes(bytes);
    int count = 0;

    for (final tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName];
      if (sheet == null) continue;

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        final city = cleanCellValue(row, 0);
        if (city.isEmpty) continue;

        final docId = city
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll('ı', 'i')
            .replaceAll('ğ', 'g')
            .replaceAll('ü', 'u')
            .replaceAll('ş', 's')
            .replaceAll('ö', 'o')
            .replaceAll('ç', 'c');

        await FirebaseFirestore.instance
            .collection('temsilciler')
            .doc(docId)
            .set({
          'city': city,
          'name': cleanCellValue(row, 1),
          'title': cleanCellValue(row, 2),
          'phone': cleanCellValue(row, 3),
          'mobile': cleanCellValue(row, 4),
          'email': cleanCellValue(row, 5),
          'address': cleanCellValue(row, 6),
          'latitude': parseDoubleValue(cleanCellValue(row, 7)),
          'longitude': parseDoubleValue(cleanCellValue(row, 8)),
          'website': cleanCellValue(row, 9),
          'isGeneralCenter': cleanCellValue(row, 10).toUpperCase() == 'EVET',
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        count++;
      }
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count temsilcilik Firestore’a yüklendi.')),
    );
  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Temsilcilik yükleme hatası: $e')),
    );
  }
}

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> importExcelToFirestore(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null) return;

      final Uint8List? bytes = result.files.single.bytes;

      if (bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel dosyası okunamadı.')),
        );
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      int addedCount = 0;

      for (final tableName in excel.tables.keys) {
        final sheet = excel.tables[tableName];
        if (sheet == null) continue;

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          final companyName = cleanCellValue(row, 0);

          if (companyName.trim().isEmpty) continue;

          final startDate = parseDateValue(cleanCellValue(row, 12));
          final endDate = parseDateValue(cleanCellValue(row, 13));

          await FirebaseFirestore.instance.collection('agreements').add({
            'companyName': companyName,
            'title': cleanCellValue(row, 1),
            'category': cleanCellValue(row, 2),
            'discountRate': cleanCellValue(row, 3),
            'city': cleanCellValue(row, 4),
            'district': cleanCellValue(row, 5),
            'address': cleanCellValue(row, 6),
            'authorizedPersonName': cleanCellValue(row, 7),
            'authorizedPersonPhone': cleanCellValue(row, 8),
            'businessPhone': cleanCellValue(row, 9),
            'description': cleanCellValue(row, 10),
            'scopeType': cleanCellValue(row, 11).isEmpty ? 'city' : cleanCellValue(row, 11),
            'startDate': startDate == null ? null : Timestamp.fromDate(startDate),
            'endDate': endDate == null ? null : Timestamp.fromDate(endDate),
            'latitude': parseDoubleValue(cleanCellValue(row, 14)),
            'longitude': parseDoubleValue(cleanCellValue(row, 15)),
            'isActive': endDate == null ||
                !DateTime(endDate.year, endDate.month, endDate.day).isBefore(todayOnly()),
            'expiredAutomatically': false,
            'isFeatured': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          addedCount++;
        }
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$addedCount anlaşma başarıyla yüklendi.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel yükleme hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetim Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Giriş yapan: ${user?.email ?? ''}'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Yeni Anlaşma Ekle'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddAgreementPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Temsilcilikleri Excel’den Yükle'),
            onPressed: () => importRepresentativesExcel(context),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.business_center),
            label: const Text('İşyeri Başvuruları'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessApplicationsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.verified_user),
            label: const Text('Sendika Yetkilisi Başvuruları'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UnionOfficerApplicationsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.badge),
            label: const Text('Temsilci Bilgilerini Düzenle'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RepresentativeSettingsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text("Excel'den Toplu Yükle"),
            onPressed: () => importExcelToFirestore(context),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.list_alt),
            label: const Text('Anlaşmaları Yönet'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminAgreementsPage()),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Excel sütun sırası: Firma Adı, Başlık, Kategori, İndirim, İl, İlçe, Adres, Yetkili Ad Soyad, Yetkili Telefon, Kurumsal Telefon, Açıklama, Kapsam, Başlangıç Tarihi, Bitiş Tarihi, Enlem, Boylam',
          ),
        ],
      ),
    );
  }
}

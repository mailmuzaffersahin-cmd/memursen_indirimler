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



DateTime todayOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}



DateTime? parseDateValue(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  try {
    return DateTime.parse(text);
  } catch (_) {}

  final parts = text.split('.');
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }

  return null;
}



String formatDate(dynamic value) {
  final date = parseDateValue(value);
  if (date == null) return '';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day.$month.$year';
}



bool isExpired(Map<String, dynamic> data) {
  final endDate = parseDateValue(data['endDate']);
  if (endDate == null) return false;
  final onlyEndDate = DateTime(endDate.year, endDate.month, endDate.day);
  return onlyEndDate.isBefore(todayOnly());
}



String cleanCellValue(List<Data?> row, int index) {
  if (index >= row.length) return '';
  final cell = row[index];
  if (cell == null || cell.value == null) return '';
  return cell.value.toString().trim();
}



double? parseDoubleValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value.toDouble();
  if (value is double) return value;

  final text = value.toString().trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}



double? agreementDistanceKm(Position? position, Map<String, dynamic> data) {
  if (position == null) return null;

  final latitude = parseDoubleValue(data['latitude']);
  final longitude = parseDoubleValue(data['longitude']);

  if (latitude == null || longitude == null) return null;

  final meters = Geolocator.distanceBetween(
    position.latitude,
    position.longitude,
    latitude,
    longitude,
  );

  return meters / 1000;
}



String distanceText(double? km) {
  if (km == null) return 'Konum bilgisi yok';

  if (km.isNaN || km.isInfinite) {
    return 'Konum bilgisi yok';
  }

  if (km < 0 || km > 500) {
    return 'Konum bilgisi yok';
  }

  return '${km.toStringAsFixed(1)} km uzaklıkta';
}




String safeStorageFileName(String fileName) {
  final cleaned = fileName
      // ignore: deprecated_member_use
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\.\-]'), '_')
      .replaceAll('__', '_');
  return cleaned.isEmpty ? 'dosya' : cleaned;
}



String contentTypeFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}



Future<String?> uploadBytesToStorage({
  required Uint8List? bytes,
  required String folder,
  required String? fileName,
}

) async {
  if (bytes == null || fileName == null || fileName.trim().isEmpty) return null;

  final safeName = safeStorageFileName(fileName);
  final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';

  final ref = FirebaseStorage.instance.ref().child(path);
  final metadata = SettableMetadata(
    contentType: contentTypeFromFileName(fileName),
  );

  await ref.putData(bytes, metadata);
  return ref.getDownloadURL();
}



bool isImageUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.contains('image%2f') ||
      lower.contains('image/');
}





const String defaultRepresentativeName = 'Mehmet Emin ASLANTÜRK';


const String defaultRepresentativeTitle = 'Memur-Sen Kayseri İl Temsilcisi';


const String defaultRepresentativePhone = '0 352 231 2541';


const String defaultRepresentativeMobile = '0 535 658 05 04';


const String defaultRepresentativeEmail = 'kayseri1@ebs.org.tr';



Map<String, String> representativeDefaults() {
  return {
    'name': defaultRepresentativeName,
    'title': defaultRepresentativeTitle,
    'phone': defaultRepresentativePhone,
    'mobile': defaultRepresentativeMobile,
    'email': defaultRepresentativeEmail,
  };
}



String representativeValue(Map<String, dynamic>? data, String key) {
  final defaults = representativeDefaults();
  final value = data?[key]?.toString().trim();
  if (value == null || value.isEmpty) return defaults[key] ?? '';
  return value;
}





const List<String> turkeyCities = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya', 'Ankara',
  'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir', 'Bartın', 'Batman',
  'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa',
  'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne',
  'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun',
  'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul', 'İzmir',
  'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri',
  'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kilis', 'Kocaeli', 'Konya',
  'Kütahya', 'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
  'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun',
  'Siirt', 'Sinop', 'Sivas', 'Şanlıurfa', 'Şırnak', 'Tekirdağ', 'Tokat',
  'Trabzon', 'Tunceli', 'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak'
];



const List<String> unionNames = [
  'Eğitim-Bir-Sen',
  'Bem-Bir-Sen',
  'Büro Memur-Sen',
  'Diyanet-Sen',
  'Enerji Bir-Sen',
  'Genç Memur-Sen',
  'Kültür Memur-Sen',
  'Memur-Sen',
  'Sağlık-Sen',
  'Toç Bir-Sen',
  'Ulaştırma Memur-Sen',
];



const List<String> unionOfficerRoles = [
  'Genel Yönetici',
  'İl Temsilcisi',
  'Şube Başkanı',
  'Teşkilatlanmadan Sorumlu Başkan Yardımcısı',
  'Teşkilatlanma Temsilci Yardımcısı',
  'İşyeri Yetkilisi',
];



String getCurrentUserRoleText(Map<String, dynamic>? data) {
  if (data == null) return 'Yetki kaydı bulunamadı';
  final status = (data['status'] ?? '').toString();
  final role = (data['role'] ?? '').toString();
  final city = (data['city'] ?? '').toString();
  final branch = (data['branchName'] ?? '').toString();
  if (status != 'active') return 'Onay bekliyor / Pasif';
  return '$role • $city • $branch';
}

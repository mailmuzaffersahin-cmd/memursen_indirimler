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




class AddAgreementPage extends StatefulWidget {
  const AddAgreementPage({super.key});

  @override
  State<AddAgreementPage> createState() => _AddAgreementPageState();
}



class _AddAgreementPageState extends State<AddAgreementPage> {
  final companyName = TextEditingController();
  final title = TextEditingController();
  final category = TextEditingController();
  final discountRate = TextEditingController();
  final city = TextEditingController(text: 'Kayseri');
  final district = TextEditingController();
  final address = TextEditingController();
  final authorizedPersonName = TextEditingController();
  final authorizedPersonPhone = TextEditingController();
  final businessPhone = TextEditingController();
  final description = TextEditingController();
  final startDate = TextEditingController();
  final endDate = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();

  Uint8List? logoBytes;
  String? logoFileName;

  Uint8List? agreementFileBytes;
  String? agreementFileName;

  bool isFeatured = false;
  bool saving = false;

  Future<void> pickDate(TextEditingController controller) async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: parseDateValue(controller.text) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    controller.text = formatDate(selected);
  }

  Future<void> pickLogoFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      logoBytes = result.files.single.bytes;
      logoFileName = result.files.single.name;
    });
  }

  Future<void> pickAgreementFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      agreementFileBytes = result.files.single.bytes;
      agreementFileName = result.files.single.name;
    });
  }

  Future<void> saveAgreement() async {
    final parsedStartDate = parseDateValue(startDate.text);
    final parsedEndDate = parseDateValue(endDate.text);

    setState(() => saving = true);

    try {
      final logoUrl = await uploadBytesToStorage(
        bytes: logoBytes,
        folder: 'agreement_logos',
        fileName: logoFileName,
      );

      final agreementFileUrl = await uploadBytesToStorage(
        bytes: agreementFileBytes,
        folder: 'agreement_files',
        fileName: agreementFileName,
      );

      await FirebaseFirestore.instance.collection('agreements').add({
        'companyName': companyName.text.trim(),
        'title': title.text.trim(),
        'category': category.text.trim(),
        'discountRate': discountRate.text.trim(),
        'city': city.text.trim(),
        'district': district.text.trim(),
        'address': address.text.trim(),
        'authorizedPersonName': authorizedPersonName.text.trim(),
        'authorizedPersonPhone': authorizedPersonPhone.text.trim(),
        'businessPhone': businessPhone.text.trim(),
        'description': description.text.trim(),
        'scopeType': 'city',
        'startDate': parsedStartDate == null ? null : Timestamp.fromDate(parsedStartDate),
        'endDate': parsedEndDate == null ? null : Timestamp.fromDate(parsedEndDate),
        'latitude': parseDoubleValue(latitude.text),
        'longitude': parseDoubleValue(longitude.text),
        'logoUrl': logoUrl,
        'agreementFileUrl': agreementFileUrl,
        'agreementFileName': agreementFileName,
        'isActive': parsedEndDate == null ||
            !DateTime(parsedEndDate.year, parsedEndDate.month, parsedEndDate.day).isBefore(todayOnly()),
        'expiredAutomatically': false,
        'isFeatured': isFeatured,
        'createdByUid': FirebaseAuth.instance.currentUser?.uid,
        'createdByEmail': FirebaseAuth.instance.currentUser?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => saving = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt/yükleme hatası: $e')),
      );
    }
  }

  Widget input(String label, TextEditingController controller,
      {int maxLines = 1, bool isDate = false, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: isDate,
        maxLines: maxLines,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : label.toLowerCase().contains('telefon')
                ? TextInputType.phone
                : null,
        onTap: isDate ? () => pickDate(controller) : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: isDate ? 'gg.aa.yyyy' : null,
          suffixIcon: isDate ? const Icon(Icons.calendar_month) : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget selectedFileCard({
    required String title,
    required String? fileName,
    required IconData icon,
  }) {
    return Card(
      color: fileName == null ? Colors.grey.shade100 : Colors.green.shade50,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0D1B52)),
        title: Text(title),
        subtitle: Text(fileName ?? 'Henüz dosya seçilmedi'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Anlaşma Ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          input('Firma Adı', companyName),
          input('Anlaşma Başlığı', title),
          input('Kategori', category),
          input('İndirim Oranı', discountRate),
          input('Başlangıç Tarihi', startDate, isDate: true),
          input('Bitiş Tarihi', endDate, isDate: true),
          input('İl', city),
          input('İlçe', district),
          input('Adres', address, maxLines: 2),
          input('Enlem', latitude, isNumber: true),
          input('Boylam', longitude, isNumber: true),

          const Divider(height: 28),
          const Text(
            'Logo ve Anlaşma Dosyaları',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          selectedFileCard(
            title: 'İşyeri Logosu',
            fileName: logoFileName,
            icon: Icons.image,
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : pickLogoFile,
            icon: const Icon(Icons.upload),
            label: const Text('İşyeri Logosu Seç (PNG/JPG)'),
          ),
          const SizedBox(height: 8),
          selectedFileCard(
            title: 'Anlaşma Metni / Sözleşme Dosyası',
            fileName: agreementFileName,
            icon: Icons.picture_as_pdf,
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : pickAgreementFile,
            icon: const Icon(Icons.attach_file),
            label: const Text('PDF veya Görsel Seç (PDF/PNG/JPG)'),
          ),

          const Divider(height: 28),
          SwitchListTile(
            title: const Text('Öne Çıkan Firma'),
            subtitle: const Text('Ana sayfada üst bölümde gösterilir'),
            value: isFeatured,
            onChanged: (value) {
              setState(() {
                isFeatured = value;
              });
            },
          ),
          input('Yetkili Kişi Adı Soyadı', authorizedPersonName),
          input('Yetkili Kişi Telefonu', authorizedPersonPhone),
          input('İşyeri Kurumsal Telefonu', businessPhone),
          input('Açıklama', description, maxLines: 4),
          ElevatedButton.icon(
            onPressed: saving ? null : saveAgreement,
            icon: const Icon(Icons.save),
            label: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
          ),
        ],
      ),
    );
  }
}

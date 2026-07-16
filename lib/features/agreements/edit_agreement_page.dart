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



class EditAgreementPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditAgreementPage({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditAgreementPage> createState() => _EditAgreementPageState();
}



class _EditAgreementPageState extends State<EditAgreementPage> {
  late TextEditingController companyName;
  late TextEditingController title;
  late TextEditingController category;
  late TextEditingController discountRate;
  late TextEditingController city;
  late TextEditingController district;
  late TextEditingController address;
  late TextEditingController authorizedPersonName;
  late TextEditingController authorizedPersonPhone;
  late TextEditingController businessPhone;
  late TextEditingController description;
  late TextEditingController startDate;
  late TextEditingController endDate;
  late TextEditingController latitude;
  late TextEditingController longitude;

  Uint8List? logoBytes;
  String? logoFileName;
  String? currentLogoUrl;

  Uint8List? agreementFileBytes;
  String? agreementFileName;
  String? currentAgreementFileUrl;
  String? currentAgreementFileName;

  bool isFeatured = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    companyName = TextEditingController(text: widget.data['companyName'] ?? '');
    title = TextEditingController(text: widget.data['title'] ?? '');
    category = TextEditingController(text: widget.data['category'] ?? '');
    discountRate = TextEditingController(text: widget.data['discountRate'] ?? '');
    city = TextEditingController(text: widget.data['city'] ?? '');
    district = TextEditingController(text: widget.data['district'] ?? '');
    address = TextEditingController(text: widget.data['address'] ?? '');
    authorizedPersonName = TextEditingController(text: widget.data['authorizedPersonName'] ?? '');
    authorizedPersonPhone = TextEditingController(text: widget.data['authorizedPersonPhone'] ?? '');
    businessPhone = TextEditingController(text: widget.data['businessPhone'] ?? '');
    description = TextEditingController(text: widget.data['description'] ?? '');
    startDate = TextEditingController(text: formatDate(widget.data['startDate']));
    endDate = TextEditingController(text: formatDate(widget.data['endDate']));
    latitude = TextEditingController(text: widget.data['latitude']?.toString() ?? '');
    longitude = TextEditingController(text: widget.data['longitude']?.toString() ?? '');

    currentLogoUrl = (widget.data['logoUrl'] ?? widget.data['imageUrl'])?.toString();
    currentAgreementFileUrl = widget.data['agreementFileUrl']?.toString();
    currentAgreementFileName = widget.data['agreementFileName']?.toString();

    isFeatured = widget.data['isFeatured'] ?? false;
  }

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

  Future<void> updateAgreement() async {
    final parsedStartDate = parseDateValue(startDate.text);
    final parsedEndDate = parseDateValue(endDate.text);

    setState(() => saving = true);

    try {
      final uploadedLogoUrl = await uploadBytesToStorage(
        bytes: logoBytes,
        folder: 'agreement_logos',
        fileName: logoFileName,
      );

      final uploadedAgreementFileUrl = await uploadBytesToStorage(
        bytes: agreementFileBytes,
        folder: 'agreement_files',
        fileName: agreementFileName,
      );

      await FirebaseFirestore.instance.collection('agreements').doc(widget.docId).update({
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
        'startDate': parsedStartDate == null ? null : Timestamp.fromDate(parsedStartDate),
        'endDate': parsedEndDate == null ? null : Timestamp.fromDate(parsedEndDate),
        'latitude': parseDoubleValue(latitude.text),
        'longitude': parseDoubleValue(longitude.text),
        'logoUrl': uploadedLogoUrl ?? currentLogoUrl,
        'agreementFileUrl': uploadedAgreementFileUrl ?? currentAgreementFileUrl,
        'agreementFileName': agreementFileName ?? currentAgreementFileName,
        'isActive': parsedEndDate == null ||
            !DateTime(parsedEndDate.year, parsedEndDate.month, parsedEndDate.day).isBefore(todayOnly()),
        'expiredAutomatically': false,
        'isFeatured': isFeatured,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => saving = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncelleme/yükleme hatası: $e')),
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
    required String? selectedFileName,
    required String? existingUrl,
    required IconData icon,
    VoidCallback? onOpenExisting,
  }) {
    final subtitle = selectedFileName ??
        (existingUrl != null && existingUrl.trim().isNotEmpty
            ? 'Mevcut dosya yüklü'
            : 'Henüz dosya seçilmedi');

    return Card(
      color: selectedFileName != null
          ? Colors.green.shade50
          : (existingUrl != null && existingUrl.trim().isNotEmpty)
              ? Colors.blue.shade50
              : Colors.grey.shade100,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0D1B52)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: existingUrl != null && existingUrl.trim().isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: onOpenExisting,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final end = parseDateValue(endDate.text);
    final expired = end != null && DateTime(end.year, end.month, end.day).isBefore(todayOnly());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anlaşmayı Düzenle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (expired)
            Card(
              color: Colors.red.shade50,
              child: const ListTile(
                leading: Icon(Icons.warning, color: Colors.red),
                title: Text('Bu anlaşmanın bitiş tarihi geçmiştir.'),
                subtitle: Text('Güncellerseniz sistem otomatik pasif yapar.'),
              ),
            ),
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
            selectedFileName: logoFileName,
            existingUrl: currentLogoUrl,
            icon: Icons.image,
            onOpenExisting: currentLogoUrl == null || currentLogoUrl!.trim().isEmpty
                ? null
                : () => launchUrl(Uri.parse(currentLogoUrl!), mode: LaunchMode.externalApplication),
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : pickLogoFile,
            icon: const Icon(Icons.upload),
            label: const Text('Yeni Logo Seç (PNG/JPG)'),
          ),
          const SizedBox(height: 8),
          selectedFileCard(
            title: 'Anlaşma Metni / Sözleşme Dosyası',
            selectedFileName: agreementFileName,
            existingUrl: currentAgreementFileUrl,
            icon: Icons.picture_as_pdf,
            onOpenExisting: currentAgreementFileUrl == null || currentAgreementFileUrl!.trim().isEmpty
                ? null
                : () => launchUrl(Uri.parse(currentAgreementFileUrl!), mode: LaunchMode.externalApplication),
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : pickAgreementFile,
            icon: const Icon(Icons.attach_file),
            label: const Text('Yeni PDF veya Görsel Seç'),
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
            onPressed: saving ? null : updateAgreement,
            icon: const Icon(Icons.save),
            label: Text(saving ? 'Güncelleniyor...' : 'Güncelle'),
          ),
        ],
      ),
    );
  }
}

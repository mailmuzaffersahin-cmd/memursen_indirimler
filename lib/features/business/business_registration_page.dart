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



class BusinessRegistrationPage extends StatefulWidget {
  const BusinessRegistrationPage({super.key});

  @override
  State<BusinessRegistrationPage> createState() => _BusinessRegistrationPageState();
}



class _BusinessRegistrationPageState extends State<BusinessRegistrationPage> {
  final companyName = TextEditingController();
  final ownerName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final city = TextEditingController(text: 'Kayseri');
  final district = TextEditingController();
  final address = TextEditingController();
  final discountRate = TextEditingController();
  final branchName = TextEditingController();
  final branchPhone = TextEditingController();
  final branchAddress = TextEditingController();
  final password = TextEditingController();

  bool wantsPasswordLogin = false;
  bool hasMultipleBranches = false;
  bool saving = false;

  Widget input(String label, TextEditingController controller,
      {int maxLines = 1, bool obscureText = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> saveApplication() async {
    if (companyName.text.trim().isEmpty || phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firma adı ve telefon zorunludur.')),
      );
      return;
    }

    setState(() => saving = true);

    await FirebaseFirestore.instance.collection('business_applications').add({
      'companyName': companyName.text.trim(),
      'ownerName': ownerName.text.trim(),
      'phone': phone.text.trim(),
      'email': email.text.trim(),
      'city': city.text.trim(),
      'district': district.text.trim(),
      'address': address.text.trim(),
      'discountRate': discountRate.text.trim(),
      'wantsPasswordLogin': wantsPasswordLogin,
      'passwordRequested': wantsPasswordLogin,
      'status': 'pending',
      'contractStatus': 'not_uploaded',
      'hasMultipleBranches': hasMultipleBranches,
      'branches': hasMultipleBranches
          ? [
              {
                'branchName': branchName.text.trim(),
                'phone': branchPhone.text.trim(),
                'address': branchAddress.text.trim(),
                'latitude': null,
                'longitude': null,
              }
            ]
          : [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    setState(() => saving = false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Başvuru Alındı'),
        content: const Text('İşyeri başvurunuz kaydedildi. Sözleşme çıktısını alıp imzaladıktan sonra yetkiliye teslim edebilirsiniz.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void openContractPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractPreviewPage(
          companyName: companyName.text.trim(),
          ownerName: ownerName.text.trim(),
          phone: phone.text.trim(),
          address: address.text.trim(),
          discountRate: discountRate.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İşyeri Kayıt Ol')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: Color(0xFFF4F1FA),
            child: ListTile(
              leading: Icon(Icons.info, color: Color(0xFF0D1B52)),
              title: Text('Anlaşmalı işyeri başvurusu'),
              subtitle: Text('Bilgilerinizi doldurun, sözleşme çıktısını alın ve imzalı şekilde teslim/yükleme sürecine geçin.'),
            ),
          ),
          input('Firma / İşyeri Adı *', companyName),
          input('Yetkili Ad Soyad', ownerName),
          input('Telefon *', phone, keyboardType: TextInputType.phone),
          input('E-posta', email, keyboardType: TextInputType.emailAddress),
          input('İl', city),
          input('İlçe', district),
          input('Adres', address, maxLines: 3),
          input('Sunulacak İndirim / Kampanya', discountRate),
          const Divider(height: 28),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: hasMultipleBranches,
            title: const Text('Birden fazla şubem var'),
            subtitle: const Text('Farklı şube bilgisi girecekseniz işaretleyin.'),
            onChanged: (value) {
              setState(() {
                hasMultipleBranches = value ?? false;
                if (!hasMultipleBranches) {
                  branchName.clear();
                  branchPhone.clear();
                  branchAddress.clear();
                }
              });
            },
          ),
          if (hasMultipleBranches) ...[
            const SizedBox(height: 8),
            const Text('Şube Bilgileri', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            input('Şube Adı', branchName),
            input('Şube Telefonu', branchPhone, keyboardType: TextInputType.phone),
            input('Şube Adresi', branchAddress, maxLines: 2),
          ],
          const Divider(height: 28),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('app_settings')
                .doc('representative')
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              return Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: const Icon(Icons.badge, color: Color(0xFF0D1B52)),
                  title: Text(representativeValue(data, 'name')),
                  subtitle: Text(
                    '${representativeValue(data, 'title')}\n'
                    '${representativeValue(data, 'phone')}\n'
                    '${representativeValue(data, 'mobile')}\n'
                    '${representativeValue(data, 'email')}',
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Şifreli işyeri girişi istiyorum'),
            subtitle: const Text('İşyeri daha sonra kendi bilgileriyle giriş yapabilir.'),
            value: wantsPasswordLogin,
            onChanged: (value) => setState(() => wantsPasswordLogin = value),
          ),
          if (wantsPasswordLogin) input('Talep Edilen Şifre', password, obscureText: true),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: openContractPreview,
            icon: const Icon(Icons.description),
            label: const Text('Sözleşme Önizle / Çıktı Metni'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: saving ? null : saveApplication,
            icon: const Icon(Icons.save),
            label: Text(saving ? 'Kaydediliyor...' : 'Başvuruyu Kaydet'),
          ),
        ],
      ),
    );
  }
}

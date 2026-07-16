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



class RepresentativeSettingsPage extends StatefulWidget {
  const RepresentativeSettingsPage({super.key});

  @override
  State<RepresentativeSettingsPage> createState() => _RepresentativeSettingsPageState();
}



class _RepresentativeSettingsPageState extends State<RepresentativeSettingsPage> {
  final name = TextEditingController(text: defaultRepresentativeName);
  final title = TextEditingController(text: defaultRepresentativeTitle);
  final phone = TextEditingController(text: defaultRepresentativePhone);
  final mobile = TextEditingController(text: defaultRepresentativeMobile);
  final email = TextEditingController(text: defaultRepresentativeEmail);
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadRepresentative();
  }

  Future<void> loadRepresentative() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('representative')
        .get();

    final data = doc.data();
    if (data != null) {
      name.text = representativeValue(data, 'name');
      title.text = representativeValue(data, 'title');
      phone.text = representativeValue(data, 'phone');
      mobile.text = representativeValue(data, 'mobile');
      email.text = representativeValue(data, 'email');
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Widget input(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> saveRepresentative() async {
    setState(() => saving = true);

    await FirebaseFirestore.instance.collection('app_settings').doc('representative').set({
      'name': name.text.trim(),
      'title': title.text.trim(),
      'phone': phone.text.trim(),
      'mobile': mobile.text.trim(),
      'email': email.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Temsilci bilgileri güncellendi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temsilci Bilgileri')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  color: Color(0xFFF4F1FA),
                  child: ListTile(
                    leading: Icon(Icons.lock, color: Color(0xFF0D1B52)),
                    title: Text('Sadece yetkili girişinden düzenlenir'),
                    subtitle: Text('Bu bilgiler sözleşme önizleme ekranında otomatik kullanılır.'),
                  ),
                ),
                input('Ad Soyad', name),
                input('Görev / Unvan', title),
                input('Sabit Telefon', phone, keyboardType: TextInputType.phone),
                input('Cep Telefonu', mobile, keyboardType: TextInputType.phone),
                input('E-posta', email, keyboardType: TextInputType.emailAddress),
                ElevatedButton.icon(
                  onPressed: saving ? null : saveRepresentative,
                  icon: const Icon(Icons.save),
                  label: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ],
            ),
    );
  }
}

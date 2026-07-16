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



class UnionOfficerRegisterPage extends StatefulWidget {
  const UnionOfficerRegisterPage({super.key});

  @override
  State<UnionOfficerRegisterPage> createState() => _UnionOfficerRegisterPageState();
}



class _UnionOfficerRegisterPageState extends State<UnionOfficerRegisterPage> {
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final phone = TextEditingController();
  final branchName = TextEditingController(text: 'Kayseri 1 Nolu Şube');
  final district = TextEditingController();

  String unionName = 'Eğitim-Bir-Sen';
  String city = 'Kayseri';
  String role = 'Şube Başkanı';
  bool saving = false;

  Widget input(String label, TextEditingController controller,
      {bool obscureText = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> registerOfficer() async {
    if (fullName.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.trim().length < 6 ||
        phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad soyad, e-posta, telefon ve en az 6 haneli şifre zorunludur.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      await FirebaseFirestore.instance.collection('authorized_users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'fullName': fullName.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'unionName': unionName,
        'city': city,
        'district': district.text.trim(),
        'branchName': branchName.text.trim(),
        'role': role,
        'status': 'pending',
        'canCreateAgreement': false,
        'canEditAgreement': false,
        'canDeleteAgreement': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => saving = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Başvuru Alındı'),
          content: const Text('Sendika yetkilisi başvurunuz alındı. Genel yönetici onayından sonra anlaşma girişi yapabilirsiniz.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                  (route) => false,
                );
              },
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sendika Yetkilisi Kayıt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: Color(0xFFF4F1FA),
            child: ListTile(
              leading: Icon(Icons.verified_user, color: Color(0xFF0D1B52)),
              title: Text('Türkiye geneli yetkili başvuru sistemi'),
              subtitle: Text('Başvurular onaylandıktan sonra il/şube bazlı anlaşma ekleme yetkisi verilir.'),
            ),
          ),
          input('Ad Soyad *', fullName),
          input('E-posta *', email, keyboardType: TextInputType.emailAddress),
          input('Şifre *', password, obscureText: true),
          input('Telefon *', phone, keyboardType: TextInputType.phone),
          dropdown(
            label: 'Sendika',
            value: unionName,
            items: unionNames,
            onChanged: (value) => setState(() => unionName = value ?? unionName),
          ),
          dropdown(
            label: 'İl',
            value: city,
            items: turkeyCities,
            onChanged: (value) => setState(() => city = value ?? city),
          ),
          input('İlçe', district),
          input('Şube / Temsilcilik Adı', branchName),
          dropdown(
            label: 'Görev',
            value: role,
            items: unionOfficerRoles,
            onChanged: (value) => setState(() => role = value ?? role),
          ),
          ElevatedButton.icon(
            onPressed: saving ? null : registerOfficer,
            icon: const Icon(Icons.how_to_reg),
            label: Text(saving ? 'Kaydediliyor...' : 'Başvuruyu Gönder'),
          ),
        ],
      ),
    );
  }
}

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



class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  Future<void> openPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Future<void> openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(' ', '').replaceAll('+', '');
    final uri = Uri.parse('https://wa.me/90$cleanPhone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    const phone = '03522312541';
    const whatsapp = '03522312541';
    const email = 'memursen.kayseri.temsilciligi@gmail.com';
    const address =
        'Cumhuriyet Mahallesi Tutluhan Sokak Köşk Apartmanı Dış Kapı No:6 İç Kapı No:501 Melikgazi / KAYSERİ';
    return Scaffold(
      appBar: AppBar(
        title: const Text('İletişim'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 150,
          ),
          const SizedBox(height: 20),
          const Card(
            child: ListTile(
              leading: Icon(Icons.business),
              title: Text('Memur-Sen Kayseri İl Temsilciliği'),
              subtitle: Text('Kayseri Anlaşmalı İndirimler Uygulaması'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Telefon'),
              subtitle: const Text(phone),
              onTap: () => openPhone(phone),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.message),
              title: const Text('WhatsApp'),
              subtitle: const Text(whatsapp),
              onTap: () => openWhatsApp(whatsapp),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email),
              title: const Text('E-posta'),
              subtitle: const Text(email),
              onTap: () => openEmail(email),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.location_on),
              title: Text('Adres'),
              subtitle: Text(address),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyPage(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.privacy_tip, color: Color(0xFF0D1B52)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'KVKK ve Gizlilik Politikası',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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




class RepresentativesPage extends StatefulWidget {
  const RepresentativesPage({super.key});

  @override
  State<RepresentativesPage> createState() => _RepresentativesPageState();
}



class _RepresentativesPageState extends State<RepresentativesPage> {
  String searchText = '';

  String getText(Map<String, dynamic> data, String key) {
    return (data[key] ?? '').toString();
  }

  Future<void> openPhone(String phone) async {
    if (phone.trim().isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> openEmail(String email) async {
    if (email.trim().isEmpty) return;
    await launchUrl(Uri.parse('mailto:$email'));
  }

  Future<void> openMap(Map<String, dynamic> data) async {
    final lat = data['latitude'];
    final lng = data['longitude'];
    final address = getText(data, 'address');

    final query = lat != null && lng != null ? '$lat,$lng' : address;
    if (query.trim().isEmpty) return;

    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temsilcilikler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('temsilciler')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Temsilcilik bilgileri alınamadı.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final city = getText(data, 'city').toLowerCase();
            final name = getText(data, 'name').toLowerCase();
            final title = getText(data, 'title').toLowerCase();
            final q = searchText.toLowerCase().trim();
            return q.isEmpty || city.contains(q) || name.contains(q) || title.contains(q);
          }).toList();

          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final generalA = dataA['isGeneralCenter'] == true;
            final generalB = dataB['isGeneralCenter'] == true;
            if (generalA && !generalB) return -1;
            if (!generalA && generalB) return 1;
            return getText(dataA, 'city').compareTo(getText(dataB, 'city'));
          });

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                onChanged: (value) => setState(() => searchText = value),
                decoration: InputDecoration(
                  hintText: 'İl veya temsilcilik ara...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final phone = getText(data, 'phone');
                final mobile = getText(data, 'mobile');
                final email = getText(data, 'email');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getText(data, 'city'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D1B52),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(getText(data, 'title')),
                        if (getText(data, 'name').trim().isNotEmpty)
                          Text(getText(data, 'name')),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (phone.trim().isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => openPhone(phone),
                                icon: const Icon(Icons.call),
                                label: const Text('Ara'),
                              ),
                            if (mobile.trim().isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => openPhone(mobile),
                                icon: const Icon(Icons.phone_android),
                                label: const Text('Cep'),
                              ),
                            if (email.trim().isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => openEmail(email),
                                icon: const Icon(Icons.email),
                                label: const Text('E-posta'),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => openMap(data),
                              icon: const Icon(Icons.map),
                              label: const Text('Yol Tarifi'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

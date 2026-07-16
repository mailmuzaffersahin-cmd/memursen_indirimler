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



class BusinessApplicationsPage extends StatelessWidget {
  const BusinessApplicationsPage({super.key});

  String text(Map<String, dynamic> data, String key) => (data[key] ?? '').toString();

  Future<void> approveApplication(String docId, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    final applicationRef = FirebaseFirestore.instance.collection('business_applications').doc(docId);
    final agreementRef = FirebaseFirestore.instance.collection('agreements').doc();
    final now = DateTime.now();

    batch.set(agreementRef, {
      'companyName': text(data, 'companyName'),
      'title': 'Memur-Sen üyelerine özel indirim',
      'category': 'Diğer',
      'discountRate': text(data, 'discountRate'),
      'city': text(data, 'city').isEmpty ? 'Kayseri' : text(data, 'city'),
      'district': text(data, 'district'),
      'address': text(data, 'address'),
      'authorizedPersonName': text(data, 'ownerName'),
      'authorizedPersonPhone': text(data, 'phone'),
      'businessPhone': text(data, 'phone'),
      'description': 'İşyeri başvurusu üzerinden oluşturuldu.',
      'scopeType': 'city',
      'startDate': Timestamp.fromDate(now),
      'endDate': Timestamp.fromDate(DateTime(now.year, now.month + 12, now.day)),
      'latitude': null,
      'longitude': null,
      'isActive': true,
      'expiredAutomatically': false,
      'isFeatured': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(applicationRef, {
      'status': 'approved',
      'agreementId': agreementRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> rejectApplication(String docId) async {
    await FirebaseFirestore.instance.collection('business_applications').doc(docId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İşyeri Başvuruları')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('business_applications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Henüz işyeri başvurusu yok.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = text(data, 'status');

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(text(data, 'companyName')),
                  subtitle: Text('${text(data, 'phone')} • ${text(data, 'district')} • Durum: $status'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Onayla ve anlaşmaya aktar',
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: status == 'approved'
                            ? null
                            : () async {
                                await approveApplication(doc.id, data);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Başvuru onaylandı ve anlaşmaya aktarıldı.')),
                                  );
                                }
                              },
                      ),
                      IconButton(
                        tooltip: 'Reddet',
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: status == 'rejected'
                            ? null
                            : () async {
                                await rejectApplication(doc.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Başvuru reddedildi.')),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

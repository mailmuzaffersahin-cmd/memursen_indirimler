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



class AgreementDetailPage extends StatefulWidget {
final Map<String, dynamic> agreement;
final Position? currentPosition;

const AgreementDetailPage({
  super.key,
  required this.agreement,
  this.currentPosition,
});

@override
State<AgreementDetailPage> createState() => _AgreementDetailPageState();
}



class _AgreementDetailPageState extends State<AgreementDetailPage> {

  String value(String key) {
    final v = widget.agreement[key];
    if (v == null || v.toString().trim().isEmpty) return 'Bilgi yok';
    return v.toString();
  }

  Future<void> callPhone(String phone) async {
    if (phone.trim().isEmpty || phone == 'Bilgi yok') return;
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Future<void> openWhatsApp(String phone) async {
    if (phone.trim().isEmpty || phone == 'Bilgi yok') return;

    String cleanPhone = phone.replaceAll(' ', '').replaceAll('+', '');

    if (cleanPhone.startsWith('0')) {
      cleanPhone = '9$cleanPhone';
    }

    final uri = Uri.parse('https://wa.me/$cleanPhone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openMap() async {
    final lat = widget.agreement['latitude'];
    final lng = widget.agreement['longitude'];

    if (lat == null || lng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF4F1FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: Color(0xFF0D1B52)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agreement = widget.agreement;

final favoritesBox = Hive.box('favorites');

final favoriteKey =
    agreement['companyName']?.toString() ?? '';

final isFavorite =
    favoritesBox.get(favoriteKey) == true;

final expired = isExpired(agreement);
    final km = agreementDistanceKm(widget.currentPosition, agreement);
    final endDateText = formatDate(agreement['endDate']);
    final companyName = value('companyName');
    final imageUrl = (agreement['logoUrl'] ?? agreement['imageUrl'] ?? '').toString();
    final agreementFileUrl = (agreement['agreementFileUrl'] ?? '').toString();
    final agreementFileName = (agreement['agreementFileName'] ?? 'Anlaşma Dosyası').toString();
    final discountRate = value('discountRate');
    final businessPhone = value('businessPhone');
    final authorizedPhone = value('authorizedPersonPhone');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anlaşma Detayı'),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Favoriden çıkar' : 'Favorilere ekle',
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: Colors.red,
            ),
            onPressed: () async {
              await favoritesBox.put(favoriteKey, !isFavorite);
              if (!context.mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    !isFavorite
                        ? 'Favorilere eklendi.'
                        : 'Favorilerden çıkarıldı.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B52),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                if (imageUrl.trim().isNotEmpty && imageUrl.startsWith('http'))
  ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.network(
      imageUrl,
      height: 90,
      width: 90,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.storefront,
          size: 58,
          color: Colors.white,
        );
      },
    ),
  )
else
  const Icon(
    Icons.storefront,
    size: 58,
    color: Colors.white,
  ),
                const SizedBox(height: 12),
                Text(
                  companyName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value('title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: expired ? Colors.red : Colors.amber.shade200,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    expired ? 'SÜRESİ DOLDU' : discountRate,
                    style: TextStyle(
                      color: expired ? Colors.white : const Color(0xFF0D1B52),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (expired)
            Card(
              color: Colors.red.shade50,
              child: const ListTile(
                leading: Icon(Icons.warning, color: Colors.red),
                title: Text('Bu anlaşmanın süresi dolmuştur.'),
                subtitle: Text('Süresi dolan anlaşmalar ana listede gösterilmez.'),
              ),
            ),

          if (!expired && endDateText.isNotEmpty)
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.event_available, color: Colors.green),
                title: const Text('Geçerlilik Tarihi'),
                subtitle: Text('Bu anlaşma $endDateText tarihine kadar geçerlidir.'),
              ),
            ),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => callPhone(businessPhone),
                  icon: const Icon(Icons.call),
                  label: const Text('Ara'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => openWhatsApp(authorizedPhone),
                  icon: const Icon(Icons.message),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: openMap,
              icon: const Icon(Icons.map),
              label: const Text('Yol Tarifi Al'),
            ),
          ),

          const SizedBox(height: 16),

          infoCard(
            icon: Icons.category,
            title: 'Kategori',
            subtitle: value('category'),
          ),
          infoCard(
            icon: Icons.location_city,
            title: 'İl',
            subtitle: value('city'),
          ),
          infoCard(
            icon: Icons.map_outlined,
            title: 'İlçe',
            subtitle: value('district'),
          ),
          infoCard(
            icon: Icons.location_on,
            title: 'Adres',
            subtitle: value('address'),
          ),
          infoCard(
            icon: Icons.near_me,
            title: 'Yakınlık',
            subtitle: distanceText(km),
          ),
          infoCard(
            icon: Icons.person,
            title: 'Yetkili Kişi',
            subtitle: value('authorizedPersonName'),
          ),
          infoCard(
            icon: Icons.phone_android,
            title: 'Yetkili Telefonu',
            subtitle: value('authorizedPersonPhone'),
          ),
          infoCard(
            icon: Icons.phone,
            title: 'İşyeri Kurumsal Telefonu',
            subtitle: value('businessPhone'),
          ),
          infoCard(
            icon: Icons.description,
            title: 'Açıklama',
            subtitle: value('description'),
          ),

if (imageUrl.trim().isNotEmpty)
            infoCard(
              icon: Icons.image,
              title: 'Firma Logosu / Görseli',
              subtitle: imageUrl,
            ),

          if (agreementFileUrl.trim().isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF0D1B52)),
                title: const Text(
                  'Anlaşma Metni / Dosyası',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(agreementFileName),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => launchUrl(
                  Uri.parse(agreementFileUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),

          const SizedBox(height: 10),

          const Text(
            'Not: İndirimlerden faydalanmak için Memur-Sen üyeliğinizi gösteren belge veya kimlik istenebilir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

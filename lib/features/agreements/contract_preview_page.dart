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



class ContractPreviewPage extends StatelessWidget {
  final String companyName;
  final String ownerName;
  final String phone;
  final String address;
  final String discountRate;

  const ContractPreviewPage({
    super.key,
    required this.companyName,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.discountRate,
  });

  String buildContractText(Map<String, dynamic>? representativeData) {
    final firm = companyName.isEmpty ? '................................' : companyName;
    final owner = ownerName.isEmpty ? '................................' : ownerName;
    final tel = phone.isEmpty ? '................................' : phone;
    final adr = address.isEmpty ? '................................' : address;
    final discount = discountRate.isEmpty ? '................................' : discountRate;

    final repName = representativeValue(representativeData, 'name');
    final repTitle = representativeValue(representativeData, 'title');
    final repPhone = representativeValue(representativeData, 'phone');
    final repMobile = representativeValue(representativeData, 'mobile');
    final repEmail = representativeValue(representativeData, 'email');

    return """
MEMUR-SEN KAYSERİ İL TEMSİLCİLİĞİ
ANLAŞMALI İNDİRİM PROTOKOLÜ

1. TARAFLAR
Bu protokol, Memur-Sen Kayseri İl Temsilciliği ile aşağıda bilgileri yer alan işyeri arasında düzenlenmiştir.

MEMUR-SEN TARAFI
Temsilci: $repName
Görevi: $repTitle
Telefon: $repPhone
Cep Telefonu: $repMobile
E-posta: $repEmail

İŞYERİ TARAFI
İşyeri/Firma Adı: $firm
Yetkili Kişi: $owner
Telefon: $tel
Adres: $adr

2. KONU
Bu protokolün konusu, Memur-Sen üyelerine işyeri tarafından sağlanacak indirim ve avantajların belirlenmesidir.

3. İNDİRİM / AVANTAJ
İşyeri, Memur-Sen üyelerine aşağıdaki indirim veya avantajı sunmayı kabul eder:
$discount

4. UYGULAMA ŞARTLARI
İndirimden yararlanmak isteyen kişilerden Memur-Sen üyeliğini gösteren belge, kimlik veya dijital doğrulama istenebilir.

5. SÜRE
Protokol imza tarihinden itibaren yürürlüğe girer. Taraflardan biri yazılı bildirimde bulunmadıkça uygulama devam eder.

6. DUYURU VE YAYIN
İşyeri bilgileri, Memur-Sen Kayseri İndirimler uygulamasında ve uygun görülen dijital mecralarda yayınlanabilir.

7. VERİ VE GİZLİLİK
Taraflar, paylaşılan iletişim ve işyeri bilgilerinin yalnızca anlaşmalı indirim hizmetinin yürütülmesi amacıyla kullanılacağını kabul eder.

8. İMZA
Bu protokol iki nüsha olarak düzenlenmiş ve taraflarca kabul edilmiştir.

MEMUR-SEN KAYSERİ İL TEMSİLCİLİĞİ
$repName
$repTitle
İmza / Kaşe: .................................

İŞYERİ / FİRMA
Yetkili Ad Soyad: $owner
İmza / Kaşe: .................................

Tarih: .... / .... / ........
""";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sözleşme Önizleme')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('app_settings')
            .doc('representative')
            .snapshots(),
        builder: (context, snapshot) {
          final representativeData = snapshot.data?.data() as Map<String, dynamic>?;
          final contractText = buildContractText(representativeData);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                color: Color(0xFFFFF3CD),
                child: ListTile(
                  leading: Icon(Icons.print),
                  title: Text('Çıktı alma'),
                  subtitle: Text('Bu ekranı PDF/çıktı için kullanabilirsiniz. Bir sonraki aşamada otomatik PDF oluşturma eklenecek.'),
                ),
              ),
              SelectableText(contractText, style: const TextStyle(fontSize: 15, height: 1.5)),
            ],
          );
        },
      ),
    );
  }
}

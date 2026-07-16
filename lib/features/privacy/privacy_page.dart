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



class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KVKK ve Gizlilik Politikası'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: const Text(
          '''
Memur-Sen Kayseri İndirim Uygulaması kullanıcı bilgilerinin güvenliğine önem verir.

Uygulama içerisinde kullanılan bilgiler:
- Ad Soyad
- E-posta
- Telefon bilgisi
- Konum bilgisi (yakındaki anlaşmalar için)

yalnızca uygulama hizmetlerinin sunulması amacıyla kullanılmaktadır.

Kullanıcı bilgileri üçüncü kişilerle paylaşılmaz.

Uygulama Firebase altyapısı kullanmaktadır.

KVKK kapsamında kullanıcı dilediği zaman bilgilerinin silinmesini talep edebilir.

İletişim:
memursen.kayseri.temsilciligi@gmail.com
          ''',
          style: TextStyle(
            fontSize: 15,
            height: 1.7,
          ),
        ),
      ),
    );
  }
}

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



class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final favoritesBox = Hive.box('favorites');

    final favoriteKeys = favoritesBox.keys
        .where((key) => favoritesBox.get(key) == true)
        .map((key) => key.toString())
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorilerim'),
      ),
      body: favoriteKeys.isEmpty
          ? const Center(
              child: Text('Henüz favori anlaşma eklenmedi.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favoriteKeys.length,
              itemBuilder: (context, index) {
                final item = favoriteKeys[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                    ),
                    title: Text(item),
                    subtitle: const Text('Favori anlaşma'),
                  ),
                );
              },
            ),
    );
  }
}

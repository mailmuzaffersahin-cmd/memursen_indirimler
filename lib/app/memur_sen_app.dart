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
import 'package:memursen_indirimler/core/widgets/font_scale_provider.dart';
import 'package:memursen_indirimler/features/splash/splash_page.dart';



class MemurSenApp extends StatelessWidget {
  const MemurSenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memur-Sen İndirimler',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D1B52)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1B52),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final fontState = FontScaleProvider.of(context);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontState.textScale),
          ),
          child: Stack(
            children: [
              child ?? const SizedBox(),
              Positioned(
                right: 8,
                bottom: 140,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 36,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B52),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 8,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        fontScaleButton('A+', fontState.increase),
                        const Divider(height: 1, color: Colors.white24),
                        fontScaleButton('A', fontState.reset),
                        const Divider(height: 1, color: Colors.white24),
                        fontScaleButton('A-', fontState.decrease),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      home: const SplashPage(),
    );
  }
}

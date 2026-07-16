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


class FontScaleProvider extends StatefulWidget {
  final Widget child;

  const FontScaleProvider({
    super.key,
    required this.child,
  });

  // ignore: library_private_types_in_public_api
  static _FontScaleProviderState of(BuildContext context) {
    return context.findAncestorStateOfType<_FontScaleProviderState>()!;
  }

  @override
  State<FontScaleProvider> createState() => _FontScaleProviderState();
}



class _FontScaleProviderState extends State<FontScaleProvider> {
  double textScale = 1.0;

  void increase() {
    setState(() {
      textScale += 0.1;
      if (textScale > 2.0) textScale = 2.0;
    });
  }

  void decrease() {
    setState(() {
      textScale -= 0.1;
      if (textScale < 0.8) textScale = 0.8;
    });
  }

  void reset() {
    setState(() {
      textScale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: widget.child,
    );
  }
}



Widget _fontButton(String text, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: SizedBox(
      width: 34,
      height: 30,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}

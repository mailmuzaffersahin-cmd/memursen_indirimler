// Temel duman (smoke) testi.
//
// Not: Bu proje Firebase'e bağımlı (Firestore/Auth). Splash ekranı 3 saniye
// sonra HomePage'e geçiyor ve HomePage Firestore akışlarını dinliyor; bu da
// gerçek/mock bir Firebase kurulumu olmadan test ortamında çökmeye yol açar.
// Bu yüzden bu test kasıtlı olarak yalnızca ilk kareyi (splash ekranı) test
// eder — Firestore'a hiç dokunmaz. Firebase'e bağımlı ekranların (HomePage,
// AdminGate, vb.) tam kapsamlı testleri, `firebase_core` mock kurulumu
// eklendikten sonra (bkz. TEST_REPORT_TR.md) ayrı dosyalarda yazılacaktır.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memursen_indirimler/main.dart';

void main() {
  testWidgets('MemurSenApp splash ekranını hatasız açar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MemurSenApp());

    // Yalnızca ilk kareyi çiziyoruz; 3 saniyelik zamanlayıcıyı (ve ardından
    // gelen Firestore çağrılarını) tetiklememek için pumpAndSettle
    // KULLANMIYORUZ.
    await tester.pump();

    // Splash ekranı beyaz arka plan ü
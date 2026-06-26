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

import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  await Hive.openBox('agreementsCache');
  await Hive.openBox('favorites');
  await Hive.openBox('settings');

  await FirebaseMessaging.instance.requestPermission();

  final token = await FirebaseMessaging.instance.getToken();
  debugPrint('FCM TOKEN: $token');

  runApp(const FontScaleProvider(child: MemurSenApp()));
}
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
                        _fontButton('A+', fontState.increase),
                        const Divider(height: 1, color: Colors.white24),
                        _fontButton('A', fontState.reset),
                        const Divider(height: 1, color: Colors.white24),
                        _fontButton('A-', fontState.decrease),
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

DateTime todayOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime? parseDateValue(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  try {
    return DateTime.parse(text);
  } catch (_) {}

  final parts = text.split('.');
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }

  return null;
}

String formatDate(dynamic value) {
  final date = parseDateValue(value);
  if (date == null) return '';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day.$month.$year';
}

bool isExpired(Map<String, dynamic> data) {
  final endDate = parseDateValue(data['endDate']);
  if (endDate == null) return false;
  final onlyEndDate = DateTime(endDate.year, endDate.month, endDate.day);
  return onlyEndDate.isBefore(todayOnly());
}

String cleanCellValue(List<Data?> row, int index) {
  if (index >= row.length) return '';
  final cell = row[index];
  if (cell == null || cell.value == null) return '';
  return cell.value.toString().trim();
}

double? parseDoubleValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value.toDouble();
  if (value is double) return value;

  final text = value.toString().trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

double? agreementDistanceKm(Position? position, Map<String, dynamic> data) {
  if (position == null) return null;

  final latitude = parseDoubleValue(data['latitude']);
  final longitude = parseDoubleValue(data['longitude']);

  if (latitude == null || longitude == null) return null;

  final meters = Geolocator.distanceBetween(
    position.latitude,
    position.longitude,
    latitude,
    longitude,
  );

  return meters / 1000;
}

String distanceText(double? km) {
  if (km == null) return 'Konum bilgisi yok';

  if (km.isNaN || km.isInfinite) {
    return 'Konum bilgisi yok';
  }

  if (km < 0 || km > 500) {
    return 'Konum bilgisi yok';
  }

  return '${km.toStringAsFixed(1)} km uzaklıkta';
}


String safeStorageFileName(String fileName) {
  final cleaned = fileName
      // ignore: deprecated_member_use
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\.\-]'), '_')
      .replaceAll('__', '_');
  return cleaned.isEmpty ? 'dosya' : cleaned;
}

String contentTypeFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}

Future<String?> uploadBytesToStorage({
  required Uint8List? bytes,
  required String folder,
  required String? fileName,
}) async {
  if (bytes == null || fileName == null || fileName.trim().isEmpty) return null;

  final safeName = safeStorageFileName(fileName);
  final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';

  final ref = FirebaseStorage.instance.ref().child(path);
  final metadata = SettableMetadata(
    contentType: contentTypeFromFileName(fileName),
  );

  await ref.putData(bytes, metadata);
  return ref.getDownloadURL();
}

bool isImageUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.contains('image%2f') ||
      lower.contains('image/');
}



const String defaultRepresentativeName = 'Mehmet Emin ASLANTÜRK';
const String defaultRepresentativeTitle = 'Memur-Sen Kayseri İl Temsilcisi';
const String defaultRepresentativePhone = '0 352 231 2541';
const String defaultRepresentativeMobile = '0 535 658 05 04';
const String defaultRepresentativeEmail = 'kayseri1@ebs.org.tr';

Map<String, String> representativeDefaults() {
  return {
    'name': defaultRepresentativeName,
    'title': defaultRepresentativeTitle,
    'phone': defaultRepresentativePhone,
    'mobile': defaultRepresentativeMobile,
    'email': defaultRepresentativeEmail,
  };
}

String representativeValue(Map<String, dynamic>? data, String key) {
  final defaults = representativeDefaults();
  final value = data?[key]?.toString().trim();
  if (value == null || value.isEmpty) return defaults[key] ?? '';
  return value;
}
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset('assets/images/logo.png', width: 260),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController scrollController = ScrollController();
  bool compactMode = false;

  int selectedBottomIndex = 0;
  Position? currentPosition;
  bool loadingLocation = false;
  bool sortByNearest = false;
  String currentCityName = '';
  String currentDistrictName = '';

  String searchText = '';
  String selectedCategory = 'Tümü';
  String selectedCity = 'Tümü';
  String selectedDistrict = 'Tümü';
  String selectedScope = 'Tümü';
  bool showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    getLocation();

    scrollController.addListener(() {
      if (!mounted) return;

      if (scrollController.offset > 160 && !compactMode) {
        setState(() => compactMode = true);
      }

      if (scrollController.offset <= 160 && compactMode) {
        setState(() => compactMode = false);
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> getLocation() async {
    if (!mounted) return;

    setState(() {
      loadingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => loadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum servisi kapalı.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => loadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum izni verilmedi.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String cityName = '';
      String districtName = '';

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          cityName = cleanLocationName(place.administrativeArea ?? '');
          districtName = cleanLocationName(place.subAdministrativeArea ?? '');

          if (districtName.isEmpty) {
            districtName = cleanLocationName(place.locality ?? '');
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        currentPosition = position;
        currentCityName = cityName;
        currentDistrictName = districtName;
        loadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum alınamadı: $e')),
      );
    }
  }

  String getText(Map<String, dynamic> data, String key) {
    return (data[key] ?? '').toString();
  }

  String pageTitle() {
    if (sortByNearest) return 'YAKINIMDAKİ ANLAŞMALAR';
    if (selectedCity == 'Tümü') return 'TÜM ANLAŞMALAR';
    if (selectedCity == 'Türkiye Geneli') return 'TÜRKİYE GENELİ';
    return '${selectedCity.toUpperCase()} İLİ';
  }

  void openAdmin(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            user == null ? const AdminLoginPage() : const AdminDashboardPage(),
      ),
    );
  }

  Future<void> autoExpireAgreements(List<QueryDocumentSnapshot> docs) async {
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      if (data['isActive'] == true && isExpired(data)) {
        await FirebaseFirestore.instance.collection('agreements').doc(doc.id).update({
          'isActive': false,
          'expiredAutomatically': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }


  String normalizeFilterValue(String value) {
    return value.trim().toLowerCase()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  String cleanLocationName(String value) {
    return value
        .replaceAll(' Province', '')
        .replaceAll(' province', '')
        .replaceAll(' İli', '')
        .replaceAll(' ili', '')
        .trim();
  }

  String scopeToFirestoreValue(String value) {
    switch (value) {
      case 'İl Geneli':
        return 'city';
      case 'İlçe Geneli':
        return 'district';
      case 'Türkiye Geneli':
        return 'nationwide';
      case 'Online':
        return 'online';
      case 'İl Dışı':
        return 'out_of_city';
      default:
        return value;
    }
  }

  bool matchesFilter(Map<String, dynamic> data) {
    if (data['isActive'] != true) return false;
    if (isExpired(data)) return false;

    final companyName = getText(data, 'companyName').toLowerCase();
    final category = getText(data, 'category');
    final city = getText(data, 'city');
    final district = getText(data, 'district');
    final scopeType = getText(data, 'scopeType');

    final selectedScopeValue = scopeToFirestoreValue(selectedScope);

    return (searchText.isEmpty ||
            normalizeFilterValue(companyName).contains(normalizeFilterValue(searchText))) &&
        (selectedCategory == 'Tümü' ||
            normalizeCategory(category) == normalizeCategory(selectedCategory)) &&
        (selectedCity == 'Tümü' ||
            normalizeFilterValue(city) == normalizeFilterValue(selectedCity)) &&
        (selectedDistrict == 'Tümü' ||
            normalizeFilterValue(district) == normalizeFilterValue(selectedDistrict)) &&
        (selectedScope == 'Tümü' || scopeType == selectedScopeValue);
  }

  Widget dropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
return DropdownButtonFormField<String>(
  isExpanded: true,
  value: items.contains(value) ? value : 'Tümü',
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }

String normalizeCategory(String value) {
  final text = value.trim().toLowerCase();

  if (text.isEmpty) return '';

  final words = text.split(' ');

  return words
      .map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1);
      })
      .join(' ');
}

int turkishCompare(String a, String b) {
  const alphabet = 'aâbcçdefgğhıijklmnoöprsştuüvyz';

  String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  final x = normalize(a);
  final y = normalize(b);

  for (int i = 0; i < x.length && i < y.length; i++) {
    final ix = alphabet.indexOf(x[i]);
    final iy = alphabet.indexOf(y[i]);

    if (ix != iy) return ix.compareTo(iy);
  }

  return x.length.compareTo(y.length);
}

  List<String> createDynamicList(
  List<QueryDocumentSnapshot> docs,
  String fieldName,
  List<String> defaultItems,
) {
  final values = <String>{};

  for (final item in defaultItems) {
    final clean = normalizeCategory(item);
    if (clean.isNotEmpty) values.add(clean);
  }

  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>;

    if (data['isActive'] == true && !isExpired(data)) {
      final clean = normalizeCategory(getText(data, fieldName));
      if (clean.isNotEmpty) values.add(clean);
    }
  }

  final sorted = values.toList()
    ..sort((a, b) => turkishCompare(a, b));

  return ['Tümü', ...sorted];
}

  @override
  Widget build(BuildContext context) {
    final scopes = [
      'Tümü',
      'İl Geneli',
      'İlçe Geneli',
      'Türkiye Geneli',
      'Online',
      'İl Dışı',
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Memur-Sen İndirimler'),
        actions: [
          IconButton(
            tooltip: 'İşyeri Kayıt Ol',
            icon: const Icon(Icons.store_mall_directory),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessRegistrationPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Sendika Yetkilisi Kayıt',
            icon: const Icon(Icons.how_to_reg),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UnionOfficerRegisterPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => openAdmin(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('agreements').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Veri alınamadı.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;
          Future.microtask(() => autoExpireAgreements(allDocs));

          final categories = createDynamicList(allDocs, 'category', [
            'Sağlık',
            'Eğitim',
            'Yazılım',
            'Market',
            'Giyim',
            'Otomotiv',
            'Yemek',
          ]);

          final cities = createDynamicList(allDocs, 'city', [
            'Kayseri',
            'Türkiye Geneli',
          ]);

          if (currentCityName.isNotEmpty && !cities.contains(currentCityName)) {
            cities.insert(1, currentCityName);
          }

          final districts = createDynamicList(allDocs, 'district', []);

          if (currentDistrictName.isNotEmpty && !districts.contains(currentDistrictName)) {
            districts.insert(1, currentDistrictName);
          }

          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return matchesFilter(data);
          }).toList();

          if (sortByNearest && currentPosition != null) {
            filteredDocs.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;

              final distanceA = agreementDistanceKm(currentPosition, dataA) ?? 999999;
              final distanceB = agreementDistanceKm(currentPosition, dataB) ?? 999999;

              return distanceA.compareTo(distanceB);
            });
          }

          final featuredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isFeatured'] == true &&
                data['isActive'] == true &&
                !isExpired(data);
          }).toList();

          return SingleChildScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: compactMode ? 8 : 20,
                ),
                color: const Color(0xFF0D1B52),
                child: Column(
                  children: [
                    Text(
                      pageTitle(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compactMode ? 16 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!compactMode) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'MEMUR-SEN ÜYELERİNE ÖZEL İNDİRİMLER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (featuredDocs.isNotEmpty && !compactMode)
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    itemCount: featuredDocs.length,
                    itemBuilder: (context, index) {
                      final data = featuredDocs[index].data() as Map<String, dynamic>;
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AgreementDetailPage(
                                agreement: data,
                                currentPosition: currentPosition,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 260,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1B52),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 20),
                                  SizedBox(width: 6),
                                  Text(
                                    'ÖNE ÇIKAN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                getText(data, 'companyName'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                getText(data, 'discountRate'),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  onTap: () {
                    setState(() {
                      compactMode = true;
                      showAdvancedFilters = false;
                    });
                  },
                  onChanged: (value) => setState(() => searchText = value),
                  decoration: InputDecoration(
                    hintText: 'Firma ara...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: dropdown(
                        label: 'Kategori',
                        value: selectedCategory,
                        items: categories,
                        onChanged: (value) {
                          setState(() => selectedCategory = value!);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: dropdown(
                        label: 'İl',
                        value: selectedCity,
                        items: cities,
                        onChanged: (value) {
                          setState(() => selectedCity = value!);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (!compactMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ElevatedButton.icon(
                  onPressed: loadingLocation
                      ? null
                      : () async {
                          if (currentPosition == null) {
                            await getLocation();
                          }
                          if (!mounted) return;
                          setState(() => sortByNearest = !sortByNearest);
                        },
                  icon: Icon(sortByNearest ? Icons.location_off : Icons.my_location),
                  label: Text(
                    loadingLocation
                        ? 'Konum alınıyor...'
                        : sortByNearest
                            ? 'Yakınımdaki Sıralamayı Kapat'
                            : 'Yakınımdaki Anlaşmaları Göster',
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: compactMode ? 3 : 4,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => showAdvancedFilters = !showAdvancedFilters);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Gelişmiş Filtre',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Icon(
                          showAdvancedFilters
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showAdvancedFilters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      dropdown(
                        label: 'İşyerinin Bulunduğu İlçe',
                        value: selectedDistrict,
                        items: districts,
                        onChanged: (value) {
                          setState(() => selectedDistrict = value!);
                        },
                      ),
                      const SizedBox(height: 8),
                      dropdown(
                        label: 'Kapsam',
                        value: selectedScope,
                        items: scopes,
                        onChanged: (value) {
                          setState(() => selectedScope = value!);
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            searchText = '';
                            selectedCategory = 'Tümü';
                            selectedCity = 'Tümü';
                            selectedDistrict = 'Tümü';
                            selectedScope = 'Tümü';
                            sortByNearest = false;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Filtreleri Temizle'),
                      ),
                    ],
                  ),
                ),
              if (filteredDocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Bu filtreye uygun anlaşma bulunamadı.'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data() as Map<String, dynamic>;
                          final km = agreementDistanceKm(currentPosition, data);
                          final imageUrl = (data['logoUrl'] ?? data['imageUrl'] ?? '').toString();
                          final companyName = getText(data, 'companyName');
                          final categoryText = getText(data, 'category');
                          final districtText = getText(data, 'district');
                          final cityText = getText(data, 'city');
                          final discountText = getText(data, 'discountRate');
                          final favoritesBox = Hive.box('favorites');
                          final favoriteKey = companyName;
                          final isFavorite = favoritesBox.get(favoriteKey) == true;

                          return Card(
                            elevation: 5,
                            shadowColor: Colors.black12,
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AgreementDetailPage(
                                      agreement: data,
                                      currentPosition: currentPosition,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D1B52),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: imageUrl.trim().isNotEmpty && imageUrl.startsWith('http')
                                          ? Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Icon(Icons.store, color: Colors.white, size: 32);
                                              },
                                            )
                                          : const Icon(Icons.store, color: Colors.white, size: 32),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  companyName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15.5,
                                                  ),
                                                ),
                                              ),
                                              if (data['isFeatured'] == true)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade100,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: const Text(
                                                    'Öne çıkan',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF0D1B52),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '$categoryText • $districtText',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              if (discountText.trim().isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0D1B52),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    discountText,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              if (currentPosition != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: Colors.green.shade100),
                                                  ),
                                                  child: Text(
                                                    distanceText(km),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: isFavorite ? 'Favoriden çıkar' : 'Favorilere ekle',
                                          icon: Icon(
                                            isFavorite ? Icons.favorite : Icons.favorite_border,
                                            color: isFavorite ? Colors.red : Colors.grey,
                                          ),
                                          onPressed: () async {
                                            await favoritesBox.put(favoriteKey, !isFavorite);
                                            if (!mounted) return;
                                            setState(() {});
                                          },
                                        ),
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedBottomIndex,
        selectedItemColor: const Color(0xFF0D1B52),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            selectedBottomIndex = index;

            if (index == 0) {
              sortByNearest = false;
              selectedCategory = 'Tümü';
              selectedCity = 'Tümü';
              selectedDistrict = 'Tümü';
              selectedScope = 'Tümü';
              showAdvancedFilters = false;
            }

            if (index == 1) {
              sortByNearest = true;
              if (currentPosition == null) {
                getLocation();
              }
            }

            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RepresentativesPage(),
                ),
              );
            }

            if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ContactPage(),
                ),
              );
            }

            if (index == 4) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FavoritesPage(),
                ),
              );
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.my_location),
            label: 'Yakınımdaki',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment),
            label: 'Temsilcilikler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_phone),
            label: 'İletişim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favoriler',
          ),
        ],
      ),
    );
  }
}

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

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giriş başarısız.')),
      );
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yetkili Girişi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.business_center),
                label: const Text('İşyeri Başvuruları'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BusinessApplicationsPage(),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: loading ? null : login,
              icon: const Icon(Icons.login),
              label: Text(loading ? 'Giriş yapılıyor...' : 'Giriş Yap'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  Future<void> importRepresentativesExcel(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    final excel = Excel.decodeBytes(bytes);
    int count = 0;

    for (final tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName];
      if (sheet == null) continue;

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        final city = cleanCellValue(row, 0);
        if (city.isEmpty) continue;

        final docId = city
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll('ı', 'i')
            .replaceAll('ğ', 'g')
            .replaceAll('ü', 'u')
            .replaceAll('ş', 's')
            .replaceAll('ö', 'o')
            .replaceAll('ç', 'c');

        await FirebaseFirestore.instance
            .collection('temsilciler')
            .doc(docId)
            .set({
          'city': city,
          'name': cleanCellValue(row, 1),
          'title': cleanCellValue(row, 2),
          'phone': cleanCellValue(row, 3),
          'mobile': cleanCellValue(row, 4),
          'email': cleanCellValue(row, 5),
          'address': cleanCellValue(row, 6),
          'latitude': parseDoubleValue(cleanCellValue(row, 7)),
          'longitude': parseDoubleValue(cleanCellValue(row, 8)),
          'website': cleanCellValue(row, 9),
          'isGeneralCenter': cleanCellValue(row, 10).toUpperCase() == 'EVET',
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        count++;
      }
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count temsilcilik Firestore’a yüklendi.')),
    );
  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Temsilcilik yükleme hatası: $e')),
    );
  }
}

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> importExcelToFirestore(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null) return;

      final Uint8List? bytes = result.files.single.bytes;

      if (bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel dosyası okunamadı.')),
        );
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      int addedCount = 0;

      for (final tableName in excel.tables.keys) {
        final sheet = excel.tables[tableName];
        if (sheet == null) continue;

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          final companyName = cleanCellValue(row, 0);

          if (companyName.trim().isEmpty) continue;

          final startDate = parseDateValue(cleanCellValue(row, 12));
          final endDate = parseDateValue(cleanCellValue(row, 13));

          await FirebaseFirestore.instance.collection('agreements').add({
            'companyName': companyName,
            'title': cleanCellValue(row, 1),
            'category': cleanCellValue(row, 2),
            'discountRate': cleanCellValue(row, 3),
            'city': cleanCellValue(row, 4),
            'district': cleanCellValue(row, 5),
            'address': cleanCellValue(row, 6),
            'authorizedPersonName': cleanCellValue(row, 7),
            'authorizedPersonPhone': cleanCellValue(row, 8),
            'businessPhone': cleanCellValue(row, 9),
            'description': cleanCellValue(row, 10),
            'scopeType': cleanCellValue(row, 11).isEmpty ? 'city' : cleanCellValue(row, 11),
            'startDate': startDate == null ? null : Timestamp.fromDate(startDate),
            'endDate': endDate == null ? null : Timestamp.fromDate(endDate),
            'latitude': parseDoubleValue(cleanCellValue(row, 14)),
            'longitude': parseDoubleValue(cleanCellValue(row, 15)),
            'isActive': endDate == null ||
                !DateTime(endDate.year, endDate.month, endDate.day).isBefore(todayOnly()),
            'expiredAutomatically': false,
            'isFeatured': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          addedCount++;
        }
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$addedCount anlaşma başarıyla yüklendi.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel yükleme hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetim Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Giriş yapan: ${user?.email ?? ''}'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Yeni Anlaşma Ekle'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddAgreementPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Temsilcilikleri Excel’den Yükle'),
            onPressed: () => importRepresentativesExcel(context),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.business_center),
            label: const Text('İşyeri Başvuruları'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessApplicationsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.verified_user),
            label: const Text('Sendika Yetkilisi Başvuruları'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UnionOfficerApplicationsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.badge),
            label: const Text('Temsilci Bilgilerini Düzenle'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RepresentativeSettingsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text("Excel'den Toplu Yükle"),
            onPressed: () => importExcelToFirestore(context),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.list_alt),
            label: const Text('Anlaşmaları Yönet'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminAgreementsPage()),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Excel sütun sırası: Firma Adı, Başlık, Kategori, İndirim, İl, İlçe, Adres, Yetkili Ad Soyad, Yetkili Telefon, Kurumsal Telefon, Açıklama, Kapsam, Başlangıç Tarihi, Bitiş Tarihi, Enlem, Boylam',
          ),
        ],
      ),
    );
  }
}

class AdminAgreementsPage extends StatefulWidget {
  const AdminAgreementsPage({super.key});

  @override
  State<AdminAgreementsPage> createState() => _AdminAgreementsPageState();
}

class _AdminAgreementsPageState extends State<AdminAgreementsPage> {
  final Set<String> selectedDocIds = {};
  String searchText = '';
  bool showOnlyNoLocation = false;
  bool showOnlyExpired = false;

  String getText(Map<String, dynamic> data, String key) {
    return (data[key] ?? '').toString();
  }

  bool hasNoLocation(Map<String, dynamic> data) {
    final latitude = parseDoubleValue(data['latitude']);
    final longitude = parseDoubleValue(data['longitude']);
    return latitude == null || longitude == null;
  }

  bool matchesAdminFilter(Map<String, dynamic> data) {
    final query = searchText.trim().toLowerCase();
    final companyName = getText(data, 'companyName').toLowerCase();
    final phone = getText(data, 'businessPhone').toLowerCase();
    final authorizedPhone = getText(data, 'authorizedPersonPhone').toLowerCase();
    final address = getText(data, 'address').toLowerCase();

    final matchesSearch = query.isEmpty ||
        companyName.contains(query) ||
        phone.contains(query) ||
        authorizedPhone.contains(query) ||
        address.contains(query);

    final matchesLocation = !showOnlyNoLocation || hasNoLocation(data);
    final matchesExpired = !showOnlyExpired || isExpired(data);

    return matchesSearch && matchesLocation && matchesExpired;
  }

  Future<bool> confirmAction(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> deleteAgreement(String docId) async {
    await FirebaseFirestore.instance.collection('agreements').doc(docId).delete();
  }

  Future<void> toggleActive(String docId, bool value) async {
    await FirebaseFirestore.instance.collection('agreements').doc(docId).update({
      'isActive': !value,
      'expiredAutomatically': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> autoExpireAgreement(String docId, Map<String, dynamic> data) async {
    if (data['isActive'] == true && isExpired(data)) {
      await FirebaseFirestore.instance.collection('agreements').doc(docId).update({
        'isActive': false,
        'expiredAutomatically': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> deleteSelected() async {
    if (selectedDocIds.isEmpty) return;

    final confirmed = await confirmAction(
      context,
      title: 'Toplu Silme Onayı',
      message:
          '${selectedDocIds.length} anlaşma kalıcı olarak silinecek. Devam etmek istiyor musunuz?',
    );

    if (!confirmed) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final docId in selectedDocIds) {
      final ref = FirebaseFirestore.instance.collection('agreements').doc(docId);
      batch.delete(ref);
    }

    await batch.commit();

    if (!mounted) return;
    setState(() => selectedDocIds.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seçilen anlaşmalar silindi.')),
    );
  }

  Future<void> passiveSelected() async {
    if (selectedDocIds.isEmpty) return;

    final confirmed = await confirmAction(
      context,
      title: 'Toplu Pasif Yapma',
      message:
          '${selectedDocIds.length} anlaşma pasif hale getirilecek. Devam etmek istiyor musunuz?',
    );

    if (!confirmed) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final docId in selectedDocIds) {
      final ref = FirebaseFirestore.instance.collection('agreements').doc(docId);
      batch.update(ref, {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    if (!mounted) return;
    setState(() => selectedDocIds.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seçilen anlaşmalar pasif yapıldı.')),
    );
  }

  Future<void> extendExpiredOneMonth(List<QueryDocumentSnapshot> docs) async {
    final expiredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return isExpired(data);
    }).toList();

    if (expiredDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Süresi biten anlaşma bulunamadı.')),
      );
      return;
    }

    final confirmed = await confirmAction(
      context,
      title: 'Süresi Bitenleri Uzat',
      message:
          '${expiredDocs.length} süresi biten anlaşma 1 ay uzatılacak ve aktif yapılacak. Devam etmek istiyor musunuz?',
    );

    if (!confirmed) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in expiredDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final oldEndDate = parseDateValue(data['endDate']) ?? DateTime.now();
      final newEndDate = DateTime(
        oldEndDate.year,
        oldEndDate.month + 1,
        oldEndDate.day,
      );

      batch.update(doc.reference, {
        'endDate': Timestamp.fromDate(newEndDate),
        'isActive': true,
        'expiredAutomatically': false,
        'extendedAutomatically': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Süresi biten anlaşmalar 1 ay uzatıldı.')),
    );
  }

  void toggleSelection(String docId) {
    setState(() {
      if (selectedDocIds.contains(docId)) {
        selectedDocIds.remove(docId);
      } else {
        selectedDocIds.add(docId);
      }
    });
  }

  void selectAll(List<QueryDocumentSnapshot> docs) {
    setState(() {
      selectedDocIds
        ..clear()
        ..addAll(docs.map((doc) => doc.id));
    });
  }

  void clearSelection() {
    setState(() => selectedDocIds.clear());
  }

  Widget topActionBar(List<QueryDocumentSnapshot> visibleDocs) {
    final selectedCount = selectedDocIds.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            onChanged: (value) => setState(() => searchText = value),
            decoration: InputDecoration(
              hintText: 'İşyeri adı, telefon veya adres ara...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: const Text('Konumu Olmayanlar'),
                  selected: showOnlyNoLocation,
                  onSelected: (value) {
                    setState(() {
                      showOnlyNoLocation = value;
                      selectedDocIds.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('Süresi Bitenler'),
                  selected: showOnlyExpired,
                  onSelected: (value) {
                    setState(() {
                      showOnlyExpired = value;
                      selectedDocIds.clear();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: visibleDocs.isEmpty ? null : () => selectAll(visibleDocs),
                icon: const Icon(Icons.select_all),
                label: const Text('Tümünü Seç'),
              ),
              OutlinedButton.icon(
                onPressed: selectedCount == 0 ? null : clearSelection,
                icon: const Icon(Icons.clear),
                label: Text('Seçimi Temizle ($selectedCount)'),
              ),
              ElevatedButton.icon(
                onPressed: selectedCount == 0 ? null : passiveSelected,
                icon: const Icon(Icons.visibility_off),
                label: const Text('Pasif Yap'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: selectedCount == 0 ? null : deleteSelected,
                icon: const Icon(Icons.delete),
                label: const Text('Seçilenleri Sil'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => extendExpiredOneMonth(visibleDocs),
                icon: const Icon(Icons.update),
                label: const Text('Süresi Bitenleri 1 Ay Uzat'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anlaşmaları Yönet'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('agreements').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;

          final visibleDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return matchesAdminFilter(data);
          }).toList();

          visibleDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            return getText(dataA, 'companyName')
                .toLowerCase()
                .compareTo(getText(dataB, 'companyName').toLowerCase());
          });

          return Column(
            children: [
              topActionBar(visibleDocs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Toplam: ${visibleDocs.length} | Seçilen: ${selectedDocIds.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleDocs.isEmpty
                    ? const Center(child: Text('Bu filtreye uygun anlaşma bulunamadı.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleDocs.length,
                        itemBuilder: (context, index) {
                          final doc = visibleDocs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          Future.microtask(() => autoExpireAgreement(doc.id, data));

                          final expired = isExpired(data);
                          final isActive = data['isActive'] == true && !expired;
                          final selected = selectedDocIds.contains(doc.id);
                          final noLocation = hasNoLocation(data);

                          return Card(
                            color: selected
                                ? Colors.blue.shade50
                                : expired
                                    ? Colors.red.shade50
                                    : noLocation
                                        ? Colors.orange.shade50
                                        : null,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onLongPress: () => toggleSelection(doc.id),
                              onTap: selectedDocIds.isNotEmpty
                                  ? () => toggleSelection(doc.id)
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditAgreementPage(
                                            docId: doc.id,
                                            data: data,
                                          ),
                                        ),
                                      );
                                    },
                              leading: Checkbox(
                                value: selected,
                                onChanged: (_) => toggleSelection(doc.id),
                              ),
                              title: Text(getText(data, 'companyName')),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${getText(data, 'discountRate')} • ${isActive ? 'Aktif' : 'Pasif'} • Bitiş: ${formatDate(data['endDate'])}',
                                  ),
                                  if (noLocation)
                                    const Text(
                                      'Konum bilgisi eksik',
                                      style: TextStyle(
                                        color: Colors.deepOrange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: isActive ? 'Pasif yap' : 'Aktif yap',
                                    icon: Icon(
                                      isActive ? Icons.toggle_on : Icons.toggle_off,
                                      color: isActive ? Colors.green : Colors.grey,
                                    ),
                                    onPressed: () => toggleActive(doc.id, isActive),
                                  ),
                                  IconButton(
                                    tooltip: 'Sil',
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final confirmed = await confirmAction(
                                        context,
                                        title: 'Silme Onayı',
                                        message:
                                            '${getText(data, 'companyName')} kaydı silinecek. Devam etmek istiyor musunuz?',
                                      );
                                      if (confirmed) {
                                        await deleteAgreement(doc.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class AddAgreementPage extends StatefulWidget {
  const AddAgreementPage({super.key});

  @override
  State<AddAgreementPage> createState() => _AddAgreementPageState();
}

class _AddAgreementPageState extends State<AddAgreementPage> {
  final companyName = TextEditingController();
  final title = TextEditingController();
  final category = TextEditingController();
  final discountRate = TextEditingController();
  final city = TextEditingController(text: 'Kayseri');
  final district = TextEditingController();
  final address = TextEditingController();
  final authorizedPersonName = TextEditingController();
  final authorizedPersonPhone = TextEditingController();
  final businessPhone = TextEditingController();
  final description = TextEditingController();
  final startDate = TextEditingController();
  final endDate = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();

  Uint8List? logoBytes;
  String? logoFileName;

  Uint8List? agreementFileBytes;
  String? agreementFileName;

  bool isFeatured = false;
  bool saving = false;

  Future<void> pickDate(TextEditingController controller) async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: parseDateValue(controller.text) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    controller.text = formatDate(selected);
  }

  Future<void> pickLogoFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      logoBytes = result.files.single.bytes;
      logoFileName = result.files.single.name;
    });
  }

  Future<void> pickAgreementFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      agreementFileBytes = result.files.single.bytes;
      agreementFileName = result.files.single.name;
    });
  }

  Future<void> saveAgreement() async {
    final parsedStartDate = parseDateValue(startDate.text);
    final parsedEndDate = parseDateValue(endDate.text);

    setState(() => saving = true);

    try {
      final logoUrl = await uploadBytesToStorage(
        bytes: logoBytes,
        folder: 'agreement_logos',
        fileName: logoFileName,
      );

      final agreementFileUrl = await uploadBytesToStorage(
        bytes: agreementFileBytes,
        folder: 'agreement_files',
        fileName: agreementFileName,
      );

      await FirebaseFirestore.instance.collection('agreements').add({
        'companyName': companyName.text.trim(),
        'title': title.text.trim(),
        'category': category.text.trim(),
        'discountRate': discountRate.text.trim(),
        'city': city.text.trim(),
        'district': district.text.trim(),
        'address': address.text.trim(),
        'authorizedPersonName': authorizedPersonName.text.trim(),
        'authorizedPersonPhone': authorizedPersonPhone.text.trim(),
        'businessPhone': businessPhone.text.trim(),
        'description': description.text.trim(),
        'scopeType': 'city',
        'startDate': parsedStartDate == null ? null : Timestamp.fromDate(parsedStartDate),
        'endDate': parsedEndDate == null ? null : Timestamp.fromDate(parsedEndDate),
        'latitude': parseDoubleValue(latitude.text),
        'longitude': parseDoubleValue(longitude.text),
        'logoUrl': logoUrl,
        'agreementFileUrl': agreementFileUrl,
        'agreementFileName': agreementFileName,
        'isActive': parsedEndDate == null ||
            !DateTime(parsedEndDate.year, parsedEndDate.month, parsedEndDate.day).isBefore(todayOnly()),
        'expiredAutomatically': false,
        'isFeatured': isFeatured,
        'createdByUid': FirebaseAuth.instance.currentUser?.uid,
        'createdByEmail': FirebaseAuth.instance.currentUser?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => saving = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt/yükleme hatası: $e')),
      );
    }
  }

  Widget input(String label, TextEditingController controller,
      {int maxLines = 1, bool isDate = false, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: isDate,
        maxLines: maxLines,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : label.toLowerCase().contains('telefon')
                ? TextInputType.phone
                : null,
        onTap: isDate ? () => pickDate(controller) : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: isDate ? 'gg.aa.yyyy' : null,
          suffixIcon: isDate ? const Icon(Icons.calendar_month) : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget selectedFileCard({
    required String title,
    required String? fileName,
    required IconData icon,
  }) {
    return Card(
      color: fileName == null ? Colors.grey.shade100 : Colors.green.shade50,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0D1B52)),
        title: Text(title),
        subtitle: Text(fileName ?? 'Henüz dosya seçilmedi'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Anlaşma Ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          input('Firma Adı', companyName),
          input('Anlaşma Başlığı', title),
          input('Kategori', category),
          input('İndirim Oranı', discountRate),
          input('Başlangıç Tarihi', startDate, isDate: true),
          input('Bitiş Tarihi', endDate, isDate: true),
          input('İl', city),
          input('İlçe', district),
          input('Adres', address, maxLines: 2),
          input('Enlem', latitude, isNumber: true),
          input('Boylam', longitude, isNumber: true),

          const Divider(height: 28),
          const Text(
            'Logo ve Anlaşma Dosyaları',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          selectedFileCard(
            title: 'İşyeri Logosu',
            fileName: logoFileName,
            icon: Icons.image,
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : pickLogoFile,
            icon: const Icon(Icons.upload),
            label: const Text('İşyeri Logosu Seç (PNG/JPG)'),
          ),
          const SizedBox(height: 8),
          selectedFileCard(
            title: 'Anlaşma Metni / Sözleşme Dosyası',
            fileName: agreementFileName,
            icon: Icons.picture_as_pdf,
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : pickAgreementFile,
            icon: const Icon(Icons.attach_file),
            label: const Text('PDF veya Görsel Seç (PDF/PNG/JPG)'),
          ),

          const Divider(height: 28),
          SwitchListTile(
            title: const Text('Öne Çıkan Firma'),
            subtitle: const Text('Ana sayfada üst bölümde gösterilir'),
            value: isFeatured,
            onChanged: (value) {
              setState(() {
                isFeatured = value;
              });
            },
          ),
          input('Yetkili Kişi Adı Soyadı', authorizedPersonName),
          input('Yetkili Kişi Telefonu', authorizedPersonPhone),
          input('İşyeri Kurumsal Telefonu', businessPhone),
          input('Açıklama', description, maxLines: 4),
          ElevatedButton.icon(
            onPressed: saving ? null : saveAgreement,
            icon: const Icon(Icons.save),
            label: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
          ),
        ],
      ),
    );
  }
}

class EditAgreementPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditAgreementPage({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditAgreementPage> createState() => _EditAgreementPageState();
}

class _EditAgreementPageState extends State<EditAgreementPage> {
  late TextEditingController companyName;
  late TextEditingController title;
  late TextEditingController category;
  late TextEditingController discountRate;
  late TextEditingController city;
  late TextEditingController district;
  late TextEditingController address;
  late TextEditingController authorizedPersonName;
  late TextEditingController authorizedPersonPhone;
  late TextEditingController businessPhone;
  late TextEditingController description;
  late TextEditingController startDate;
  late TextEditingController endDate;
  late TextEditingController latitude;
  late TextEditingController longitude;

  Uint8List? logoBytes;
  String? logoFileName;
  String? currentLogoUrl;

  Uint8List? agreementFileBytes;
  String? agreementFileName;
  String? currentAgreementFileUrl;
  String? currentAgreementFileName;

  bool isFeatured = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    companyName = TextEditingController(text: widget.data['companyName'] ?? '');
    title = TextEditingController(text: widget.data['title'] ?? '');
    category = TextEditingController(text: widget.data['category'] ?? '');
    discountRate = TextEditingController(text: widget.data['discountRate'] ?? '');
    city = TextEditingController(text: widget.data['city'] ?? '');
    district = TextEditingController(text: widget.data['district'] ?? '');
    address = TextEditingController(text: widget.data['address'] ?? '');
    authorizedPersonName = TextEditingController(text: widget.data['authorizedPersonName'] ?? '');
    authorizedPersonPhone = TextEditingController(text: widget.data['authorizedPersonPhone'] ?? '');
    businessPhone = TextEditingController(text: widget.data['businessPhone'] ?? '');
    description = TextEditingController(text: widget.data['description'] ?? '');
    startDate = TextEditingController(text: formatDate(widget.data['startDate']));
    endDate = TextEditingController(text: formatDate(widget.data['endDate']));
    latitude = TextEditingController(text: widget.data['latitude']?.toString() ?? '');
    longitude = TextEditingController(text: widget.data['longitude']?.toString() ?? '');

    currentLogoUrl = (widget.data['logoUrl'] ?? widget.data['imageUrl'])?.toString();
    currentAgreementFileUrl = widget.data['agreementFileUrl']?.toString();
    currentAgreementFileName = widget.data['agreementFileName']?.toString();

    isFeatured = widget.data['isFeatured'] ?? false;
  }

  Future<void> pickDate(TextEditingController controller) async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: parseDateValue(controller.text) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    controller.text = formatDate(selected);
  }

  Future<void> pickLogoFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      logoBytes = result.files.single.bytes;
      logoFileName = result.files.single.name;
    });
  }

  Future<void> pickAgreementFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      agreementFileBytes = result.files.single.bytes;
      agreementFileName = result.files.single.name;
    });
  }

  Future<void> updateAgreement() async {
    final parsedStartDate = parseDateValue(startDate.text);
    final parsedEndDate = parseDateValue(endDate.text);

    setState(() => saving = true);

    try {
      final uploadedLogoUrl = await uploadBytesToStorage(
        bytes: logoBytes,
        folder: 'agreement_logos',
        fileName: logoFileName,
      );

      final uploadedAgreementFileUrl = await uploadBytesToStorage(
        bytes: agreementFileBytes,
        folder: 'agreement_files',
        fileName: agreementFileName,
      );

      await FirebaseFirestore.instance.collection('agreements').doc(widget.docId).update({
        'companyName': companyName.text.trim(),
        'title': title.text.trim(),
        'category': category.text.trim(),
        'discountRate': discountRate.text.trim(),
        'city': city.text.trim(),
        'district': district.text.trim(),
        'address': address.text.trim(),
        'authorizedPersonName': authorizedPersonName.text.trim(),
        'authorizedPersonPhone': authorizedPersonPhone.text.trim(),
        'businessPhone': businessPhone.text.trim(),
        'description': description.text.trim(),
        'startDate': parsedStartDate == null ? null : Timestamp.fromDate(parsedStartDate),
        'endDate': parsedEndDate == null ? null : Timestamp.fromDate(parsedEndDate),
        'latitude': parseDoubleValue(latitude.text),
        'longitude': parseDoubleValue(longitude.text),
        'logoUrl': uploadedLogoUrl ?? currentLogoUrl,
        'agreementFileUrl': uploadedAgreementFileUrl ?? currentAgreementFileUrl,
        'agreementFileName': agreementFileName ?? currentAgreementFileName,
        'isActive': parsedEndDate == null ||
            !DateTime(parsedEndDate.year, parsedEndDate.month, parsedEndDate.day).isBefore(todayOnly()),
        'expiredAutomatically': false,
        'isFeatured': isFeatured,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => saving = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncelleme/yükleme hatası: $e')),
      );
    }
  }

  Widget input(String label, TextEditingController controller,
      {int maxLines = 1, bool isDate = false, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: isDate,
        maxLines: maxLines,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : label.toLowerCase().contains('telefon')
                ? TextInputType.phone
                : null,
        onTap: isDate ? () => pickDate(controller) : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: isDate ? 'gg.aa.yyyy' : null,
          suffixIcon: isDate ? const Icon(Icons.calendar_month) : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget selectedFileCard({
    required String title,
    required String? selectedFileName,
    required String? existingUrl,
    required IconData icon,
    VoidCallback? onOpenExisting,
  }) {
    final subtitle = selectedFileName ??
        (existingUrl != null && existingUrl.trim().isNotEmpty
            ? 'Mevcut dosya yüklü'
            : 'Henüz dosya seçilmedi');

    return Card(
      color: selectedFileName != null
          ? Colors.green.shade50
          : (existingUrl != null && existingUrl.trim().isNotEmpty)
              ? Colors.blue.shade50
              : Colors.grey.shade100,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0D1B52)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: existingUrl != null && existingUrl.trim().isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: onOpenExisting,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final end = parseDateValue(endDate.text);
    final expired = end != null && DateTime(end.year, end.month, end.day).isBefore(todayOnly());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anlaşmayı Düzenle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (expired)
            Card(
              color: Colors.red.shade50,
              child: const ListTile(
                leading: Icon(Icons.warning, color: Colors.red),
                title: Text('Bu anlaşmanın bitiş tarihi geçmiştir.'),
                subtitle: Text('Güncellerseniz sistem otomatik pasif yapar.'),
              ),
            ),
          input('Firma Adı', companyName),
          input('Anlaşma Başlığı', title),
          input('Kategori', category),
          input('İndirim Oranı', discountRate),
          input('Başlangıç Tarihi', startDate, isDate: true),
          input('Bitiş Tarihi', endDate, isDate: true),
          input('İl', city),
          input('İlçe', district),
          input('Adres', address, maxLines: 2),
          input('Enlem', latitude, isNumber: true),
          input('Boylam', longitude, isNumber: true),

          const Divider(height: 28),
          const Text(
            'Logo ve Anlaşma Dosyaları',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          selectedFileCard(
            title: 'İşyeri Logosu',
            selectedFileName: logoFileName,
            existingUrl: currentLogoUrl,
            icon: Icons.image,
            onOpenExisting: currentLogoUrl == null || currentLogoUrl!.trim().isEmpty
                ? null
                : () => launchUrl(Uri.parse(currentLogoUrl!), mode: LaunchMode.externalApplication),
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : pickLogoFile,
            icon: const Icon(Icons.upload),
            label: const Text('Yeni Logo Seç (PNG/JPG)'),
          ),
          const SizedBox(height: 8),
          selectedFileCard(
            title: 'Anlaşma Metni / Sözleşme Dosyası',
            selectedFileName: agreementFileName,
            existingUrl: currentAgreementFileUrl,
            icon: Icons.picture_as_pdf,
            onOpenExisting: currentAgreementFileUrl == null || currentAgreementFileUrl!.trim().isEmpty
                ? null
                : () => launchUrl(Uri.parse(currentAgreementFileUrl!), mode: LaunchMode.externalApplication),
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : pickAgreementFile,
            icon: const Icon(Icons.attach_file),
            label: const Text('Yeni PDF veya Görsel Seç'),
          ),

          const Divider(height: 28),
          SwitchListTile(
            title: const Text('Öne Çıkan Firma'),
            subtitle: const Text('Ana sayfada üst bölümde gösterilir'),
            value: isFeatured,
            onChanged: (value) {
              setState(() {
                isFeatured = value;
              });
            },
          ),
          input('Yetkili Kişi Adı Soyadı', authorizedPersonName),
          input('Yetkili Kişi Telefonu', authorizedPersonPhone),
          input('İşyeri Kurumsal Telefonu', businessPhone),
          input('Açıklama', description, maxLines: 4),
          ElevatedButton.icon(
            onPressed: saving ? null : updateAgreement,
            icon: const Icon(Icons.save),
            label: Text(saving ? 'Güncelleniyor...' : 'Güncelle'),
          ),
        ],
      ),
    );
  }
}

class RepresentativeSettingsPage extends StatefulWidget {
  const RepresentativeSettingsPage({super.key});

  @override
  State<RepresentativeSettingsPage> createState() => _RepresentativeSettingsPageState();
}

class _RepresentativeSettingsPageState extends State<RepresentativeSettingsPage> {
  final name = TextEditingController(text: defaultRepresentativeName);
  final title = TextEditingController(text: defaultRepresentativeTitle);
  final phone = TextEditingController(text: defaultRepresentativePhone);
  final mobile = TextEditingController(text: defaultRepresentativeMobile);
  final email = TextEditingController(text: defaultRepresentativeEmail);
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadRepresentative();
  }

  Future<void> loadRepresentative() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('representative')
        .get();

    final data = doc.data();
    if (data != null) {
      name.text = representativeValue(data, 'name');
      title.text = representativeValue(data, 'title');
      phone.text = representativeValue(data, 'phone');
      mobile.text = representativeValue(data, 'mobile');
      email.text = representativeValue(data, 'email');
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Widget input(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> saveRepresentative() async {
    setState(() => saving = true);

    await FirebaseFirestore.instance.collection('app_settings').doc('representative').set({
      'name': name.text.trim(),
      'title': title.text.trim(),
      'phone': phone.text.trim(),
      'mobile': mobile.text.trim(),
      'email': email.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Temsilci bilgileri güncellendi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temsilci Bilgileri')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  color: Color(0xFFF4F1FA),
                  child: ListTile(
                    leading: Icon(Icons.lock, color: Color(0xFF0D1B52)),
                    title: Text('Sadece yetkili girişinden düzenlenir'),
                    subtitle: Text('Bu bilgiler sözleşme önizleme ekranında otomatik kullanılır.'),
                  ),
                ),
                input('Ad Soyad', name),
                input('Görev / Unvan', title),
                input('Sabit Telefon', phone, keyboardType: TextInputType.phone),
                input('Cep Telefonu', mobile, keyboardType: TextInputType.phone),
                input('E-posta', email, keyboardType: TextInputType.emailAddress),
                ElevatedButton.icon(
                  onPressed: saving ? null : saveRepresentative,
                  icon: const Icon(Icons.save),
                  label: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ],
            ),
    );
  }
}

class BusinessRegistrationPage extends StatefulWidget {
  const BusinessRegistrationPage({super.key});

  @override
  State<BusinessRegistrationPage> createState() => _BusinessRegistrationPageState();
}

class _BusinessRegistrationPageState extends State<BusinessRegistrationPage> {
  final companyName = TextEditingController();
  final ownerName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final city = TextEditingController(text: 'Kayseri');
  final district = TextEditingController();
  final address = TextEditingController();
  final discountRate = TextEditingController();
  final branchName = TextEditingController();
  final branchPhone = TextEditingController();
  final branchAddress = TextEditingController();
  final password = TextEditingController();

  bool wantsPasswordLogin = false;
  bool hasMultipleBranches = false;
  bool saving = false;

  Widget input(String label, TextEditingController controller,
      {int maxLines = 1, bool obscureText = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> saveApplication() async {
    if (companyName.text.trim().isEmpty || phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firma adı ve telefon zorunludur.')),
      );
      return;
    }

    setState(() => saving = true);

    await FirebaseFirestore.instance.collection('business_applications').add({
      'companyName': companyName.text.trim(),
      'ownerName': ownerName.text.trim(),
      'phone': phone.text.trim(),
      'email': email.text.trim(),
      'city': city.text.trim(),
      'district': district.text.trim(),
      'address': address.text.trim(),
      'discountRate': discountRate.text.trim(),
      'wantsPasswordLogin': wantsPasswordLogin,
      'passwordRequested': wantsPasswordLogin,
      'status': 'pending',
      'contractStatus': 'not_uploaded',
      'hasMultipleBranches': hasMultipleBranches,
      'branches': hasMultipleBranches
          ? [
              {
                'branchName': branchName.text.trim(),
                'phone': branchPhone.text.trim(),
                'address': branchAddress.text.trim(),
                'latitude': null,
                'longitude': null,
              }
            ]
          : [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    setState(() => saving = false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Başvuru Alındı'),
        content: const Text('İşyeri başvurunuz kaydedildi. Sözleşme çıktısını alıp imzaladıktan sonra yetkiliye teslim edebilirsiniz.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void openContractPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractPreviewPage(
          companyName: companyName.text.trim(),
          ownerName: ownerName.text.trim(),
          phone: phone.text.trim(),
          address: address.text.trim(),
          discountRate: discountRate.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İşyeri Kayıt Ol')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: Color(0xFFF4F1FA),
            child: ListTile(
              leading: Icon(Icons.info, color: Color(0xFF0D1B52)),
              title: Text('Anlaşmalı işyeri başvurusu'),
              subtitle: Text('Bilgilerinizi doldurun, sözleşme çıktısını alın ve imzalı şekilde teslim/yükleme sürecine geçin.'),
            ),
          ),
          input('Firma / İşyeri Adı *', companyName),
          input('Yetkili Ad Soyad', ownerName),
          input('Telefon *', phone, keyboardType: TextInputType.phone),
          input('E-posta', email, keyboardType: TextInputType.emailAddress),
          input('İl', city),
          input('İlçe', district),
          input('Adres', address, maxLines: 3),
          input('Sunulacak İndirim / Kampanya', discountRate),
          const Divider(height: 28),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: hasMultipleBranches,
            title: const Text('Birden fazla şubem var'),
            subtitle: const Text('Farklı şube bilgisi girecekseniz işaretleyin.'),
            onChanged: (value) {
              setState(() {
                hasMultipleBranches = value ?? false;
                if (!hasMultipleBranches) {
                  branchName.clear();
                  branchPhone.clear();
                  branchAddress.clear();
                }
              });
            },
          ),
          if (hasMultipleBranches) ...[
            const SizedBox(height: 8),
            const Text('Şube Bilgileri', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            input('Şube Adı', branchName),
            input('Şube Telefonu', branchPhone, keyboardType: TextInputType.phone),
            input('Şube Adresi', branchAddress, maxLines: 2),
          ],
          const Divider(height: 28),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('app_settings')
                .doc('representative')
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              return Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: const Icon(Icons.badge, color: Color(0xFF0D1B52)),
                  title: Text(representativeValue(data, 'name')),
                  subtitle: Text(
                    '${representativeValue(data, 'title')}\n'
                    '${representativeValue(data, 'phone')}\n'
                    '${representativeValue(data, 'mobile')}\n'
                    '${representativeValue(data, 'email')}',
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Şifreli işyeri girişi istiyorum'),
            subtitle: const Text('İşyeri daha sonra kendi bilgileriyle giriş yapabilir.'),
            value: wantsPasswordLogin,
            onChanged: (value) => setState(() => wantsPasswordLogin = value),
          ),
          if (wantsPasswordLogin) input('Talep Edilen Şifre', password, obscureText: true),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: openContractPreview,
            icon: const Icon(Icons.description),
            label: const Text('Sözleşme Önizle / Çıktı Metni'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: saving ? null : saveApplication,
            icon: const Icon(Icons.save),
            label: Text(saving ? 'Kaydediliyor...' : 'Başvuruyu Kaydet'),
          ),
        ],
      ),
    );
  }
}

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



const List<String> turkeyCities = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya', 'Ankara',
  'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir', 'Bartın', 'Batman',
  'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa',
  'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne',
  'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun',
  'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul', 'İzmir',
  'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri',
  'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kilis', 'Kocaeli', 'Konya',
  'Kütahya', 'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
  'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun',
  'Siirt', 'Sinop', 'Sivas', 'Şanlıurfa', 'Şırnak', 'Tekirdağ', 'Tokat',
  'Trabzon', 'Tunceli', 'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak'
];

const List<String> unionNames = [
  'Eğitim-Bir-Sen',
  'Bem-Bir-Sen',
  'Büro Memur-Sen',
  'Diyanet-Sen',
  'Enerji Bir-Sen',
  'Genç Memur-Sen',
  'Kültür Memur-Sen',
  'Memur-Sen',
  'Sağlık-Sen',
  'Toç Bir-Sen',
  'Ulaştırma Memur-Sen',
];

const List<String> unionOfficerRoles = [
  'Genel Yönetici',
  'İl Temsilcisi',
  'Şube Başkanı',
  'Teşkilatlanmadan Sorumlu Başkan Yardımcısı',
  'Teşkilatlanma Temsilci Yardımcısı',
  'İşyeri Yetkilisi',
];

String getCurrentUserRoleText(Map<String, dynamic>? data) {
  if (data == null) return 'Yetki kaydı bulunamadı';
  final status = (data['status'] ?? '').toString();
  final role = (data['role'] ?? '').toString();
  final city = (data['city'] ?? '').toString();
  final branch = (data['branchName'] ?? '').toString();
  if (status != 'active') return 'Onay bekliyor / Pasif';
  return '$role • $city • $branch';
}

class UnionOfficerRegisterPage extends StatefulWidget {
  const UnionOfficerRegisterPage({super.key});

  @override
  State<UnionOfficerRegisterPage> createState() => _UnionOfficerRegisterPageState();
}

class _UnionOfficerRegisterPageState extends State<UnionOfficerRegisterPage> {
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final phone = TextEditingController();
  final branchName = TextEditingController(text: 'Kayseri 1 Nolu Şube');
  final district = TextEditingController();

  String unionName = 'Eğitim-Bir-Sen';
  String city = 'Kayseri';
  String role = 'Şube Başkanı';
  bool saving = false;

  Widget input(String label, TextEditingController controller,
      {bool obscureText = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> registerOfficer() async {
    if (fullName.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.trim().length < 6 ||
        phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad soyad, e-posta, telefon ve en az 6 haneli şifre zorunludur.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      await FirebaseFirestore.instance.collection('authorized_users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'fullName': fullName.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'unionName': unionName,
        'city': city,
        'district': district.text.trim(),
        'branchName': branchName.text.trim(),
        'role': role,
        'status': 'pending',
        'canCreateAgreement': false,
        'canEditAgreement': false,
        'canDeleteAgreement': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => saving = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Başvuru Alındı'),
          content: const Text('Sendika yetkilisi başvurunuz alındı. Genel yönetici onayından sonra anlaşma girişi yapabilirsiniz.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                  (route) => false,
                );
              },
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sendika Yetkilisi Kayıt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: Color(0xFFF4F1FA),
            child: ListTile(
              leading: Icon(Icons.verified_user, color: Color(0xFF0D1B52)),
              title: Text('Türkiye geneli yetkili başvuru sistemi'),
              subtitle: Text('Başvurular onaylandıktan sonra il/şube bazlı anlaşma ekleme yetkisi verilir.'),
            ),
          ),
          input('Ad Soyad *', fullName),
          input('E-posta *', email, keyboardType: TextInputType.emailAddress),
          input('Şifre *', password, obscureText: true),
          input('Telefon *', phone, keyboardType: TextInputType.phone),
          dropdown(
            label: 'Sendika',
            value: unionName,
            items: unionNames,
            onChanged: (value) => setState(() => unionName = value ?? unionName),
          ),
          dropdown(
            label: 'İl',
            value: city,
            items: turkeyCities,
            onChanged: (value) => setState(() => city = value ?? city),
          ),
          input('İlçe', district),
          input('Şube / Temsilcilik Adı', branchName),
          dropdown(
            label: 'Görev',
            value: role,
            items: unionOfficerRoles,
            onChanged: (value) => setState(() => role = value ?? role),
          ),
          ElevatedButton.icon(
            onPressed: saving ? null : registerOfficer,
            icon: const Icon(Icons.how_to_reg),
            label: Text(saving ? 'Kaydediliyor...' : 'Başvuruyu Gönder'),
          ),
        ],
      ),
    );
  }
}

class UnionOfficerApplicationsPage extends StatelessWidget {
  const UnionOfficerApplicationsPage({super.key});

  String text(Map<String, dynamic> data, String key) => (data[key] ?? '').toString();

  Future<void> updateStatus({
    required String uid,
    required String status,
    bool canCreate = true,
    bool canEdit = true,
    bool canDelete = false,
  }) async {
    await FirebaseFirestore.instance.collection('authorized_users').doc(uid).update({
      'status': status,
      'canCreateAgreement': status == 'active' && canCreate,
      'canEditAgreement': status == 'active' && canEdit,
      'canDeleteAgreement': status == 'active' && canDelete,
      'approvedByUid': FirebaseAuth.instance.currentUser?.uid,
      'approvedByEmail': FirebaseAuth.instance.currentUser?.email,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> openEditDialog(BuildContext context, QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String role = text(data, 'role').isEmpty ? 'Şube Başkanı' : text(data, 'role');
    String status = text(data, 'status').isEmpty ? 'pending' : text(data, 'status');
    bool canCreate = data['canCreateAgreement'] == true;
    bool canEdit = data['canEditAgreement'] == true;
    bool canDelete = data['canDeleteAgreement'] == true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Yetki Düzenle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: unionOfficerRoles.contains(role) ? role : unionOfficerRoles.first,
                      decoration: const InputDecoration(labelText: 'Görev'),
                      items: unionOfficerRoles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (value) => setDialogState(() => role = value ?? role),
                    ),
                    DropdownButtonFormField<String>(
                      value: ['pending', 'active', 'passive'].contains(status) ? status : 'pending',
                      decoration: const InputDecoration(labelText: 'Durum'),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Onay Bekliyor')),
                        DropdownMenuItem(value: 'active', child: Text('Aktif')),
                        DropdownMenuItem(value: 'passive', child: Text('Pasif')),
                      ],
                      onChanged: (value) => setDialogState(() => status = value ?? status),
                    ),
                    CheckboxListTile(
                      value: canCreate,
                      title: const Text('Anlaşma ekleyebilir'),
                      onChanged: (value) => setDialogState(() => canCreate = value ?? false),
                    ),
                    CheckboxListTile(
                      value: canEdit,
                      title: const Text('Anlaşma düzenleyebilir'),
                      onChanged: (value) => setDialogState(() => canEdit = value ?? false),
                    ),
                    CheckboxListTile(
                      value: canDelete,
                      title: const Text('Anlaşma silebilir'),
                      onChanged: (value) => setDialogState(() => canDelete = value ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('authorized_users').doc(doc.id).update({
                      'role': role,
                      'status': status,
                      'canCreateAgreement': status == 'active' && canCreate,
                      'canEditAgreement': status == 'active' && canEdit,
                      'canDeleteAgreement': status == 'active' && canDelete,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color statusColor(String status) {
    if (status == 'active') return Colors.green.shade50;
    if (status == 'passive') return Colors.red.shade50;
    return Colors.orange.shade50;
  }

  String statusText(String status) {
    if (status == 'active') return 'Aktif';
    if (status == 'passive') return 'Pasif';
    return 'Onay bekliyor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sendika Yetkilisi Başvuruları')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('authorized_users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Henüz başvuru yok.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = text(data, 'status');

              return Card(
                color: statusColor(status),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.verified_user, color: Color(0xFF0D1B52)),
                  title: Text(text(data, 'fullName')),
                  subtitle: Text(
                    '${text(data, 'unionName')} • ${text(data, 'city')} • ${text(data, 'branchName')}\n${text(data, 'role')} • ${statusText(status)}\n${text(data, 'email')} • ${text(data, 'phone')}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'approve') {
                        await updateStatus(uid: doc.id, status: 'active');
                      } else if (value == 'passive') {
                        await updateStatus(uid: doc.id, status: 'passive', canCreate: false, canEdit: false, canDelete: false);
                      } else if (value == 'edit') {
                        await openEditDialog(context, doc);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'approve', child: Text('Onayla / Aktif Yap')),
                      PopupMenuItem(value: 'passive', child: Text('Pasif Yap')),
                      PopupMenuItem(value: 'edit', child: Text('Yetki Düzenle')),
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

class CurrentOfficerInfoCard extends StatelessWidget {
  const CurrentOfficerInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('authorized_users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        return Card(
          color: data == null || data['status'] != 'active'
              ? Colors.orange.shade50
              : Colors.green.shade50,
          child: ListTile(
            leading: const Icon(Icons.badge, color: Color(0xFF0D1B52)),
            title: const Text('Sendika Yetkisi'),
            subtitle: Text(getCurrentUserRoleText(data)),
          ),
        );
      },
    );
  }
}


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

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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminGate()),
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

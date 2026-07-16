# MEMUR-SEN İNDİRİMLER — PROJE ANALİZ RAPORU

**Tarih:** 16 Temmuz 2026
**Analiz eden:** Claude (Cowork)
**Kapsam:** AŞAMA 1 — Tam proje analizi, yedekleme, derleme durumu tespiti

---

## 1. GENEL DURUM ÖZETİ

Proje, tek bir geliştiricinin elle yazdığı, **çalışan ve yayınlanmış** bir Flutter uygulaması. Paket adı, Firebase bağlantısı ve imzalama yapılandırması doğru ve tutarlı. Ancak uygulamanın tamamı (33 ekran/sınıf) **tek bir dosyada** (`lib/main.dart`, 4413 satır) yazılmış durumda. Bu, "Kayseri indirim uygulaması" ölçeğinde çalışabiliyor olsa da, talep edilen "Türkiye geneli çok katmanlı platform" dönüşümü için **yeniden yapılandırma (refactor) şart**.

İki konu **kritik öncelikli** ve aşağıda ayrıca işaretlendi: (1) imzalama anahtarınız GitHub'a yüklenmiş durumda, (2) binlerce kişisel e-posta adresi proje deposunda düz metin olarak duruyor.

---

## 2. DOĞRULANAN TEMEL BİLGİLER

| Alan | Değer | Durum |
|---|---|---|
| Proje adı | memursen_indirimler | ✅ |
| applicationId | com.muzaffersahin.memursen_indirimler | ✅ Korunuyor |
| namespace | com.muzaffersahin.memursen_indirimler | ✅ Korunuyor, ikisi birebir aynı |
| pubspec sürümü | 1.0.3+7 | ✅ Belirtilenle eşleşiyor |
| Java uyumluluğu | 17 (build.gradle.kts içinde tanımlı) | ✅ |
| Android Gradle Plugin | 8.11.1 | ✅ Güncel |
| Gradle | 8.14 | ✅ Güncel |
| Kotlin | 2.2.20 | ✅ Güncel |
| Firebase projesi | memursenindirimler (google-services.json mevcut) | ✅ |
| Git deposu | Mevcut, GitHub'a bağlı (mailmuzaffersahin-cmd/memursen_indirimler) | ⚠️ Aşağıya bakın |
| Aktif branch | feature/performans-cache | Bilgi amaçlı |

---

## 3. 🔴 KRİTİK GÜVENLİK RİSKLERİ (ÖNCELİKLİ OKUYUN)

### 3.1 İmzalama anahtarınız GitHub deposuna yüklenmiş
`android/key.properties`, kök dizindeki `key.properties`, ve üç kopya hâlinde `upload-keystore.jks` dosyası **Git tarafından takip ediliyor** ve deponuz `github.com/mailmuzaffersahin-cmd/memursen_indirimler.git` adresine bağlı. Bu dosyalar geçmiş commit'lerde (`53c5c9f`, `206bc2b`) zaten var — yani reponuz herkese açıksa (public) veya ileride açık hâle gelirse, **Play Store imzalama şifreniz internette erişilebilir olur.**

İçeriklerine hiç dokunmadım, ekrana yazdırmadım. Ama bu konuda **sizin kararınız gerekiyor**, çünkü çözüm iki türlü olabilir ve ikisi de sizin onayınızı gerektirir:
- Depo zaten **private** ise: riski `.gitignore`'a ekleyip ileri commit'lerden çıkarmak yeterli olur (geçmiş commit'ler yine de o dosyaları içerir, ama depo herkese kapalıysa acil değildir).
- Depo **public** ise veya public olma ihtimali varsa: geçmişten de temizlenmesi gerekir (git history rewrite + GitHub'da force-push), bu da imzalama anahtarının **değiştirilmesi gerekip gerekmediğinin** değerlendirilmesini gerektirir. Anahtar değişirse Play Store'da mevcut uygulamayı güncelleyemezsiniz — bu yüzden bu adımı sizin açık onayınız olmadan yapmayacağım.

**Sizden istediğim:** GitHub deposunun public mi private mı olduğunu kontrol edip bana söyleyin. Ona göre 2. aşamada güvenli adımı birlikte atarız.

### 3.2 Binlerce kişisel e-posta adresi Git deposunda
Kök dizinde üç CSV dosyası (`Eposta Adresleri.csv`, `Eposta Adresleri2.csv`, `Eposta Adresleri son ekleme.csv` — toplam **2.374 satır**) ve bir Excel dosyası, muhtemelen üye e-posta adreslerini düz metin olarak içeriyor ve Git tarafından takip ediliyor. Bu, KVKK açısından risk oluşturuyor: bu veriler bir uygulama deposunda değil, ayrı ve erişimi kısıtlı bir yerde durmalı.

**Önerim:** Bu dosyaları depodan çıkarıp sizin güvenli bir yerde (yerel bilgisayar, şifreli klasör) saklamanızı sağlamak. Onayınızla bir sonraki aşamada yaparım.

### 3.3 .gitignore güvenlik açığı
Mevcut `.gitignore` dosyası `key.properties`, `*.jks`, `*.keystore` gibi hassas dosyaları **hiç hariç tutmuyor**. Bunu düzeltmek geriye dönük olarak geçmiş commit'leri temizlemez ama yeni sızıntıları önler. Bu değişiklik zararsız olduğu için 2. aşamada sizden ayrıca onay almadan uygulayacağım.

### 3.4 Firestore / Storage güvenlik kuralları depoda yok
Projede `firestore.rules` veya `storage.rules` dosyası bulunmuyor. Bu, kuralların hiç yazılmadığı ya da yalnızca Firebase Console üzerinden (kaynak kodu dışında, versiyon kontrolsüz) yönetildiği anlamına gelir. İkinci durum bile risklidir çünkü kurallar hiçbir yedeğe veya teste tabi değildir. 2. aşamada mevcut kuralları Firebase Console'dan görmem gerekecek ya da siz bana aktarmanız gerekecek.

---

## 4. SAĞLAM ÇALIŞAN ÖZELLİKLER

- Paket adı / namespace / Firebase bağlantısı tutarlı, güncelleme olarak yayımlamaya uygun.
- Yönetici girişi gerçek Firebase Authentication (e-posta/şifre) üzerinden yapılıyor, hardcoded şifre yok.
- Oturum kalıcılığı: Firebase Auth mobilde varsayılan olarak kalıcıdır (LOCAL persistence); kodda `signOut()` sadece beklenen tek bir yerde çağrılıyor. Talep edilen "listeye dönünce oturum kapanmasın" sorunu şu an kodda görünmüyor — ayrıca test edilecek.
- Hive ile 3 kutu (`agreementsCache`, `favorites`, `settings`) üzerinden yerel önbellekleme çalışıyor.
- Android Gradle/Kotlin/Java yapılandırması güncel ve tutarlı, mevcut haliyle derlenebilir görünüyor (gerçek derleme testi 6. bölümde açıklanan nedenle bu ortamda yapılamadı).
- 33 ekran zaten var: splash, ana sayfa, anlaşma detayı, admin girişi/panel/CRUD, işyeri kaydı, sözleşme önizleme, temsilci kayıt/onay, temsilciler, iletişim, favoriler, gizlilik.

## 5. HATALI / EKSİK / RİSKLİ BULGULAR

| Bulgu | Açıklama |
|---|---|
| Monolitik kod | Tüm uygulama mantığı tek dosyada (`lib/main.dart`, 4413 satır, 33 sınıf). Bakımı ve genişletilmesi zor, hata riski yüksek. |
| Kullanılmayan iskelet klasörler | `lib/models`, `lib/repositories`, `lib/services`, `lib/theme`, `lib/utils`, `lib/constants`, `lib/cache`, `lib/pages/*` klasörleri oluşturulmuş ama tamamen **boş** — geçmişte başlanıp yarım bırakılmış bir mimari geçişin izi. |
| Başıboş kopya dosyalar | `lib/lib/pages/agreement/agreement_detail_page.dart`, `lib/lib/pages/home/home_page.dart`, `lib/lib/utils/app_helpers.dart` — yanlışlıkla oluşmuş `lib/lib/` iç içe klasörü, pubspec/main.dart tarafından kullanılmıyor, muhtemelen döküntü. |
| Bozuk test dosyası | `test/widget_test.dart` hâlâ Flutter'ın varsayılan "sayaç" şablonu; olmayan bir `MyApp` sınıfına referans veriyor, gerçek uygulamayı test etmiyor. **Şu an proje sıfır gerçek test kapsamına sahip.** |
| ProGuard/R8 kapalı | `isMinifyEnabled = false`, `isShrinkResources = false` — APK/AAB gereksiz büyük olur, kod küçültme/gizleme yok. Play Store'u engellemez ama önerilmez. |
| Üç kopya imzalama dosyası | `upload-keystore.jks` kök, `android/`, ve `android/app/` içinde üç kez duruyor — karışıklığa açık. |
| README güncel değil | İçeriği kısa ve muhtemelen şablon düzeyinde; kapsamlı değil. |

## 6. DERLEME / TEST ORTAMI — ÖNEMLİ SINIRLAMA

Bu Cowork oturumunun çalıştığı sanal ortamda **Flutter SDK kurulu değil** ve internet erişimi bir izin listesiyle kısıtlı olduğu için Flutter SDK'yı indirip kuramıyorum (`storage.googleapis.com` erişimi engelleniyor). Bu nedenle şu adımları bu ortamda **çalıştıramadım**:

- `flutter doctor`
- `flutter --version`
- `flutter pub get`
- `flutter analyze`
- `flutter build apk` / `flutter build appbundle`

**Bunun anlamı:** Kod düzeyinde inceleme, dosya düzenleme, mimari yeniden yapılandırma, Firestore/Storage kural yazımı gibi işleri burada tam olarak yapabilirim. Ama gerçek derleme, `flutter analyze` çıktısı, ve APK/AAB üretimi için sizin bilgisayarınızda (Android Studio / terminal, Flutter SDK kurulu) birkaç komutu benim yönlendirmemle **siz çalıştırmanız** gerekecek. Her seferinde tek bir komut vereceğim, sonucu yapıştırmanız yeterli olacak — sizi terminale boğmayacağım.

## 7. VERİTABANI (FIRESTORE / HIVE) DURUMU

- Firestore koleksiyon yapısı kod içinde (`FirebaseFirestore.instance.collection(...)` çağrıları) doğrudan görülebiliyor ama henüz koleksiyon isimlerini tek tek çıkarmadım — bu, 2. aşamanın (mimari + migration planı) ilk işi olacak.
- Firestore/Storage güvenlik kuralları depoda yok (bkz. 3.4).
- Hive yerel verisi (favoriler, önbellek, ayarlar) basit ve düşük riskli; yeni mimaride korunabilir.
- Mevcut üye/firma/anlaşma verisi Firebase Console tarafında duruyor; bu analiz sırasında Firebase'e bağlanmadım (kimlik bilgisi paylaşmadınız), dolayısıyla gerçek veri hacmini göremedim. 2. aşamada gerekirse Firebase Console ekran görüntüsü veya erişim isteyebilirim.

## 8. ÖNERİLEN MİMARİ

Talep edilen ölçek (çok il/şube, RBAC, onay iş akışları, PDF, harita, bildirim, AI katmanı) için:

- **Feature-first + Clean Architecture** klasör yapısı (`lib/core`, `lib/features/*`) — talep ettiğiniz yapıyla birebir uyumlu.
- **State management:** Mevcut kodda hiç state management kütüphanesi yok (sade `StatefulWidget`/`setState`). Bu ölçekte elle `setState` yönetimi sürdürülemez. **Riverpod** öneriyorum (test edilebilirlik, DI, moda olduğu için değil ihtiyaç olduğu için); Bloc alternatif olarak değerlendirilebilir. Kesin kararı 2. aşamada, ilk feature modülünü taşırken vereceğim ve burada gerekçelendireceğim.
- Repository/Service katmanları zaten iskelet olarak var ama boş — bunları gerçek içerikle dolduracağız, sıfırdan icat etmeyeceğiz.
- Mevcut `main.dart` tek seferde silinmeyecek; ekran ekran yeni yapıya taşınacak, her taşımadan sonra ayrı commit atılacak.

## 9. GÜNCELLEME PLANI VE TAHMİNİ AŞAMALAR

Talebinizdeki 8 aşamalık plana sadık kalıyorum:

1. ✅ **Analiz** (bu rapor) — tamamlandı.
2. Mimari düzenleme, kritik hata/güvenlik düzeltmeleri (yukarıdaki 3.1–3.4), oturum yönetimi doğrulaması.
3. Rol/yetki (RBAC), organizasyon/il/şube altyapısı, admin modülleri.
4. İşyeri başvuru + anlaşma + PDF + onay iş akışı.
5. İndirim/filtreleme/harita/favoriler, duyuru, etkinlik, bildirim.
6. Dijital üye kartı + QR, şikâyet/değerlendirme, raporlama.
7. Web yönetim paneli, responsive tasarım, AI servis katmanı.
8. Test, güvenlik, performans, release APK/AAB.

Bu, tek oturumda bitecek bir iş değil — çok geniş kapsamlı bir platforma dönüşüm. Her aşamayı ayrı ayrı ilerleteceğiz, her birinin sonunda ne yapıldığını, hangi dosyaların değiştiğini ve kalan riskleri Türkçe raporlayacağım.

## 10. ŞİMDİ SİZDEN GEREKEN KARARLAR

Devam etmeden önce yalnızca şunları bilmem gerekiyor:

1. **GitHub deposu public mi, private mi?** (3.1 için)
2. E-posta CSV/Excel dosyalarını depodan çıkarıp ayrı güvenli bir yere taşımamı ister misiniz? (3.2 için)
3. Firestore/Storage güvenlik kurallarının mevcut hâlini Firebase Console'dan bana aktarabilir misiniz (ekran görüntüsü yeterli), yoksa sıfırdan mı yazayım?
4. 2. aşamaya (mimari + kritik düzeltmeler) şimdi geçmemi ister misiniz, yoksa önce yukarıdaki güvenlik konularını mı çözelim?

---

## EK: YEDEKLEME

Analiz sırasında hiçbir dosya silinmedi veya üzerine yazılmadı. Proje kaynak kodunun (build/derleme önbellekleri hariç) tam bir yedeği alındı:

`_yedekler/memursen_indirimler_yedek_20260716_184020.zip` (7,1 MB)

Not: Bu ortamdaki bağlı klasörde dosya **silme** işlemi kısıtlı — yedekleme sırasında oluşan iki küçük geçici dosya (`_yedekler/` içinde 0 bayt ve isimsiz bir dosya) kalmış olabilir, zararsızdır, isterseniz manuel silebilirsiniz ya da bana silme izni verebilirsiniz.

Git tarafında henüz yeni bir commit **atılmadı** çünkü `git status` mevcut çalışma dizininde neredeyse tüm dosyaları "değişmiş" gösteriyor — incelediğimde bunun gerçek kod değişikliği değil, dosyaların bu ortama satır sonu (Windows CRLF → Linux LF) farkıyla senkronize olmasından kaynaklandığını gördüm. Bunu gerçek bir commit gibi kaydetmek geçmişi kirletebileceğinden, sizden onay almadan commit atmadım.

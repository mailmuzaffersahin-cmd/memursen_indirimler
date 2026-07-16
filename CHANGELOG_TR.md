# DEĞİŞİKLİK GÜNLÜĞÜ (Türkçe)

## 16 Temmuz 2026 — Güvenlik Düzeltmesi #1: Sızan sırların takipten çıkarılması

**Tespit:** GitHub deposu (`mailmuzaffersahin-cmd/memursen_indirimler`) **public** durumda ve şu dosyalar Git tarafından takip edilip GitHub'da herkese açık şekilde görünüyordu:
- `key.properties` (imzalama şifreleri)
- `upload-keystore.jks` (imzalama anahtarı)
- `Eposta Adresleri.csv`, `Eposta Adresleri2.csv`, `Eposta Adresleri son ekleme.csv` (2.374 satır kişisel e-posta)
- `Excel_Toplu_Yukle.xlsx`, `MemurSen_Temsilcilikler_Excel_Styles_Duzeltildi(1).xlsx`

**Yapılan:**
1. `.gitignore` güncellendi: `key.properties`, `*.jks`, `*.keystore`, `service-account*.json`, `.env`, kişisel veri dosyaları ve `_yedekler/` artık takip dışı.
2. Yukarıdaki 7 dosya `git rm --cached` ile depo takibinden çıkarıldı (dosyalar bilgisayarınızda duruyor, sadece Git artık onları izlemiyor).
3. Değişiklik yerel olarak commit edildi.

## 16 Temmuz 2026 — Güvenlik Düzeltmesi #2: Git geçmişinin tamamen temizlenmesi

Kullanıcı onayıyla `git filter-branch` kullanılarak **tüm branch'lerin ve `v1.0.5` etiketinin** komple geçmişi yeniden yazıldı; `key.properties`, `upload-keystore.jks` ve kişisel veri dosyaları geçmişteki hiçbir commit'te kalmayacak şekilde kaldırıldı. Yerel `.git` deposu doğrulandı (`git fsck --full` hatasız, tüm branch/tag'ler sağlam).

**Kullanıcı tarafından yapıldı ve doğrulandı:** `git push origin --force --all` ve `git push origin --force --tags` çalıştırıldı. GitHub'da `key.properties` ve e-posta CSV'lerinin artık `main` dalında bulunmadığı doğrulandı (404 dönüyor).

**Devam eden öneri:** İmzalama şifrelerini bir süre herkese açık kaldığı için güvenilir kabul etmeyin. Google Play Console'da **"Play App Signing"** kullanıp kullanmadığını kontrol edin: kullanılıyorsa yükleme (upload) anahtarı Play Console üzerinden sıfırlanabilir ve mevcut yayınlanmış uygulamayı bozmaz. Kullanılmıyorsa anahtar değişimi daha risklidir, ayrıca değerlendirilmesi gerekir.

## 16 Temmuz 2026 — AŞAMA 2 (kısmi): Ölü kod, oturum yönetimi, test düzeltmesi

**Yapılan (commit `038b281`):**
1. `lib/lib/` klasörü kaldırıldı — pubspec/main.dart tarafından hiç kullanılmayan, tamamen boş 3 döküntü dosya içeriyordu.
2. **Oturum yönetimi güçlendirildi:** Yönetici girişi artık `AdminGate` adlı yeni bir widget üzerinden `FirebaseAuth.instance.authStateChanges()` akışı dinlenerek kontrol ediliyor. Eskiden `openAdmin()` fonksiyonu oturumu yalnızca butona basıldığı anda tek seferlik kontrol ediyordu; bu, ekranlar arası geçişte oturumun bayatlaması riski taşıyordu. Yeni yapı bu riski ortadan kaldırır.
3. `test/widget_test.dart` düzeltildi — eski hâli var olmayan bir `MyApp` sınıfına referans veriyordu ve hiçbir zaman çalışmıyordu. Artık gerçek `MemurSenApp`'i açıp splash ekranının hatasız çizildiğini doğrulayan çalışır bir test var.

**Şeffaflık notu:** Bu adımı uygularken bir defasında bu ortamdaki dosya senkronizasyon gecikmesi yüzünden `.gitignore` güncellemesi henüz etkili olmadan `git add -A` çalıştırdım ve imzalama/kişisel veri dosyaları yanlışlıkla iki kez yeniden commit'e girdi. Her ikisi de fark edilir edilmez `git reset --soft` ile geri alındı ve GitHub'a hiçbir zaman push edilmedi — yalnızca bu ortamdaki yerel commit geçmişinde kısa süre var oldular. Son durum doğrulandı: `git ls-files` içinde bu dosyalardan hiçbiri yok, `git fsck` temiz.

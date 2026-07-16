# DEĞİŞİKLİK GÜNLÜĞÜ (Türkçe)

## 16 Temmuz 2026 — Güvenlik Düzeltmesi #1: Sızan sırların takipten çıkarılması

**Branch:** feature/performans-cache
**Commit:** c1860f4 — "guvenlik: imzalama sirlari ve kisisel veri dosyalari git takibinden cikarildi"

**Tespit:** GitHub deposu (`mailmuzaffersahin-cmd/memursen_indirimler`) **public** durumda ve şu dosyalar Git tarafından takip edilip GitHub'da herkese açık şekilde görünüyordu:
- `key.properties` (imzalama şifreleri)
- `upload-keystore.jks` (imzalama anahtarı)
- `Eposta Adresleri.csv`, `Eposta Adresleri2.csv`, `Eposta Adresleri son ekleme.csv` (2.374 satır kişisel e-posta)
- `Excel_Toplu_Yukle.xlsx`, `MemurSen_Temsilcilikler_Excel_Styles_Duzeltildi(1).xlsx`

**Yapılan:**
1. `.gitignore` güncellendi: `key.properties`, `*.jks`, `*.keystore`, `service-account*.json`, `.env`, kişisel veri dosyaları ve `_yedekler/` artık takip dışı.
2. Yukarıdaki 7 dosya `git rm --cached` ile depo takibinden çıkarıldı (dosyalar bilgisayarınızda duruyor, sadece Git artık onları izlemiyor).
3. Değişiklik yerel olarak commit edildi.

**Yapılamayan / sizin yapmanız gereken:**
- Bu ortamdan GitHub'a ağ erişimim yok (proxy engelliyor), bu yüzden hiçbir şeyi **push edemedim**. Aşağıdaki tek komutu kendi bilgisayarınızdan çalıştırmanız gerekiyor.
- **En acil ve en düşük riskli önlem (hemen yapın):** GitHub'da depoyu **private** yapın: Settings → Danger Zone → Change repository visibility. Bu, aşağıdaki adımı beklemeden anlık herkese açık erişimi durdurur.

## 16 Temmuz 2026 — Güvenlik Düzeltmesi #2: Git geçmişinin tamamen temizlenmesi

Kullanıcı onayıyla `git filter-branch` kullanılarak **tüm branch'lerin ve `v1.0.5` etiketinin** komple geçmişi yeniden yazıldı; `key.properties`, `upload-keystore.jks` ve kişisel veri dosyaları geçmişteki hiçbir commit'te kalmayacak şekilde kaldırıldı. Yerel `.git` deposu doğrulandı (`git fsck --full` hatasız, tüm branch/tag'ler sağlam).

**⚠️ ÖNEMLİ — Commit numaraları (
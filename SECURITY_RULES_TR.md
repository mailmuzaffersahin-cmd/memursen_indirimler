# GÜVENLİK KURALLARI — UYGULAMA TALİMATI (ÇOK ÖNEMLİ SIRA)

Bu belge, `firestore.rules` ve `storage.rules` dosyalarını **kendi admin
girişinizi kilitlemeden** nasıl canlıya alacağınızı anlatır. Adımları
sırayla, atlamadan uygulayın.

## Neden bu kurallar gerekli?

Analiz sırasında tespit edildiği gibi (`PROJECT_ANALYSIS_TR.md` bölüm 3.4),
projede hiç güvenlik kuralı yoktu. Ayrıca mevcut uygulamada **herhangi bir
Firebase Auth hesabıyla giriş yapan herkes** (yönetici girişi yapan siz dahil,
ama teorik olarak sendika yetkilisi kayıt formundan kendi hesabını oluşturan
biri de) admin paneline erişebiliyordu — çünkü uygulama içi kontrol yalnızca
"giriş yapılmış mı" diye bakıyor, "bu kişi gerçekten admin mi" diye
bakmıyordu. Yeni kurallar bunu, ayrı bir `admins` listesiyle düzeltiyor.

## ADIM 1 — Kendi Firebase Auth UID'nizi bulun

1. https://console.firebase.google.com adresine gidin, `memursenindirimler`
   projesini açın.
2. Sol menüden **Authentication** → **Users** sekmesine gidin.
3. Şu an admin girişi için kullandığınız e-posta adresini bulun, yanındaki
   **User UID** değerini kopyalayın (uzun bir harf/rakam dizisi).

## ADIM 2 — `admins` koleksiyonuna kendinizi ekleyin

1. Sol menüden **Firestore Database** → **Data** sekmesine gidin.
2. **Start collection** (Koleksiyon başlat) deyin, koleksiyon adı olarak
   tam olarak `admins` yazın.
3. Belge ID'si olarak Adım 1'de kopyaladığınız UID'yi yapıştırın.
4. En az bir alan eklemeniz istenecek — `email` alanı ekleyip kendi
   e-postanızı yazmanız yeterli (değeri önemli değil, sadece belge var
   olsun).
5. Kaydedin.

**Birden fazla yönetici hesabınız varsa, her biri için bu adımı tekrarlayın.**

## ADIM 3 — Kuralları Firebase Console'a yapıştırın

### Firestore kuralları
1. **Firestore Database** → **Rules** sekmesine gidin.
2. Projenizdeki `firestore.rules` dosyasının tüm içeriğini kopyalayıp
   oradaki editöre yapıştırın (mevcut içeriğin üzerine yazın).
3. **Publish** (Yayımla) butonuna basın.

### Storage kuralları
1. **Storage** → **Rules** sekmesine gidin.
2. Projenizdeki `storage.rules` dosyasının tüm içeriğini kopyalayıp
   yapıştırın.
3. **Publish** butonuna basın.

## ADIM 4 — Doğrulayın

1. Uygulamayı (veya web önizlemeyi) açın, admin girişi yapın.
2. Yönetim paneline erişebildiğinizi, anlaşma ekleyebildiğinizi doğrulayın.
3. Eğer erişim reddedildi hatası alırsanız: Adım 1-2'yi tekrar kontrol edin
   — UID doğru kopyalanmamış veya `admins` koleksiyonundaki belge ID'si
   yanlış yazılmış olabilir.

## Bu kurallar neyi değiştiriyor?

- `agreements`, `temsilciler`, `app_settings`: herkes okuyabilir (uygulama
  bunlara misafir olarak da erişiyor), yalnızca `admins` listesindeki
  kullanıcılar yazabilir.
- `authorized_users`: bir kullanıcı yalnızca **kendi** başvuru kaydını
  oluşturabilir/okuyabilir; onaylama/reddetme gibi işlemler yalnızca admin'e
  ait.
- `business_applications`: herkes başvuru gönderebilir, yalnızca admin
  görüp yönetebilir.
- `organizations`, `roles`: giriş yapmış herkes okuyabilir (uygulama içi
  yetki kontrolleri için gerekli), yalnızca admin değiştirebilir.
- `admins`: yalnızca Firebase Console'dan elle yönetilir — hiçbir kullanıcı
  kendini veya başkasını uygulama üzerinden admin yapamaz.
- Storage'da yüklenen dosyalar için tür (resim/PDF) ve boyut sınırı
  (logo 10 MB, belge 20 MB) sunucu tarafında zorunlu kılınıyor.
- Yukarıda tanımlanmayan her koleksiyon/yol varsayılan olarak **kapalı**.

## Bilinmesi gereken sınırlama

Bu kurallar "admin mi değil mi" ayrımını netleştiriyor, ama **il/şube bazlı
ince taneli yetkilendirmeyi** (bir il temsilcisinin yalnızca kendi iline ait
kayıtları düzenleyebilmesi gibi) henüz uygulamıyor — bunun için önce gerçek
kullanıcıların `organizationId`/`roleId` alanlarının doldurulmuş olması
gerekiyor (bkz. `FIRESTORE_SCHEMA_TR.md` bölüm 3, migration planı). Bu,
sonraki bir aşamada ele alınacak.

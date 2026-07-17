# FIRESTORE ŞEMA DOKÜMANI (Türkçe)

Bu belge, mevcut koleksiyonları ve Aşama 3 kapsamında eklenen RBAC (rol/yetki)
ve organizasyon altyapısını açıklar. **Mevcut koleksiyonlar hiçbir alanı
kaybetmeden korunuyor** — yeni alanlar/koleksiyonlar üstüne ekleniyor.

## 1. MEVCUT KOLEKSİYONLAR (korunuyor, değişmiyor)

### `agreements`
Firma/indirim kayıtları. Alanlar (koddan tespit edilen): `companyName`,
`category`, `city`, `district`, `discountRate`, `scopeType`
(`city`|`district`|`nationwide`|`online`|`out_of_city`), `isActive`,
`isFeatured`, `startDate`, `endDate`, `latitude`, `longitude`, `logoUrl`/
`imageUrl`, `expiredAutomatically`.

### `temsilciler`
İl/şube temsilci bilgileri. Alanlar: `city`, `name`, `title`, `phone`,
`mobile`, `email`, `address`, `latitude`, `longitude`, `website`,
`isGeneralCenter`, `isActive`, `updatedAt`.

### `authorized_users`
Sendika yetkilisi başvuruları ve hesapları (doc id = Firebase Auth uid).
Mevcut alanlar: `uid`, `fullName`, `email`, `phone`, `unionName`, `city`,
`district`, `branchName`, `role` (serbest metin), `status` (`pending` vb.),
`canCreateAgreement`, `canEditAgreement`, `canDeleteAgreement`, `createdAt`,
`updatedAt`.

**Bu koleksiyon RBAC'ın temelini zaten atmış durumda** — yeni sistem bunu
sıfırdan değiştirmek yerine üzerine inşa ediyor (bkz. aşağıdaki yeni alanlar).

### `business_applications`
İşyeri başvuruları (mevcut kod tabanında kullanılıyor, alanları
`business_registration_page.dart` içinde tanımlı).

### `app_settings`
Tekil ayar dokümanları (örn. `app_settings/representative`).

## 2. YENİ KOLEKSİYONLAR (Aşama 3)

### `organizations`
Genel Merkez → İl → Şube → İlçe Temsilciliği hiyerarşisi.

```
organizations/{orgId}
  name: string
  type: 'headquarters' | 'province' | 'branch' | 'district'
  parentId: string | null        // ust organizasyonun orgId'si, Genel Merkez icin null
  code: string | null            // opsiyonel kisa kod (ör. "38" Kayseri plaka kodu)
  isActive: bool
  createdAt, updatedAt, createdBy, updatedBy
```

### `roles`
Yönetim panelinden düzenlenebilir rol tanımları (sabit kodlanmamış).

```
roles/{roleId}
  name: string                    // ör. "İl Temsilcisi"
  key: string                     // ör. "province_rep" - koddaki sabit anahtar
  isSystemRole: bool               // true ise silinemez (super_admin gibi)
  permissions: string[]            // aşağıdaki yetki anahtarları listesi
  scopeType: 'global' | 'province' | 'branch' | 'business' | 'self'
  createdAt, updatedAt
```

Başlangıç (tohum/seed) rolleri — `lib/core/rbac/app_roles.dart` içinde kod
tarafında sabit tanımlı, ama Firestore `roles` koleksiyonunda override
edilebilir:

| key | Türkçe ad | scopeType |
|---|---|---|
| super_admin | Genel Merkez Süper Admin | global |
| province_rep | İl Temsilcisi | province |
| branch_rep | Şube Temsilcisi | branch |
| business_owner | Anlaşmalı İşyeri Yetkilisi | business |
| member | Üye | self |
| guest | Misafir | self |
| content_editor | İçerik Editörü | province |
| auditor | Denetçi | global |
| legal | Hukuk Birimi | global |
| finance | Mali İşler | global |
| communications | İletişim Birimi | global |
| event_manager | Etkinlik Sorumlusu | province |
| viewer | Salt Görüntüleme Yetkilisi | province |
| approver | Onay Yetkilisi | province |
| support | Destek Personeli | global |

Yetki anahtarları (`permissions[]` içinde kullanılan sabit string'ler):
`view`, `create`, `edit`, `delete`, `deactivate`, `submit_for_approval`,
`approve`, `reject`, `request_correction`, `publish`, `archive`,
`generate_report`, `export_excel`, `generate_pdf`, `send_notification`,
`manage_users`, `grant_permission`, `view_logs`.

### `auditLogs`
Onay/yetki işlemlerinin denetim izi.

```
auditLogs/{logId}
  action: string                  // 'approve' | 'reject' | ...
  targetCollection: string
  targetDocId: string
  performedByUid: string
  performedByEmail: string
  organizationId: string | null
  oldValue: map | null
  newValue: map | null
  note: string | null
  createdAt: timestamp
```

## 3. `authorized_users` GENİŞLETMESİ (geriye dönük uyumlu)

Mevcut alanlar korunuyor. Şu yeni alanlar **eklenir** (mevcut veriler için
boş/null olabilir, kod her iki durumu da idare edecek şekilde yazılacak):

```
roleId: string | null            // roles/{roleId} referansı
organizationId: string | null    // organizations/{orgId} referansı
legacyRole: string                // eski 'role' alaninin bir kopyasi (migration guvenligi)
```

Geçiş stratejisi: Yeni kullanıcı kayıtlarında hem eski (`role`, `city`,
`district`, `branchName`) hem yeni (`roleId`, `organizationId`) alanlar
birlikte yazılır (dual-write). Mevcut kayıtlar için ayrı bir migration script'i
(Aşama 3 sonunda) eski alanlardan yeni referanslara eşleme yapacak. Bu, hiçbir
mevcut kullanıcının erişimini kesintiye uğratmadan geçişi sağlar.

## 4. SOFT DELETE VE STANDART ALANLAR

Yeni koleksiyonların tümünde standart alanlar: `createdAt`, `updatedAt`,
`createdBy`, `updatedBy`, `isDeleted` (soft delete), `version`. Mevcut
koleksiyonlar (`agreements`, `temsilciler`) bu alanları henüz zorunlu
tutmuyor; ileride kademeli olarak eklenecek.

## 5. GÜVENLİK KURALLARI DURUMU

Bu belge yazıldığı sırada `firestore.rules` / `storage.rules` proje
deposunda **bulunmuyordu** (bkz. `PROJECT_ANALYSIS_TR.md` bölüm 3.4).
`organizations` ve `roles` koleksiyonları eklendikten sonra, kural yazımı bu
şemaya göre yapılacak: temel prensip — `roles/{roleId}.permissions` içinde
gerekli yetki olmadan yazma yok, kullanıcı kendi `roleId`/`organizationId`
alanını değiştiremez, `organizationId` kapsamı dışındaki kayıtlara yazamaz.

# BIST-Algo-Analyzer

### Team Members

1. **Caner Erenler**
2. **Fırat Kat**
3. **Mina Sultan Çelik**
4. **Abdurrahman Baykan**

Github Link https://github.com/firatkatt/BIST-Algo-Analyzer

Video link https://drive.google.com/file/d/1dat0VaryJ-QR-v28ymTVaPi21C7e91_I/view?usp=sharing

PostgreSQL tabanlı bu proje, Borsa İstanbul şirketlerinin günlük fiyat hareketleri ile KAP haberlerini aynı veritabanında birleştirerek analiz etmeyi amaçlayan bir karar destek sistemidir.

Projenin final sürümünde:
- normalize edilmiş çekirdek şema
- indeksler ve veri bütünlüğü kısıtları
- 2 anlamlı view
- 1 stored procedure
- 1 trigger
- CTE, window function, subquery ve aggregate içeren ileri SQL sorguları
- çalıştırılabilir test verisi
bulunur.

---

## Proje İçeriği

- `sql/schema.sql`: Final veritabanı şeması
- `sql/seed_data.sql`: Tüm tabloları dolduran örnek veri seti
- `sql/queries.sql`: View, procedure, trigger ve demo sorgular
- `docs/technical_report.md`: Final teknik rapor
- `docs/video_script.md`: 5-10 dakikalık video sunum akışı
- `scripts/data_builder.py`: Daha büyük CSV veri seti üreticisi

---

## Veri Modeli

Çekirdek tasarım 8 tablo üzerine kuruludur:

- `Sectors`
- `Companies`
- `Market_Indices`
- `Company_Indices`
- `Daily_Prices`
- `KAP_News`
- `Sentiment_Dictionary`
- `News_Sentiments`

Bu yapı;
- 1:N ilişkiler,
- M:N ara tablo ilişkileri,
- PK/FK bütünlüğü,
- performans indeksleri
ile desteklenir.

`Base_Sentiment_Score` alanı, analitik amaçlı bir cache olarak tutulur ve `News_Sentiments` tablosundaki değişikliklere trigger ile otomatik senkronlanır.

---

## Final SQL Ozellikleri

### View'lar
- `Firsat_Hisseleri_View`
  - Pozitif haber akışı olan günlerde şirket fiyatı, hacim ve duygu skorunu tek tabloda toplar.
- `Sektor_Risk_Ozeti_View`
  - Sektör bazında haber yoğunluğu, ortalama kapanış fiyatı ve negatif kelime sayısını özetler.

### Stored Procedure
- `sp_recalculate_news_sentiment(p_news_id)`
  - Tek bir haberin veya tüm haberlerin sentiment skorunu yeniden hesaplar.
  - Bulk yükleme sonrası veya manuel veri değişikliğinde kullanılabilir.

### Trigger
- `trg_news_sentiments_refresh_score`
  - `News_Sentiments` tablosuna insert/update/delete olduğunda ilgili `KAP_News.Base_Sentiment_Score` alanını otomatik günceller.

### Ileri SQL Sorgulari
- View üzerinden fırsat hisseleri analizi
- CTE + window function ile SMA-50 analizi
- Correlated subquery ile sektör ortalamasına göre karşılaştırma

---

## Veri Seti

`sql/seed_data.sql` içinde şu örnek veriler hazırlanmıştır:

- 8 sektör
- 5 endeks
- 10 şirket
- 12 duygu sözlüğü terimi
- 80+ işlem günü kapsayan günlük fiyat verisi
- 12 KAP haberi
- 36 haber-kelime eşleştirmesi

Bu veri seti:
- SMA-50 sorgusunun çalışması,
- sector summary view'ının anlamlı sonuç dönmesi,
- trigger ve procedure testleri
için yeterlidir.

Repo içinde ayrıca `data/` klasöründe daha büyük CSV veri setleri de bulunur. İsterseniz bu CSV'leri ayrı bir import akışıyla da kullanabilirsiniz.

---

## Kurulum Sırası

1. Boş bir PostgreSQL veritabanı oluşturun.
2. `sql/schema.sql` dosyasını çalıştırın.
3. `sql/seed_data.sql` dosyasını çalıştırın.
4. `sql/queries.sql` dosyasını çalıştırın.
5. Örnek sonuçları görmek için şu sorguları çalıştırın:
   - `SELECT * FROM Firsat_Hisseleri_View;`
   - `SELECT * FROM Sektor_Risk_Ozeti_View;`
   - `CALL sp_recalculate_news_sentiment(NULL);`

---

## Teknik Notlar

- Şema PostgreSQL uyumludur.
- Tarih bazlı analizler için `Daily_Prices(Company_ID, Price_Date)` ve `KAP_News((News_Date::date))` indeksleri eklendi.
- `Daily_Prices` tablosunda OHLC mantığını koruyan `CHECK` kısıtları vardır.
- `News_Sentiments.Match_Count` pozitif değer zorunluluğu ile veri kalitesi korunur.


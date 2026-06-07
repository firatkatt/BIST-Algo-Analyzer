# Final Video Sunum Scripti

Süre hedefi: 5-10 dakika

## 0:00 - 0:30 | Açılış

- Projenin adını söyleyin: `BIST-Algo-Analyzer`.
- Tek cümlede problemi anlatın: fiyat verisi ile KAP haberlerinin tek yerde toplanması.
- Projenin amacını vurgulayın: yatırımcıya karar destek sağlamak.

Örnek konuşma:
- "Bu proje, Borsa İstanbul şirketlerinin günlük fiyatlarını ve KAP haberlerini aynı veritabanında birleştirerek analiz etmeyi amaçlıyor."

## 0:30 - 1:30 | Veri Modeli ve ERD

- ERD görselini açın.
- 8 temel tabloyu tek tek söyleyin.
- 1:N ve M:N ilişkileri belirtin.
- `Company_Indices` ve `News_Sentiments` ara tablolarının neden gerekli olduğunu açıklayın.

Örnek konuşma:
- "Sektörler, şirketler, fiyatlar ve haberler birbirinden ayrıldı. Böylece hem normalizasyon sağlandı hem de analiz için esnek bir yapı kuruldu."

## 1:30 - 2:30 | Normalizasyon ve Bütünlük

- PK, FK ve unique kısıtlarını gösterin.
- `Daily_Prices` tablosundaki CHECK kısıtlarını anlatın.
- `Base_Sentiment_Score` alanının cache olduğunu ve trigger ile güncellendiğini söyleyin.
- Performans indekslerinden bahsedin.

Örnek konuşma:
- "Çekirdek yapı 3NF mantığıyla tasarlandı. Derlenen sentiment skorunu da ayrı bir cache alanında tutuyoruz ama bunu trigger ile otomatik senkronluyoruz."

## 2:30 - 3:30 | Seed Data ve Test Ortamı

- `seed_data.sql` dosyasını gösterin.
- Örnek veri setinin ne kadar yeterli olduğunu söyleyin:
  - sektörler
  - şirketler
  - endeksler
  - 80+ işlem günü
  - haberler ve sentiment eşleştirmeleri
- Verinin neden gerçekçi olduğunu açıklayın.

Örnek konuşma:
- "Bu veri seti sadece tabloları doldurmak için değil, SMA-50 ve sektör özetleri gibi analizleri gerçek anlamda test etmek için hazırlandı."

## 3:30 - 5:00 | View'lar ve İleri SQL

- `Firsat_Hisseleri_View` çıktısını gösterin.
- Bu view’un JOIN, GROUP BY, HAVING ve aggregate kullandığını söyleyin.
- `Sektor_Risk_Ozeti_View` çıktısını gösterin.
- Burada sektör bazlı risk analizi yaptığınızı belirtin.

Örnek konuşma:
- "İlk görünüm, pozitif haber akışı olan fırsat hisselerini tek tabloda topluyor. İkinci görünüm ise sektörlerin haber riski profilini özetliyor."

## 5:00 - 6:30 | CTE, Window Function ve Subquery

- `queries.sql` içindeki SMA-50 sorgusunu çalıştırın.
- CTE kullanımını ve window function ile hareketli ortalamayı anlatın.
- Correlated subquery sorgusunu gösterin.
- Sektör ortalamasına göre karşılaştırma mantığını özetleyin.

Örnek konuşma:
- "Burada klasik raporlama değil, analitik SQL görüyoruz. CTE ile kod okunabilir oldu, window function ile SMA-50 hesaplandı, subquery ile de sektör bazlı karşılaştırma yaptık."

## 6:30 - 7:30 | Procedure ve Trigger

- `sp_recalculate_news_sentiment` procedure'ını anlatın.
- Trigger'ın ne zaman çalıştığını söyleyin.
- Mümkünse kısa bir demo yapın:
  - bir `News_Sentiments` kaydı ekleyin
  - `KAP_News.Base_Sentiment_Score` değerinin otomatik güncellendiğini gösterin

Örnek konuşma:
- "Buradaki amaç, analiz skorunun elle hesaplanmasına gerek kalmadan otomatik olarak güncel kalması."

## 7:30 - 8:30 | Sonuç ve Kapanış

- Projenin ne sağladığını tekrar özetleyin.
- Final kriterlerinin nasıl karşılandığını tek cümleyle bağlayın.
- Eğer frontend varsa kısa bir ekran gösterimi ekleyin; yoksa backend çıktılarıyla kapanış yapın.

Örnek konuşma:
- "Bu proje, finansal veriyi ve haber duyarlılığını tek ilişkisel yapıda birleştirerek hem normalizasyonu hem de ileri SQL yeteneklerini gösteren bir karar destek sistemi ortaya koyuyor."

## Sunum Sırasında Unutulmaması Gerekenler

- Backend’i atlamayın.
- Sadece frontend gösterip geçmeyin.
- En az bir view, bir trigger, bir procedure ve bir CTE sorgusunu canlı olarak gösterin.
- Veri akışını schema -> seed -> query sırasıyla anlatın.


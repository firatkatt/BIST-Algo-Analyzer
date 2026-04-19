-- ============================================================================
-- BIST-Algo-Analyzer: Final Queries
-- Kategori 3 (İleri Seviye SQL Uygulamaları) için Şov Sorguları
-- Mimarimizdeki Views, Window Functions, JOINs, CTE (WITH) yeteneklerini gösterir.
-- NOT: Tablolar data klasöründeki CSV'lerden "Import Data" yapılarak doldurulmalıdır.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PROJE SORGUSU 1: ALGORİTMİK FIRSAT HİSSELERİ GÖRÜNÜMÜ (VIEW + JOIN + GROUP BY)
-- Amaç: Bugün hakkında olumlu haberler (Duygu skoru pozitif) çıkmış olan 
--       ama borsa fiyatında beklenen sıçramayı (henüz) yapmamış olan hisseleri 
--       sentezleyerek yatırımcıya bir öneri tablosu sunar.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW Firsat_Hisseleri_View AS
SELECT 
    c.Company_Code, 
    c.Company_Name,
    dp.Price_Date,
    dp.Close_Price,
    dp.Volume,
    -- Haberin ve kelimenin ağırlıklandırılmış toplam puanı
    SUM(sd.Sentiment_Score * ns.Match_Count) AS Total_Daily_Sentiment_Score,
    COUNT(DISTINCT kn.News_ID) AS Total_News_Count
FROM Companies c
JOIN Daily_Prices dp ON c.Company_ID = dp.Company_ID
-- O gün çıkan haberlerle eşleşme
JOIN KAP_News kn ON c.Company_ID = kn.Company_ID AND dp.Price_Date = DATE(kn.News_Date)
JOIN News_Sentiments ns ON kn.News_ID = ns.News_ID
JOIN Sentiment_Dictionary sd ON ns.Word_ID = sd.Word_ID
GROUP BY 
    c.Company_Code, 
    c.Company_Name, 
    dp.Price_Date, 
    dp.Close_Price,
    dp.Volume
HAVING SUM(sd.Sentiment_Score * ns.Match_Count) > 0 -- Sadece pozitif algısı olan günler
ORDER BY dp.Price_Date DESC, Total_Daily_Sentiment_Score DESC;


-- ----------------------------------------------------------------------------
-- PROJE SORGUSU 2: FİYAT / HAREKETLİ ORTALAMA KIYASLAMASI (WINDOW FUNCTIONS)
-- Amaç: Hisse senetlerinin o günkü kapanış fiyati ile kendi geçmiş 50 günlük
--       (SMA-50) ortalamalarını kıyaslayarak teknik bir indikatör oluşturmak.
-- ----------------------------------------------------------------------------
-- CTE (Common Table Expression - WITH) kullanarak kodu daha okunabilir hale getirdik
WITH Moving_Averages_CTE AS (
    SELECT 
        c.Company_Code,
        dp.Price_Date,
        dp.Close_Price,
        -- Window Function: Şirketi grupla (Partition), TARIHE göre sırala (Order) 
        -- ve kendisinden önceki 50 günün Fiyat Ortalamasını (AVG) satır satır al.
        ROUND(AVG(dp.Close_Price) OVER (
            PARTITION BY c.Company_Code 
            ORDER BY dp.Price_Date 
            ROWS BETWEEN 50 PRECEDING AND CURRENT ROW
        ), 2) AS SMA_50
    FROM Daily_Prices dp
    JOIN Companies c ON dp.Company_ID = c.Company_ID
)
SELECT 
    Company_Code,
    Price_Date,
    Close_Price,
    SMA_50,
    -- Eğer mevcut hisse fiyatı 50 günlük ortalamasından düşükse (Ucuzlamışsa) sinyal üret
    CASE 
        WHEN Close_Price < SMA_50 THEN 'POTANSIYEL ALIM NOKTASI'
        ELSE 'BEKLE / SAT'
    END AS Technical_Signal
FROM Moving_Averages_CTE
ORDER BY Company_Code, Price_Date DESC;


-- ----------------------------------------------------------------------------
-- PROJE SORGUSU 3: SEKTÖREL NEGATİF HABER TEPKİLERİ (AGGREGATION)
-- Amaç: Hangi sektör negatif içerikli kelimeler (dava, ceza, zarar) geçiren haberler
--       yüzünden en çok etkilenmiştir? 
-- ----------------------------------------------------------------------------
SELECT 
    s.Sector_Name,
    COUNT(kn.News_ID) AS Total_Negative_News
FROM Sectors s
JOIN Companies c ON s.Sector_ID = c.Sector_ID
JOIN KAP_News kn ON c.Company_ID = kn.Company_ID
JOIN News_Sentiments ns ON kn.News_ID = ns.News_ID
JOIN Sentiment_Dictionary sd ON ns.Word_ID = sd.Word_ID
WHERE sd.Sentiment_Score < 0 -- Sadece negatif kelime barındıranlar
GROUP BY s.Sector_Name
ORDER BY Total_Negative_News DESC;

-- ============================================================================
-- BIST-Algo-Analyzer: Final SQL Objects and Advanced Queries
-- Bu dosya schema.sql'den sonra çalıştırılmalıdır.
-- İçerik:
--   1) Views
--   2) Stored Procedure
--   3) Trigger + Trigger Function
--   4) Advanced demo queries
-- ============================================================================

DROP VIEW IF EXISTS Firsat_Hisseleri_View CASCADE;
DROP VIEW IF EXISTS Sektor_Risk_Ozeti_View CASCADE;
DROP PROCEDURE IF EXISTS sp_recalculate_news_sentiment(INTEGER);
DROP FUNCTION IF EXISTS fn_refresh_news_sentiment_score();

-- ----------------------------------------------------------------------------
-- VIEW 1: FIRSAT HİSSELERİ
-- Amaç: Aynı gün içinde pozitif haber akışı olan şirketleri, fiyat ve hacim
--       bilgileriyle birlikte tek bir rapor görünümünde toplamak.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW Firsat_Hisseleri_View AS
SELECT
    c.Company_Code,
    c.Company_Name,
    dp.Price_Date,
    dp.Close_Price,
    dp.Volume,
    COUNT(DISTINCT kn.News_ID) AS Total_News_Count,
    COALESCE(ROUND(SUM(sd.Sentiment_Score * ns.Match_Count), 2), 0) AS Total_Daily_Sentiment_Score
FROM Companies c
JOIN Daily_Prices dp
    ON dp.Company_ID = c.Company_ID
LEFT JOIN KAP_News kn
    ON kn.Company_ID = c.Company_ID
   AND kn.News_Date::date = dp.Price_Date
LEFT JOIN News_Sentiments ns
    ON ns.News_ID = kn.News_ID
LEFT JOIN Sentiment_Dictionary sd
    ON sd.Word_ID = ns.Word_ID
GROUP BY
    c.Company_Code,
    c.Company_Name,
    dp.Price_Date,
    dp.Close_Price,
    dp.Volume
HAVING COALESCE(SUM(sd.Sentiment_Score * ns.Match_Count), 0) > 0;

-- ----------------------------------------------------------------------------
-- VIEW 2: SEKTÖR RİSK ÖZETİ
-- Amaç: Hangi sektörlerin negatif haber ve olumsuz skor açısından daha kırılgan
--       olduğunu tek bir görünümde özetlemek.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW Sektor_Risk_Ozeti_View AS
WITH Sector_Companies AS (
    SELECT
        s.Sector_ID,
        s.Sector_Name,
        COUNT(c.Company_ID) AS Company_Count
    FROM Sectors s
    JOIN Companies c
        ON c.Sector_ID = s.Sector_ID
    GROUP BY s.Sector_ID, s.Sector_Name
),
Sector_Prices AS (
    SELECT
        c.Sector_ID,
        ROUND(AVG(dp.Close_Price), 2) AS Avg_Close_Price
    FROM Companies c
    JOIN Daily_Prices dp
        ON dp.Company_ID = c.Company_ID
    GROUP BY c.Sector_ID
),
Sector_News AS (
    SELECT
        c.Sector_ID,
        COUNT(DISTINCT kn.News_ID) AS Total_News_Count,
        ROUND(AVG(kn.Base_Sentiment_Score), 2) AS Avg_News_Sentiment,
        COALESCE(SUM(news_word.Negative_Word_Mentions), 0) AS Negative_Word_Mentions
    FROM Companies c
    LEFT JOIN KAP_News kn
        ON kn.Company_ID = c.Company_ID
    LEFT JOIN (
        SELECT
            ns.News_ID,
            SUM(CASE WHEN sd.Sentiment_Score < 0 THEN ns.Match_Count ELSE 0 END) AS Negative_Word_Mentions
        FROM News_Sentiments ns
        JOIN Sentiment_Dictionary sd
            ON sd.Word_ID = ns.Word_ID
        GROUP BY ns.News_ID
    ) news_word
        ON news_word.News_ID = kn.News_ID
    GROUP BY c.Sector_ID
)
SELECT
    sc.Sector_Name,
    sc.Company_Count,
    COALESCE(sn.Total_News_Count, 0) AS Total_News_Count,
    COALESCE(sp.Avg_Close_Price, 0) AS Avg_Close_Price,
    COALESCE(sn.Avg_News_Sentiment, 0) AS Avg_News_Sentiment,
    COALESCE(sn.Negative_Word_Mentions, 0) AS Negative_Word_Mentions
FROM Sector_Companies sc
LEFT JOIN Sector_Prices sp
    ON sp.Sector_ID = sc.Sector_ID
LEFT JOIN Sector_News sn
    ON sn.Sector_ID = sc.Sector_ID
ORDER BY COALESCE(sn.Negative_Word_Mentions, 0) DESC, COALESCE(sn.Total_News_Count, 0) DESC;

-- ----------------------------------------------------------------------------
-- STORED PROCEDURE
-- Amaç: Haberlerin Base_Sentiment_Score alanını toplu ya da tekil olarak yeniden
--       hesaplamak. Bulk yükleme sonrası veya manuel güncelleme sonrası kullanılabilir.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_recalculate_news_sentiment(IN p_news_id INT DEFAULT NULL)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE KAP_News kn
    SET Base_Sentiment_Score = COALESCE((
        SELECT ROUND(SUM(sd.Sentiment_Score * ns.Match_Count), 2)
        FROM News_Sentiments ns
        JOIN Sentiment_Dictionary sd
            ON sd.Word_ID = ns.Word_ID
        WHERE ns.News_ID = kn.News_ID
    ), 0)
    WHERE p_news_id IS NULL
       OR kn.News_ID = p_news_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- TRIGGER FUNCTION
-- Amaç: News_Sentiments tablosuna ekleme/güncelleme/silme olduğunda ilgili
--       KAP_News kaydının sentiment skorunu otomatik güncellemek.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_refresh_news_sentiment_score()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_news_id INT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_news_id := OLD.News_ID;
        UPDATE KAP_News kn
        SET Base_Sentiment_Score = COALESCE((
            SELECT ROUND(SUM(sd.Sentiment_Score * ns.Match_Count), 2)
            FROM News_Sentiments ns
            JOIN Sentiment_Dictionary sd
                ON sd.Word_ID = ns.Word_ID
            WHERE ns.News_ID = v_news_id
        ), 0)
        WHERE kn.News_ID = v_news_id;
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        UPDATE KAP_News kn
        SET Base_Sentiment_Score = COALESCE((
            SELECT ROUND(SUM(sd.Sentiment_Score * ns.Match_Count), 2)
            FROM News_Sentiments ns
            JOIN Sentiment_Dictionary sd
                ON sd.Word_ID = ns.Word_ID
            WHERE ns.News_ID = kn.News_ID
        ), 0)
        WHERE kn.News_ID IN (OLD.News_ID, NEW.News_ID);
        RETURN NEW;
    ELSE
        v_news_id := NEW.News_ID;
        UPDATE KAP_News kn
        SET Base_Sentiment_Score = COALESCE((
            SELECT ROUND(SUM(sd.Sentiment_Score * ns.Match_Count), 2)
            FROM News_Sentiments ns
            JOIN Sentiment_Dictionary sd
                ON sd.Word_ID = ns.Word_ID
            WHERE ns.News_ID = v_news_id
        ), 0)
        WHERE kn.News_ID = v_news_id;
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_news_sentiments_refresh_score ON News_Sentiments;
CREATE TRIGGER trg_news_sentiments_refresh_score
AFTER INSERT OR UPDATE OR DELETE ON News_Sentiments
FOR EACH ROW
EXECUTE FUNCTION fn_refresh_news_sentiment_score();

-- ----------------------------------------------------------------------------
-- ADVANCED QUERY 1
-- View üzerinden en güçlü pozitif algıya sahip fırsat hisseleri
-- ----------------------------------------------------------------------------
SELECT
    Company_Code,
    Company_Name,
    Price_Date,
    Close_Price,
    Volume,
    Total_News_Count,
    Total_Daily_Sentiment_Score
FROM Firsat_Hisseleri_View
ORDER BY Total_Daily_Sentiment_Score DESC, Price_Date DESC, Volume DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- ADVANCED QUERY 2
-- CTE + Window Function: SMA-50 ve haber duyarlılığını birlikte analiz et
-- ----------------------------------------------------------------------------
WITH Daily_Momentum AS (
    SELECT
        c.Company_ID,
        c.Company_Code,
        dp.Price_Date,
        dp.Close_Price,
        ROUND(
            AVG(dp.Close_Price) OVER (
                PARTITION BY c.Company_ID
                ORDER BY dp.Price_Date
                ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS SMA_50
    FROM Companies c
    JOIN Daily_Prices dp
        ON dp.Company_ID = c.Company_ID
),
Daily_Sentiment AS (
    SELECT
        kn.Company_ID,
        kn.News_Date::date AS Price_Date,
        ROUND(SUM(sd.Sentiment_Score * ns.Match_Count), 2) AS Day_Sentiment
    FROM KAP_News kn
    JOIN News_Sentiments ns
        ON ns.News_ID = kn.News_ID
    JOIN Sentiment_Dictionary sd
        ON sd.Word_ID = ns.Word_ID
    GROUP BY kn.Company_ID, kn.News_Date::date
)
SELECT
    dm.Company_Code,
    dm.Price_Date,
    dm.Close_Price,
    dm.SMA_50,
    COALESCE(ds.Day_Sentiment, 0) AS Day_Sentiment,
    CASE
        WHEN dm.Close_Price < dm.SMA_50 AND COALESCE(ds.Day_Sentiment, 0) > 0
            THEN 'GUCLU ALIM ADAYI'
        WHEN dm.Close_Price > dm.SMA_50 AND COALESCE(ds.Day_Sentiment, 0) < 0
            THEN 'TEMKİNLİ / RİSKLİ'
        ELSE 'NÖTR'
    END AS Technical_Signal
FROM Daily_Momentum dm
LEFT JOIN Daily_Sentiment ds
    ON ds.Company_ID = dm.Company_ID
   AND ds.Price_Date = dm.Price_Date
WHERE dm.Price_Date >= (
    SELECT MAX(Price_Date) - 30
    FROM Daily_Prices
)
ORDER BY dm.Company_Code, dm.Price_Date DESC;

-- ----------------------------------------------------------------------------
-- ADVANCED QUERY 3
-- Correlated subquery: Son kapanış fiyatı sektör ortalamasının üstünde olan
-- şirketleri ve son 15 gündeki haber yoğunluğunu göster.
-- ----------------------------------------------------------------------------
WITH Latest_Prices AS (
    SELECT
        dp.Company_ID,
        dp.Price_Date,
        dp.Close_Price,
        ROW_NUMBER() OVER (
            PARTITION BY dp.Company_ID
            ORDER BY dp.Price_Date DESC
        ) AS rn
    FROM Daily_Prices dp
)
SELECT
    c.Company_Code,
    c.Company_Name,
    s.Sector_Name,
    lp.Price_Date AS Latest_Price_Date,
    lp.Close_Price AS Latest_Close_Price,
    (
        SELECT ROUND(AVG(lp2.Close_Price), 2)
        FROM Latest_Prices lp2
        JOIN Companies c2
            ON c2.Company_ID = lp2.Company_ID
        WHERE lp2.rn = 1
          AND c2.Sector_ID = c.Sector_ID
    ) AS Sector_Avg_Close_Price,
    (
        SELECT COUNT(*)
        FROM KAP_News kn
        WHERE kn.Company_ID = c.Company_ID
          AND kn.News_Date::date >= lp.Price_Date - 15
    ) AS News_Count_Last_15_Days
FROM Latest_Prices lp
JOIN Companies c
    ON c.Company_ID = lp.Company_ID
JOIN Sectors s
    ON s.Sector_ID = c.Sector_ID
WHERE lp.rn = 1
  AND lp.Close_Price > (
        SELECT AVG(lp2.Close_Price)
        FROM Latest_Prices lp2
        JOIN Companies c2
            ON c2.Company_ID = lp2.Company_ID
        WHERE lp2.rn = 1
          AND c2.Sector_ID = c.Sector_ID
  )
ORDER BY (lp.Close_Price - (
    SELECT AVG(lp2.Close_Price)
    FROM Latest_Prices lp2
    JOIN Companies c2
        ON c2.Company_ID = lp2.Company_ID
    WHERE lp2.rn = 1
      AND c2.Sector_ID = c.Sector_ID
)) DESC,
lp.Close_Price DESC;


-- ----------------------------------------------------------------------------
-- VIEW TEST QUERY 1
-- En yüksek pozitif duyarlılığa sahip ilk 5 fırsat hissesi
-- ----------------------------------------------------------------------------
SELECT *
FROM Firsat_Hisseleri_View
ORDER BY Total_Daily_Sentiment_Score DESC
LIMIT 5;

-- ----------------------------------------------------------------------------
-- VIEW TEST QUERY 2
-- Negatif haber yoğunluğu en yüksek ilk 5 sektör
-- ----------------------------------------------------------------------------
SELECT *
FROM Sektor_Risk_Ozeti_View
ORDER BY Negative_Word_Mentions DESC
LIMIT 5;

-- ----------------------------------------------------------------------------
-- VIEW TEST QUERY 3
-- Son haber sayısı en yüksek 5 fırsat hissesi
-- ----------------------------------------------------------------------------
SELECT
    Company_Code,
    Company_Name,
    Total_News_Count
FROM Firsat_Hisseleri_View
ORDER BY Total_News_Count DESC
LIMIT 5;
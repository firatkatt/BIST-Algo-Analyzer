-- ============================================================================
-- BIST-Algo-Analyzer: Final Seed Data
-- PostgreSQL uyumlu örnek veri seti
-- Amaç: Final sorgularını, view'ları, procedure ve trigger'ı test etmek.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Referans tablolar
-- ----------------------------------------------------------------------------
INSERT INTO Sectors (Sector_ID, Sector_Name) VALUES
    (1, 'Bankacılık'),
    (2, 'Havacılık'),
    (3, 'Teknoloji'),
    (4, 'Otomotiv'),
    (5, 'Perakende'),
    (6, 'Sanayi'),
    (7, 'Enerji'),
    (8, 'Holding');

INSERT INTO Market_Indices (Index_ID, Index_Code, Index_Name) VALUES
    (1, 'BIST100', 'BIST 100'),
    (2, 'BIST30', 'BIST 30'),
    (3, 'BISTSINAI', 'BIST Sınai'),
    (4, 'BISTHOLDING', 'BIST Holding'),
    (5, 'BISTBANKA', 'BIST Banka');

INSERT INTO Companies (Company_ID, Company_Code, Company_Name, Sector_ID) VALUES
    (1, 'THYAO', 'Türk Hava Yolları A.O.', 2),
    (2, 'ASELS', 'Aselsan A.Ş.', 3),
    (3, 'AKBNK', 'Akbank T.A.Ş.', 1),
    (4, 'TOASO', 'Tofaş Türk Otomobil Fabrikası A.Ş.', 4),
    (5, 'BIMAS', 'BİM Birleşik Mağazalar A.Ş.', 5),
    (6, 'SISE', 'Türkiye Şişe ve Cam Fabrikaları A.Ş.', 6),
    (7, 'ENJSA', 'Enerjisa Enerji A.Ş.', 7),
    (8, 'SAHOL', 'Hacı Ömer Sabancı Holding A.Ş.', 8),
    (9, 'TUPRS', 'Tüpraş Türkiye Petrol Rafinerileri A.Ş.', 7),
    (10, 'KCHOL', 'Koç Holding A.Ş.', 8);

INSERT INTO Company_Indices (Company_ID, Index_ID) VALUES
    (1, 1), (1, 2),
    (2, 1), (2, 2), (2, 3),
    (3, 1), (3, 2), (3, 5),
    (4, 1), (4, 2), (4, 3),
    (5, 1), (5, 2),
    (6, 1), (6, 2), (6, 3),
    (7, 1), (7, 4),
    (8, 1), (8, 2), (8, 4),
    (9, 1), (9, 2), (9, 3),
    (10, 1), (10, 2), (10, 4);

INSERT INTO Sentiment_Dictionary (Word_ID, Word, Sentiment_Score) VALUES
    (1, 'büyüme', 1.00),
    (2, 'temettü', 1.00),
    (3, 'kâr', 1.00),
    (4, 'artış', 0.50),
    (5, 'yatırım', 1.00),
    (6, 'rekor', 1.50),
    (7, 'düşüş', -1.00),
    (8, 'zarar', -1.00),
    (9, 'ceza', -1.00),
    (10, 'dava', -1.50),
    (11, 'küçülme', -1.00),
    (12, 'istifa', -0.50);

-- ----------------------------------------------------------------------------
-- Günlük fiyatlar
-- ----------------------------------------------------------------------------
WITH trading_days AS (
    SELECT
        d::date AS price_date,
        ROW_NUMBER() OVER (ORDER BY d) - 1 AS day_index
    FROM generate_series(DATE '2025-08-01', DATE '2025-11-28', INTERVAL '1 day') AS d
    WHERE EXTRACT(ISODOW FROM d) < 6
)
INSERT INTO Daily_Prices (
    Company_ID,
    Price_Date,
    Open_Price,
    High_Price,
    Low_Price,
    Close_Price,
    Volume
)
SELECT
    c.Company_ID,
    td.price_date,
    ROUND((40 + c.Company_ID * 8 + td.day_index * 0.22 + ((td.day_index % 8) - 4) * 0.35)::numeric, 2) AS Open_Price,
    ROUND((40 + c.Company_ID * 8 + td.day_index * 0.22 + ((td.day_index % 8) - 4) * 0.35 + 1.75)::numeric, 2) AS High_Price,
    ROUND((40 + c.Company_ID * 8 + td.day_index * 0.22 + ((td.day_index % 8) - 4) * 0.35 - 1.85)::numeric, 2) AS Low_Price,
    ROUND((
        40 + c.Company_ID * 8 + td.day_index * 0.22 + ((td.day_index % 8) - 4) * 0.35 +
        CASE
            WHEN td.day_index % 7 = 0 THEN -1.25
            WHEN td.day_index % 5 = 0 THEN 1.65
            ELSE 0.45
        END
    )::numeric, 2) AS Close_Price,
    850000 + c.Company_ID * 60000 + td.day_index * 11000 AS Volume
FROM Companies c
CROSS JOIN trading_days td;

-- ----------------------------------------------------------------------------
-- KAP haberleri
-- ----------------------------------------------------------------------------
WITH news_seed (
    News_ID,
    Company_Code,
    News_Date,
    News_Content,
    News_URL,
    Base_Sentiment_Score
) AS (
    VALUES
        (1, 'THYAO', TIMESTAMP '2025-10-07 09:15:00',
            'Filo büyüme planı, yatırım programı ve temettü beklentisi açıklandı.',
            'https://kap.org.tr/tr/Bildirim/1000001', 3.00),
        (2, 'THYAO', TIMESTAMP '2025-10-14 11:20:00',
            'Dava süreci, ceza riski ve zarar etkisi gündemde.',
            'https://kap.org.tr/tr/Bildirim/1000002', -3.50),
        (3, 'ASELS', TIMESTAMP '2025-10-09 10:05:00',
            'Rekor sipariş, yatırım paketi ve büyüme beklentisi açıklandı.',
            'https://kap.org.tr/tr/Bildirim/1000003', 3.50),
        (4, 'ASELS', TIMESTAMP '2025-10-17 14:00:00',
            'İstifa sonrası küçülme ve zarar baskısı görüldü.',
            'https://kap.org.tr/tr/Bildirim/1000004', -2.50),
        (5, 'AKBNK', TIMESTAMP '2025-10-10 09:40:00',
            'Kâr artışı ve temettü dağıtımı açıklandı.',
            'https://kap.org.tr/tr/Bildirim/1000005', 2.50),
        (6, 'AKBNK', TIMESTAMP '2025-10-20 13:30:00',
            'Düşüş baskısı, zarar görünümü ve ceza gündemi izleniyor.',
            'https://kap.org.tr/tr/Bildirim/1000006', -3.00),
        (7, 'TOASO', TIMESTAMP '2025-10-11 09:10:00',
            'Yatırım planı, büyüme hedefi ve rekor üretim açıklandı.',
            'https://kap.org.tr/tr/Bildirim/1000007', 3.50),
        (8, 'TOASO', TIMESTAMP '2025-10-23 15:05:00',
            'Küçülme planı, zarar baskısı ve dava riski değerlendiriliyor.',
            'https://kap.org.tr/tr/Bildirim/1000008', -3.50),
        (9, 'BIMAS', TIMESTAMP '2025-10-15 08:55:00',
            'Kâr artışı, temettü politikası ve yatırımcı güveni desteklendi.',
            'https://kap.org.tr/tr/Bildirim/1000009', 2.50),
        (10, 'SISE', TIMESTAMP '2025-10-21 11:45:00',
            'Ceza kararı sonrası zarar ve düşüş baskısı arttı.',
            'https://kap.org.tr/tr/Bildirim/1000010', -3.00),
        (11, 'TUPRS', TIMESTAMP '2025-10-24 10:25:00',
            'Yatırım planı, rekor kapasite ve büyüme beklentisi açıklandı.',
            'https://kap.org.tr/tr/Bildirim/1000011', 3.50),
        (12, 'SAHOL', TIMESTAMP '2025-10-28 12:10:00',
            'Artış eğilimi, kâr hedefi ve temettü politikası öne çıktı.',
            'https://kap.org.tr/tr/Bildirim/1000012', 2.50)
)
INSERT INTO KAP_News (
    News_ID,
    Company_ID,
    News_Date,
    News_Content,
    News_URL,
    Base_Sentiment_Score
)
SELECT
    n.News_ID,
    c.Company_ID,
    n.News_Date,
    n.News_Content,
    n.News_URL,
    n.Base_Sentiment_Score
FROM news_seed n
JOIN Companies c
    ON c.Company_Code = n.Company_Code;

-- ----------------------------------------------------------------------------
-- Haber-kelime eşleştirmeleri
-- ----------------------------------------------------------------------------
INSERT INTO News_Sentiments (News_ID, Word_ID, Match_Count) VALUES
    (1, 1, 1), (1, 5, 1), (1, 2, 1),
    (2, 10, 1), (2, 9, 1), (2, 8, 1),
    (3, 6, 1), (3, 5, 1), (3, 1, 1),
    (4, 12, 1), (4, 11, 1), (4, 8, 1),
    (5, 3, 1), (5, 4, 1), (5, 2, 1),
    (6, 7, 1), (6, 8, 1), (6, 9, 1),
    (7, 5, 1), (7, 1, 1), (7, 6, 1),
    (8, 11, 1), (8, 8, 1), (8, 10, 1),
    (9, 3, 1), (9, 4, 1), (9, 2, 1),
    (10, 9, 1), (10, 8, 1), (10, 7, 1),
    (11, 5, 1), (11, 6, 1), (11, 1, 1),
    (12, 4, 1), (12, 3, 1), (12, 2, 1);

-- ----------------------------------------------------------------------------
-- Sequence hizalama
-- ----------------------------------------------------------------------------
SELECT setval(pg_get_serial_sequence('sectors', 'sector_id'), (SELECT MAX(Sector_ID) FROM Sectors));
SELECT setval(pg_get_serial_sequence('market_indices', 'index_id'), (SELECT MAX(Index_ID) FROM Market_Indices));
SELECT setval(pg_get_serial_sequence('companies', 'company_id'), (SELECT MAX(Company_ID) FROM Companies));
SELECT setval(pg_get_serial_sequence('daily_prices', 'price_id'), (SELECT MAX(Price_ID) FROM Daily_Prices));
SELECT setval(pg_get_serial_sequence('kap_news', 'news_id'), (SELECT MAX(News_ID) FROM KAP_News));
SELECT setval(pg_get_serial_sequence('sentiment_dictionary', 'word_id'), (SELECT MAX(Word_ID) FROM Sentiment_Dictionary));

COMMIT;

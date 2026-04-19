-- ============================================================================
-- BIST-Algo-Analyzer: Database Schema
-- Amac: KAP haberleri ile borsa fiyat hareketleri arasındaki ilişkinin analizi
-- Tablo Sayısı: 8 (Normalizasyon kurallarına uygun, M:N ilişkiler içerir)
-- ============================================================================

-- 1. Sektörler Tablosu
CREATE TABLE Sectors (
    Sector_ID SERIAL PRIMARY KEY,
    Sector_Name VARCHAR(100) NOT NULL UNIQUE
);

-- 2. Şirketler Tablosu
CREATE TABLE Companies (
    Company_ID SERIAL PRIMARY KEY,
    Company_Code VARCHAR(10) NOT NULL UNIQUE, -- Örn: THYAO, ASELS
    Company_Name VARCHAR(255),
    Sector_ID INT,
    FOREIGN KEY (Sector_ID) REFERENCES Sectors(Sector_ID) ON DELETE SET NULL
);

-- 3. Piyasa Endeksleri Tablosu (BIST30, BIST100 vb.)
CREATE TABLE Market_Indices (
    Index_ID SERIAL PRIMARY KEY,
    Index_Code VARCHAR(20) NOT NULL UNIQUE,
    Index_Name VARCHAR(100) NOT NULL
);

-- 4. Şirket - Endeks Bağlantı Tablosu (Many-to-Many ilişkisi)
-- Bir şirket birden fazla endekste olabilir. 
CREATE TABLE Company_Indices (
    Company_ID INT,
    Index_ID INT,
    PRIMARY KEY (Company_ID, Index_ID),
    FOREIGN KEY (Company_ID) REFERENCES Companies(Company_ID) ON DELETE CASCADE,
    FOREIGN KEY (Index_ID) REFERENCES Market_Indices(Index_ID) ON DELETE CASCADE
);

-- 5. Günlük Fiyatlar Tablosu
CREATE TABLE Daily_Prices (
    Price_ID SERIAL PRIMARY KEY,
    Company_ID INT NOT NULL,
    Price_Date DATE NOT NULL,
    Open_Price DECIMAL(10, 2) NOT NULL,
    High_Price DECIMAL(10, 2) NOT NULL,
    Low_Price DECIMAL(10, 2) NOT NULL,
    Close_Price DECIMAL(10, 2) NOT NULL,
    Volume BIGINT,
    FOREIGN KEY (Company_ID) REFERENCES Companies(Company_ID) ON DELETE CASCADE,
    UNIQUE (Company_ID, Price_Date) -- Bir şirketin bir günde tek kapanışı olur
);

-- 6. KAP Haberleri Tablosu
CREATE TABLE KAP_News (
    News_ID SERIAL PRIMARY KEY,
    Company_ID INT NOT NULL,
    News_Date TIMESTAMP NOT NULL,
    News_Content TEXT NOT NULL,
    News_URL TEXT,
    Base_Sentiment_Score DECIMAL(5, 2) DEFAULT 0, -- Başlangıç skor (0 = Nötr)
    FOREIGN KEY (Company_ID) REFERENCES Companies(Company_ID) ON DELETE CASCADE
);

-- 7. Duygu Analizi Kelime Sözlüğü
CREATE TABLE Sentiment_Dictionary (
    Word_ID SERIAL PRIMARY KEY,
    Word VARCHAR(50) NOT NULL UNIQUE, -- Örn: 'Büyüme', 'Zarar', 'Temettü'
    Sentiment_Score DECIMAL(5, 2) NOT NULL -- Örn: Büyüme (+1), Zarar (-1)
);

-- 8. Haber Detay / Kelime Eşleştirme Tablosu (Many-to-Many ilişkisi)
-- Bir haberin içinde veri sözlüğünden hangi kelimeler geçti?
CREATE TABLE News_Sentiments (
    News_ID INT,
    Word_ID INT,
    Match_Count INT DEFAULT 1, -- Eğer kelime metinde birden fazla geçiyorsa ağırlığı artabilir
    PRIMARY KEY (News_ID, Word_ID),
    FOREIGN KEY (News_ID) REFERENCES KAP_News(News_ID) ON DELETE CASCADE,
    FOREIGN KEY (Word_ID) REFERENCES Sentiment_Dictionary(Word_ID) ON DELETE CASCADE
);

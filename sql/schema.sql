-- ============================================================================
-- BIST-Algo-Analyzer: Final Database Schema
-- PostgreSQL uyumlu, normalize edilmiş çekirdek tablo yapısı
-- Not: Base_Sentiment_Score alanı, trigger/procedure ile senkronlanan
--      analitik cache alanı olarak tutulur.
-- ============================================================================

DROP TABLE IF EXISTS News_Sentiments CASCADE;
DROP TABLE IF EXISTS KAP_News CASCADE;
DROP TABLE IF EXISTS Daily_Prices CASCADE;
DROP TABLE IF EXISTS Company_Indices CASCADE;
DROP TABLE IF EXISTS Market_Indices CASCADE;
DROP TABLE IF EXISTS Companies CASCADE;
DROP TABLE IF EXISTS Sectors CASCADE;
DROP TABLE IF EXISTS Sentiment_Dictionary CASCADE;

-- 1. Sektörler
CREATE TABLE Sectors (
    Sector_ID SERIAL PRIMARY KEY,
    Sector_Name VARCHAR(100) NOT NULL UNIQUE
);

-- 2. Şirketler
CREATE TABLE Companies (
    Company_ID SERIAL PRIMARY KEY,
    Company_Code VARCHAR(10) NOT NULL UNIQUE,
    Company_Name VARCHAR(255) NOT NULL,
    Sector_ID INT NOT NULL,
    CONSTRAINT fk_companies_sector
        FOREIGN KEY (Sector_ID)
        REFERENCES Sectors (Sector_ID)
        ON DELETE RESTRICT
);

-- 3. Piyasa endeksleri
CREATE TABLE Market_Indices (
    Index_ID SERIAL PRIMARY KEY,
    Index_Code VARCHAR(20) NOT NULL UNIQUE,
    Index_Name VARCHAR(100) NOT NULL
);

-- 4. Şirket-Endeks ilişkisi
CREATE TABLE Company_Indices (
    Company_ID INT NOT NULL,
    Index_ID INT NOT NULL,
    PRIMARY KEY (Company_ID, Index_ID),
    CONSTRAINT fk_company_indices_company
        FOREIGN KEY (Company_ID)
        REFERENCES Companies (Company_ID)
        ON DELETE CASCADE,
    CONSTRAINT fk_company_indices_index
        FOREIGN KEY (Index_ID)
        REFERENCES Market_Indices (Index_ID)
        ON DELETE CASCADE
);

-- 5. Günlük fiyatlar
CREATE TABLE Daily_Prices (
    Price_ID SERIAL PRIMARY KEY,
    Company_ID INT NOT NULL,
    Price_Date DATE NOT NULL,
    Open_Price DECIMAL(10, 2) NOT NULL CHECK (Open_Price >= 0),
    High_Price DECIMAL(10, 2) NOT NULL CHECK (High_Price >= 0),
    Low_Price DECIMAL(10, 2) NOT NULL CHECK (Low_Price >= 0),
    Close_Price DECIMAL(10, 2) NOT NULL CHECK (Close_Price >= 0),
    Volume BIGINT NOT NULL DEFAULT 0 CHECK (Volume >= 0),
    CONSTRAINT fk_daily_prices_company
        FOREIGN KEY (Company_ID)
        REFERENCES Companies (Company_ID)
        ON DELETE CASCADE,
    CONSTRAINT uq_daily_prices_company_date UNIQUE (Company_ID, Price_Date),
    CONSTRAINT ck_daily_prices_price_order CHECK (
        High_Price >= GREATEST(Open_Price, Close_Price)
        AND Low_Price <= LEAST(Open_Price, Close_Price)
        AND High_Price >= Low_Price
    )
);

-- 6. KAP haberleri
CREATE TABLE KAP_News (
    News_ID SERIAL PRIMARY KEY,
    Company_ID INT NOT NULL,
    News_Date TIMESTAMP NOT NULL,
    News_Content TEXT NOT NULL,
    News_URL TEXT NOT NULL,
    Base_Sentiment_Score DECIMAL(5, 2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_kap_news_company
        FOREIGN KEY (Company_ID)
        REFERENCES Companies (Company_ID)
        ON DELETE CASCADE,
    CONSTRAINT uq_kap_news_url UNIQUE (News_URL)
);

-- 7. Duygu sözlüğü
CREATE TABLE Sentiment_Dictionary (
    Word_ID SERIAL PRIMARY KEY,
    Word VARCHAR(50) NOT NULL UNIQUE,
    Sentiment_Score DECIMAL(5, 2) NOT NULL,
    CONSTRAINT ck_sentiment_dictionary_score CHECK (Sentiment_Score BETWEEN -5 AND 5)
);

-- 8. Haber-kelime eşleştirme
CREATE TABLE News_Sentiments (
    News_ID INT NOT NULL,
    Word_ID INT NOT NULL,
    Match_Count INT NOT NULL DEFAULT 1 CHECK (Match_Count > 0),
    PRIMARY KEY (News_ID, Word_ID),
    CONSTRAINT fk_news_sentiments_news
        FOREIGN KEY (News_ID)
        REFERENCES KAP_News (News_ID)
        ON DELETE CASCADE,
    CONSTRAINT fk_news_sentiments_word
        FOREIGN KEY (Word_ID)
        REFERENCES Sentiment_Dictionary (Word_ID)
        ON DELETE CASCADE
);

-- Performans indeksleri
CREATE INDEX idx_companies_sector_id
    ON Companies (Sector_ID);

CREATE INDEX idx_company_indices_index_company
    ON Company_Indices (Index_ID, Company_ID);

CREATE INDEX idx_daily_prices_company_date
    ON Daily_Prices (Company_ID, Price_Date DESC);

CREATE INDEX idx_daily_prices_date
    ON Daily_Prices (Price_Date DESC);

CREATE INDEX idx_kap_news_company_date
    ON KAP_News (Company_ID, News_Date DESC);

CREATE INDEX idx_kap_news_news_day
    ON KAP_News ((News_Date::date));

CREATE INDEX idx_news_sentiments_word_id
    ON News_Sentiments (Word_ID);


# Milestone: Project Proposal & Justification
*Project Title:* BIST-Algo-Analyzer: Borsa Istanbul Data and News Analysis System

---

## 1. Problem Statement

One of the biggest challenges individual investors face in financial markets is that market data (numerical data) and market news (textual and sentiment data) are scattered across fragmented platforms. Today, when an investor wants to assess the current status of a stock, they must check the stock’s OHLCV (Open, High, Low, Close, Volume) data on one app (such as TradingView or a brokerage app) and track the latest news about that company on another app (such as KAP or Bloomberg HT). 

This situation disrupts the analytical decision-making process and creates information asymmetry, leading investors to make incorrect or delayed emotional decisions.
*The core solution of this project:* Thanks to this relational database project we will develop, investors will be able to view the latest news about the stocks they own or track through a single system. At the same time, they will also be able to analyze OHLCV-style pricing data—simple yet critically important for technical analysis—all in one place. When they log into the system for a specific stock, they will see both the company’s financial volume and moving averages, as well as sentiment analyses of the latest KAP disclosures. This infrastructure will significantly simplify investors’ lives, keep data tracking up-to-date on a single screen, and enable them to make rapid financial decisions through an algorithmic system.

---

## 2. Justification (Why It Matters)

The significance of the project we have developed lies in its ability to organically integrate quantitative stock market data with qualitative news sentiment scores within a database-centric architecture. Thanks to our expanded dataset based on the BIST 100 index, we will be able to generate clear SQL queries in seconds to answer complex, multi-parameter questions such as: “How does a positive KAP news item translate into a percentage change in trading volume for a stock the following day?” or “Which sectors exhibit a more fragile OHLCV chart in response to negative news (such as lawsuits, losses, or fines)?” we will be able to generate clear answers to such multi-parameter, complex questions within seconds using precise SQL queries.

Additionally, rather than limiting the project to just 3–5 stocks, we expanded our scope to include *all (approximately 100) companies within the BIST100 index*. For each of these companies, we have 1 year of historical price data (250 days) and carefully processed KAP news. This “Big Data” approach offers a scale befitting the academic rigor of a database design course, justifying the transformation of this application from a simple storage tool into a professional “Financial Decision Support System.”

---

## 3. Schema Design (ERD & Table Descriptions)

Our project consists of a total of 8 tables designed in accordance with full normalization rules (1NF, 2NF, 3NF). The architecture successfully addresses One-to-Many (1:N) and Many-to-Many (M:N) relationships. Below is the Entity-Relationship Diagram (ERD) of our database architecture and detailed lists of table functions:

mermaid
erDiagram
    Sectors ||--o{ Companies : "contains"
    Companies ||--o{ Company_Indices : "included_in"
    Market_Indices ||--o{ Company_Indices : "has"
    Companies ||--o{ Daily_Prices : "has_prices"
    Companies ||--o{ KAP_News : "publishes"
    KAP_News ||--o{ News_Sentiments : "contains"
    Sentiment_Dictionary ||--o{ News_Sentiments : "is_found_in"

    Sectors {
        int Sector_ID PK
        varchar Sector_Name
    }
    Companies {
        int Company_ID PK
        varchar Company_Code
        varchar Company_Name
        int Sector_ID FK
    }
    Market_Indices {
        int Index_ID PK
        varchar Index_Code
        varchar Index_Name
    }
    Company_Indices {
        int Company_ID PK,FK
        int Index_ID PK,FK
    }
    Daily_Prices {
        int Price_ID PK
        int Company_ID FK
        date Price_Date
        decimal Open_Price
        decimal High_Price
        decimal Low_Price
        decimal Close_Price
        bigint Volume
    }
    KAP_News {
        int News_ID PK
        int Company_ID FK
        timestamp News_Date
        text News_Content
        text News_URL
        decimal Base_Sentiment_Score
    }
    Sentiment_Dictionary {
        int Word_ID PK
        varchar Word
        decimal Sentiment_Score
    }
    News_Sentiments {
        int News_ID PK,FK
        int Word_ID PK,FK
        int Match_Count
    }


### Table Descriptions
1. *Sectors:* This is the primary reference table containing the business sectors of BIST companies (IT, Banking, Manufacturing, etc.) (linked to the *Companies* table via a 1:N relationship).
2. *Companies:* The main backbone table containing the codes (e.g., THYAO, ASELS) and basic company information for the BIST100 companies under review.
3. *Market_Indices & Company_Indices:* A system linking market indices (e.g., BIST30, BIST100, BIST_TEMETTU) with companies. Since a company can be listed in multiple indices, the relationship is managed via a *Many-to-Many* junction table (Company_Indices).
4. *Daily_Prices:* This is where OHLCV data (Opening, Closing, Volume, etc.)—which is vital for investors—is stored. It maintains detailed records of all trading days over a one-year period. It is a large table containing approximately 25,000 rows.
5. *KAP_News:* This is a news notification table that has moved away from the traditional simple title format (Title) and stores content in full format (as News_Content, a TEXT data type with no size limit). It stores official news data specific to the relevant company.
6. *Sentiment_Dictionary:* A financial word/score dictionary serving as the foundation for NLP analysis (e.g., “Decline” -> -1.0, “Dividend” -> +1.5).
7. *News_Sentiments:* Our critical M:N junction table that enables news-word matching. By counting how many times each sentiment appears in a news item (Match_Count), it provides a flexible SQL infrastructure for algorithmic scoring.

---

## 4. Proposed SQL Features

During the final project implementation phase at the end of the term, we actively used—or will use—the following advanced SQL features to read data from the system and receive a perfect score evaluation under Category 3:

- *JOINs (INNER, LEFT):* These will be extensively used to seamlessly link Price (Daily_Prices), Company (Companies), and News (KAP_News) data via Foreign Keys.
- *Aggregations (GROUP BY, SUM, AVG, COUNT):* These will be fundamental when calculating the total daily news sentiment score or the average 10-day volume (Volume) of a stock.
- *Views:* These will be used to store queries containing complex 5-6 JOIN operations and calculations in the database as objects. The “Opportunity Stocks” view we will develop will provide convenience for the application layer.
- *Window Functions (OVER, PARTITION BY):* This is the most advanced technique in this project. It will be used to process each company’s data separately (PARTITION BY Company_ID) to compare a stock’s current price with its sector average or to calculate the 50-Day Simple Moving Average (SMA-50).
- *CTEs (Common Table Expressions - WITH):* Instead of writing long, nested subqueries, CTEs will be used in a structured block to enhance the readability of our code with a clean architectural design.

---

## 5. Sample Queries (Advanced Sample Queries)

Three of the sample queries we wrote—which serve as proof that the data integrity implemented in the project translates into mathematical analyses—are listed below.

### Query 1: Analytical Opportunity Stocks View (Views & Aggregation)
This query combines the company’s daily closing price from the OHLCV feed with the total sentiment score calculated from the news supporting that day, creating an extremely useful report table ready for analysis:

sql
CREATE OR REPLACE VIEW Firsat_Hisseleri_View AS
SELECT 
    c.Company_Code, 
    c.Company_Name,
    dp.Price_Date,
    dp.Close_Price,
    dp.Volume,
    SUM(sd.Sentiment_Score * ns.Match_Count) AS Total_Daily_Sentiment_Score,
    COUNT(DISTINCT kn.News_ID) AS Total_News_Count
FROM Companies c
JOIN Daily_Prices dp ON c.Company_ID = dp.Company_ID
JOIN KAP_News kn ON c.Company_ID = kn.Company_ID AND dp.Price_Date = DATE(kn.News_Date)
JOIN News_Sentiments ns ON kn.News_ID = ns.News_ID
JOIN Sentiment_Dictionary sd ON ns.Word_ID = sd.Word_ID
GROUP BY c.Company_Code, c.Company_Name, dp.Price_Date, dp.Close_Price, dp.Volume
HAVING SUM(sd.Sentiment_Score * ns.Match_Count) > 0 -- Temelde olumlu bir algı yaratılmış günleri filtrele
ORDER BY dp.Price_Date DESC, Total_Daily_Sentiment_Score DESC;


### Query 2: Simple Moving Average (SMA-50) Comparison (Window Functions)
The Moving Average calculation, the most commonly used methodology in traditional investment tools. It generates buy/sell/hold signals based on the current price relative to the weighted average of the stock price over the last “50” trading days (ROWS BETWEEN 50 PRECEDING):

sql
WITH Moving_Averages_CTE AS (
    SELECT 
        c.Company_Code,
        dp.Price_Date,
        dp.Close_Price,
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
    CASE 
        WHEN Close_Price < SMA_50 THEN 'POTANSİYEL UCUZLUK - ALIM DÜŞÜNÜLEBİLİR'
        ELSE 'NORMAL / AŞIRI ALIM BÖLGESİ ETKİSİ'
    END AS Technical_Signal
FROM Moving_Averages_CTE
ORDER BY Company_Code, Price_Date DESC;


### Query 3: Sector-Specific Disruptive Impact Analysis (GROUP BY and Negative Scoring)
This query comes into play when investors want to identify negative news (such as lawsuits, fines, or downsizing) related to the sectors in which their stocks or stock portfolios are held. This allows them to list sectors that are suffering overall, rather than focusing solely on specific companies:

sql
SELECT 
    s.Sector_Name,
    COUNT(kn.News_ID) AS Total_Negative_News,
    SUM(sd.Sentiment_Score * ns.Match_Count) AS Absolute_Pessimism_Score
FROM Sectors s
JOIN Companies c ON s.Sector_ID = c.Sector_ID
JOIN KAP_News kn ON c.Company_ID = kn.Company_ID
JOIN News_Sentiments ns ON kn.News_ID = ns.News_ID
JOIN Sentiment_Dictionary sd ON ns.Word_ID = sd.Word_ID
WHERE sd.Sentiment_Score < 0 -- Negatif kelime filtresi
GROUP BY s.Sector_Name
ORDER BY Total_Negative_News DESC;

import yfinance as yf
import pandas as pd
import random
from datetime import datetime, timedelta
import os

# Ayarlar
BIST100_TICKERS = [
    "AEFES", "AGHOL", "AHGAZ", "AKBNK", "AKCNS", "AKFGY", "AKSA", "AKSEN", "ALARK", "ALBRK", 
    "ALFAS", "ARCLK", "ASELS", "ASTOR", "AYDEM", "BIMAS", "BRSAN", "BRYAT", "BUCIM", "CANTE", 
    "CCOLA", "CEMTS", "CIMSA", "CWENE", "DOAS", "DOHOL", "ECILC", "ECZYT", "EGEEN", "EKGYO", 
    "ENJSA", "ENKAI", "EREGL", "EUREN", "EUPWR", "FROTO", "GARAN", "GENIL", "GESAN", "GLYHO", 
    "GUBRF", "GWIND", "HALKB", "HEKTS", "IPEKE", "ISCTR", "ISDMR", "ISFIN", "ISGYO", "ISMEN", 
    "IZENR", "KCAER", "KCHOL", "KLSER", "KMPUR", "KONTR", "KONYA", "KORDS", "KOZAA", "KOZAL", 
    "KRDMD", "MAVI", "MGROS", "MIATK", "ODAS", "OTKAR", "OYAKC", "PENTA", "PETKM", "PGSUS", 
    "PSGYO", "QUAGR", "SAHOL", "SASA", "SISE", "SMRTG", "SNGYO", "SOKM", "TAVHL", 
    "TCELL", "THYAO", "TKFEN", "TOASO", "TSKB", "TTKOM", "TTRAK", "TUKAS", "TUPRS", "ULKER", 
    "VAKBN", "VESBE", "VESTL", "YEOTK", "YKBNK", "YYLGD", "ZOREN"
]

COMPANIES = {ticker: idx for idx, ticker in enumerate(BIST100_TICKERS, 1)}

SENTIMENT_DICT = {
    "büyüme": 1.0,
    "temettü": 1.0,
    "kâr": 1.0,
    "artış": 0.5,
    "yatırım": 1.0,
    "rekor": 1.5,
    "düşüş": -1.0,
    "zarar": -1.0,
    "ceza": -1.0,
    "dava": -1.5,
    "küçülme": -1.0,
    "istifa": -0.5
}

# Verilerin kaydedileceği klasör
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
os.makedirs(DATA_DIR, exist_ok=True)

def fetch_prices():
    """yfinance kullanarak gerçek borsa verilerini çeker."""
    print("1. Borsa fiyatları yfinance üzerinden çekiliyor (Son 1 yıl)...")
    price_records = []
    price_id = 1
    
    # Tüm şirketlerin listesi (BIST hisseleri için sonuna .IS eklenir)
    for ticker, comp_id in COMPANIES.items():
        print(f"[{ticker}] Veri indiriliyor...")
        try:
            stock = yf.Ticker(f"{ticker}.IS")
            # Son 1 yıllık veri
            hist = stock.history(period="1y")
            
            for index, row in hist.iterrows():
                # NaN veya eksik verileri atla
                if pd.isna(row['Close']):
                    continue
                    
                price_records.append({
                    "Price_ID": price_id,
                    "Company_ID": comp_id,
                    "Price_Date": index.strftime('%Y-%m-%d'),
                    "Open_Price": round(row['Open'], 2),
                    "High_Price": round(row['High'], 2),
                    "Low_Price": round(row['Low'], 2),
                    "Close_Price": round(row['Close'], 2),
                    "Volume": int(row['Volume'])
                })
                price_id += 1
        except Exception as e:
            print(f"Hata! {ticker} fiyatı çekilemedi: {e}")

    df_prices = pd.DataFrame(price_records)
    if df_prices.empty:
        print("HATA: Yahoo Finance (yfinance) verileri çekilemedi! (API Rate Limit / Config değişimi)")
        print("-> Akademik proje testi kesintiye uğramasın diye gerçeğe yakın sentetik (mock) fiyat verileri oluşturuluyor...")
        for comp_code, comp_id in COMPANIES.items():
            base_price = random.uniform(20.0, 300.0)
            for i in range(250): # Son 1 yıl (yaklaşık 250 işlem günü)
                date_str = (datetime.now() - timedelta(days=250-i)).strftime('%Y-%m-%d')
                open_p = base_price * random.uniform(0.98, 1.02)
                close_p = open_p * random.uniform(0.95, 1.05)
                high_p = max(open_p, close_p) * random.uniform(1.0, 1.02)
                low_p = min(open_p, close_p) * random.uniform(0.98, 1.0)
                price_records.append({
                    "Price_ID": price_id,
                    "Company_ID": comp_id,
                    "Price_Date": date_str,
                    "Open_Price": round(open_p, 2),
                    "High_Price": round(high_p, 2),
                    "Low_Price": round(low_p, 2),
                    "Close_Price": round(close_p, 2),
                    "Volume": random.randint(100000, 5000000)
                })
                price_id += 1
                base_price = close_p
        df_prices = pd.DataFrame(price_records)

    output_path = os.path.join(DATA_DIR, 'Daily_Prices.csv')
    df_prices.to_csv(output_path, index=False)
    print(f"-> {output_path} başarıyla oluşturuldu! ({len(price_records)} satır)")
    
    # Fiyat tarihlerini döndür ki haberleri bu tarihlere göre senkronlayalım
    return df_prices['Price_Date'].unique().tolist()

def generate_mock_news(valid_dates):
    """Zorlu scraping operasyonları (Captcha vb.) yerine akademik projeye uygun 
       algoritmik bir KAP/Bloomberg haber üreteci."""
    print("2. Şirket haber metinleri ve duygu skorları oluşturuluyor...")
    
    news_records = []
    news_sentiments_records = []
    news_id = 1
    
    sentiment_items = list(SENTIMENT_DICT.items())
    
    # Haber kelimeleri için veritabanı dict listesi
    dict_records = []
    word_to_id = {}
    for w_id, (word, score) in enumerate(sentiment_items, 1):
        dict_records.append({"Word_ID": w_id, "Word": word, "Sentiment_Score": score})
        word_to_id[word] = w_id
        
    df_dict = pd.DataFrame(dict_records)
    df_dict.to_csv(os.path.join(DATA_DIR, 'Sentiment_Dictionary.csv'), index=False)
    
    for comp_code, comp_id in COMPANIES.items():
        # Kullanıcının özel isteği: Her hisseden tam olarak 5 haber olsun
        num_news = 5
        
        for _ in range(num_news):
            # Haber tarihini gerçek borsa günlerinden seç
            n_date = random.choice(valid_dates)
            
            # Rastgele 1 veya 2 pozitif/negatif kelime seç
            selected_words = random.sample([k for k, v in sentiment_items], random.randint(1, 2))
            
            # Sentiment skoru hesaplama (İstenen basit skorlama algoritması)
            total_sentiment = 0
            for word in selected_words:
                total_sentiment += SENTIMENT_DICT[word]
            
            # Haber içeriği şablonları (uzun metinler)
            contents = [
                f"Kamuoyunun dikkatine; {comp_code} A.Ş. yönetim kurulu bu sabah yapılan olağanüstü toplantıda şirketin geleceğini ilgilendiren önemli kararlar aldı. Özellikle son çeyrekte gözlemlenen piyasa etkileri neticesinde ortaya çıkan {selected_words[0]} beklentileri yatırımcılarla şeffaf bir şekilde paylaşıldı. Piyasadaki dalgalanmalara karşı stratejik hamleler yapılmaya devam edilecektir.",
                f"Piyasalarda dikkat çeken gelişmeler yaşanıyor. Türkiye'nin önde gelen kurumlarından {comp_code}, üçüncü çeyrek bilançosundaki analizlerini yatırımcı ilişkileri sayfasında yayınladı. Kurum raporlarına göre {selected_words[0]} emarelerinin ortaya çıkması, yatırımcı güvenini doğrudan etkileyen bir faktör olarak görülüyor. Uzmanlar sektördeki gelişmeleri yakından takip ediyor.",
                f"Geçtiğimiz günlerde uluslararası derecelendirme kuruluşlarının yayımladığı analiz raporunda {comp_code} hakkında dikkat çekici detaylar yer aldı. Kurum analistleri önümüzdeki dönemde olası bir {selected_words[0]} etkisi için önceden hazırlıklı olunması gerektiğini vurguladı. Bu açıklamanın ardından hisse senedi ve endeks piyasalarındaki aktivitenin artması bekleniyor.",
                f"{comp_code} A.Ş. Kamuyu Aydınlatma Platformu'na (KAP) az önce resmi bir bildirim geçti. Şirkette son dönemde ciddi organizasyonel ve mali konularda çeşitli yapısal kararlar alındığı belirtilirken, özellikle son süreçteki {selected_words[0]} durumunun şirketin piyasa değerine yansıması konusunda tüm yatırımcıları kapsayıcı bilgi paylaşıldı. Süreç yönetim kurulu tarafından izleniyor."
            ]
            content = random.choice(contents)
            
            # Haber tablosuna ekle
            news_records.append({
                "News_ID": news_id,
                "Company_ID": comp_id,
                "News_Date": n_date,
                "News_Content": content,
                "News_URL": f"https://www.kap.org.tr/tr/haber/{random.randint(100000, 999999)}",
                "Base_Sentiment_Score": total_sentiment
            })
            
            # Many-To-Many Duygu Detay Tablosu (News_Sentiments)
            # Bu haberin içinde hangi veri sözlüğü kelimeleri geçti?
            for word in selected_words:
                news_sentiments_records.append({
                    "News_ID": news_id,
                    "Word_ID": word_to_id[word],
                    "Match_Count": 1
                })
                
            news_id += 1

    # DataFrame'lere atayalım ve kaydedelim
    df_news = pd.DataFrame(news_records)
    df_news.to_csv(os.path.join(DATA_DIR, 'KAP_News.csv'), index=False)
    
    df_ns = pd.DataFrame(news_sentiments_records)
    df_ns.to_csv(os.path.join(DATA_DIR, 'News_Sentiments.csv'), index=False)
    
    print(f"-> KAP_News.csv oluşturuldu! ({len(news_records)} satır)")
    print(f"-> Sentiment_Dictionary.csv ve News_Sentiments.csv oluşturuldu!")

def main():
    print("=== BIST-Algo-Analyzer Data Katmanı Başlıyor ===")
    valid_dates = fetch_prices()
    generate_mock_news(valid_dates)
    print("=== İŞLEM TAMAM! Tüm CSV dosyaları /data klasörüne yazıldı! ===")
    print("Artık bu CSV dosyalarını SQL Server / PostgreSQL (DBeaver vs.) üzerinden 'Import Data' diyerek projenin canlı veritabanını kurabilirsiniz.")

if __name__ == "__main__":
    main()

import json
import os
import re
import time
from datetime import datetime, timedelta
from urllib.parse import quote, urljoin

import pandas as pd
import requests
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

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

KAP_BASE_URL = "https://kap.org.tr"
MAX_NEWS_PER_COMPANY = 5

# Verilerin kaydedileceği klasörler
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(PROJECT_ROOT, "data")
FRONTEND_DATA_DIR = os.path.join(PROJECT_ROOT, "frontend", "data")
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(FRONTEND_DATA_DIR, exist_ok=True)


def write_csv(df, filename):
    """CSV çıktısını hem kök data klasörüne hem frontend data klasörüne yaz."""
    for directory in (DATA_DIR, FRONTEND_DATA_DIR):
        df.to_csv(os.path.join(directory, filename), index=False)

def load_kap_disclosure_urls():
    """KAP şirket bildirim sayfalarının URL eşlemesini dosyadan yükle."""
    candidates = [
        os.path.join(PROJECT_ROOT, "frontend", "data", "kap_company_pages.json"),
        os.path.join(PROJECT_ROOT, "data", "kap_company_pages.json"),
    ]

    for path in candidates:
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)

    return {}


def build_kap_session():
    """KAP sayfalarını çekmek için retry destekli oturum kur."""
    session = requests.Session()
    session.headers.update({
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
        "Connection": "keep-alive",
        "Referer": f"{KAP_BASE_URL}/tr/",
    })

    retry = Retry(
        total=4,
        connect=4,
        read=4,
        status=4,
        backoff_factor=1,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset(["GET"]),
        raise_on_status=False,
        respect_retry_after_header=True,
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    return session


def normalize_whitespace(text):
    return re.sub(r"\s+", " ", (text or "")).strip()


def build_company_search_terms(ticker, kap_url):
    """Şirket kodu ve KAP slug'ından olası arama terimlerini üret."""
    terms = [ticker]

    if kap_url:
        slug = kap_url.rstrip("/").split("/")[-1]
        slug = re.sub(r"^[0-9a-fA-F]+-", "", slug)
        slug = re.sub(r"^\d+-", "", slug)
        humanized = normalize_whitespace(slug.replace("-", " "))
        if humanized:
            terms.append(humanized)

    seen = []
    for term in terms:
        lowered = term.casefold()
        if lowered not in seen:
            seen.append(lowered)

    return terms[:2]


def fetch_search_html(session, term, page=1):
    """KAP arama sonuç sayfasını çek."""
    encoded_term = quote(term, safe="")
    candidate_urls = [
        f"{KAP_BASE_URL}/tr/search/{encoded_term}/{page}",
        f"{KAP_BASE_URL}/tr/search/{encoded_term}",
    ]

    last_error = None
    for url in candidate_urls:
        try:
            response = session.get(url, timeout=30)
            if response.status_code == 404:
                last_error = f"404: {url}"
                continue
            response.raise_for_status()
            return response.text, url
        except Exception as exc:
            last_error = f"{url} hata verdi: {exc}"

    raise RuntimeError(last_error or f"KAP arama sayfası alınamadı: {term}")


def extract_result_card(anchor):
    """Bir arama sonucu bağlantısından olası kart metnini ve tarihini çıkart."""
    current = anchor
    for _ in range(6):
        current = current.parent
        if current is None:
            break

        card_text = normalize_whitespace(current.get_text(" ", strip=True))
        if "/tr/Bildirim/" not in str(current):
            continue
        if len(card_text) < 80:
            continue

        date_match = re.search(r"(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})", card_text)
        if date_match:
            return current, card_text, date_match.group(1)

    return None, "", None


def parse_search_results(html):
    """KAP arama sonuç HTML'inden duyuru kartlarını ayıkla."""
    soup = BeautifulSoup(html, "html.parser")
    results = []
    seen_urls = set()

    for anchor in soup.find_all("a", href=True):
        href = anchor["href"]
        if "/tr/Bildirim/" not in href:
            continue

        full_url = urljoin(KAP_BASE_URL, href)
        if full_url in seen_urls:
            continue

        title = normalize_whitespace(anchor.get_text(" ", strip=True))
        if not title:
            continue

        card, card_text, raw_date = extract_result_card(anchor)
        if not raw_date:
            continue

        snippet = card_text
        snippet = snippet.replace(title, "", 1).strip()
        snippet = re.sub(r"^Gönderim Tarihi\s*" + re.escape(raw_date), "", snippet).strip()
        snippet = normalize_whitespace(snippet)

        if not snippet:
            continue

        results.append({
            "title": title,
            "url": full_url,
            "raw_date": raw_date,
            "snippet": snippet,
        })
        seen_urls.add(full_url)

    return results


def parse_kap_date(raw_date):
    return datetime.strptime(raw_date, "%d/%m/%Y %H:%M:%S").strftime("%Y-%m-%d")


def detail_matches_company(session, url, ticker, search_terms):
    """Bildirim detay sayfasının gerçekten ilgili şirkete ait olup olmadığını doğrula."""
    try:
        response = session.get(url, timeout=30)
        response.raise_for_status()
    except Exception:
        return False

    soup = BeautifulSoup(response.text, "html.parser")
    title = normalize_whitespace(soup.title.get_text(" ", strip=True) if soup.title else "")
    h1 = normalize_whitespace(soup.find("h1").get_text(" ", strip=True) if soup.find("h1") else "")
    body_text = normalize_whitespace(soup.get_text(" ", strip=True))
    haystack = f"{title} {h1} {body_text}".casefold()

    candidates = [ticker.casefold()]
    candidates.extend(term.casefold() for term in search_terms if term)

    return any(term in haystack for term in candidates)


def filter_company_results(results, ticker, search_terms):
    """Sonuçları ilgili şirkete daha sıkı filtrele."""
    accepted = []
    term_pool = [ticker.casefold()]
    term_pool.extend(term.casefold() for term in search_terms if term)

    for item in results:
        haystack = f"{item['title']} {item['snippet']}".casefold()
        if any(term in haystack for term in term_pool):
            accepted.append(item)

    return accepted


def score_news_content(content):
    """Gerçek haber metnini mevcut duygu sözlüğüyle puanla."""
    lowered = content.casefold()
    matched_words = []
    total_score = 0.0

    for word, score in SENTIMENT_DICT.items():
        match_count = lowered.count(word.casefold())
        if match_count > 0:
            matched_words.extend([word] * match_count)
            total_score += score * match_count

    return total_score, matched_words


def fetch_company_news(session, ticker, kap_url):
    """Şirket için KAP aramasından gerçek duyuruları getir."""
    search_terms = build_company_search_terms(ticker, kap_url)
    collected = []
    seen_urls = set()

    for term in search_terms:
        html, search_url = fetch_search_html(session, term, page=1)
        parsed_results = parse_search_results(html)
        filtered_results = filter_company_results(parsed_results, ticker, search_terms)

        for item in filtered_results:
            if item["url"] in seen_urls:
                continue

            if not detail_matches_company(session, item["url"], ticker, search_terms):
                continue

            item["search_url"] = search_url
            collected.append(item)
            seen_urls.add(item["url"])
            if len(collected) >= MAX_NEWS_PER_COMPANY:
                return collected

    return collected

def build_yahoo_session():
    """Yahoo Finance için tarayıcıya benzer ve retry destekli bir oturum kur."""
    session = requests.Session()
    session.headers.update({
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
        ),
        "Accept": "application/json,text/plain,*/*",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive",
        "Referer": "https://finance.yahoo.com/",
        "Origin": "https://finance.yahoo.com",
    })

    retry = Retry(
        total=3,
        connect=3,
        read=3,
        status=3,
        backoff_factor=1,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset(["GET"]),
        raise_on_status=False,
        respect_retry_after_header=True,
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    return session


def parse_yahoo_chart_payload(payload):
    """Yahoo chart API JSON çıktısını OHLCV DataFrame'e dönüştür."""
    chart = payload.get("chart", {})
    error = chart.get("error")
    results = chart.get("result") or []

    if error:
        return None, f"Yahoo hata döndürdü: {error}"
    if not results:
        return None, "Yahoo boş sonuç döndürdü"

    result = results[0]
    timestamps = result.get("timestamp") or []
    quote_list = result.get("indicators", {}).get("quote") or []
    if not timestamps or not quote_list:
        return None, "Zaman serisi boş döndü"

    quote = quote_list[0]
    columns = {
        "Open": quote.get("open", []),
        "High": quote.get("high", []),
        "Low": quote.get("low", []),
        "Close": quote.get("close", []),
        "Volume": quote.get("volume", []),
    }

    usable_lengths = [len(timestamps)]
    usable_lengths.extend(len(values) for values in columns.values() if values is not None)
    row_count = min(usable_lengths)
    if row_count == 0:
        return None, "Fiyat sütunları boş döndü"

    data = {name: values[:row_count] for name, values in columns.items()}
    frame = pd.DataFrame(data)
    frame.index = pd.to_datetime(timestamps[:row_count], unit="s", utc=True).tz_convert(None)
    frame = frame.dropna(subset=["Close"])

    if frame.empty:
        return None, "Close verisi boş döndü"

    return frame, None


def fetch_prices():
    """Yahoo Finance'tan gerçek borsa verilerini çeker."""
    print("1. Borsa fiyatları yfinance üzerinden çekiliyor (Son 1 yıl)...")
    price_records = []
    price_id = 1
    session = build_yahoo_session()
    cutoff = pd.Timestamp(datetime.utcnow().date() - timedelta(days=370))

    def download_real_history(ticker, hosts=("query1.finance.yahoo.com", "query2.finance.yahoo.com")):
        """Yahoo Finance chart API'den gerçek veri indir. Gerekirse sonsuza kadar yeniden dene."""
        symbol = f"{ticker}.IS"
        params = {
            "range": "1y",
            "interval": "1d",
            "includePrePost": "false",
            "events": "div,splits,capitalGains",
            "corsDomain": "finance.yahoo.com",
            ".tsrc": "finance",
        }
        delay_seconds = 10
        attempt = 1

        while True:
            last_error = None
            for host in hosts:
                url = f"https://{host}/v8/finance/chart/{symbol}"
                try:
                    response = session.get(url, params=params, timeout=30)

                    if response.status_code == 429:
                        last_error = f"{host} rate limit (429)"
                        continue

                    response.raise_for_status()
                    hist, parse_error = parse_yahoo_chart_payload(response.json())
                    if hist is not None and not hist.empty:
                        hist = hist[hist.index >= cutoff]
                        if not hist.empty:
                            return hist, None
                        last_error = "tarih filtresi sonrası boş veri"
                    else:
                        last_error = parse_error
                except Exception as e:
                    last_error = f"{host} hata verdi: {e}"

            print(f"[{ticker}] Veri gelmedi, {delay_seconds} saniye bekleniyor. Son hata: {last_error}")
            time.sleep(delay_seconds)
            attempt += 1
            delay_seconds = min(delay_seconds * 2, 300)

    for ticker, comp_id in COMPANIES.items():
        print(f"[{ticker}] Veri işleniyor...")
        hist, _ = download_real_history(ticker)

        for index, row in hist.iterrows():
            if pd.isna(row["Close"]):
                continue

            price_records.append({
                "Price_ID": price_id,
                "Company_ID": comp_id,
                "Price_Date": index.strftime('%Y-%m-%d'),
                "Open_Price": round(float(row["Open"]), 2),
                "High_Price": round(float(row["High"]), 2),
                "Low_Price": round(float(row["Low"]), 2),
                "Close_Price": round(float(row["Close"]), 2),
                "Volume": int(row["Volume"]) if pd.notna(row["Volume"]) else 0
            })
            price_id += 1

        time.sleep(2)

    df_prices = pd.DataFrame(price_records)
    if df_prices.empty:
        raise RuntimeError("Yahoo Finance'tan gerçek fiyat verisi çekilemedi.")

    write_csv(df_prices, 'Daily_Prices.csv')
    print(f"-> Daily_Prices.csv başarıyla oluşturuldu! ({len(price_records)} satır)")
    
    # Fiyat tarihlerini döndür ki haberleri bu tarihlere göre senkronlayalım
    return df_prices['Price_Date'].unique().tolist()

def generate_real_kap_news():
    """KAP arama sonuçlarından gerçek şirket duyurularını üret."""
    print("2. KAP'tan gerçek şirket duyuruları çekiliyor...")
    
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
    write_csv(df_dict, 'Sentiment_Dictionary.csv')
    kap_urls = load_kap_disclosure_urls()
    kap_session = build_kap_session()

    for comp_code, comp_id in COMPANIES.items():
        print(f"[{comp_code}] KAP duyuruları aranıyor...")
        company_url = kap_urls.get(comp_code)
        company_news = fetch_company_news(kap_session, comp_code, company_url)

        if not company_news:
            print(f"[{comp_code}] Gerçek duyuru bulunamadı.")
            continue

        for item in company_news:
            title = item["title"]
            snippet = item["snippet"]
            content = normalize_whitespace(f"{title}. {snippet}")
            news_date = parse_kap_date(item["raw_date"])
            total_sentiment, matched_words = score_news_content(content)

            news_records.append({
                "News_ID": news_id,
                "Company_ID": comp_id,
                "News_Date": news_date,
                "News_Content": content,
                "News_URL": item["url"],
                "Base_Sentiment_Score": total_sentiment
            })
            
            for word in matched_words:
                news_sentiments_records.append({
                    "News_ID": news_id,
                    "Word_ID": word_to_id[word],
                    "Match_Count": 1
                })
                
            news_id += 1

    df_news = pd.DataFrame(news_records)
    if df_news.empty:
        raise RuntimeError("KAP'tan gerçek duyuru çekilemedi. DNS, ağ erişimi veya KAP erişimi kontrol edilmeli.")

    write_csv(df_news, 'KAP_News.csv')
    
    df_ns = pd.DataFrame(news_sentiments_records)
    write_csv(df_ns, 'News_Sentiments.csv')
    
    print(f"-> KAP_News.csv oluşturuldu! ({len(news_records)} satır)")
    print(f"-> Sentiment_Dictionary.csv ve News_Sentiments.csv oluşturuldu!")

def main():
    print("=== BIST-Algo-Analyzer Data Katmanı Başlıyor ===")
    fetch_prices()
    generate_real_kap_news()
    print("=== İŞLEM TAMAM! Tüm CSV dosyaları /data klasörüne yazıldı! ===")
    print("Artık bu CSV dosyalarını SQL Server / PostgreSQL (DBeaver vs.) üzerinden 'Import Data' diyerek projenin canlı veritabanını kurabilirsiniz.")

if __name__ == "__main__":
    main()

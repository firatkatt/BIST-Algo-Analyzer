const { useState, useEffect, useRef, useMemo } = React;

const TICKERS = [
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
];

function App() {
    const [prices, setPrices] = useState([]);
    const [news, setNews] = useState([]);
    const [kapDisclosureUrls, setKapDisclosureUrls] = useState({});
    const [selectedCompanyId, setSelectedCompanyId] = useState(1);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // Papaparse ile CSV Data Fetching
        Promise.all([
            fetch('data/Daily_Prices.csv').then(r => r.text()),
            fetch('data/KAP_News.csv').then(r => r.text()),
            fetch('data/kap_company_pages.json').then(r => r.json())
        ]).then(([pricesText, newsText, kapUrls]) => {
            const parsedPrices = Papa.parse(pricesText, { header: true, dynamicTyping: true, skipEmptyLines: true });
            const parsedNews = Papa.parse(newsText, { header: true, dynamicTyping: true, skipEmptyLines: true });

            setPrices(parsedPrices.data);
            setNews(parsedNews.data);
            setKapDisclosureUrls(kapUrls || {});
            setLoading(false);
        }).catch(err => {
            console.error("Local veri yüklenirken hata. Lütfen 'python -m http.server' başlattığınıza emin olun.", err);
            setLoading(false);
        });
    }, []);

    const companyData = useMemo(() => {
        return prices.filter(p => p.Company_ID === selectedCompanyId)
            .sort((a, b) => new Date(a.Price_Date) - new Date(b.Price_Date));
    }, [prices, selectedCompanyId]);

    const companyNews = useMemo(() => {
        return news.filter(n => n.Company_ID === selectedCompanyId)
            .sort((a, b) => new Date(b.News_Date) - new Date(a.News_Date));
    }, [news, selectedCompanyId]);

    // Dinamik olarak Data'dan ID'leri çıkartıp ilk 50 tanesini listeleme
    const availableCompanies = useMemo(() => {
        const ids = [...new Set(prices.map(p => p.Company_ID))].filter(Boolean);
        return ids.slice(0, 98); // Tüm 98 BIST100 hissesini göster 
    }, [prices]);

    const getNewsKapUrl = (newsItem) => {
        const exactNewsUrl = typeof newsItem.News_URL === 'string' ? newsItem.News_URL.trim() : '';
        if (exactNewsUrl) {
            return exactNewsUrl;
        }

        const ticker = TICKERS[(Number(newsItem.Company_ID) || 1) - 1] || 'HISSE';
        return kapDisclosureUrls[ticker] || `https://kap.org.tr/tr/search/${encodeURIComponent(ticker)}/1`;
    };

    return (
        <div className="min-h-screen bg-darker p-6 flex flex-col items-center">
            <header className="w-full max-w-7xl flex justify-between items-center mb-8 border-b border-slate-800 pb-6">
                <div>
                    <h1 className="text-3xl font-bold bg-gradient-to-r from-blue-400 to-emerald-400 bg-clip-text text-transparent">BIST-Algo-Analyzer</h1>
                    <p className="text-slate-400 text-sm mt-1 mb-2">Kurumsal Yatırımcı Paneli & OHLCV Dashboard (Beta)</p>
                </div>
                {loading ? (
                    <div className="text-blue-400 animate-pulse font-medium">CSV Verileri Taranıyor (24.000+ satır)...</div>
                ) : (
                    <div className="flex items-center space-x-3">
                        <label className="text-slate-400 text-sm">Hisse Seç (Company ID):</label>
                        <select
                            className="glass px-4 py-2 text-lg font-bold rounded-lg text-white bg-slate-800 hover:bg-slate-700 transition cursor-pointer border-none outline-none focus:ring-2 focus:ring-blue-500"
                            value={selectedCompanyId}
                            onChange={e => setSelectedCompanyId(Number(e.target.value))}
                        >
                            {availableCompanies.map(id => (
                                <option key={id} value={id}>Hisse #{id}</option>
                            ))}
                        </select>
                    </div>
                )}
            </header>

            {!loading && prices.length > 0 && (
                <main className="w-full max-w-7xl grid grid-cols-1 xl:grid-cols-3 gap-6 animate-fade-in">

                    {/* SOL TARAF - OHLCV GRAFİĞİ */}
                    <div className="col-span-1 xl:col-span-2 glass rounded-2xl p-6 shadow-2xl relative overflow-hidden">
                        <div className="absolute top-0 right-0 w-64 h-64 bg-blue-500/10 blur-3xl mix-blend-screen rounded-full -translate-y-1/2 translate-x-1/4 pointer-events-none"></div>

                        <div className="flex justify-between items-center mb-4 z-10 relative">
                            <div>
                                <h2 className="text-xl font-semibold text-slate-100">Kapsamlı OHLCV / Fiyat Grafiği</h2>
                                <p className="text-xs text-slate-500 mt-1">Lightweight Charts (TradingView Altyapısı)</p>
                            </div>
                            <span className="px-3 py-1 bg-blue-500/10 text-blue-400 rounded-full border border-blue-500/30 text-sm font-bold tracking-wider">
                                ALGO SİNYALİ: HAZIR 🟢
                            </span>
                        </div>

                        <div className="h-[550px] w-full rounded-xl overflow-hidden border border-slate-700/50 bg-[#020617] relative z-10 shadow-inner">
                            <TradingViewChart data={companyData} />
                        </div>
                    </div>

                    {/* SAĞ TARAF - HABER VE DUYGU AKIŞI */}
                    <div className="glass rounded-2xl p-6 shadow-2xl flex flex-col h-[670px] relative">
                        <div className="flex justify-between items-center mb-4 border-b border-slate-700/50 pb-4 z-10 relative">
                            <div>
                                <h2 className="text-xl font-semibold text-slate-100">Son KAP Haberleri</h2>
                                <p className="text-xs text-slate-500 mt-1">Duygu Analizi (Sentiment) Çıktıları</p>
                            </div>
                        </div>

                        <div className="flex-1 overflow-y-auto pr-3 space-y-4">
                            {companyNews.length > 0 ? companyNews.map(n => (
                                <NewsCard key={n.News_ID} news={n} kapUrl={getNewsKapUrl(n)} />
                            )) : (
                                <div className="flex flex-col items-center justify-center h-full text-slate-500 space-y-3">
                                    <h3 className="text-lg font-medium border border-slate-700 px-4 py-2 rounded-lg bg-slate-800/50">Haber Bulunamadı</h3>
                                </div>
                            )}
                        </div>
                    </div>

                </main>
            )}
        </div>
    );
}

// TradingView Lightweight Charts Bileşeni
function TradingViewChart({ data }) {
    const chartContainerRef = useRef();
    const chartRef = useRef(null);

    useEffect(() => {
        if (!chartContainerRef.current || data.length === 0) return;

        // Container temizlik (React 18 Strict Mode Double-Render protection)
        if (chartRef.current) {
            chartRef.current.remove();
            chartRef.current = null;
        }
        chartContainerRef.current.innerHTML = "";

        // Chart oluştur
        const chart = LightweightCharts.createChart(chartContainerRef.current, {
            layout: { background: { type: 'solid', color: 'transparent' }, textColor: '#94a3b8' },
            grid: { vertLines: { color: 'rgba(30, 41, 59, 0.4)' }, horzLines: { color: 'rgba(30, 41, 59, 0.4)' } },
            timeScale: { borderColor: '#334155', rightOffset: 12 },
            crosshair: { mode: 0 }
        });
        chartRef.current = chart;

        const candlestickSeries = chart.addCandlestickSeries({
            upColor: '#10b981', downColor: '#ef4444',
            borderVisible: false, wickUpColor: '#10b981', wickDownColor: '#ef4444',
            priceFormat: { type: 'price', precision: 2, minMove: 0.01 }
        });

        // Datayı formatla
        const uniqueTimes = new Set();
        const formattedData = [];

        [...data].sort((a, b) => new Date(a.Price_Date) - new Date(b.Price_Date)).forEach(d => {
            const t = String(d.Price_Date).trim();
            if (t && d.Open_Price !== null && !uniqueTimes.has(t)) {
                uniqueTimes.add(t);
                formattedData.push({
                    time: t,
                    open: Number(d.Open_Price) || 0,
                    high: Number(d.High_Price) || Math.max(Number(d.Open_Price || 0), Number(d.Close_Price || 0)),
                    low: Number(d.Low_Price) || Math.min(Number(d.Open_Price || 0), Number(d.Close_Price || 0)),
                    close: Number(d.Close_Price) || 0
                });
            }
        });

        try {
            candlestickSeries.setData(formattedData);
            chart.timeScale().fitContent();
        } catch (err) {
            console.error("Chart Render Error:", err, formattedData);
        }

        // Responsive tasarım (Resize observer eklenebilir)

        return () => {
            if (chartRef.current) chartRef.current.remove();
        };
    }, [data]);

    return <div ref={chartContainerRef} className="w-full h-full" />;
}

// Haber Kartı Bileşeni
function NewsCard({ news, kapUrl }) {
    const isPositive = news.Base_Sentiment_Score > 0;
    const isNegative = news.Base_Sentiment_Score < 0;

    let badgeColor = 'bg-slate-500/20 text-slate-400 border-slate-500/30';
    let label = 'NÖTR ALGI';

    if (isPositive) { badgeColor = 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'; label = 'POZİTİF TREND'; }
    if (isNegative) { badgeColor = 'bg-red-500/10 text-red-400 border-red-500/30'; label = 'NEGATİF TREND'; }

    return (
        <div className={`p-4 rounded-xl border border-slate-700/60 bg-slate-800/30 hover:bg-slate-800/80 hover:border-slate-600 transition-all cursor-pointer group`}>
            <div className="flex justify-between items-start mb-3">
                <span className="text-xs text-slate-500 bg-slate-900/50 px-2 py-1 rounded font-mono">
                    {news.News_Date && news.News_Date.split(' ')[0]}
                </span>
                <span className={`text-[10px] font-bold px-2 py-1 rounded-sm border ${badgeColor} shadow-inner`}>
                    {label} ({news.Base_Sentiment_Score.toFixed(1)})
                </span>
            </div>
            <p className="text-sm text-slate-300 leading-relaxed font-normal group-hover:text-slate-100 transition-colors">
                {news.News_Content || news.Title}
            </p>
            <div className="mt-4 pt-3 border-t border-slate-700/50 flex justify-end">
                <a href={kapUrl} target="_blank" rel="noopener noreferrer" className="text-blue-400/80 text-xs hover:text-blue-400 hover:underline flex items-center font-medium">
                    KAP Sayfasına Git
                    <svg className="w-3 h-3 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
                </a>
            </div>
        </div>
    );
}

// React uygulamasını render et
const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);

// Supabase Edge Function "nieuws": maçonniek nieuws via Bing Nieuws (regio Arnhem/Velp + landelijk)
const REGIO_Q = ['vrijmetselarij Arnhem', 'vrijmetselaars Arnhem', 'vrijmetselarij Velp', 'vrijmetselaars Velp', 'vrijmetselarij Rheden', 'vrijmetselarij Oosterbeek', 'vrijmetselarij Gelderland', 'Le Droit Humain Arnhem'];
const LAND_Q = ['vrijmetselarij', 'vrijmetselaars', 'vrijmetselaarsloge', 'Le Droit Humain vrijmetselarij', 'Grootoosten der Nederlanden'];
const MASON = /vrijmetsel|maçon|macon|droit humain|grootoosten|vrijmetselaarsloge/i;
const PLACE = /arnhem|velp|rheden|rozendaal|oosterbeek|dieren|gelderland|doesburg|duiven|zevenaar|ede\b|wageningen/i;
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};
const UA = { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36', 'Accept-Language': 'nl-NL,nl;q=0.9' };
let cache: any = null, cachedAt = 0;
const decode = (s: string) => s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
  .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n)).replace(/&amp;/g, '&').replace(/<[^>]+>/g, '').trim();
const tag = (x: string, t: string) => { const m = x.match(new RegExp('<' + t + '[^>]*>([\\s\\S]*?)</' + t + '>')); return m ? decode(m[1]) : ''; };
async function search(q: string) {
  try {
    const r = await fetch('https://www.bing.com/news/search?format=rss&setlang=nl-NL&cc=NL&q=' + encodeURIComponent(q), { headers: UA });
    if (!r.ok) return [];
    const xml = await r.text();
    return [...xml.matchAll(/<item>([\s\S]*?)<\/item>/g)].map(m => {
      const it = m[1]; const d = new Date(tag(it, 'pubDate'));
      return { title: tag(it, 'title'), link: tag(it, 'link'), source: tag(it, 'News:Source'), text: tag(it, 'description'), date: isNaN(d.getTime()) ? null : d.toISOString() };
    }).filter(x => x.title && /^https?:\/\//.test(x.link));
  } catch (_) { return []; }
}
async function collect(qs: string[], test: (s: string) => boolean, days: number, max: number, skip: Set<string>) {
  const lists = await Promise.all(qs.map(search));
  const min = Date.now() - days * 864e5, seen = new Set<string>(), out: any[] = [];
  for (const x of lists.flat()) {
    const key = x.title.toLowerCase().replace(/\W+/g, '').slice(0, 80);
    if (seen.has(key) || skip.has(key)) continue;
    if (!test(x.title + ' ' + x.text)) continue;
    if (x.date && new Date(x.date).getTime() < min) continue;
    seen.add(key); out.push({ title: x.title, link: x.link, source: x.source, date: x.date, key });
  }
  out.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
  return out.slice(0, max);
}
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    if (!cache || Date.now() - cachedAt > 3 * 3600e3) {
      const regio = await collect(REGIO_Q, s => MASON.test(s) && PLACE.test(s), 730, 15, new Set());
      const landelijk = await collect(LAND_Q, s => MASON.test(s), 365, 25, new Set(regio.map(x => x.key)));
      const strip = (a: any[]) => a.map(({ key, ...r }) => r);
      cache = { regio: strip(regio), landelijk: strip(landelijk), updated: new Date().toISOString() };
      cachedAt = (regio.length + landelijk.length) ? Date.now() : 0;
    }
    return new Response(JSON.stringify(cache), { headers: { ...cors, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 502, headers: { ...cors, 'Content-Type': 'application/json' } });
  }
});

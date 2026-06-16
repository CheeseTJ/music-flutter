const APP_SECRET = 'junet';
const SIGN_EXPIRY = 21600;
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, x-timestamp, x-signature',
};

const BUGU_BASE = 'https://www.buguyy.top';

async function verifySignature(method, path, headers) {
  const ts = parseInt(headers['x-timestamp'] || '0');
  const sig = headers['x-signature'] || '';
  if (!ts || !sig) return false;
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - ts) > SIGN_EXPIRY) return false;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', encoder.encode(APP_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  const data = encoder.encode(`${ts}${method}${path}`);
  const hash = await crypto.subtle.sign('HMAC', key, data);
  const expected = Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('');
  return sig === expected;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS_HEADERS },
  });
}

async function searchBugu(keyword) {
  const kw = encodeURIComponent(keyword);
  const resp = await fetch(`${BUGU_BASE}/api/search?keyword=${kw}`, {
    headers: {
      'User-Agent': 'MusicApp/1.0',
      'Referer': `${BUGU_BASE}/search?keyword=${kw}`,
    },
  });
  const data = await resp.json();
  if (!data.success) return [];
  return (data.data || []).map(s => ({
    id: s.id,       // base64-encoded kuwo song ID
    name: s.title || '',
    artist: s.singer || '',
    album: '',
    cover: s.picurl || '',
    about: s.about || '',
    platform: 'buguyy',
  }));
}

async function getSongUrlBugu(b64id) {
  const resp = await fetch(`${BUGU_BASE}/api/geturl?id=${encodeURIComponent(b64id)}`, {
    headers: {
      'User-Agent': 'MusicApp/1.0',
      'Referer': `${BUGU_BASE}/`,
    },
  });
  const data = await resp.json();
  if (!data.success || !data.url) throw new Error('获取播放链接失败');
  return { url: data.url, name: data.name || '', lrc: data.lrc || '' };
}

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method.toUpperCase();

    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    // GET /search?name=晴天
    if (path === '/search' && method === 'GET') {
      const name = url.searchParams.get('name') || '';
      if (!name) return json({ results: [] });
      try {
        const results = await searchBugu(name);
        return json({ results });
      } catch (e) {
        return json({ error: e.message }, 500);
      }
    }

    // POST /import  {id: "MTEyNjE3ODA="}
    if (path === '/import' && method === 'POST') {
      if (!(await verifySignature(method, path, request.headers))) {
        return json({ detail: 'unauthorized' }, 403);
      }
      try {
        const body = await request.json();
        const { id } = body;
        if (!id) return json({ detail: '需要 id' }, 400);

        const info = await getSongUrlBugu(id);
        return json({
          name: info.name,
          url: info.url,
          lrc: info.lrc,
        });
      } catch (e) {
        return json({ detail: e.message }, 500);
      }
    }

    // GET /play?id=xxx  (internal server handles this, here as fallback)
    if (path === '/play' && method === 'GET') {
      if (!(await verifySignature(method, path, request.headers))) {
        return json({ detail: 'unauthorized' }, 403);
      }
      const id = url.searchParams.get('id');
      if (!id) return json({ detail: '需要 id' }, 400);
      try {
        const info = await getSongUrlBugu(id);
        return json({ url: info.url });
      } catch (e) {
        return json({ detail: e.message }, 500);
      }
    }

    return json({ detail: 'not found' }, 404);
  },
};

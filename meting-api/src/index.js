// meting-api/src/index.js — Cloudflare Worker for Meting API
import { netease } from './netease.js';
import { tencent } from './tencent.js';
import { kuwo } from './kuwo.js';

const platforms = { netease, tencent, kuwo };

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const params = url.searchParams;
    const server = params.get('server') || 'netease';
    const type = params.get('type') || 'search';

    const platform = platforms[server];
    if (!platform) {
      return json({ error: `unsupported server: ${server}`, supported: Object.keys(platforms) }, 400);
    }

    try {
      // 注入 Cookie
      if (server === 'netease' && env.NETEASE_COOKIE) platform.setCookie(env.NETEASE_COOKIE);
      if (server === 'tencent' && env.TENCENT_COOKIE) platform.setCookie(env.TENCENT_COOKIE);

      switch (type) {
        case 'search': {
          const keyword = params.get('keyword') || '';
          const page = parseInt(params.get('page') || '1');
          const limit = parseInt(params.get('limit') || '30');
          const result = await platform.search(keyword, { page, limit });
          return json(result);
        }
        case 'url': {
          const id = params.get('id');
          const br = parseInt(params.get('br') || '320');
          if (!id) return json({ error: 'missing id' }, 400);
          const result = await platform.url(id, br);
          return json(result);
        }
        case 'lyric': {
          const id = params.get('id');
          if (!id) return json({ error: 'missing id' }, 400);
          const result = await platform.lyric(id);
          return json(result);
        }
        case 'pic': {
          const id = params.get('id');
          const size = parseInt(params.get('size') || '300');
          if (!id) return json({ error: 'missing id' }, 400);
          const result = await platform.pic(id, size);
          return json(result);
        }
        default:
          return json({ error: `unknown type: ${type}`, supported: ['search', 'url', 'lyric', 'pic'] }, 400);
      }
    } catch (e) {
      return json({ error: e.message || 'internal error' }, 500);
    }
  }
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json;charset=utf-8',
      'access-control-allow-origin': '*',
      'cache-control': 'public, max-age=300',
    },
  });
}

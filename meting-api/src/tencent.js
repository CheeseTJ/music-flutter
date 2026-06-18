// tencent.js — QQ Music platform adapter for Cloudflare Workers
import { md5 } from './crypto.js';

const API = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
const SEARCH_URL = 'https://c.y.qq.com/soso/fcgi-bin/client_search_cp';

class Tencent {
  #cookie = '';

  setCookie(c) { this.#cookie = c; }

  async search(keyword, { page = 1, limit = 30 } = {}) {
    const params = new URLSearchParams({
      w: keyword,
      p: page,
      n: limit,
      format: 'json',
      platform: 'yqq.json',
    });
    const resp = await fetch(`${SEARCH_URL}?${params}`, {
      headers: { referer: 'https://y.qq.com/', ...this.#headers() },
    });
    const data = await resp.json();
    const songs = (data?.data?.song?.list || []).map(s => ({
      id: s.songmid || s.mid,
      name: s.songname || s.name,
      artist: (s.singer || []).map(a => a.name).join('、'),
      album: s.albumname || s.album,
      pic_id: s.albummid || s.album_mid,
      url_id: s.songmid || s.mid,
      lyric_id: s.songmid || s.mid,
      source: 'tencent',
    }));
    return songs;
  }

  async url(id, br = 320) {
    // vkey 获取
    const guid = String(Math.floor(Math.random() * 1e10)).padStart(10, '0');
    const data = {
      req_0: {
        module: 'vkey.GetVkeyServer',
        method: 'CgiGetVkey',
        param: {
          guid,
          songmid: [id],
          songtype: [0],
          uin: '0',
          loginflag: 1,
          platform: '20',
        },
      },
    };
    const resp = await fetch(`${API}?_=${Date.now()}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', referer: 'https://y.qq.com/', ...this.#headers() },
      body: JSON.stringify(data),
    });
    const json = await resp.json();
    const mid = json?.req_0?.data?.midurlinfo?.[0];
    const sip = json?.req_0?.data?.sip || [];
    if (!mid?.purl) return { url: null };
    const url = (sip[0] || 'http://ws.stream.qqmusic.qq.com/') + mid.purl;
    return { url };
  }

  async lyric(id) {
    const resp = await fetch(`https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=${id}&format=json`, {
      headers: { referer: 'https://y.qq.com/', ...this.#headers() },
    });
    const data = await resp.json();
    return { lyric: data?.lyric || '' };
  }

  async pic(id, size = 300) {
    return { url: `https://y.gtimg.cn/music/photo_new/T002R${size}x${size}M000${id}.jpg` };
  }

  #headers() {
    const h = {};
    if (this.#cookie) h['Cookie'] = this.#cookie;
    return h;
  }
}

export const tencent = new Tencent();

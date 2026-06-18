// kuwo.js — Kuwo Music platform adapter for Cloudflare Workers
import { md5 } from './crypto.js';

class Kuwo {
  #cookie = '';

  setCookie(c) { this.#cookie = c; }

  async search(keyword, { page = 1, limit = 30 } = {}) {
    const pn = page - 1;
    const rn = limit;
    const url = `https://search.kuwo.cn/r.s?all=${encodeURIComponent(keyword)}&ft=music&pn=${pn}&rn=${rn}&vipver=1&client=kt&rformat=json`;
    const resp = await fetch(url, { headers: this.#headers() });
    const data = await resp.json();
    const songs = (data?.abslist || []).map(s => ({
      id: s.MUSICRID?.replace('MUSIC_', '') || s.DC_TARGETID,
      name: s.SONGNAME || s.NAME,
      artist: s.ARTIST || s.ARTISTNAME,
      album: s.ALBUM || '',
      pic_id: '',
      url_id: s.MUSICRID?.replace('MUSIC_', '') || s.DC_TARGETID,
      lyric_id: s.MUSICRID?.replace('MUSIC_', '') || '',
      source: 'kuwo',
    }));
    return songs;
  }

  async url(id, br = 320) {
    const resp = await fetch(`https://www.kuwo.cn/api/v1/www/music/playUrl?mid=${id}&type=music&httpsStatus=1`, {
      headers: { referer: 'https://www.kuwo.cn/', ...this.#headers() },
    });
    const data = await resp.json();
    return { url: data?.data?.url || null };
  }

  async lyric(id) {
    const resp = await fetch(`https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=${id}`, {
      headers: this.#headers(),
    });
    const data = await resp.json();
    const lrclist = data?.data?.lrclist || [];
    const lyric = lrclist.map(l => `[${l.time}]${l.lineLyric}`).join('\n');
    return { lyric };
  }

  async pic(_id, _size) {
    return { url: null };
  }

  #headers() {
    const h = { 'csrf': this.#csrf(), referer: 'https://www.kuwo.cn/' };
    if (this.#cookie) h['Cookie'] = this.#cookie;
    return h;
  }

  #csrf() {
    return md5('site=kuwo');
  }
}

export const kuwo = new Kuwo();

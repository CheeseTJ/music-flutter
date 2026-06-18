// netease.js — Netease Cloud Music platform adapter for Cloudflare Workers
import { aesEncrypt, base64, encoder, rsaEncrypt } from './crypto.js';

const API = 'https://music.163.com/weapi/';
const NONCE = '0CoJUm6Qyw8W8jud';
const FIXED_IV = '0102030405060708';
const RSA_EXP = '010001';
const RSA_MOD = '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7';

class Netease {
  #cookie = '';

  setCookie(c) { this.#cookie = c; }

  async #weapi(path, data) {
    const text = JSON.stringify(data);
    const iv = FIXED_IV;
    // First AES with fixed key (16-byte raw string)
    const enc1 = await aesEncrypt(text, NONCE, iv);
    // Random second key (16-byte raw string)
    const secKey = randomKey(16);
    // Second AES with random key
    const enc2 = await aesEncrypt(base64(enc1), secKey, iv);
    const params = base64(enc2);
    // RSA encrypt the random key
    const encSecKey = rsaEncrypt(secKey, RSA_EXP, RSA_MOD);
    return { params, encSecKey };
  }

  async #call(path, data) {
    const body = await this.#weapi(path, data);
    const form = new URLSearchParams(body);
    const headers = {
      'content-type': 'application/x-www-form-urlencoded',
      referer: 'https://music.163.com/',
    };
    if (this.#cookie) headers['Cookie'] = this.#cookie;
    const resp = await fetch(API + path, { method: 'POST', headers, body: form });
    return resp.json();
  }

  async search(keyword, { page = 1, limit = 30 } = {}) {
    const params = {
      s: keyword,
      type: 1,
      limit,
      offset: (page - 1) * limit,
      total: true,
    };
    const data = await this.#call('cloudsearch/get/web', params);
    const songs = (data?.result?.songs || []).map(s => ({
      id: s.id,
      name: s.name,
      artist: (s.ar || []).map(a => a.name).join('、'),
      album: s.al?.name || '',
      pic_id: s.al?.pic_str || s.al?.pic || '',
      url_id: s.id,
      lyric_id: s.id,
      source: 'netease',
    }));
    return songs;
  }

  async url(id, br = 320) {
    const bitrate = { 128: 'standard', 320: 'exhigh', 999: 'lossless' }[br] || 'exhigh';
    const data = await this.#call('song/enhance/player/url/v1', {
      ids: [id],
      level: bitrate,
      encodeType: 'flac',
    });
    const urls = data?.data || [];
    return { url: urls[0]?.url || null };
  }

  async lyric(id) {
    const data = await this.#call('song/lyric', { id, lv: -1, tv: -1 });
    return { lyric: data?.lrc?.lyric || '' };
  }

  async pic(id, size = 300) {
    const s = id?.toString() || '0';
    return { url: `https://p2.music.126.net/${s}/${s}.jpg?param=${size}y${size}` };
  }
}

export const netease = new Netease();

var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/crypto.js
var encoder = new TextEncoder();
function hexToBytes(hex) {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
  return bytes;
}
__name(hexToBytes, "hexToBytes");
function base64(bytes) {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}
__name(base64, "base64");
async function aesEncrypt(text, keyStr, ivHex) {
  const keyBytes = encoder.encode(keyStr);
  const ivBytes = hexToBytes(ivHex);
  const dataBytes = encoder.encode(text);
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "AES-CBC" }, false, ["encrypt"]);
  const encrypted = await crypto.subtle.encrypt({ name: "AES-CBC", iv: ivBytes }, key, dataBytes);
  return new Uint8Array(encrypted);
}
__name(aesEncrypt, "aesEncrypt");
function rsaEncrypt(text, exponent, modulus) {
  text = text.split("").reverse().join("");
  const e = BigInt("0x" + exponent);
  const n = BigInt("0x" + modulus);
  let hex = "";
  for (let i = 0; i < text.length; i++) hex += text.charCodeAt(i).toString(16).padStart(2, "0");
  const m = BigInt("0x" + hex);
  const c = modPow(m, e, n);
  let result = c.toString(16);
  if (result.length < 256) result = result.padStart(256, "0");
  return result;
}
__name(rsaEncrypt, "rsaEncrypt");
function modPow(base, exp, mod) {
  let result = 1n;
  base = base % mod;
  while (exp > 0n) {
    if (exp & 1n) result = result * base % mod;
    exp >>= 1n;
    base = base * base % mod;
  }
  return result;
}
__name(modPow, "modPow");
function md5(string) {
  function r(n, c2) {
    return n << c2 | n >>> 32 - c2;
  }
  __name(r, "r");
  function q(n, c2) {
    return n & c2 | ~n & (4294967295 ^ c2);
  }
  __name(q, "q");
  function p(n, c2) {
    return n & (4294967295 ^ c2) | ~n & c2;
  }
  __name(p, "p");
  function o(n, c2) {
    return n ^ c2;
  }
  __name(o, "o");
  function l(n, c2) {
    return c2 ^ (n | ~c2);
  }
  __name(l, "l");
  let x = Array.from(
    { length: ((string.length + 8 >> 6) + 1) * 16 },
    (_, i) => i < string.length >> 2 ? string.charCodeAt(i * 4) | string.charCodeAt(i * 4 + 1) << 8 | string.charCodeAt(i * 4 + 2) << 16 | string.charCodeAt(i * 4 + 3) << 24 : i === string.length >> 2 ? (string.charCodeAt(i * 4) | string.charCodeAt(i * 4 + 1) << 8 | string.charCodeAt(i * 4 + 2) << 16 | 128) << string.length % 4 * 8 : 0
  );
  x[x.length - 2] = string.length * 8;
  let a = 1732584193, b = 4023233417, c = 2562383102, d = 271733878;
  for (let k = 0; k < x.length; k += 16) {
    let A = a, B = b, C = c, D = d;
    const fn = [q, q, q, p, p, p, p, q, q, q, p, p, o, q, l, p, q, q, p, q, o, q, l, l, l, p, p, q, p, q, q, p, o, l, o, o, o, o, o, l, o, q, o, q, o, q, q, q, q, q, q, l, q, l, o, o, l, q, q, l, q, q, l, q, q, o, q, q, q, q, l, q, o, l, o, q];
    const S = [7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21];
    for (let i = 0; i < 64; i++) {
      let fni = fn[i], si = S[fni], g = i < 16 ? i : i < 32 ? (5 * i + 1) % 16 : i < 48 ? (3 * i + 5) % 16 : 7 * i % 16;
      let fval = fni === q ? q(B, C, D) : fni === p ? p(B, C, D) : fni === o ? B ^ C ^ D : l(B, C, D);
      let T = A + fval + x[k + g] + Math.floor(Math.abs(Math.sin(i + 1)) * 4294967296) >>> 0;
      let rotated = (T << si | T >>> 32 - si) >>> 0;
      A = D;
      D = C;
      C = B;
      B = B + rotated >>> 0;
    }
    a = a + A >>> 0;
    b = b + B >>> 0;
    c = c + C >>> 0;
    d = d + D >>> 0;
  }
  return [a, b, c, d].map((v) => ("0000000" + v.toString(16)).slice(-8)).join("");
}
__name(md5, "md5");

// src/netease.js
var API = "https://music.163.com/weapi/";
var NONCE = "0CoJUm6Qyw8W8jud";
var FIXED_IV = "0102030405060708";
var RSA_EXP = "010001";
var RSA_MOD = "00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7";
var Netease = class {
  static {
    __name(this, "Netease");
  }
  #cookie = "";
  setCookie(c) {
    this.#cookie = c;
  }
  async #weapi(path, data) {
    const text = JSON.stringify(data);
    const iv = FIXED_IV;
    const enc1 = await aesEncrypt(text, NONCE, iv);
    const secKey = randomKey(16);
    const enc2 = await aesEncrypt(base64(enc1), secKey, iv);
    const params = base64(enc2);
    const encSecKey = rsaEncrypt(secKey, RSA_EXP, RSA_MOD);
    return { params, encSecKey };
  }
  async #call(path, data) {
    const body = await this.#weapi(path, data);
    const form = new URLSearchParams(body);
    const headers = {
      "content-type": "application/x-www-form-urlencoded",
      referer: "https://music.163.com/"
    };
    if (this.#cookie) headers["Cookie"] = this.#cookie;
    const resp = await fetch(API + path, { method: "POST", headers, body: form });
    return resp.json();
  }
  async search(keyword, { page = 1, limit = 30 } = {}) {
    const params = {
      s: keyword,
      type: 1,
      limit,
      offset: (page - 1) * limit,
      total: true
    };
    const data = await this.#call("cloudsearch/get/web", params);
    const songs = (data?.result?.songs || []).map((s) => ({
      id: s.id,
      name: s.name,
      artist: (s.ar || []).map((a) => a.name).join("\u3001"),
      album: s.al?.name || "",
      pic_id: s.al?.pic_str || s.al?.pic || "",
      url_id: s.id,
      lyric_id: s.id,
      source: "netease"
    }));
    return songs;
  }
  async url(id, br = 320) {
    const bitrate = { 128: "standard", 320: "exhigh", 999: "lossless" }[br] || "exhigh";
    const data = await this.#call("song/enhance/player/url/v1", {
      ids: [id],
      level: bitrate,
      encodeType: "flac"
    });
    const urls = data?.data || [];
    return { url: urls[0]?.url || null };
  }
  async lyric(id) {
    const data = await this.#call("song/lyric", { id, lv: -1, tv: -1 });
    return { lyric: data?.lrc?.lyric || "" };
  }
  async pic(id, size = 300) {
    const s = id?.toString() || "0";
    return { url: `https://p2.music.126.net/${s}/${s}.jpg?param=${size}y${size}` };
  }
};
var netease = new Netease();

// src/tencent.js
var API2 = "https://u.y.qq.com/cgi-bin/musicu.fcg";
var SEARCH_URL = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp";
var Tencent = class {
  static {
    __name(this, "Tencent");
  }
  #cookie = "";
  setCookie(c) {
    this.#cookie = c;
  }
  async search(keyword, { page = 1, limit = 30 } = {}) {
    const params = new URLSearchParams({
      w: keyword,
      p: page,
      n: limit,
      format: "json",
      platform: "yqq.json"
    });
    const resp = await fetch(`${SEARCH_URL}?${params}`, {
      headers: { referer: "https://y.qq.com/", ...this.#headers() }
    });
    const data = await resp.json();
    const songs = (data?.data?.song?.list || []).map((s) => ({
      id: s.songmid || s.mid,
      name: s.songname || s.name,
      artist: (s.singer || []).map((a) => a.name).join("\u3001"),
      album: s.albumname || s.album,
      pic_id: s.albummid || s.album_mid,
      url_id: s.songmid || s.mid,
      lyric_id: s.songmid || s.mid,
      source: "tencent"
    }));
    return songs;
  }
  async url(id, br = 320) {
    const guid = String(Math.floor(Math.random() * 1e10)).padStart(10, "0");
    const data = {
      req_0: {
        module: "vkey.GetVkeyServer",
        method: "CgiGetVkey",
        param: {
          guid,
          songmid: [id],
          songtype: [0],
          uin: "0",
          loginflag: 1,
          platform: "20"
        }
      }
    };
    const resp = await fetch(`${API2}?_=${Date.now()}`, {
      method: "POST",
      headers: { "content-type": "application/json", referer: "https://y.qq.com/", ...this.#headers() },
      body: JSON.stringify(data)
    });
    const json2 = await resp.json();
    const mid = json2?.req_0?.data?.midurlinfo?.[0];
    const sip = json2?.req_0?.data?.sip || [];
    if (!mid?.purl) return { url: null };
    const url = (sip[0] || "http://ws.stream.qqmusic.qq.com/") + mid.purl;
    return { url };
  }
  async lyric(id) {
    const resp = await fetch(`https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=${id}&format=json`, {
      headers: { referer: "https://y.qq.com/", ...this.#headers() }
    });
    const data = await resp.json();
    return { lyric: data?.lyric || "" };
  }
  async pic(id, size = 300) {
    return { url: `https://y.gtimg.cn/music/photo_new/T002R${size}x${size}M000${id}.jpg` };
  }
  #headers() {
    const h = {};
    if (this.#cookie) h["Cookie"] = this.#cookie;
    return h;
  }
};
var tencent = new Tencent();

// src/kuwo.js
var Kuwo = class {
  static {
    __name(this, "Kuwo");
  }
  #cookie = "";
  setCookie(c) {
    this.#cookie = c;
  }
  async search(keyword, { page = 1, limit = 30 } = {}) {
    const pn = page - 1;
    const rn = limit;
    const url = `https://search.kuwo.cn/r.s?all=${encodeURIComponent(keyword)}&ft=music&pn=${pn}&rn=${rn}&vipver=1&client=kt&rformat=json`;
    const resp = await fetch(url, { headers: this.#headers() });
    const data = await resp.json();
    const songs = (data?.abslist || []).map((s) => ({
      id: s.MUSICRID?.replace("MUSIC_", "") || s.DC_TARGETID,
      name: s.SONGNAME || s.NAME,
      artist: s.ARTIST || s.ARTISTNAME,
      album: s.ALBUM || "",
      pic_id: "",
      url_id: s.MUSICRID?.replace("MUSIC_", "") || s.DC_TARGETID,
      lyric_id: s.MUSICRID?.replace("MUSIC_", "") || "",
      source: "kuwo"
    }));
    return songs;
  }
  async url(id, br = 320) {
    const resp = await fetch(`https://www.kuwo.cn/api/v1/www/music/playUrl?mid=${id}&type=music&httpsStatus=1`, {
      headers: { referer: "https://www.kuwo.cn/", ...this.#headers() }
    });
    const data = await resp.json();
    return { url: data?.data?.url || null };
  }
  async lyric(id) {
    const resp = await fetch(`https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=${id}`, {
      headers: this.#headers()
    });
    const data = await resp.json();
    const lrclist = data?.data?.lrclist || [];
    const lyric = lrclist.map((l) => `[${l.time}]${l.lineLyric}`).join("\n");
    return { lyric };
  }
  async pic(_id, _size) {
    return { url: null };
  }
  #headers() {
    const h = { "csrf": this.#csrf(), referer: "https://www.kuwo.cn/" };
    if (this.#cookie) h["Cookie"] = this.#cookie;
    return h;
  }
  #csrf() {
    return md5("site=kuwo");
  }
};
var kuwo = new Kuwo();

// src/index.js
var platforms = { netease, tencent, kuwo };
var src_default = {
  async fetch(request, env) {
    const url = new URL(request.url);
    const params = url.searchParams;
    const server = params.get("server") || "netease";
    const type = params.get("type") || "search";
    const platform = platforms[server];
    if (!platform) {
      return json({ error: `unsupported server: ${server}`, supported: Object.keys(platforms) }, 400);
    }
    try {
      if (server === "netease" && env.NETEASE_COOKIE) platform.setCookie(env.NETEASE_COOKIE);
      if (server === "tencent" && env.TENCENT_COOKIE) platform.setCookie(env.TENCENT_COOKIE);
      switch (type) {
        case "search": {
          const keyword = params.get("keyword") || "";
          const page = parseInt(params.get("page") || "1");
          const limit = parseInt(params.get("limit") || "30");
          const result = await platform.search(keyword, { page, limit });
          return json(result);
        }
        case "url": {
          const id = params.get("id");
          const br = parseInt(params.get("br") || "320");
          if (!id) return json({ error: "missing id" }, 400);
          const result = await platform.url(id, br);
          return json(result);
        }
        case "lyric": {
          const id = params.get("id");
          if (!id) return json({ error: "missing id" }, 400);
          const result = await platform.lyric(id);
          return json(result);
        }
        case "pic": {
          const id = params.get("id");
          const size = parseInt(params.get("size") || "300");
          if (!id) return json({ error: "missing id" }, 400);
          const result = await platform.pic(id, size);
          return json(result);
        }
        default:
          return json({ error: `unknown type: ${type}`, supported: ["search", "url", "lyric", "pic"] }, 400);
      }
    } catch (e) {
      return json({ error: e.message || "internal error" }, 500);
    }
  }
};
function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json;charset=utf-8",
      "access-control-allow-origin": "*",
      "cache-control": "public, max-age=300"
    }
  });
}
__name(json, "json");

// D:/NVM/nvm/v24.13.0/node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// D:/NVM/nvm/v24.13.0/node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-npYsug/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = src_default;

// D:/NVM/nvm/v24.13.0/node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-npYsug/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map

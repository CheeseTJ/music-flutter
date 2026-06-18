import { Hono } from "hono";
import { Context } from "hono";
import { verifyRequest } from "../services/auth";
import { Env } from "../index";

type SContext = Context<{ Bindings: Env }>;

function getSearchUrl(name: string, type: string): string {
  return `https://jkyapi.top/API/hqyyid.php?name=${encodeURIComponent(name)}&type=${type}&page=1&limit=10`;
}

function getDetailUrl(id: number, type: string): string {
  return `https://jkyapi.top/API/yyjhss.php?id=${id}&type=${type}`;
}

function makeSearchHandler(type: string) {
  return async (c: SContext): Promise<Response> => {
    const name = c.req.query("name");
    if (!name) return c.json({ results: [] }, 200);
    try {
      const res = await fetch(getSearchUrl(name, type));
      const json = await res.json<{ code: number; data?: { type: string; id: number; name: string; album: string; artist: string; pic_id: string }[] }>();
      if (json.code !== 1 || !json.data) return c.json({ results: [] }, 200);
      const results = json.data.map((item) => ({
        type: item.type,
        id: item.id,
        name: item.name,
        album: item.album,
        artist: item.artist,
      }));
      return c.json({ results }, 200);
    } catch {
      return c.json({ error: "Search failed" }, 502);
    }
  };
}

function makeImportHandler(type: string) {
  return async (c: SContext): Promise<Response> => {
    const verified = await verifyRequest(c.req.raw, c.env.SIGN_SECRET);
    if (!verified) return c.text("Unauthorized", 401);

    const body = await c.req.json<{ id: number }>();
    if (!body.id) return c.json({ error: "Missing id" }, 400);

    const detailUrl = getDetailUrl(body.id, type);
    let detail: {
      code: number;
      data?: { name: string; album: string; artist: string; url: string; pic: string; lrc: string };
    };

    try {
      const res = await fetch(detailUrl);
      detail = await res.json();
    } catch {
      return c.json({ error: "Fetch song detail failed" }, 502);
    }

    if (detail.code !== 1 || !detail.data) return c.json({ error: "Song not found" }, 404);

    const { name, album, artist, url, pic, lrc } = detail.data;
    if (!url) return c.json({ error: "No playable URL" }, 400);

    const maxIdResult = await c.env.DB.prepare("SELECT MAX(id) as maxId FROM songs").first<{ maxId: number | null }>();
    const nextId = (maxIdResult?.maxId ?? 0) + 1;

    const ext = url.includes(".mp3") ? "mp3" : url.includes(".flac") ? "flac" : "mp3";
    const audioKey = `audio/${nextId}/song.${ext}`;
    let coverKey: string | null = null;
    let lyricKey: string | null = null;

    try {
      const audioRes = await fetch(url);
      if (!audioRes.ok || !audioRes.body) return c.json({ error: "Download audio failed" }, 502);
      await c.env.MUSIC_BUCKET.put(audioKey, audioRes.body, {
        httpMetadata: { contentType: `audio/${ext}` },
      });
    } catch {
      return c.json({ error: "Upload audio to R2 failed" }, 502);
    }

    if (pic) {
      try {
        const picRes = await fetch(pic + "?param=300y300");
        if (picRes.ok && picRes.body) {
          coverKey = `audio/${nextId}/cover.jpg`;
          await c.env.MUSIC_BUCKET.put(coverKey, picRes.body, {
            httpMetadata: { contentType: "image/jpeg" },
          });
        }
      } catch {}
    }

    if (lrc) {
      try {
        lyricKey = `audio/${nextId}/lyric.lrc`;
        await c.env.MUSIC_BUCKET.put(lyricKey, lrc, {
          httpMetadata: { contentType: "text/plain" },
        });
      } catch {}
    }

    await c.env.DB
      .prepare(
        "INSERT INTO songs (title, artist, album, path, format, size, duration, cover_path, lyric_path, created_at) VALUES (?, ?, ?, ?, ?, 0, 0, ?, ?, ?)"
      )
      .bind(name, artist, album, audioKey, ext, coverKey, lyricKey, Math.floor(Date.now() / 1000))
      .run();

    return c.json({ success: true, id: nextId, name, artist }, 201);
  };
}

export const searchWy = makeSearchHandler("wy");
export const searchQq = makeSearchHandler("qq");
export const searchMg = makeSearchHandler("mg");
export const searchKg = makeSearchHandler("kg");
export const searchKw = makeSearchHandler("kw");

export const importWy = makeImportHandler("wy");
export const importQq = makeImportHandler("qq");
export const importMg = makeImportHandler("mg");
export const importKg = makeImportHandler("kg");
export const importKw = makeImportHandler("kw");

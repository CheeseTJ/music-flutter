import { Context } from "hono";
import { verifyRequest } from "../services/auth";
import { Env } from "../index";

type ImportContext = Context<{ Bindings: Env }>;

export async function importRoute(c: ImportContext): Promise<Response> {
  const verified = await verifyRequest(c.req.raw, c.env.SIGN_SECRET);
  if (!verified) {
    return c.text("Unauthorized", 401);
  }

  const body = await c.req.json<{ type: string; id: number }>();
  if (!body.type || !body.id) {
    return c.json({ error: "Missing type or id" }, 400);
  }

  const detailUrl = `https://jkyapi.top/API/yyjhss.php?id=${body.id}&type=${body.type}`;

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

  if (detail.code !== 1 || !detail.data) {
    return c.json({ error: "Song not found" }, 404);
  }

  const { name, album, artist, url, pic, lrc } = detail.data;
  if (!url) {
    return c.json({ error: "No playable URL" }, 400);
  }

  const maxIdResult = await c.env.DB.prepare("SELECT MAX(id) as maxId FROM songs").first<{ maxId: number | null }>();
  const nextId = (maxIdResult?.maxId ?? 0) + 1;

  const ext = url.includes(".mp3") ? "mp3" : url.includes(".flac") ? "flac" : "mp3";
  const audioKey = `audio/${nextId}/song.${ext}`;
  let coverKey: string | null = null;
  let lyricKey: string | null = null;

  try {
    const audioRes = await fetch(url);
    if (!audioRes.ok || !audioRes.body) {
      return c.json({ error: "Download audio failed" }, 502);
    }
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
}

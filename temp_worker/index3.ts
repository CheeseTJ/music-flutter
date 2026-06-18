import { Hono } from "hono";
import { sign, getExpires } from "./services/auth";
import { listRoute } from "./routes/list";
import { playRoute } from "./routes/play";
import { uploadRoute } from "./routes/upload";
import { lyricUploadRoute } from "./routes/lyric_upload";
import { lyricGetRoute } from "./routes/lyric";
import { deleteSongRoute } from "./routes/delete_song";
import { updateSongRoute } from "./routes/update_song";
import { searchRoute } from "./routes/search";
import { importRoute } from "./routes/import_song";
import {
  searchWy, searchQq, searchMg, searchKg, searchKw,
  importWy, importQq, importMg, importKg, importKw,
} from "./routes/source_search";

export interface Env {
  MUSIC_BUCKET: R2Bucket;
  DB: D1Database;
  SIGN_SECRET: string;
  APP_KEY: string;
}

const app = new Hono<{ Bindings: Env }>();

app.get("/", (c) => c.text("Music Worker is running!"));

app.get("/sign", async (c) => {
  const appKey = c.req.query("key");
  if (appKey !== c.env.APP_KEY) {
    return c.text("Unauthorized", 401);
  }

  const path = c.req.query("path");
  if (!path) return c.text("Missing path", 400);

  const expires = getExpires(21600);
  const sig = await sign(path, expires, c.env.SIGN_SECRET);

  const origin = new URL(c.req.url).origin;
  const signedUrl = `${origin}/${path}?expires=${expires}&sig=${sig}`;
  return c.json({ url: signedUrl, expires });
});

app.get("/list", listRoute);
app.get("/play", playRoute);
app.post("/upload", uploadRoute);
app.get("/search", searchRoute);
app.post("/import", importRoute);

app.get("/search/wy", searchWy);
app.get("/search/qq", searchQq);
app.get("/search/mg", searchMg);
app.get("/search/kg", searchKg);
app.get("/search/kw", searchKw);

app.post("/import/wy", importWy);
app.post("/import/qq", importQq);
app.post("/import/mg", importMg);
app.post("/import/kg", importKg);
app.post("/import/kw", importKw);

app.put("/song", updateSongRoute);
app.post("/lyric/upload", lyricUploadRoute);
app.get("/lyric", lyricGetRoute);
app.delete("/song", deleteSongRoute);

app.get("*", async (c) => {
  const env: Env = c.env;
  const path = c.req.path;
  if (!path || path === "/") {
    return c.text("Not Found", 404);
  }

  const key = decodeURIComponent(path.slice(1));
  const expires = c.req.query("expires");
  const sig = c.req.query("sig");

  if (!expires || !sig) {
    return c.text("Forbidden: missing signature", 403);
  }
  if (Math.floor(Date.now() / 1000) > Number(expires)) {
    return c.text("Forbidden: link expired", 403);
  }
  const expectedSig = await sign(key, Number(expires), env.SIGN_SECRET);
  if (sig !== expectedSig) {
    return c.text("Forbidden: invalid signature", 403);
  }

  const range = c.req.header("range");
  let object: R2ObjectBody | null;

  if (range) {
    const match = /bytes=(\d+)-(\d*)/.exec(range);
    const offset = Number(match![1]);
    const end = match![2] ? Number(match![2]) : undefined;
    const length = end !== undefined ? end - offset + 1 : undefined;
    object = await env.MUSIC_BUCKET.get(key, { range: { offset, length } });
  } else {
    object = await env.MUSIC_BUCKET.get(key);
  }

  if (!object) return c.text("Not Found", 404);

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("Accept-Ranges", "bytes");
  headers.set("Cache-Control", "private, max-age=3600");

  if (range && object.range) {
    const start = (object.range as any).offset;
    const len = (object.range as any).length;
    headers.set("Content-Range", "bytes " + (start) + "-" + (start + len - 1) + "/" + object.size);
    headers.set("Content-Length", String(len));
    return new Response(object.body, { status: 206, headers });
  }

  return new Response(object.body, { status: 200, headers });
});

export default app;

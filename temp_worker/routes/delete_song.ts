import { Context } from "hono";
import { verifyRequest } from "../services/auth";
import { Env } from "../index";

type DeleteContext = Context<{ Bindings: Env }>;

export async function deleteSongRoute(c: DeleteContext): Promise<Response> {
  const verified = await verifyRequest(c.req.raw, c.env.SIGN_SECRET);
  if (!verified) {
    return c.text("Unauthorized", 401);
  }

  const idStr = c.req.query("id");
  if (!idStr) {
    return c.json({ error: "Missing id" }, 400);
  }

  const id = parseInt(idStr, 10);
  if (isNaN(id)) {
    return c.json({ error: "Invalid id" }, 400);
  }

  const song = await c.env.DB
    .prepare("SELECT path, cover_path, lyric_path FROM songs WHERE id = ?")
    .bind(id)
    .first<{ path: string; cover_path: string | null; lyric_path: string | null }>();

  if (!song) {
    return c.json({ error: "Song not found" }, 404);
  }

  await c.env.DB.prepare("DELETE FROM songs WHERE id = ?").bind(id).run();

  await Promise.allSettled([
    c.env.MUSIC_BUCKET.delete(song.path),
    song.cover_path ? c.env.MUSIC_BUCKET.delete(song.cover_path) : Promise.resolve(),
    song.lyric_path ? c.env.MUSIC_BUCKET.delete(song.lyric_path) : Promise.resolve(),
  ]);

  return c.json({ success: true }, 200);
}

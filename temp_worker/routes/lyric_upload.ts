import { Context } from "hono";
import { verifyRequest } from "../services/auth";
import { Env } from "../index";

type LyricContext = Context<{ Bindings: Env }>;

export async function lyricUploadRoute(c: LyricContext): Promise<Response> {
  const verified = await verifyRequest(c.req.raw, c.env.SIGN_SECRET);
  if (!verified) {
    return c.text("Unauthorized", 401);
  }

  const body = await c.req.json<{ song_id: number; lyric: string }>();
  if (!body.song_id || body.lyric === undefined) {
    return c.json({ error: "Missing song_id or lyric" }, 400);
  }

  const result = await c.env.DB
    .prepare("UPDATE songs SET lyric = ? WHERE id = ?")
    .bind(body.lyric, body.song_id)
    .run();

  if (result.meta.changes === 0) {
    return c.json({ error: "Song not found" }, 404);
  }

  return c.json({ success: true }, 200);
}

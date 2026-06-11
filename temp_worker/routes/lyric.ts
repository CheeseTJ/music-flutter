import { Context } from "hono";
import { Env } from "../index";

type LyricContext = Context<{ Bindings: Env }>;

export async function lyricGetRoute(c: LyricContext): Promise<Response> {
  const idStr = c.req.query("id");
  if (!idStr) {
    return c.json({ error: "Missing id" }, 400);
  }

  const id = parseInt(idStr, 10);
  if (isNaN(id)) {
    return c.json({ error: "Invalid id" }, 400);
  }

  const result = await c.env.DB
    .prepare("SELECT lyric FROM songs WHERE id = ?")
    .bind(id)
    .first<{ lyric: string | null }>();

  if (!result) {
    return c.json({ error: "Song not found" }, 404);
  }

  return c.json({ lyric: result.lyric ?? "" }, 200);
}

import { Context } from "hono";
import { verifyRequest } from "../services/auth";
import { Env } from "../index";

type UpdateContext = Context<{ Bindings: Env }>;

export async function updateSongRoute(c: UpdateContext): Promise<Response> {
  const verified = await verifyRequest(c.req.raw, c.env.SIGN_SECRET);
  if (!verified) {
    return c.json({ detail: "unauthorized" }, 401);
  }

  const body = await c.req.json<{
    id: number;
    title?: string;
    artist?: string;
    album?: string;
  }>();

  if (!body.id) {
    return c.json({ detail: "Missing id" }, 400);
  }

  const sets: string[] = [];
  const values: (string | number)[] = [];

  if (body.title !== undefined) {
    sets.push("title = ?");
    values.push(body.title);
  }
  if (body.artist !== undefined) {
    sets.push("artist = ?");
    values.push(body.artist);
  }
  if (body.album !== undefined) {
    sets.push("album = ?");
    values.push(body.album);
  }

  if (sets.length === 0) {
    return c.json({ detail: "No fields to update" }, 400);
  }

  values.push(body.id);

  const result = await c.env.DB
    .prepare(`UPDATE songs SET ${sets.join(", ")} WHERE id = ?`)
    .bind(...values)
    .run();

  if (result.meta.changes === 0) {
    return c.json({ detail: "Song not found" }, 404);
  }

  return c.json({ message: "ok" }, 200);
}

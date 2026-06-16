import { Hono } from "hono";
import { Context } from "hono";
import { Env } from "../index";

type SearchContext = Context<{ Bindings: Env }>;

export async function searchRoute(c: SearchContext): Promise<Response> {
  const name = c.req.query("name");
  const type = c.req.query("type") || "wy";

  if (!name) return c.json({ error: "Missing name" }, 400);

  const url = `https://jkyapi.top/API/hqyyid.php?name=${encodeURIComponent(name)}&type=${type}&page=1&limit=10`;

  try {
    const res = await fetch(url);
    const json = await res.json<{ code: number; data?: { type: string; id: number; name: string; album: string; artist: string; pic_id: string }[] }>();

    if (json.code !== 1 || !json.data) {
      return c.json({ results: [] }, 200);
    }

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
}

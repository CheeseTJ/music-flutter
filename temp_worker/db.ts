export interface Song {
  id: number;
  title: string;
  artist: string;
  album: string;
  path: string;
  format: string;
  size: number;
  duration: number;
  cover_path: string | null;
  lyric_path: string | null;
  lyric: string | null;
  created_at: number;
}

export interface SongInput {
  title: string;
  artist: string;
  album: string;
  path: string;
  format: string;
  size: number;
  duration: number;
  cover_path?: string | null;
  lyric_path?: string | null;
}

export interface SongListResponse {
  songs: Song[];
}

export async function getAllSongs(db: D1Database): Promise<Song[]> {
  const result = await db
    .prepare('SELECT * FROM songs ORDER BY created_at DESC')
    .all<Song>();
  return result.results;
}

export async function getSongById(
  db: D1Database,
  id: number
): Promise<Song | null> {
  const result = await db
    .prepare('SELECT * FROM songs WHERE id = ?')
    .bind(id)
    .first<Song>();
  return result ?? null;
}

export async function insertSong(
  db: D1Database,
  song: SongInput
): Promise<{ id: number }> {
  const result = await db
    .prepare(
      `INSERT INTO songs (title, artist, album, path, format, size, duration, cover_path, lyric_path)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      song.title,
      song.artist,
      song.album,
      song.path,
      song.format,
      song.size,
      song.duration,
      song.cover_path ?? null,
      song.lyric_path ?? null
    )
    .run();
  return { id: result.meta.last_row_id as number };
}

export async function getMaxId(db: D1Database): Promise<number> {
  const result = await db
    .prepare('SELECT MAX(id) as maxId FROM songs')
    .first<{ maxId: number | null }>();
  return result?.maxId ?? 0;
}

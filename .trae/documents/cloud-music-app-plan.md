# 个人云音乐 App 实施计划 (核心版)

---

## 0. 决策汇总

| 决策项 | 结论 |
|--------|------|
| Worker 后端状态 | 已有项目骨架，R2 签名鉴权 + 音频流播放已实现 |
| 入库方式 | 上传接口自动解析 ID3 标签 → 存 R2 + 写 D1 |
| 签名过期时间 | 6 小时 |
| D1 表结构 | 沿用规范中的 11 字段 |

---

## 1. 项目概览

| 项目 | 说明 |
|------|------|
| 后端 | `CheeseTJ/music-worker` — Cloudflare Worker + D1 + R2 (已有) |
| 客户端 | `music-app` — Flutter (Android + iOS，待建) |
| 目标 | 个人云音乐：上传歌曲 → 自动入库 → App 列表浏览 → 播放 |

---

## 2. 当前状态

### 2.1 music-worker (已有)

```
music-worker/              ← master 分支，2026-05-29
├── src/index.ts           ← 3732 字节，单文件全部逻辑
├── wrangler.jsonc         ← 已绑定 R2 "MUSIC_BUCKET"
├── package.json           ← wrangler + vitest + TypeScript
├── vitest.config.mts
├── tsconfig.json
└── test/
```

**已实现：**

| 功能 | 说明 |
|------|------|
| `GET /` | 状态检查 |
| `GET /sign?path=...&key=APP_KEY` | 签发签名 URL（HMAC-SHA256，1h 过期） |
| `GET /{path}?expires=...&sig=...` | 验证签名 → R2 取文件 → 支持 Range 流式播放 |
| `SIGN_SECRET` / `APP_KEY` | 环境变量已声明 |

**待补充：**

| 缺失项 | 说明 |
|--------|------|
| ❌ D1 数据库 | wrangler.jsonc 无 D1 绑定，未建表 |
| ❌ Hono 路由 | 当前是原生 fetch，无路由拆分 |
| ❌ `/list` | 查 D1 返回歌曲列表 |
| ❌ `/play` | 按 song id 查 D1 → 返回签名 URL |
| ❌ `/upload` | 上传 + ID3 解析 + 自动入库 |
| ❌ `music-metadata` | ID3 解析依赖未安装 |

### 2.2 music-app (不存在)

- Flutter 项目尚未创建
- 需新建 GitHub 私有仓库

---

## 3. 技术选型

### 3.1 后端

| 领域 | 方案 | 备注 |
|------|------|------|
| 运行时 | Cloudflare Workers | 已就绪 |
| 数据库 | Cloudflare D1 | 需创建 |
| 对象存储 | Cloudflare R2 | 已绑定 `MUSIC_BUCKET` |
| 路由 | Hono | 当前无，需引入 |
| 鉴权 | HMAC-SHA256 | 已有 sign() 函数，过期时间改 6h |
| ID3 解析 | music-metadata | 需安装 |

### 3.2 客户端

| 领域 | 方案 |
|------|------|
| 状态管理 | Riverpod |
| 路由 | go_router |
| 音频播放 | just_audio + LockCachingAudioSource |
| 网络请求 | dio |
| 本地缓存 | hive |
| UI | Material Design 3 |

---

## 4. 核心功能范围

```
┌─────────────────────────────────────────────────┐
│  MVP 核心（本期实现）                              │
│                                                   │
│  上传歌曲 ──► 自动入库 ──► 列表浏览 ──► 播放      │
│                                      │            │
│                           本地缓存(听过不再下载)   │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  后续迭代（暂不做）                                │
│  ❌ 搜索    ❌ 收藏    ❌ 播放列表    ❌ 播放历史    │
│  ❌ 后台播放 ❌ 通知栏  ❌ UI 美化    ❌ 歌词显示    │
└─────────────────────────────────────────────────┘
```

---

## 5. 后端接口设计

### 5.1 鉴权机制（已有，仅过期时间改 6h）

- 已有 `sign(path, expires, secret)` 函数，返回 hex 签名
- 已有 `GET /sign` 签发签名 URL
- 已有 `GET /{path}` 验证签名 + R2 Range 流式播放
- **改动**: `/sign` 过期时间从 3600s → 21600s (6h)

### 5.2 新增端点

| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| `GET` | `/list` | 无 | 查 D1，返回歌曲列表 |
| `GET` | `/play?id=1` | 需要 | 查 D1 song → 生成 R2 签名 URL |
| `POST` | `/upload` | 需要 | 接收文件 → 存 R2 + 解析 ID3 → 写 D1 |

### 5.3 数据流

```
┌─ 上传 ──────────────────────────────────────────┐
│  POST /upload (multipart mp3/flac)               │
│    → Worker 解析 ID3 标签 (歌名/歌手/专辑/时长)   │
│    → 音频存 R2: audio/{id}/song.{format}          │
│    → 写 D1: INSERT INTO songs (...)               │
│    ← { ok: true, song: {...} }                   │
└─────────────────────────────────────────────────┘

┌─ 列表 ──────────────────────────────────────────┐
│  GET /list                                       │
│    → D1: SELECT * FROM songs ORDER BY created_at │
│    ← { songs: [{id,title,artist,...}] }          │
└─────────────────────────────────────────────────┘

┌─ 播放 ───────────────────────────────────────────┐
│  GET /play?id=1                                   │
│    → D1 查 song.path                              │
│    → 生成 R2 签名 URL (6h 有效)                    │
│    ← { url: "签名URL" }                           │
│                                                    │
│  客户端拿到 URL → just_audio 直接播放 + 缓存        │
└────────────────────────────────────────────────────┘
```

---

## 6. 后端实施步骤（Detail Tasks + 验证）

> **原则：每完成一个 Task 立即验证，通过后才能进入下一个 Task。**

---

### ═══════════════════════════════════════════
### Step 1: 创建 D1 数据库 + songs 表
### ═══════════════════════════════════════════

#### Task 1.1 — 创建 D1 数据库

**操作：**
- 在当前 music-worker 目录执行 `wrangler d1 create music-db`
- 记录控制台输出的 database_id

**验证：**
- [ ] 命令执行成功，输出了 database_id
- [ ] `wrangler d1 list` 能看到 `music-db`

---

#### Task 1.2 — 在 wrangler.jsonc 添加 D1 绑定

**操作：**
- 在 `wrangler.jsonc` 的顶层增加 `d1_databases` 配置，将 Task 1.1 的 database_id 填入：

```jsonc
"d1_databases": [
  {
    "binding": "DB",
    "database_name": "music-db",
    "database_id": "<Task1.1输出的 database_id>"
  }
]
```

- 同时更新 `worker-configuration.d.ts` 中的 `Env` 接口（或重新生成类型）：
```typescript
export interface Env {
  MUSIC_BUCKET: R2Bucket;
  DB: D1Database;           // 新增
  SIGN_SECRET: string;
  APP_KEY: string;
}
```

**验证：**
- [ ] `wrangler.jsonc` 格式有效（JSON 解析不报错）
- [ ] `wrangler dev` 能正常启动（出现 `Ready on http://localhost:8787`）

---

#### Task 1.3 — 创建 schema.sql 并建表

**操作：**
- 新建 `music-worker/schema.sql`：

```sql
CREATE TABLE IF NOT EXISTS songs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT NOT NULL,
  artist      TEXT NOT NULL DEFAULT '',
  album       TEXT NOT NULL DEFAULT '',
  path        TEXT NOT NULL,
  format      TEXT NOT NULL DEFAULT 'mp3',
  size        INTEGER NOT NULL DEFAULT 0,
  duration    INTEGER NOT NULL DEFAULT 0,
  cover_path  TEXT,
  lyric_path  TEXT,
  created_at  INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_songs_title  ON songs(title);
CREATE INDEX IF NOT EXISTS idx_songs_artist ON songs(artist);
CREATE INDEX IF NOT EXISTS idx_songs_album  ON songs(album);
```

- 执行建表：
  ```bash
  wrangler d1 execute music-db --file=./schema.sql --remote
  ```
  如果是本地开发，用 `--local`。

**验证：**
- [ ] `wrangler d1 execute music-db --command="PRAGMA table_info(songs)" --remote` 能看到 11 列
- [ ] `wrangler d1 execute music-db --command="SELECT name FROM sqlite_master WHERE type='index'" --remote` 能看到 3 个索引
- [ ] `wrangler d1 execute music-db --command="INSERT INTO songs (title, artist, path, format) VALUES ('Test', 'Tester', 'audio/1/test.mp3', 'mp3')" --remote` 执行成功
- [ ] `wrangler d1 execute music-db --command="SELECT * FROM songs" --remote` 能查到刚插入的数据
- [ ] `wrangler d1 execute music-db --command="DELETE FROM songs WHERE title='Test'" --remote` 清理测试数据

---

### ═══════════════════════════════════════════
### Step 2: 引入 Hono 路由，拆分代码结构
### ═══════════════════════════════════════════

#### Task 2.1 — 安装 Hono

**操作：**
- `npm install hono`
- 验证 `package.json` 中 hono 已加入 dependencies

**验证：**
- [ ] `npm list hono` 显示版本号

---

#### Task 2.2 — 抽取 auth.ts (签名服务)

**操作：**
- 新建 `music-worker/src/services/auth.ts`
- 从 `index.ts` 中提取 `sign()` 函数到 `auth.ts`，并导出
- 新增 `verifyRequest()` 函数：从请求头提取 `x-timestamp` + `x-signature`，重新计算签名并比对
- 将过期时间改为 6 小时 (21600s)
- 对外暴露：
  - `sign(path: string, expires: number, secret: string): Promise<string>`
  - `verifyRequest(request: Request, secret: string): boolean`

**验证：**
- [ ] TypeScript 编译无错误：`npx tsc --noEmit`
- [ ] 单元测试通过（如已有 test/ 目录）

---

#### Task 2.3 — 抽取 r2.ts (R2 存储服务)

**操作：**
- 新建 `music-worker/src/services/r2.ts`
- 封装方法：
  - `uploadFile(bucket: R2Bucket, key: string, body: ArrayBuffer | ReadableStream, contentType: string): Promise<void>`
  - `getFile(bucket: R2Bucket, key: string): Promise<R2ObjectBody | null>`
  - `getFileWithRange(bucket: R2Bucket, key: string, range: string): Promise<{ object: R2ObjectBody, range: { offset: number, length: number } } | null>`

**验证：**
- [ ] TypeScript 编译无错误

---

#### Task 2.4 — 创建 db.ts (D1 数据服务)

**操作：**
- 新建 `music-worker/src/services/db.ts`
- 实现以下方法：
  - `getAllSongs(db: D1Database): Promise<Song[]>`
  - `getSongById(db: D1Database, id: number): Promise<Song | null>`
  - `insertSong(db: D1Database, song: Omit<Song, 'id'>): Promise<{ id: number }>`

- 定义 Song 类型（在共享 types 文件或 db.ts 中）：

```typescript
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
  created_at: number;
}
```

**验证：**
- [ ] TypeScript 编译无错误

---

#### Task 2.5 — 重构 index.ts 为 Hono 路由入口

**操作：**
- 重写 `src/index.ts`：用 Hono 创建 app，挂载路由分组
- 保留原有的 `/` 状态检查、`/sign` 签名签发、`/{path}` 文件代理逻辑
- 结构：

```typescript
import { Hono } from 'hono';
import { sign } from './services/auth';

const app = new Hono<{ Bindings: Env }>();

// 状态检查
app.get('/', (c) => c.text('Music Worker is running!'));

// 签发签名 URL (保留原有逻辑，过期改 6h)
app.get('/sign', async (c) => { /* ... */ });

// R2 文件代理 (保留原有逻辑)
app.get('/:path', async (c) => { /* ... */ });

export default app;
```

**验证：**
- [ ] `npx tsc --noEmit` 编译无错误
- [ ] `wrangler dev` 启动成功
- [ ] `curl http://localhost:8787/` → 返回 `Music Worker is running!`
- [ ] `curl "http://localhost:8787/sign?path=audio/test.mp3&key=test-key"` → 返回 JSON `{url, expires}`（需 APP_KEY 正确）
- [ ] 原有功能完全保留，未破坏

---

### ═══════════════════════════════════════════
### Step 3: 实现 /upload 端点（上传 + ID3 解析 + 入库）
### ═══════════════════════════════════════════

#### Task 3.1 — 安装 music-metadata

**操作：**
- `npm install music-metadata`

**验证：**
- [ ] `npm list music-metadata` 显示版本号

---

#### Task 3.2 — 实现 id3.ts (ID3 标签解析)

**操作：**
- 新建 `music-worker/src/utils/id3.ts`
- 实现 `parseAudioMetadata(buffer: ArrayBuffer, filename?: string)` 函数：
  - 使用 `music-metadata` 解析 buffer，提取：`title`, `artist`, `album`, `duration` (秒), `format`
  - 如果 ID3 标签缺失 title → 从 filename 解析："歌手 - 歌名.mp3"
  - 返回类型：`{ title: string, artist: string, album: string, duration: number, format: string }`
- 额外实现 filename 兜底解析：支持 `歌手 - 歌名.mp3` 和 `歌名.mp3` 两种格式

**验证：**
- [ ] 用本地 mp3 文件写单元测试：`describe('parseAudioMetadata', () => { ... })`
- [ ] 测试用例覆盖：完整 ID3 / 缺失 title / 缺失 artist / 缺失 album
- [ ] 文件名兜底解析测试：`"周杰伦 - 晴天.mp3"` → `{title:"晴天", artist:"周杰伦"}`
- [ ] `npx vitest run` 全部通过

---

#### Task 3.3 — 创建 upload.ts 路由

**操作：**
- 新建 `music-worker/src/routes/upload.ts`
- 实现 `POST /upload`：
  1. 鉴权：调用 `auth.verifyRequest()` 验证签名
  2. 接收 multipart/form-data 中的文件
  3. 读取文件为 ArrayBuffer
  4. 调用 `id3.parseAudioMetadata()` 解析标签
  5. 取 D1 中当前最大 id，+1 作为新 song id
  6. 根据格式确定文件扩展名，生成 R2 key：`audio/{id}/song.{format}`
  7. 调用 `r2.uploadFile()` 存到 R2
  8. 调用 `db.insertSong()` 写 D1
  9. 返回 `{ ok: true, song: { id, title, artist, ... } }`

**在 index.ts 中注册：**
```typescript
import { uploadRoute } from './routes/upload';
app.post('/upload', uploadRoute);
```

**验证：**
- [ ] `wrangler dev` 启动成功
- [ ] 准备一个测试 mp3 文件，用 curl 上传：

```bash
# 生成签名（时间戳 + HMAC）
TIMESTAMP=$(date +%s)
SIGNATURE=$(echo -n "${TIMESTAMP}POST/upload" | openssl dgst -sha256 -hmac "your-sign-secret" | awk '{print $2}')

curl -X POST http://localhost:8787/upload \
  -H "x-timestamp: $TIMESTAMP" \
  -H "x-signature: $SIGNATURE" \
  -F "file=@test.mp3"
```

- [ ] 返回 `{ ok: true, song: { id: 1, title, artist, ... } }`
- [ ] `wrangler d1 execute music-db --command="SELECT * FROM songs" --local` 能看到新记录
- [ ] R2 中 `audio/1/song.mp3` 文件存在（通过 `/play?id=1` 间接验证）

---

### ═══════════════════════════════════════════
### Step 4: 实现 /list + /play 端点
### ═══════════════════════════════════════════

#### Task 4.1 — 创建 list.ts 路由

**操作：**
- 新建 `music-worker/src/routes/list.ts`
- `GET /list` — 无需鉴权
- 调用 `db.getAllSongs()`，返回 JSON：

```json
{
  "songs": [
    { "id": 1, "title": "晴天", "artist": "周杰伦", "album": "叶惠美", "format": "mp3", "duration": 269, "size": 8123456 }
  ]
}
```

**验证：**
- [ ] `wrangler dev` 启动成功
- [ ] `curl http://localhost:8787/list` → 返回 JSON 数组（如果没有数据则为空数组）
- [ ] 上传一首歌后，`/list` 能立即看到
- [ ] 返回的字段名称和类型与预期一致

---

#### Task 4.2 — 创建 play.ts 路由

**操作：**
- 新建 `music-worker/src/routes/play.ts`
- `GET /play?id=1` — 需要鉴权
- 流程：
  1. 调用 `auth.verifyRequest()` 验证签名
  2. 从 query 取 id → 调用 `db.getSongById(id)` 获取 song
  3. song 不存在 → 返回 404
  4. 调用 `auth.sign(song.path, expires, SIGN_SECRET)` 生成签名 URL
  5. 返回 JSON：`{ url: "https://.../audio/1/song.mp3?expires=...&sig=..." }`

**验证：**
- [ ] `wrangler dev` 启动成功
- [ ] 带正确签名请求 `/play?id=1` → 返回 `{ url: "..." }`
- [ ] 无签名请求 `/play?id=1` → 返回 401 Unauthorized
- [ ] 错误签名请求 `/play?id=1` → 返回 403 Forbidden
- [ ] 请求不存在的 id → 返回 404
- [ ] 在浏览器中打开返回的 url → 音频可播放
- [ ] 返回的 url 中 `expires` 是 6 小时后的时间戳

---

#### Task 4.3 — 整合路由到 index.ts

**操作：**
- 在 `index.ts` 中注册所有路由：

```typescript
import { Hono } from 'hono';
import { listRoute } from './routes/list';
import { playRoute } from './routes/play';
import { uploadRoute } from './routes/upload';
import { sign } from './services/auth';

const app = new Hono<{ Bindings: Env }>();

app.get('/', (c) => c.text('Music Worker is running!'));

// 原有 /sign 和文件代理
app.get('/sign', async (c) => { /* ... */ });
app.get('/:path', async (c) => { /* ... */ });

// 新增路由
app.get('/list', listRoute);
app.get('/play', playRoute);
app.post('/upload', uploadRoute);

export default app;
```

**验证：**
- [ ] `npx tsc --noEmit` 编译无错误
- [ ] `wrangler dev` 启动成功，无路由冲突
- [ ] 所有端点正常工作

---

### ═══════════════════════════════════════════
### Step 5: 部署 + 全链路验证
### ═══════════════════════════════════════════

#### Task 5.1 — 配置线上密钥

**操作：**
```bash
wrangler secret put SIGN_SECRET
wrangler secret put APP_KEY
```

**验证：**
- [ ] `wrangler secret list` 能看到 SIGN_SECRET 和 APP_KEY

---

#### Task 5.2 — 部署到 Cloudflare

**操作：**
```bash
wrangler deploy
```

**验证：**
- [ ] 部署成功，输出 Worker URL（如 `https://music-worker.cheesetj.workers.dev`）
- [ ] `curl https://music-worker.xxx.workers.dev/` → `Music Worker is running!`

---

#### Task 5.3 — 全链路端到端验证（必须全部通过）

**验证清单：**

**1. 健康检查**
- [ ] `curl {WORKER_URL}/` → 200 `Music Worker is running!`

**2. 上传歌曲**
- [ ] 准备一个真实的 mp3 文件（有完整 ID3 标签）
- [ ] 生成签名后 POST 上传 → 返回 `{ ok: true, song: { id: 1, title: "xxx", artist: "xxx" } }`
- [ ] 再上传一个 flac 文件 → 同样成功

**3. 列表查询**
- [ ] `curl {WORKER_URL}/list` → 返回 `{ songs: [...] }`，包含刚上传的歌曲
- [ ] 返回字段完整：id, title, artist, album, format, duration, size, created_at

**4. 播放链接**
- [ ] 生成签名后请求 `{WORKER_URL}/play?id=1` → 返回 `{ url: "..." }`
- [ ] 在浏览器中打开该 url → 音频能正常播放，支持拖动进度条（Range 请求）

**5. 鉴权验证**
- [ ] 无签名请求 `/play?id=1` → 401
- [ ] 错误签名请求 `/play?id=1` → 403
- [ ] 无签名请求 `/upload` → 401
- [ ] `/list` 无需鉴权 → 直接返回 200

**6. 错误处理**
- [ ] 请求不存在的 id `/play?id=999` → 404
- [ ] 上传空请求体 `/upload` → 400

**7. 成本验证**
- [ ] 确认 `/list` 查的是 D1（不是 LIST R2）
- [ ] 确认签名 URL 过期时间是 6 小时
- [ ] 确认 `/list` 不触发 R2 Class A 操作

---

## 7. 客户端实施步骤

### Step 6 — 创建 Flutter 项目 `music-app`

- `flutter create music_app`
- 配置 `pubspec.yaml`：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  just_audio: ^0.9.38
  dio: ^5.4.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  json_annotation: ^4.8.0
  crypto: ^3.0.3
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
```

### Step 7 — 搭建 Flutter 基础架构

```
lib/
├── main.dart                       # 入口 + ProviderScope
├── app.dart                        # MaterialApp.router
├── core/
│   ├── theme/app_theme.dart        # 深色主题
│   ├── router/app_router.dart      # / → Home, /player → Player
│   ├── constants/app_constants.dart # API 地址
│   └── utils/signer.dart           # HMAC-SHA256 签名
├── data/
│   ├── models/song.dart            # Song 数据模型
│   ├── datasources/
│   │   ├── remote/api_client.dart  # Dio + 签名拦截器
│   │   └── local/cache_datasource.dart # Hive 缓存
│   └── repositories/music_repository.dart
├── features/
│   ├── home/
│   │   ├── providers/song_list_provider.dart
│   │   └── presentation/home_page.dart  # 歌曲列表
│   └── player/
│       ├── providers/player_provider.dart
│       └── presentation/player_page.dart # 播放页
└── shared/widgets/song_tile.dart
```

### Step 8 — 实现歌曲列表页

- `HomePage`：AppBar "我的音乐" + `ListView` 展示歌曲
- 每项显示：歌名 + 歌手 + 格式标签 + 时长
- 点击 → 导航到播放页

### Step 9 — 实现播放页 + 本地缓存

- 使用 `LockCachingAudioSource`，just_audio 自动缓存已播放音频
- 播放页：封面图 + 歌名 + 歌手 + 进度条 + 播放/暂停 + 上一首/下一首
- 从 `/play?id=1` 获取签名 URL → AudioPlayer 播放

### Step 10 — 列表本地缓存

- Hive 缓存歌曲列表，有效期 30 分钟
- 启动时先展示缓存，异步刷新

### Step 11 — 创建 GitHub 仓库并推送

- 在 CheeseTJ 下创建 `music-app` 私有仓库
- 推送代码

---

## 8. 实施顺序

```
后端 (Step 1-5，含详细 Task)      客户端 (Step 6-11)
─────────────────────────────     ─────────────────
Task 1.1 创建 D1 数据库           Step 6  创建 Flutter 项目
Task 1.2 添加 D1 绑定             Step 7  搭建基础架构
Task 1.3 建表 + 验证              Step 8  歌曲列表页
  ↓                                Step 9  播放页 + 缓存
Task 2.1 安装 Hono                Step 10 列表缓存
Task 2.2 抽取 auth.ts             Step 11 推送 GitHub
Task 2.3 抽取 r2.ts
Task 2.4 创建 db.ts
Task 2.5 重构 index.ts (Hono)
  ↓
Task 3.1 安装 music-metadata
Task 3.2 实现 id3.ts + 单元测试
Task 3.3 实现 upload.ts + 验证
  ↓
Task 4.1 实现 list.ts + 验证
Task 4.2 实现 play.ts + 验证
Task 4.3 整合路由 + 验证
  ↓
Task 5.1 配置线上密钥
Task 5.2 部署
Task 5.3 全链路端到端验证 ──────► 接口就绪，客户端可对接
```

**关键依赖：** Step 5 必须全部验证通过后，才能进入客户端开发（Step 6-11）。

---

## 9. 总体验证标准

### 后端 (完成后逐项打勾)
- [ ] `npx tsc --noEmit` 编译零错误
- [ ] `npx vitest run` 全部通过
- [ ] `wrangler dev` 本地启动成功
- [ ] `/list` 返回正确 JSON
- [ ] `/play?id=1` 返回有效签名 URL（6h 过期）
- [ ] `/upload` 上传 mp3/flac 自动入库
- [ ] 鉴权：无签名 → 401，错签名 → 403
- [ ] 音频 URL 浏览器可播放
- [ ] `wrangler deploy` 部署成功

### 客户端
- [ ] `flutter analyze` — 无 error
- [ ] `flutter run` — 真机验证：
  1. 启动 App → 显示歌曲列表
  2. 点击歌曲 → 播放 + 进度条走动
  3. 再次播放同一首歌 → 走本地缓存（不发起网络请求）
  4. 断网启动 → 显示缓存列表

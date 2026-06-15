# 資料庫設計與 Notion 整合方案

## Supabase 資料庫設計

### 1. 用戶表 (users)
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  apple_id TEXT,
  email TEXT UNIQUE,
  phone TEXT,
  nickname TEXT,
  avatar_url TEXT,
  coins INTEGER DEFAULT 0,
  user_level INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### 2. AI 任務表 (ai_tasks)
```sql
CREATE TABLE ai_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  task_type TEXT NOT NULL, -- 'TYPE_SELF_PORTRAIT', 'TYPE_FOUR_SQUARE_GRID'
  status TEXT DEFAULT 'RUNNING', -- 'RUNNING', 'SUCCESS', 'FAILED', 'SECURITY_FAILED'
  input_image_url TEXT,
  result_images TEXT[],
  created_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP
);
```

### 3. 任務記錄表 (task_records)
```sql
CREATE TABLE task_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  task_type TEXT NOT NULL, -- 'video', 'app'
  reward_coins INTEGER,
  completed_at TIMESTAMP DEFAULT NOW()
);
```

### 4. 視頻表 (videos)
```sql
CREATE TABLE videos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  cover_url TEXT,
  video_url TEXT,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### 5. 小說表 (novels)
```sql
CREATE TABLE novels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  author TEXT,
  cover_url TEXT,
  description TEXT,
  chapter_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### 6. 內購記錄表 (purchase_records)
```sql
CREATE TABLE purchase_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  product_id TEXT NOT NULL,
  amount DECIMAL(10, 2),
  status TEXT DEFAULT 'pending', -- 'pending', 'completed', 'failed'
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## Notion 整合方案

### 1. 用戶反饋表
使用 Notion API 管理用戶反饋：

```swift
struct Feedback {
    let title: String
    let category: String // 'bug', 'feature', 'general'
    let description: String
    let priority: String // 'low', 'medium', 'high'
    let status: String // 'open', 'in_progress', 'resolved'
}
```

### 2. 內容管理
使用 Notion 管理小說和視頻的元數據：

```swift
struct ContentItem {
    let title: String
    let description: String
    let coverUrl: String
    let contentUrl: String
    let tags: [String]
}
```

### 3. 團隊協作
使用 Notion 進行任務管理和進度追蹤。

---

## API 端點設計

### 用戶相關
- `POST /api/auth/apple` - Apple ID 登入
- `POST /api/auth/email` - Email 登入
- `GET /api/users/:id` - 獲取用戶資料
- `PUT /api/users/:id` - 更新用戶資料

### AI 任務
- `POST /api/ai/tasks` - 創建 AI 任務
- `GET /api/ai/tasks/:id` - 獲取任務狀態
- `GET /api/ai/tasks` - 獲取用戶的任務列表

### 任務記錄
- `POST /api/tasks/video` - 完成看視頻任務
- `POST /api/tasks/app` - 完成 App 活躍任務
- `GET /api/tasks/daily-limit` - 獲取每日任務上限

### 內容相關
- `GET /api/videos` - 獲取視頻列表
- `GET /api/videos/:id` - 獲取視頻詳情
- `GET /api/novels` - 獲取小說列表
- `GET /api/novels/:id` - 獲取小說詳情

### 內購相關
- `POST /api/purchases/verify` - 驗證內購收據
- `GET /api/purchases/:userId` - 獲取用戶購買記錄

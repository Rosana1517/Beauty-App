-- 美麗日記正式資源資料 schema（v1）
-- 目標：支援小紅書 / YouTube / Instagram / 網頁匯入後的標準化存儲

create extension if not exists "pgcrypto";

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  apple_user_id text unique,
  email text unique,
  nickname text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.resource_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.app_users(id) on delete cascade,
  source_type text not null check (source_type in ('xiaohongshu', 'youtube', 'instagram', 'web')),
  content_type text not null check (content_type in ('video', 'imagePost', 'carousel', 'article', 'unknown')),
  category text not null check (category in ('skincare', 'fitness', 'food', 'outfit', 'learning', 'other')),
  title text not null,
  description_text text,
  author_name text,
  original_url text not null,
  canonical_url text,
  external_id text,
  thumbnail_url text,
  published_at timestamptz,
  tags text[] not null default '{}',
  import_status text not null check (import_status in ('parsed', 'partial', 'manualCompleted', 'failedFallbackSaved')),
  metadata_confidence numeric(4,3) not null default 0,
  media_retention_policy text not null default 'metadataOnly' check (media_retention_policy in ('metadataOnly', 'temporaryCache', 'explicitKeep')),
  raw_metadata_snapshot jsonb not null default '{}'::jsonb,
  source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_resource_items_user_id on public.resource_items(user_id);
create index if not exists idx_resource_items_source_type on public.resource_items(source_type);
create index if not exists idx_resource_items_external_id on public.resource_items(source_type, external_id);
create index if not exists idx_resource_items_category on public.resource_items(category);
create index if not exists idx_resource_items_created_at on public.resource_items(created_at desc);

create table if not exists public.resource_import_events (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid references public.resource_items(id) on delete cascade,
  user_id uuid references public.app_users(id) on delete cascade,
  source_type text not null,
  request_url text not null,
  resolved_url text,
  importer_version text not null default 'v1',
  status text not null check (status in ('parsed', 'partial', 'manualCompleted', 'failedFallbackSaved')),
  error_message text,
  parser_mode text not null check (parser_mode in ('youtubeDataAPI', 'publicHTML', 'manualFallback')),
  response_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_resource_import_events_resource_id on public.resource_import_events(resource_id);
create index if not exists idx_resource_import_events_created_at on public.resource_import_events(created_at desc);

create table if not exists public.resource_analysis_results (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid references public.resource_items(id) on delete cascade,
  provider text not null default 'rule-engine',
  status text not null check (status in ('pending', 'analyzing', 'analyzed', 'fallback')),
  summary text,
  insights jsonb not null default '[]'::jsonb,
  recommended_actions jsonb not null default '[]'::jsonb,
  confidence numeric(4,3) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_resource_analysis_results_resource_id on public.resource_analysis_results(resource_id);
create index if not exists idx_resource_analysis_results_created_at on public.resource_analysis_results(created_at desc);

create table if not exists public.resource_recommendations (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid references public.resource_items(id) on delete cascade,
  title text not null,
  detail text not null default '',
  category text not null check (category in ('skincare', 'fitness', 'food', 'outfit', 'learning', 'other')),
  reason text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists idx_resource_recommendations_resource_id on public.resource_recommendations(resource_id);

create table if not exists public.resource_media_assets (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid references public.resource_items(id) on delete cascade,
  asset_id text not null,
  asset_type text not null check (asset_type in ('image', 'video', 'cover', 'livePhoto', 'unknown')),
  remote_url text not null,
  preview_url text,
  width integer,
  height integer,
  duration numeric(8,3),
  display_index integer not null default 0,
  retention_policy text not null check (retention_policy in ('metadataOnly', 'temporaryCache', 'explicitKeep')),
  storage_path text,
  checksum text,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_resource_media_assets_resource_id on public.resource_media_assets(resource_id);
create index if not exists idx_resource_media_assets_asset_id on public.resource_media_assets(asset_id);

create table if not exists public.resource_source_payloads (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid references public.resource_items(id) on delete cascade,
  source_type text not null check (source_type in ('xiaohongshu', 'youtube', 'instagram', 'web')),
  payload_type text not null default 'xhsParsedPayload',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_resource_source_payloads_resource_id on public.resource_source_payloads(resource_id);

create table if not exists public.temporary_media_leases (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid references public.resource_items(id) on delete cascade,
  asset_id text not null,
  storage_path text not null,
  retention_policy text not null check (retention_policy in ('metadataOnly', 'temporaryCache', 'explicitKeep')),
  expires_at timestamptz not null,
  cleaned_at timestamptz,
  cleanup_status text not null check (cleanup_status in ('pending', 'syncing', 'succeeded', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_temporary_media_leases_resource_id on public.temporary_media_leases(resource_id);
create index if not exists idx_temporary_media_leases_expires_at on public.temporary_media_leases(expires_at);

create table if not exists public.resource_sync_queue (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid references public.resource_items(id) on delete cascade,
  job_type text not null default 'import' check (job_type in ('import', 'reparse', 'recommendation', 'media_cleanup')),
  sync_target text not null default 'supabase',
  sync_status text not null check (sync_status in ('pending', 'syncing', 'succeeded', 'failed')),
  retry_count integer not null default 0,
  request_payload jsonb not null default '{}'::jsonb,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_app_users_updated_at on public.app_users;
create trigger trg_app_users_updated_at
before update on public.app_users
for each row execute function public.set_updated_at();

drop trigger if exists trg_resource_items_updated_at on public.resource_items;
create trigger trg_resource_items_updated_at
before update on public.resource_items
for each row execute function public.set_updated_at();

drop trigger if exists trg_resource_analysis_results_updated_at on public.resource_analysis_results;
create trigger trg_resource_analysis_results_updated_at
before update on public.resource_analysis_results
for each row execute function public.set_updated_at();

drop trigger if exists trg_resource_source_payloads_updated_at on public.resource_source_payloads;
create trigger trg_resource_source_payloads_updated_at
before update on public.resource_source_payloads
for each row execute function public.set_updated_at();

drop trigger if exists trg_temporary_media_leases_updated_at on public.temporary_media_leases;
create trigger trg_temporary_media_leases_updated_at
before update on public.temporary_media_leases
for each row execute function public.set_updated_at();

drop trigger if exists trg_resource_sync_queue_updated_at on public.resource_sync_queue;
create trigger trg_resource_sync_queue_updated_at
before update on public.resource_sync_queue
for each row execute function public.set_updated_at();

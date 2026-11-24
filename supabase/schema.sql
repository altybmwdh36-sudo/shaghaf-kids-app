-- Shaghaf central administration schema (Supabase / PostgreSQL)
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('admin','moderator','member')),
  created_at timestamptz not null default now()
);

create table if not exists public.subscribers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  display_name text not null,
  phone text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);

alter table public.subscribers add column if not exists phone text;
create unique index if not exists subscribers_phone_unique on public.subscribers(phone) where phone is not null;

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  category text not null,
  language text not null default 'العربية',
  video_url text not null,
  status text not null default 'pending' check (status in ('draft','pending','published','blocked')),
  allow_comments boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  author_id uuid references auth.users(id) on delete set null,
  body text not null check (char_length(body) between 1 and 1000),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.video_views (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  viewer_id uuid references auth.users(id) on delete set null,
  viewed_at timestamptz not null default now()
);

create table if not exists public.video_likes (
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(video_id,user_id)
);

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  video_id uuid references public.videos(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  reporter_id uuid references auth.users(id) on delete set null,
  reason text not null,
  status text not null default 'open' check (status in ('open','reviewed','closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  target_type text,
  target_id text,
  created_at timestamptz not null default now()
);

create or replace function public.is_shaghaf_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;

alter table public.profiles enable row level security;
alter table public.subscribers enable row level security;
alter table public.videos enable row level security;
alter table public.comments enable row level security;
alter table public.video_views enable row level security;
alter table public.video_likes enable row level security;
alter table public.content_reports enable row level security;
alter table public.app_settings enable row level security;
alter table public.admin_audit_log enable row level security;

create policy "profile self or admin read" on public.profiles for select to authenticated
using (id = auth.uid() or public.is_shaghaf_admin());
create policy "admin manages profiles" on public.profiles for all to authenticated
using (public.is_shaghaf_admin()) with check (public.is_shaghaf_admin());

create policy "admin reads subscriber totals and records" on public.subscribers for select to authenticated
using (public.is_shaghaf_admin());
create policy "admin manages subscribers" on public.subscribers for all to authenticated
using (public.is_shaghaf_admin()) with check (public.is_shaghaf_admin());

create policy "published videos visible" on public.videos for select to anon, authenticated
using (status = 'published' or public.is_shaghaf_admin());
create policy "admin manages videos" on public.videos for all to authenticated
using (public.is_shaghaf_admin()) with check (public.is_shaghaf_admin());

create policy "approved comments visible" on public.comments for select to anon, authenticated
using (status = 'approved' or public.is_shaghaf_admin());
create policy "admin moderates comments" on public.comments for all to authenticated
using (public.is_shaghaf_admin()) with check (public.is_shaghaf_admin());

create policy "admin reads views" on public.video_views for select to authenticated
using (public.is_shaghaf_admin());
create policy "admin reads likes" on public.video_likes for select to authenticated
using (public.is_shaghaf_admin());
create policy "admin handles reports" on public.content_reports for all to authenticated
using (public.is_shaghaf_admin()) with check (public.is_shaghaf_admin());
create policy "admin controls settings" on public.app_settings for all to authenticated
using (public.is_shaghaf_admin()) with check (public.is_shaghaf_admin());
create policy "admin reads audit log" on public.admin_audit_log for select to authenticated
using (public.is_shaghaf_admin());

insert into storage.buckets (id, name, public)
values ('shaghaf-videos', 'shaghaf-videos', true)
on conflict (id) do nothing;

create policy "public reads published media" on storage.objects for select
using (bucket_id = 'shaghaf-videos');
create policy "admins upload media" on storage.objects for insert to authenticated
with check (bucket_id = 'shaghaf-videos' and public.is_shaghaf_admin());
create policy "admins update media" on storage.objects for update to authenticated
using (bucket_id = 'shaghaf-videos' and public.is_shaghaf_admin())
with check (bucket_id = 'shaghaf-videos' and public.is_shaghaf_admin());
create policy "admins delete media" on storage.objects for delete to authenticated
using (bucket_id = 'shaghaf-videos' and public.is_shaghaf_admin());

-- After creating the first administrator through Supabase Auth, grant the role:
-- insert into public.profiles(id, role) values ('AUTH-USER-UUID-HERE', 'admin');
-- Never put a service_role key or administrator password in the mobile application.


-- Online search endpoint: searches only published and moderated videos.
-- SECURITY INVOKER keeps the caller's RLS policies in force.
create or replace function public.search_published_videos(
  p_query text default '',
  p_category text default null,
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (
  id uuid,
  title text,
  description text,
  category text,
  language text,
  video_url text,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select v.id, v.title, v.description, v.category, v.language, v.video_url, v.created_at
  from public.videos v
  where v.status = 'published'
    and (p_category is null or v.category = p_category)
    and (
      coalesce(trim(p_query), '') = ''
      or v.title ilike '%' || trim(p_query) || '%'
      or v.description ilike '%' || trim(p_query) || '%'
      or v.category ilike '%' || trim(p_query) || '%'
    )
  order by v.created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 50))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.search_published_videos(text, text, integer, integer) to anon, authenticated;

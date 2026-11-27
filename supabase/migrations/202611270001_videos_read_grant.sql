-- Required table privilege for the published-video RPC and direct fallback query.
-- Row-level security remains enabled and the existing policies still restrict visible rows.
grant select on table public.videos to anon, authenticated;

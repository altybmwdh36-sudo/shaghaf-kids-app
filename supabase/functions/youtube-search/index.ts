import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const apiKey = Deno.env.get("YOUTUBE_API_KEY");
  if (!supabaseUrl || !anonKey || !apiKey) return json({ error: "YouTube search is not configured on the server." }, 503);

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Authentication required." }, 401);
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: auth, error: authError } = await supabase.auth.getUser(token);
  if (authError || !auth.user) return json({ error: "Invalid session." }, 401);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON body." }, 400); }
  const q = typeof body.q === "string" ? body.q.trim().slice(0, 100) : "";
  if (q.length < 2) return json({ error: "اكتب كلمتين على الأقل للبحث." }, 400);
  const requested = Number(body.maxResults) || 12;
  const maxResults = Math.max(1, Math.min(Math.floor(requested), 15));

  const url = new URL("https://www.googleapis.com/youtube/v3/search");
  url.search = new URLSearchParams({
    key: apiKey, part: "snippet", type: "video", q,
    maxResults: String(maxResults), safeSearch: "strict",
    videoEmbeddable: "true", relevanceLanguage: "ar", regionCode: "YE",
  }).toString();

  try {
    const upstream = await fetch(url, { signal: AbortSignal.timeout(12000) });
    const data = await upstream.json();
    if (!upstream.ok) {
      return json({ error: "تعذر إكمال بحث YouTube.", details: data?.error?.message ?? "YouTube API error" }, upstream.status === 403 ? 503 : 502);
    }
    const items = Array.isArray(data.items) ? data.items.map((item: any) => ({
      videoId: String(item?.id?.videoId ?? ""),
      title: String(item?.snippet?.title ?? "").slice(0, 300),
      description: String(item?.snippet?.description ?? "").slice(0, 1200),
      thumbnail: String(item?.snippet?.thumbnails?.high?.url ?? item?.snippet?.thumbnails?.medium?.url ?? ""),
      channelTitle: String(item?.snippet?.channelTitle ?? "").slice(0, 160),
      publishedAt: String(item?.snippet?.publishedAt ?? ""),
    })).filter((item: any) => /^[A-Za-z0-9_-]{11}$/.test(item.videoId)) : [];
    return json({
      items,
      moderation: "Search results are unreviewed external content. Do not treat them as approved Shaghaf library entries.",
      nextPageToken: typeof data.nextPageToken === "string" ? data.nextPageToken : null,
    });
  } catch {
    return json({ error: "تعذر الاتصال بخدمة YouTube حالياً." }, 502);
  }
});

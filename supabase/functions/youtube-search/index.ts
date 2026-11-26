import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});
const clean = (value: unknown, max = 1200) =>
  typeof value === "string" ? value.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim().slice(0, max) : "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const apiKey = Deno.env.get("YOUTUBE_API_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey || !apiKey) {
    return json({ error: "YouTube search server secrets are not configured." }, 503);
  }

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Authentication required." }, 401);
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: auth, error: authError } = await userClient.auth.getUser(token);
  if (authError || !auth.user) return json({ error: "Invalid session." }, 401);
  const { data: profile } = await userClient.from("profiles").select("role")
    .eq("id", auth.user.id).maybeSingle();
  if (profile?.role !== "admin") return json({ error: "Admin access required." }, 403);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON body." }, 400); }
  const q = clean(body.q, 100);
  const category = clean(body.category, 100) || "بحث مخصص";
  const maxResults = Math.max(1, Math.min(Math.floor(Number(body.maxResults) || 4), 5));
  if (q.length < 2) return json({ error: "Search query is too short." }, 400);

  const searchUrl = new URL("https://www.googleapis.com/youtube/v3/search");
  searchUrl.search = new URLSearchParams({
    key: apiKey, part: "snippet", type: "video", q,
    maxResults: String(maxResults), safeSearch: "strict",
    videoEmbeddable: "true", relevanceLanguage: "ar", regionCode: "YE",
    order: "relevance",
  }).toString();

  try {
    const response = await fetch(searchUrl, { signal: AbortSignal.timeout(15000) });
    const payload = await response.json();
    if (!response.ok) {
      return json({ error: "YouTube API request failed.", details: payload?.error?.message ?? "Unknown API error" },
        response.status === 403 ? 503 : 502);
    }

    const db = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const items = Array.isArray(payload.items) ? payload.items : [];
    let imported = 0;
    for (const item of items) {
      const id = clean(item?.id?.videoId, 20);
      if (!/^[A-Za-z0-9_-]{11}$/.test(id)) continue;
      const videoUrl = `https://www.youtube.com/watch?v=${id}`;
      const { data: existing } = await db.from("videos").select("id")
        .eq("video_url", videoUrl).maybeSingle();
      if (existing) continue;

      const snippet = item?.snippet ?? {};
      const title = clean(snippet.title, 180);
      if (!title) continue;
      const description = [
        clean(snippet.description, 1200),
        `القناة: ${clean(snippet.channelTitle, 160)}`,
        `تاريخ النشر: ${clean(snippet.publishedAt, 40)}`,
        "المصدر: YouTube Data API",
        "تنبيه: نتيجة بحث خارجية غير مراجعة؛ يجب فحص الفيديو كاملاً قبل النشر.",
      ].filter(Boolean).join("\n\n");

      const { error: insertError } = await db.from("videos").insert({
        title, description, category, language: "العربية",
        video_url: videoUrl, status: "pending",
        allow_comments: false, created_by: auth.user.id,
      });
      if (!insertError) imported++;
    }
    return json({
      found_count: items.length,
      imported_count: imported,
      moderation: "All YouTube results were saved as pending. Admin review is required before publication.",
    });
  } catch {
    return json({ error: "Unable to reach YouTube Data API." }, 502);
  }
});

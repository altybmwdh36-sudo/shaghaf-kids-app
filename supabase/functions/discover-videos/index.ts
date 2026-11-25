// Discover NASA-hosted educational video candidates for Shaghaf.
// Every imported item is inserted as "pending". Nothing is published automatically.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const collections = [
  { category: "الفضاء", query: "solar system planets space exploration" },
  { category: "العلوم", query: "Earth science climate oceans science" },
  { category: "الطبيعة", query: "Earth nature water atmosphere" },
  { category: "التقنية", query: "NASA robotics technology engineering" },
];

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function safeText(value: unknown, max: number) {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim().slice(0, max) : "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "Server secrets are not configured." }, 500);

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Authentication required." }, 401);

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "Invalid session." }, 401);

  const { data: profile, error: profileError } = await userClient
    .from("profiles").select("role").eq("id", userData.user.id).maybeSingle();
  if (profileError || profile?.role !== "admin") return json({ error: "Admin access required." }, 403);

  const db = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let requested: string[] = [];
  try {
    const body = await req.json();
    if (Array.isArray(body.categories)) requested = body.categories.filter((v: unknown) => typeof v === "string");
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }
  const selected = collections.filter((item) => requested.length === 0 || requested.includes(item.category));
  if (selected.length === 0) return json({ error: "No supported categories selected." }, 400);

  const imported: Array<{ title: string; category: string }> = [];
  const skipped: Array<{ title: string; reason: string }> = [];

  for (const section of selected) {
    try {
      const searchUrl = new URL("https://images-api.nasa.gov/search");
      searchUrl.searchParams.set("q", section.query);
      searchUrl.searchParams.set("media_type", "video");
      searchUrl.searchParams.set("page_size", "12");
      const searchResponse = await fetch(searchUrl, { signal: AbortSignal.timeout(15000) });
      if (!searchResponse.ok) throw new Error(`NASA search returned ${searchResponse.status}`);
      const payload = await searchResponse.json();
      const items = payload?.collection?.items ?? [];

      for (const item of items) {
        const metadata = item?.data?.[0] ?? {};
        const title = safeText(metadata.title, 180);
        const description = safeText(metadata.description, 1200);
        const nasaId = safeText(metadata.nasa_id, 80);
        const assetHref = item?.href;
        if (!title || !nasaId || typeof assetHref !== "string" ||
            !assetHref.startsWith("https://images-assets.nasa.gov/")) {
          skipped.push({ title: title || "بدون عنوان", reason: "بيانات المصدر غير مكتملة" });
          continue;
        }

        const assetResponse = await fetch(assetHref, { signal: AbortSignal.timeout(15000) });
        if (!assetResponse.ok) continue;
        const assets = await assetResponse.json();
        const videoUrl = Array.isArray(assets)
          ? assets.find((v: unknown) => typeof v === "string" &&
              /^https:\/\/images-assets\.nasa\.gov\/video\/[^\s]+\.mp4(?:\?.*)?$/i.test(v))
          : null;
        if (typeof videoUrl !== "string") continue;

        const { data: existing } = await db.from("videos")
          .select("id").eq("video_url", videoUrl).maybeSingle();
        if (existing) continue;

        const { error: insertError } = await db.from("videos").insert({
          title,
          description,
          category: section.category,
          language: "الإنجليزية",
          video_url: videoUrl,
          status: "pending",
          allow_comments: false,
          created_by: userData.user.id,
        });
        if (insertError) {
          skipped.push({ title, reason: "تعذر حفظ المرشح في قاعدة البيانات" });
        } else {
          imported.push({ title, category: section.category });
        }
      }
    } catch (error) {
      skipped.push({ title: section.category, reason: error instanceof Error ? error.message : "تعذر البحث" });
    }
  }

  return json({
    source: "NASA Image and Video Library",
    imported_count: imported.length,
    imported,
    skipped_count: skipped.length,
    skipped: skipped.slice(0, 30),
    moderation: "All discovered videos are pending. Admin review and explicit publication are required.",
  });
});

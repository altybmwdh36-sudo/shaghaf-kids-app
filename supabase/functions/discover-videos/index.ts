// Discover NASA-hosted educational video candidates for Shaghaf.
// Every imported item is inserted as "pending". Nothing is published automatically.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const collections = [
  { category: "الفضاء", nasa: "solar system planets space exploration", commons: "filetype:video solar system astronomy" },
  { category: "العلوم", nasa: "Earth science climate oceans science", commons: "filetype:video science education experiment" },
  { category: "الطبيعة", nasa: "Earth nature water atmosphere", commons: "filetype:video nature Earth oceans" },
  { category: "التقنية", nasa: "NASA robotics technology engineering", commons: "filetype:video robotics engineering technology" },
];

const commonsLicenseAllowed = (license: string) =>
  /^(CC BY 4\.0|CC BY-SA 4\.0|CC BY 3\.0|CC BY-SA 3\.0|CC0 1\.0|Public domain)/i.test(license);

function metadataText(value: unknown, max: number) {
  if (typeof value !== "string") return "";
  return value.replace(/<[^>]*>/g, " ").replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&").replace(/&#39;/g, "'").replace(/&quot;/g, '"')
    .replace(/\s+/g, " ").trim().slice(0, max);
}

function isCommonsVideoUrl(value: unknown): value is string {
  if (typeof value !== "string") return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" &&
      parsed.hostname === "upload.wikimedia.org" &&
      parsed.pathname.startsWith("/wikipedia/commons/") &&
      /\.(?:webm|mp4)$/i.test(parsed.pathname);
  } catch {
    return false;
  }
}

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
      searchUrl.searchParams.set("q", section.nasa);
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

  // Wikimedia Commons provides a second discovery source. Only files with
  // explicit machine-readable reuse licenses and supported direct video URLs
  // are considered. All candidates remain pending for human review.
  const importedCommons = new Set<string>();
  for (const section of selected) {
    try {
      const commonsUrl = new URL("https://commons.wikimedia.org/w/api.php");
      commonsUrl.searchParams.set("action", "query");
      commonsUrl.searchParams.set("format", "json");
      commonsUrl.searchParams.set("generator", "search");
      commonsUrl.searchParams.set("gsrsearch", section.commons);
      commonsUrl.searchParams.set("gsrnamespace", "6");
      commonsUrl.searchParams.set("gsrlimit", "12");
      commonsUrl.searchParams.set("prop", "imageinfo");
      commonsUrl.searchParams.set("iiprop", "url|mime|extmetadata");
      commonsUrl.searchParams.set("iiextmetadatafilter",
        "LicenseShortName|LicenseUrl|Artist|Credit|AttributionRequired|Restrictions|ImageDescription");

      const commonsResponse = await fetch(commonsUrl, {
        signal: AbortSignal.timeout(15000),
        headers: { "User-Agent": "ShaghafKidsApp/1.0 (educational content review)" },
      });
      if (!commonsResponse.ok) throw new Error(`Wikimedia Commons returned ${commonsResponse.status}`);
      const commonsPayload = await commonsResponse.json();
      const pages = Object.values(commonsPayload?.query?.pages ?? {}) as Array<Record<string, unknown>>;

      for (const page of pages) {
        const info = (page.imageinfo as Array<Record<string, unknown>> | undefined)?.[0];
        if (!info) continue;
        const videoUrl = info.url;
        const mime = safeText(info.mime, 60).toLowerCase();
        const descriptionUrl = safeText(info.descriptionurl, 500);
        const ext = (info.extmetadata ?? {}) as Record<string, { value?: unknown }>;
        const licenseName = metadataText(ext.LicenseShortName?.value, 100);
        const licenseUrl = metadataText(ext.LicenseUrl?.value, 500);
        const artist = metadataText(ext.Artist?.value, 300);
        const credit = metadataText(ext.Credit?.value, 300);
        const restrictions = metadataText(ext.Restrictions?.value, 300);
        const attributionRequired = metadataText(ext.AttributionRequired?.value, 30);
        const title = safeText(page.title, 180).replace(/^File:/i, "");
        const description = metadataText(ext.ImageDescription?.value, 900);

        if (typeof videoUrl !== "string" ||
            !isCommonsVideoUrl(videoUrl) ||
            !["video/webm", "video/mp4"].includes(mime) ||
            !descriptionUrl.startsWith("https://commons.wikimedia.org/wiki/File:") ||
            !title || !commonsLicenseAllowed(licenseName)) {
          skipped.push({ title: title || "ملف من Wikimedia Commons", reason: "الرابط أو نوع الفيديو أو بيانات الترخيص غير مكتملة أو غير مدعومة" });
          continue;
        }
        if (importedCommons.has(videoUrl)) continue;
        importedCommons.add(videoUrl);

        const attribution = [
          "المصدر: Wikimedia Commons",
          `صفحة الملف: ${descriptionUrl}`,
          artist ? `المؤلف: ${artist}` : "",
          credit ? `الاعتماد: ${credit}` : "",
          `الرخصة: ${licenseName}`,
          licenseUrl ? `رابط الرخصة: ${licenseUrl}` : "",
          attributionRequired.toLowerCase() === "true" ? "يتطلب نسب العمل إلى صاحبه." : "",
          restrictions ? `قيود مذكورة من المصدر: ${restrictions}` : "",
        ].filter(Boolean).join("\n");

        const { data: existing } = await db.from("videos")
          .select("id").eq("video_url", videoUrl).maybeSingle();
        if (existing) continue;

        const { error: insertError } = await db.from("videos").insert({
          title,
          description: [description, attribution].filter(Boolean).join("\n\n"),
          category: section.category,
          language: "غير محددة",
          video_url: videoUrl,
          status: "pending",
          allow_comments: false,
          created_by: userData.user.id,
        });
        if (insertError) {
          skipped.push({ title, reason: "تعذر حفظ مرشح Wikimedia Commons" });
        } else {
          imported.push({ title, category: section.category });
        }
      }
    } catch (error) {
      skipped.push({ title: `Wikimedia Commons • ${section.category}`, reason: error instanceof Error ? error.message : "تعذر البحث" });
    }
  }

  return json({
    source: "NASA Image and Video Library + Wikimedia Commons",
    imported_count: imported.length,
    imported,
    skipped_count: skipped.length,
    skipped: skipped.slice(0, 30),
    moderation: "All discovered videos are pending. Admin review and explicit publication are required.",
  });
});

// Dynamic, admin-directed video discovery for Shaghaf.
// Search candidates from multiple public catalogs. Every candidate stays pending.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Section = { category: string; terms: string; nasa?: string };
const SECTIONS: Record<string, Section> = {
  "التعليم والمعرفة": { category: "التعليم والمعرفة", terms: "educational learning mathematics science lessons", nasa: "science education Earth science" },
  "التحفيز والدراسة": { category: "التحفيز والدراسة", terms: "study motivation student success learning inspiration" },
  "الاختراعات والهندسة": { category: "الاختراعات والهندسة", terms: "inventions engineering technology robotics" , nasa: "engineering robotics technology invention" },
  "الدين والأخلاق": { category: "الدين والأخلاق", terms: "Islam Islamic education morals values Quran" },
  "قصص الأنبياء والصالحين": { category: "قصص الأنبياء والصالحين", terms: "prophets stories Islamic history righteous people" },
  "القرآن الكريم": { category: "القرآن الكريم", terms: "Quran recitation Quran education" },
  "العلوم والاكتشاف": { category: "العلوم والاكتشاف", terms: "science discovery nature space astronomy experiments", nasa: "space science nature astronomy" },
  "الفكاهة النظيفة": { category: "الفكاهة النظيفة", terms: "family friendly clean comedy children funny educational" },
  "الطبيعة والوثائقيات": { category: "الطبيعة والوثائقيات", terms: "nature wildlife environment documentary", nasa: "Earth nature oceans atmosphere" },
};

const clean = (value: unknown, max = 500) =>
  typeof value === "string" ? value.replace(/<[^>]*>/g, " ").replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&").replace(/\s+/g, " ").trim().slice(0, max) : "";

const commonsLicenseAllowed = (license: string) =>
  /^(CC BY 4\.0|CC BY-SA 4\.0|CC BY 3\.0|CC BY-SA 3\.0|CC0 1\.0|Public domain)/i.test(license);

function commonsVideoUrl(value: unknown): value is string {
  if (typeof value !== "string") return false;
  try {
    const u = new URL(value);
    return u.protocol === "https:" && u.hostname === "upload.wikimedia.org" &&
      u.pathname.startsWith("/wikipedia/commons/") && /\.(webm|mp4)$/i.test(u.pathname);
  } catch { return false; }
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});

async function getJson(url: URL, userAgent = "ShaghafKidsApp/1.0 (educational discovery)") {
  const response = await fetch(url, {
    signal: AbortSignal.timeout(18000),
    headers: { "User-Agent": userAgent },
  });
  if (!response.ok) throw new Error(`Source returned HTTP ${response.status}`);
  return await response.json();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) return json({ error: "Server secrets are not configured." }, 500);

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
  const requested = Array.isArray(body.categories)
    ? body.categories.filter((v): v is string => typeof v === "string") : [];
  if (requested.length > 5) {
    return json({ error: "اختر خمسة أقسام كحد أقصى في عملية البحث الواحدة، ويمكنك تكرار البحث لبقية الأقسام." }, 400);
  }
  const topic = clean(body.topic, 180);
  if (requested.length === 0 && !topic) {
    return json({ error: "اختر قسماً واحداً على الأقل أو اكتب موضوع البحث." }, 400);
  }
  const sections: Section[] = requested.map((name) => SECTIONS[name]).filter(Boolean);
  if (topic) sections.push({ category: clean(body.topic_category, 100) || topic, terms: topic });
  if (!sections.length) return json({ error: "لا توجد أقسام بحث معروفة." }, 400);

  const db = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const imported: Array<{ title: string; category: string; source: string }> = [];
  const skipped: Array<{ title: string; reason: string }> = [];
  const seen = new Set<string>();
  const maxPerSection = Math.max(1, Math.min(Number(body.max_per_section) || 4, 4));

  async function saveCandidate(candidate: {
    title: string; description: string; category: string; url: string;
    language?: string; source: string;
  }) {
    if (!candidate.title || !candidate.url || seen.has(candidate.url)) return;
    seen.add(candidate.url);
    const { data: exists } = await db.from("videos").select("id")
      .eq("video_url", candidate.url).maybeSingle();
    if (exists) return;
    const { error } = await db.from("videos").insert({
      title: candidate.title.slice(0, 180),
      description: [candidate.description, `المصدر: ${candidate.source}`].filter(Boolean).join("\n\n").slice(0, 4000),
      category: candidate.category,
      language: candidate.language ?? "غير محددة",
      video_url: candidate.url,
      status: "pending",
      allow_comments: false,
      created_by: auth.user.id,
    });
    if (error) skipped.push({ title: candidate.title, reason: "تعذر حفظ المرشح في قاعدة البيانات" });
    else imported.push({ title: candidate.title, category: candidate.category, source: candidate.source });
  }

  for (const section of sections) {
    // Wikimedia Commons: searchable video files with explicit reusable licenses.
    try {
      const u = new URL("https://commons.wikimedia.org/w/api.php");
      u.searchParams.set("action", "query"); u.searchParams.set("format", "json");
      u.searchParams.set("generator", "search");
      u.searchParams.set("gsrsearch", `filetype:video ${section.terms}`);
      u.searchParams.set("gsrnamespace", "6"); u.searchParams.set("gsrlimit", String(maxPerSection));
      u.searchParams.set("prop", "imageinfo"); u.searchParams.set("iiprop", "url|mime|extmetadata");
      u.searchParams.set("iiextmetadatafilter", "LicenseShortName|LicenseUrl|Artist|Credit|AttributionRequired|Restrictions|ImageDescription");
      const payload = await getJson(u);
      const pages = Object.values(payload?.query?.pages ?? {}) as Array<Record<string, unknown>>;
      for (const page of pages) {
        const info = (page.imageinfo as Array<Record<string, unknown>> | undefined)?.[0];
        if (!info) continue;
        const ext = (info.extmetadata ?? {}) as Record<string, { value?: unknown }>;
        const license = clean(ext.LicenseShortName?.value, 100);
        const licenseUrl = clean(ext.LicenseUrl?.value, 500);
        const direct = info.url;
        const pageUrl = clean(info.descriptionurl, 500);
        const mime = clean(info.mime, 60).toLowerCase();
        if (!commonsVideoUrl(direct) || !["video/mp4", "video/webm"].includes(mime) ||
            !pageUrl.startsWith("https://commons.wikimedia.org/wiki/File:") ||
            !commonsLicenseAllowed(license)) continue;
        const title = clean(page.title, 180).replace(/^File:/i, "");
        const attribution = [
          `صفحة الملف: ${pageUrl}`,
          clean(ext.Artist?.value, 300) ? `المؤلف: ${clean(ext.Artist?.value, 300)}` : "",
          clean(ext.Credit?.value, 300) ? `الاعتماد: ${clean(ext.Credit?.value, 300)}` : "",
          `الرخصة: ${license}`, licenseUrl ? `رابط الرخصة: ${licenseUrl}` : "",
          clean(ext.AttributionRequired?.value, 20).toLowerCase() === "true" ? "يتطلب نسب العمل لصاحبه." : "",
          clean(ext.Restrictions?.value, 250),
        ].filter(Boolean).join("\n");
        await saveCandidate({
          title, description: [clean(ext.ImageDescription?.value, 900), attribution].filter(Boolean).join("\n\n"),
          category: section.category, url: direct as string, source: "Wikimedia Commons",
        });
      }
    } catch (e) {
      skipped.push({ title: section.category, reason: `Wikimedia Commons: ${e instanceof Error ? e.message : "تعذر البحث"}` });
    }

    // Internet Archive: only direct MP4 files with an explicit approved license.
    try {
      const q = new URL("https://archive.org/advancedsearch.php");
      q.searchParams.set("q", `mediatype:movies AND (title:"${section.terms.replace(/["\\]/g, " ")}" OR description:"${section.terms.replace(/["\\]/g, " ")}")`);
      q.searchParams.set("fl[]", "identifier,title,description,creator,licenseurl");
      q.searchParams.set("rows", String(maxPerSection)); q.searchParams.set("output", "json");
      const result = await getJson(q);
      for (const doc of result?.response?.docs ?? []) {
        const identifier = clean(doc.identifier, 120);
        const licenseUrl = clean(doc.licenseurl, 500);
        if (!/creativecommons\.org\/(licenses\/by(-sa)?\/4\.0|publicdomain\/zero\/1\.0)/i.test(licenseUrl)) continue;
        if (!/^[a-zA-Z0-9._-]+$/.test(identifier)) continue;
        const metaUrl = new URL(`https://archive.org/metadata/${identifier}`);
        const meta = await getJson(metaUrl);
        const files = Array.isArray(meta?.files) ? meta.files as Array<Record<string, unknown>> : [];
        const mp4 = files.find((f) => clean(f.name, 300).toLowerCase().endsWith(".mp4") &&
          !String(f.name).includes("/") && String(f.source ?? "") !== "metadata");
        if (!mp4) continue;
        const direct = `https://archive.org/download/${encodeURIComponent(identifier)}/${encodeURIComponent(String(mp4.name))}`;
        await saveCandidate({
          title: clean(doc.title, 180), description: [
            clean(doc.description, 1200), `المؤلف: ${clean(doc.creator, 250)}`,
            `الرخصة: ${licenseUrl}`, `صفحة المصدر: https://archive.org/details/${identifier}`,
          ].filter(Boolean).join("\n"),
          category: section.category, url: direct, source: "Internet Archive",
        });
      }
    } catch (e) {
      skipped.push({ title: section.category, reason: `Internet Archive: ${e instanceof Error ? e.message : "تعذر البحث"}` });
    }

    // NASA is useful for science/space topics, not treated as a universal catalog.
    if (section.nasa) {
      try {
        const u = new URL("https://images-api.nasa.gov/search");
        u.searchParams.set("q", section.nasa); u.searchParams.set("media_type", "video");
        u.searchParams.set("page_size", String(maxPerSection));
        const payload = await getJson(u);
        for (const item of payload?.collection?.items ?? []) {
          const meta = item?.data?.[0] ?? {};
          const title = clean(meta.title, 180), description = clean(meta.description, 1200);
          const nasaId = clean(meta.nasa_id, 80), asset = item?.href;
          if (!title || !nasaId || typeof asset !== "string" || !asset.startsWith("https://images-assets.nasa.gov/")) continue;
          const assets = await getJson(new URL(asset));
          const direct = Array.isArray(assets) ? assets.find((v) => typeof v === "string" &&
            /^https:\/\/images-assets\.nasa\.gov\/video\/[a-zA-Z0-9_./-]+\.mp4(?:\?.*)?$/i.test(v)) : null;
          if (typeof direct !== "string") continue;
          await saveCandidate({ title, description, category: section.category, url: direct, language: "الإنجليزية", source: "NASA Image and Video Library" });
        }
      } catch (e) {
        skipped.push({ title: section.category, reason: `NASA: ${e instanceof Error ? e.message : "تعذر البحث"}` });
      }
    }
  }

  return json({
    sources: ["Wikimedia Commons", "Internet Archive", "NASA (للموضوعات العلمية ذات الصلة)"],
    sections: sections.map((s) => s.category), imported_count: imported.length, imported,
    skipped_count: skipped.length, skipped: skipped.slice(0, 40),
    moderation: "All discovered items are pending. Admin must review the complete video, audio, thumbnail, age suitability and reuse rights before publishing.",
    notice: "Search metadata and reuse licenses do not establish child-safety. Automated content moderation is not yet integrated.",
  });
});

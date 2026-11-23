import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods": "POST, OPTIONS" };
function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "Método no permitido." });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: session, error: authError } = await userClient.auth.getUser();
    if (authError || !session.user) return json(401, { error: "Inicia sesión nuevamente." });
    const server = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: profile } = await server.from("profiles").select("rol,activo").eq("id", session.user.id).single();
    if (!profile?.activo || !["ADMINISTRADOR", "ALMACEN"].includes(profile.rol)) return json(403, { error: "Sin permiso para usar el reconocimiento." });

    if (Number(req.headers.get("content-length") ?? 0) > 32 * 1024 * 1024) return json(413, { error: "Las fotografías superan el tamaño permitido." });
    const raw = await req.text();
    if (raw.length > 32 * 1024 * 1024) return json(413, { error: "Las fotografías superan el tamaño permitido." });
    let input;
    try { input = JSON.parse(raw); } catch { return json(400, { error: "Solicitud inválida." }); }
    if (!["modelos", "generar"].includes(input.accion)) return json(400, { error: "Acción no válida." });
    const { data: credentials, error } = await server.rpc("credencial_gemini_servidor");
    if (error) return json(503, { error: "La configuración segura de IA no está disponible." });
    const key = credentials?.[0]?.clave;
    if (!key) return json(409, { error: "Administrador debe añadir o activar una clave de IA." });
    let path = "models";
    let body: string | undefined;
    if (input.accion === "generar") {
      if (typeof input.modelo !== "string" || !/^gemini-[a-zA-Z0-9.-]+$/.test(input.modelo)) return json(400, { error: "Modelo no válido." });
      const parts = input.contenido?.contents?.[0]?.parts;
      if (!Array.isArray(parts) || parts.length < 2 || parts.length > 5 || typeof parts[0]?.text !== "string" || parts[0].text.length > 20000) return json(400, { error: "Contenido de reconocimiento no válido." });
      if (!parts.slice(1).every((p: { inline_data?: { mime_type?: string; data?: string } }) =>
        ["image/jpeg", "image/png", "image/webp"].includes(p.inline_data?.mime_type ?? "") && typeof p.inline_data?.data === "string" && p.inline_data.data.length > 0
      )) return json(400, { error: "Fotografías no válidas." });
      path = `models/${input.modelo}:generateContent`;
      body = JSON.stringify({ contents: [{ parts }], generationConfig: { temperature: 0.1, responseMimeType: "application/json" } });
    }
    // La clave se usa solo en memoria del servidor y nunca viaja al móvil o a logs.
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/${path}`, {
      method: body ? "POST" : "GET", headers: { "x-goog-api-key": key, "Content-Type": "application/json" }, body,
      signal: AbortSignal.timeout(45000),
    });
    if (!response.ok) {
      const message = response.status === 429 ? "Cuota o límite temporal de Gemini alcanzado. Intenta más tarde."
        : [400, 401, 403].includes(response.status) ? "Gemini rechazó la credencial o sus permisos. Administrador debe revisarla."
        : response.status === 404 ? "Modelo no disponible." : "Gemini no pudo completar la solicitud.";
      return json(200, { estado: response.status, respuesta: { error: { message } } });
    }
    return json(200, { estado: response.status, respuesta: await response.json() });
  } catch {
    return json(503, { error: "No se pudo contactar al reconocimiento. Conserva tus fotografías e intenta nuevamente." });
  }
});

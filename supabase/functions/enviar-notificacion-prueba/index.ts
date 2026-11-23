import { createClient } from "https://esm.sh/@supabase/supabase-js@2.119.2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
});
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const b64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
const encoded = (value: unknown) => b64(new TextEncoder().encode(JSON.stringify(value)));

async function accessToken(): Promise<string> {
  const credentials = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "{}");
  if (credentials.project_id !== Deno.env.get("FIREBASE_PROJECT_ID") || credentials.type !== "service_account") throw Error("configuration");
  const pem = credentials.private_key.replace(/-----[^-]+-----|\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), c => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const now = Math.floor(Date.now() / 1000);
  const input = `${encoded({ alg: "RS256", typ: "JWT" })}.${encoded({ iss: credentials.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging", aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 })}`;
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(input));
  const response = await fetch("https://oauth2.googleapis.com/token", { method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${input}.${b64(new Uint8Array(signature))}` }),
    signal: AbortSignal.timeout(15000) });
  const result = await response.json();
  if (!response.ok || !result.access_token) throw Error("configuration");
  return result.access_token;
}

Deno.serve(async req => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "Método no permitido" });
  let notificationId: string | undefined;
  const server = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } });
  try {
    const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await client.auth.getUser();
    if (error || !data.user) return json(401, { error: "Inicia sesión nuevamente" });
    const raw = await req.text();
    if (raw.length > 1024) return json(400, { error: "Solicitud no válida" });
    let input;
    try { input = JSON.parse(raw); } catch { return json(400, { error: "Solicitud no válida" }); }
    if (!input || typeof input !== "object" || Array.isArray(input)) return json(400, { error: "Solicitud no válida" });
    if (!uuid.test(input.instalacion_id ?? "") || !uuid.test(input.solicitud_id ?? "")) return json(400, { error: "Solicitud no válida" });
    const { data: prepared, error: prepareError } = await server.rpc("preparar_prueba_push", {
      p_usuario: data.user.id, p_instalacion: input.instalacion_id, p_solicitud: input.solicitud_id,
    });
    if (prepareError) return json(503, { error: "No se pudo preparar el aviso" });
    if (prepared.error) return json(409, { error: prepared.error });
    if (prepared.estado === "enviado") return json(200, { id: prepared.id, estado: "enviado" });
    notificationId = prepared.id;
    const bearer = await accessToken();
    const project = Deno.env.get("FIREBASE_PROJECT_ID")!;
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(project)}/messages:send`, {
      method: "POST", headers: { Authorization: `Bearer ${bearer}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: { token: prepared.token,
        notification: { title: prepared.titulo, body: prepared.mensaje },
        data: { notification_id: notificationId, usuario_id: data.user.id, tipo: "PRUEBA" },
        android: { priority: "HIGH", ttl: "300s", notification: { channel_id: "sitra_avisos", tag: notificationId } },
      } }), signal: AbortSignal.timeout(20000),
    });
    if (!response.ok) {
      const failure = await response.json().catch(() => ({}));
      const invalid = failure.error?.details?.some((d: { errorCode?: string }) => d.errorCode === "UNREGISTERED");
      if (invalid) await server.from("dispositivos_push").update({ activo: false }).eq("instalacion_id", input.instalacion_id).eq("usuario_id", data.user.id).eq("token", prepared.token);
      await server.from("notificaciones").update({ envio_estado: "error" }).eq("id", notificationId);
      return json(200, { estado: "error", error: invalid ? "El dispositivo necesita registrarse otra vez. Pulsa Activar avisos."
        : response.status === 403 ? "Revisa la API de Cloud Messaging y los permisos de la cuenta de servicio en Firebase."
        : "Firebase no aceptó el envío. Puedes reintentar en 30 segundos." });
    }
    const { error: updateError } = await server.from("notificaciones").update({ envio_estado: "enviado" }).eq("id", notificationId);
    return json(200, { id: notificationId, estado: updateError ? "incierto" : "enviado" });
  } catch {
    if (notificationId) await server.from("notificaciones").update({ envio_estado: "error" }).eq("id", notificationId);
    return json(503, { error: "No se pudo confirmar el envío. Revisa conexión y configuración del servidor antes de reintentar." });
  }
});

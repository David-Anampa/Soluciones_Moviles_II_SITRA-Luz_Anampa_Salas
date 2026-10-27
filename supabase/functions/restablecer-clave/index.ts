// HU-022: restablecimiento administrativo. La clave service-role permanece
// exclusivamente en el servidor. Nunca registrar cuerpos ni contraseñas en logs.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Responde sin incluir datos sensibles del proveedor de autenticación. */
function responder(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return responder(405, { error: "Método no permitido." });

  const url = Deno.env.get("SUPABASE_URL")!;
  const auth = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: sesion, error: errorSesion } = await auth.auth.getUser();
  if (errorSesion || !sesion.user) return responder(401, { error: "Inicia sesión para continuar." });

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: perfil, error: errorPerfil } = await admin.from("profiles")
    .select("rol,activo").eq("id", sesion.user.id).single();
  if (errorPerfil || perfil?.rol !== "ADMINISTRADOR" || perfil.activo !== true) {
    return responder(403, { error: "Solo Administrador activo puede restablecer contraseñas." });
  }

  let entrada: Record<string, unknown>;
  try {
    entrada = await req.json();
    if (!entrada || typeof entrada !== "object" || Array.isArray(entrada)) throw new Error();
  } catch {
    return responder(400, { error: "Solicitud inválida." });
  }
  const id = entrada.id;
  const password = entrada.password;
  if (typeof id !== "string" || !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(id)) {
    return responder(400, { error: "Usuario inválido." });
  }
  if (typeof password !== "string" || password.length < 8 || new TextEncoder().encode(password).length > 72) {
    return responder(400, { error: "Usa al menos 8 caracteres; máximo 72 bytes." });
  }
  const { data: destino, error: errorDestino } = await admin.from("profiles")
    .select("id").eq("id", id).single();
  if (errorDestino || !destino) return responder(404, { error: "El usuario ya no está disponible." });

  const operacion = crypto.randomUUID();
  // Se exige una constancia previa: si falla, no se cambia la contraseña.
  const base = {
    entidad_referencia_id: id, tabla_referencia: "profiles", usuario_id: sesion.user.id,
    detalles_extra: { operacion_id: operacion },
  };
  const { error: errorAuditoria } = await admin.from("auditoria_trazabilidad").insert({
    ...base, tipo_evento: "USUARIO_CLAVE_SOLICITADA",
    descripcion: "Administrador solicitó restablecer la contraseña.",
  });
  if (errorAuditoria) return responder(503, { error: "No se pudo registrar la solicitud. No se cambió la contraseña." });

  // API oficial de Auth: no modifica profiles ni devuelve la clave a la aplicación.
  const { error: errorClave } = await admin.auth.admin.updateUserById(id, { password });
  const { error: errorResultado } = await admin.from("auditoria_trazabilidad").insert({
    ...base, tipo_evento: errorClave ? "USUARIO_CLAVE_FALLIDA" : "USUARIO_CLAVE_RESTABLECIDA",
    descripcion: errorClave ? "Auth rechazó el restablecimiento." : "Administrador restableció la contraseña.",
  });
  if (errorClave) return responder(400, { error: "No se pudo cambiar la contraseña. Verifica que sea diferente de la anterior y cumpla la política de seguridad." });

  // Auth y auditoría son servicios distintos: no afirmar rollback si Auth ya cambió.
  return responder(200, {
    actualizado: true,
    advertencia: errorResultado ? "Contraseña cambiada. La solicitud quedó registrada, pero falta registrar el resultado en auditoría. No repitas el cambio." : null,
  });
});

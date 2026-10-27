// Acceso por nombre de usuario sin publicar correos ni perfiles anónimamente.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Nunca registrar este cuerpo: una respuesta exitosa contiene la sesión de Auth. */
function responder(status: number, cuerpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(cuerpo), {
    status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}
const invalido = () => responder(401, { error: "Usuario o contraseña incorrectos, o cuenta no habilitada." });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return responder(405, { error: "Método no permitido." });
  let entrada: Record<string, unknown>;
  try {
    entrada = await req.json();
    if (!entrada || typeof entrada !== "object" || Array.isArray(entrada)) throw new Error();
  } catch { return invalido(); }
  const usuario = typeof entrada.usuario === "string" ? entrada.usuario.trim() : "";
  const password = entrada.password;
  // No imponer aquí la política de creación: las claves históricas siguen siendo válidas.
  if (!/^[A-Za-z0-9][A-Za-z0-9_.-]{2,31}$/.test(usuario) || typeof password !== "string" || !password || password.length > 1024) return invalido();

  const url = Deno.env.get("SUPABASE_URL")!;
  const opciones = { auth: { persistSession: false, autoRefreshToken: false } };
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, opciones);
  // Escapar los comodines de ILIKE: '_' debe coincidir literalmente.
  const patron = usuario.replace(/[\\%_]/g, (caracter) => "\\" + caracter);
  const { data: perfil, error: errorPerfil } = await admin.from("profiles")
    .select("id,email,activo").ilike("nombre_usuario", patron).maybeSingle();
  if (errorPerfil) return responder(503, { error: "El servicio de acceso no está disponible." });
  if (!perfil || !perfil.activo || !perfil.email) return invalido();

  // Autenticar con clave pública: el service-role no inicia ni suplanta la sesión.
  const auth = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, opciones);
  const { data, error } = await auth.auth.signInWithPassword({ email: perfil.email, password });
  if (error || !data.session || data.user?.id !== perfil.id) {
    if (data.session) await auth.auth.signOut();
    return error?.status === 429
      ? responder(429, { error: "Demasiados intentos. Vuelve a intentar más tarde." }) : invalido();
  }
  // Comprobar otra vez la habilitación después de autenticar.
  const { data: actual, error: errorActual } = await admin.from("profiles")
    .select("activo").eq("id", perfil.id).single();
  if (errorActual || actual?.activo !== true) {
    await auth.auth.signOut();
    return invalido();
  }
  return responder(200, { session: data.session });
});

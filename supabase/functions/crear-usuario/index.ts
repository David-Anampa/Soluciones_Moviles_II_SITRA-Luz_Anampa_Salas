// HU-021: alta segura de usuarios.
// Crea la cuenta en Supabase Auth con la clave service-role (disponible solo en el
// servidor como variable de entorno) y completa su perfil mediante la RPC
// `registrar_perfil_usuario_hu021`. La app Flutter nunca recibe ni guarda esa clave.
//
// Despliegue:  supabase functions deploy crear-usuario
// (SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY las inyecta Supabase.)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const EMAIL_VALIDO = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const CLAVE_MINIMA = 8;

/** Respuesta JSON con el estado HTTP indicado. */
function responder(estado: number, cuerpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { "Content-Type": "application/json" },
  });
}

/** Devuelve el error de validación de las credenciales o null si son correctas. */
function validarCredenciales(email: string, password: string): string | null {
  if (!EMAIL_VALIDO.test(email)) return "El correo de acceso no es válido.";
  if (password.length < CLAVE_MINIMA) {
    return `La contraseña debe tener al menos ${CLAVE_MINIMA} caracteres.`;
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return responder(405, { error: "Método no permitido." });

  const url = Deno.env.get("SUPABASE_URL")!;
  const autorizacion = req.headers.get("Authorization") ?? "";

  // 1. Identifica al solicitante con su propio token y exige Administrador activo.
  const cliente = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: autorizacion } },
  });
  const { data: sesion } = await cliente.auth.getUser();
  if (!sesion.user) return responder(401, { error: "Inicia sesión para continuar." });

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: perfil } = await admin
    .from("profiles").select("rol,activo").eq("id", sesion.user.id).single();
  if (perfil?.rol !== "ADMINISTRADOR" || perfil?.activo !== true) {
    return responder(403, { error: "Solo Administrador puede crear usuarios." });
  }

  // 2. Valida las credenciales; el resto de datos lo valida la RPC.
  let entrada: { email?: string; password?: string; perfil?: Record<string, unknown> };
  try {
    entrada = await req.json();
  } catch {
    return responder(400, { error: "Solicitud inválida." });
  }
  const email = (entrada.email ?? "").trim().toLowerCase();
  const password = entrada.password ?? "";
  const errorCredenciales = validarCredenciales(email, password);
  if (errorCredenciales) return responder(400, { error: errorCredenciales });

  // 3. Crea la cuenta de acceso (el trigger handle_new_user crea el perfil inactivo).
  const nombre = `${entrada.perfil?.nombres ?? ""} ${entrada.perfil?.apellidos ?? ""}`.trim();
  const { data: creada, error: errorAuth } = await admin.auth.admin.createUser({
    email, password, email_confirm: true, user_metadata: { nombre },
  });
  if (errorAuth || !creada.user) {
    const duplicado = /already|registered|exists/i.test(errorAuth?.message ?? "");
    return responder(duplicado ? 409 : 400, {
      error: duplicado ? "Ese correo ya tiene una cuenta." : "No se pudo crear la cuenta de acceso.",
    });
  }

  // 4. Completa y activa el perfil. Si falla, se elimina la cuenta recién creada
  //    para no dejar usuarios a medias (la operación es todo o nada).
  const { error: errorPerfil } = await admin.rpc("registrar_perfil_usuario_hu021", {
    p_admin_id: sesion.user.id, p_id: creada.user.id, p_datos: entrada.perfil ?? {},
  });
  if (errorPerfil) {
    await admin.auth.admin.deleteUser(creada.user.id);
    return responder(400, { error: errorPerfil.message });
  }
  return responder(200, { id: creada.user.id });
});

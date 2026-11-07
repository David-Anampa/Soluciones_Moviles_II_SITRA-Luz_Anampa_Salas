# Política de Privacidad — SITRA-Luz

**Aplicación Móvil:** `com.sitra_luz.miapp`  
**Última actualización:** 6 de noviembre de 2026  
**Responsable:** Proyecto SITRA-Luz (Clínica La Luz / Universidad Privada de Tacna)  
**Contacto:** da2022074268@virtual.upt.pe  

---

La presente Política de Privacidad describe el tratamiento, recopilación, uso y protección de los datos en la aplicación móvil **SITRA-Luz** (Sistema de Trazabilidad y Dispensación de Medicamentos), desarrollada para la digitalización y control de flujo interno de medicamentos en la **Clínica La Luz** (Tacna, Perú).

## 1. Permisos del Dispositivo y Finalidad

* **Cámara (`android.permission.CAMERA`):** Se utiliza exclusivamente en el módulo de Almacén para escanear códigos de barras GS1/GTIN y capturar fotografías del empaque de los medicamentos con el fin de extraer datos de lote, registro sanitario y fecha de vencimiento. No se capturan imágenes de rostros ni del entorno fuera del empaque del medicamento.
* **Almacenamiento / Galería:** Permite guardar localmente en el dispositivo copia de las fotos capturadas del empaque del medicamento (en la carpeta `Pictures/SITRA_Luz`) como respaldo de trazabilidad farmacéutica física.
* **Acceso a Internet y Estado de Red:** Requerido para sincronizar los registros de inventario con el backend seguro en la nube y verificar la conectividad antes de realizar llamadas a los servicios.

## 2. Datos Recopilados y su Uso

* **Datos de Cuenta y Acceso:** Correo electrónico institucional y credenciales de acceso para autenticación con control de acceso basado en roles (RBAC: Administrador, Jefatura, Farmacia, Almacén, Enfermería).
* **Datos de Inventario y Fichas Clínicas:** Nombres estandarizados de medicamentos, números de lote, fechas de vencimiento, laboratorios, existencias por área y solicitudes de pedidos internos entre áreas asistenciales (SOP, Emergencia, Neonatología) y Farmacia.

## 3. Servicios de Terceros y Transferencia de Datos

Para su correcto funcionamiento, la aplicación interactúa con proveedores de servicios de infraestructura tecnológica bajo estrictos estándares de seguridad:
* **Supabase (PostgreSQL & Auth):** Proporciona autenticación segura, control de acceso mediante Row Level Security (RLS) y persistencia cifrada de datos en reposo y en tránsito (HTTPS/TLS).
* **Google Gemini Vision API:** Utilizado en el módulo de Almacén para realizar análisis óptico y extracción asistida de datos a partir de las fotografías del empaque de medicamentos. No se envían datos personales de pacientes ni información sensible a este servicio.
* **Firebase Cloud Messaging (Google):** Utilizado como infraestructura para notificaciones operativas entre turnos.

## 4. Seguridad de la Información

* Todo el tráfico de red se realiza mediante protocolos cifrados HTTPS / TLS (`usesCleartextTraffic="false"`).
* Las contraseñas de los usuarios no se almacenan en texto plano; están protegidas por algoritmos robustos de derivación de claves en Supabase Auth.
* No vendemos, comercializamos ni cedemos información personal a terceros con fines publicitarios o comerciales.

## 5. Privacidad de Menores

La aplicación está destinada exclusivamente a profesionales y personal autorizado de la clínica. No está dirigida a niños ni recopila deliberadamente datos personales de menores sin el consentimiento de sus tutores en el marco de la atención médica hospitalaria regulada.

## 6. Derechos del Usuario y Eliminación de Datos

Cualquier usuario con cuenta registrada puede solicitar la corrección, actualización o desactivación de su perfil dirigiéndose al Administrador del sistema o enviando una solicitud por correo a `da2022074268@virtual.upt.pe`.

---
**Contacto:**  
SITRA-Luz — Clínica La Luz / Universidad Privada de Tacna  
Correo: da2022074268@virtual.upt.pe  
Tacna, Perú

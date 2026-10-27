import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../data/usuarios_repository.dart';
import '../../domain/usuario_validadores.dart';
import 'catalogo_estilo.dart';

/// Acción independiente del guardado del perfil; nunca precarga la clave actual.
class RestablecerClaveDialog extends StatefulWidget {
  final UsuarioAdministrativo usuario;
  final UsuariosRepository repositorio;
  const RestablecerClaveDialog({
    super.key,
    required this.usuario,
    required this.repositorio,
  });
  @override
  State<RestablecerClaveDialog> createState() => _RestablecerClaveDialogState();
}

class _RestablecerClaveDialogState extends State<RestablecerClaveDialog> {
  final _form = GlobalKey<FormState>();
  final _clave = TextEditingController(),
      _confirmacion = TextEditingController();
  bool _enviando = false, _verClave = false, _verConfirmacion = false;
  String? _error;

  @override
  void dispose() {
    _clave.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  /// Valida las dos entradas y bloquea doble envío y cierre durante la solicitud.
  Future<void> _guardar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final advertencia = await widget.repositorio.restablecerClave(
        widget.usuario.id,
        _clave.text,
      );
      if (!mounted) return;
      Navigator.pop(context, (
        mensaje: advertencia ?? 'Contraseña actualizada correctamente.',
        advertencia: advertencia != null,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = error is StateError
            ? error.message.toString()
            : 'No se pudo confirmar el cambio. Revisa la conexión antes de reintentar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_enviando,
    child: DialogoAdaptable(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: CatalogoEstilo.rojo,
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.lock_reset_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Restablecer contraseña',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _enviando ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.usuario.nombreCompleto,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.usuario.correo,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  MensajesApp.nota(
                    'Cambiará únicamente la contraseña de acceso. Los cambios pendientes del perfil se guardan por separado.',
                    tipo: TipoMensaje.advertencia,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _clave,
                    enabled: !_enviando,
                    obscureText: !_verClave,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _verClave
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        onPressed: () => setState(() => _verClave = !_verClave),
                        icon: Icon(
                          _verClave
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (valor) {
                      final error = UsuarioValidadores.contrasena(valor);
                      if (error != null) return error;
                      return utf8.encode(valor!).length > 72
                          ? 'Máximo 72 bytes.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mínimo 8 caracteres, con letras y números.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmacion,
                    enabled: !_enviando,
                    obscureText: !_verConfirmacion,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        tooltip: _verConfirmacion
                            ? 'Ocultar confirmación'
                            : 'Mostrar confirmación',
                        onPressed: () => setState(
                          () => _verConfirmacion = !_verConfirmacion,
                        ),
                        icon: Icon(
                          _verConfirmacion
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (valor) =>
                        valor == _clave.text && (valor?.isNotEmpty ?? false)
                        ? null
                        : 'Las contraseñas no coinciden.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    MensajesApp.nota(_error!, tipo: TipoMensaje.error),
                  ],
                  const SizedBox(height: 24),
                  AccionesAdaptables(
                    acciones: [
                      TextButton(
                        onPressed: _enviando
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton.icon(
                        onPressed: _enviando ? null : _guardar,
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_reset_rounded),
                        label: Text(
                          _enviando ? 'Actualizando…' : 'Cambiar contraseña',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

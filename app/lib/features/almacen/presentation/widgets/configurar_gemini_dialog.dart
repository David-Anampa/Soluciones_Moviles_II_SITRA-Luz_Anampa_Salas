import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../data/services/medicamento_ia_service.dart';

/// Diálogo para configurar y verificar la API Key de Google Gemini Vision en el dispositivo (HU-014 / HU-015).
class ConfigurarGeminiDialog extends StatefulWidget {
  const ConfigurarGeminiDialog({super.key});

  static Future<bool?> mostrar(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const ConfigurarGeminiDialog(),
    );
  }

  @override
  State<ConfigurarGeminiDialog> createState() => _ConfigurarGeminiDialogState();
}

class _ConfigurarGeminiDialogState extends State<ConfigurarGeminiDialog> {
  final TextEditingController _keyController = TextEditingController();
  final MedicamentoIaService _iaService = MedicamentoIaService();
  bool _ocultar = true;
  bool _cargando = true;
  bool _verificando = false;
  String? _estadoVerificacion;
  bool _verificacionExitosa = false;

  @override
  void initState() {
    super.initState();
    _cargarKeyActual();
  }

  Future<void> _cargarKeyActual() async {
    final actual = await MedicamentoIaService.obtenerApiKeyConfigurada();
    if (!mounted) return;
    setState(() {
      _keyController.text = actual;
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _probarClave() async {
    final valor = _keyController.text.replaceAll(RegExp(r'\s+'), '');
    if (valor.isEmpty) {
      setState(() {
        _estadoVerificacion = 'Pega primero tu API Key de Google AI Studio.';
        _verificacionExitosa = false;
      });
      return;
    }

    setState(() {
      _verificando = true;
      _estadoVerificacion = null;
    });

    try {
      final modelos = await _iaService.descubrirModelosDisponibles(valor);
      if (!mounted) return;
      if (modelos.isEmpty) {
        setState(() {
          _verificando = false;
          _verificacionExitosa = false;
          _estadoVerificacion =
              'La clave respondió pero no tiene modelos generateContent habilitados.';
        });
      } else {
        setState(() {
          _verificando = false;
          _verificacionExitosa = true;
          _estadoVerificacion =
              'Conexión exitosa con Google Gemini. Modelo principal detectado: ${modelos.first}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verificando = false;
        _verificacionExitosa = false;
        _estadoVerificacion = '$e';
      });
    }
  }

  Future<void> _guardar() async {
    final valor = _keyController.text.replaceAll(RegExp(r'\s+'), '');
    await MedicamentoIaService.guardarApiKey(valor);
    if (!mounted) return;
    MensajesApp.mostrar(
      context,
      valor.isEmpty
          ? 'Clave de Gemini eliminada. Se usará el catálogo de Supabase y lectura GS1 local.'
          : 'Clave de Gemini Vision guardada correctamente.',
      tipo: valor.isEmpty ? TipoMensaje.advertencia : TipoMensaje.exito,
    );
    Navigator.of(context).pop(valor.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return AlertaAdaptable(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.almacenColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.almacenColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Configurar Gemini Vision IA',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: _cargando
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingresa tu API Key de Google AI Studio (aistudio.google.com) para habilitar la lectura óptica multimodal de las 3 a 4 fotografías del empaque:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _keyController,
                  obscureText: _ocultar,
                  decoration: InputDecoration(
                    labelText: 'API Key de Google Gemini (AIza...)',
                    hintText: 'Pega aquí tu clave de Google AI Studio',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      tooltip: _ocultar ? 'Mostrar clave' : 'Ocultar clave',
                      onPressed: () => setState(() => _ocultar = !_ocultar),
                      icon: Icon(
                        _ocultar
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _verificando ? null : _probarClave,
                    icon: _verificando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(
                      _verificando
                          ? 'Verificando clave con Google AI Studio...'
                          : 'Probar conexión de mi API Key',
                    ),
                  ),
                ),
                if (_estadoVerificacion != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          (_verificacionExitosa
                                  ? AppColors.success
                                  : AppColors.error)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            (_verificacionExitosa
                                    ? AppColors.success
                                    : AppColors.error)
                                .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _verificacionExitosa
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 18,
                          color: _verificacionExitosa
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _estadoVerificacion!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.info,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La app detecta automáticamente el modelo Gemini activo en tu cuenta (como gemini-2.5-flash o gemini-2.5-flash-lite) para evitar errores 404.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        if (_keyController.text.trim().isNotEmpty)
          TextButton(
            onPressed: () {
              _keyController.clear();
              _guardar();
            },
            child: const Text(
              'Limpiar clave',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.almacenColor,
          ),
          onPressed: _guardar,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

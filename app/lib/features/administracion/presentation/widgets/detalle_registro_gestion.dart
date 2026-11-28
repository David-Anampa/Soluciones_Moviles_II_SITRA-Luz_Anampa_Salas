import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/tema_pedidos.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../data/gestion_registros_repository.dart';

Future<bool> mostrarRegistroGestion(
  BuildContext context, {
  required String entidad,
  required String id,
  required String nombre,
  required Map<String, String> datos,
  bool eliminar = false,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Theme(
        data: TemaPedidos.aplicar(context, TemaPedidos.rolActual(context)),
        child: _DetalleRegistro(
          entidad: entidad,
          id: id,
          nombre: nombre,
          datos: datos,
          eliminar: eliminar,
        ),
      ),
    ) ??
    false;

class _DetalleRegistro extends StatefulWidget {
  final String entidad, id, nombre;
  final Map<String, String> datos;
  final bool eliminar;
  const _DetalleRegistro({
    required this.entidad,
    required this.id,
    required this.nombre,
    required this.datos,
    required this.eliminar,
  });
  @override
  State<_DetalleRegistro> createState() => _DetalleRegistroState();
}

class _DetalleRegistroState extends State<_DetalleRegistro> {
  final _repo = GestionRegistrosRepository();
  Map<String, dynamic>? _relaciones;
  String? _error;
  bool _cargando = true, _guardando = false;
  static const _nombres = {
    'dispensaciones': 'Fichas',
    'auditoria_trazabilidad': 'Auditoría de operaciones',
    'profile_areas': 'Usuarios asignados',
    'doctor_areas': 'Profesionales asignados',
    'inventario_stock': 'Registros de stock',
    'pedidos_abastecimiento': 'Pedidos de abastecimiento',
    'operaciones_ingreso_lote': 'Operaciones de ingreso',
    'diferencias_abastecimiento': 'Reportes de diferencias',
    'diferencias_abastecimiento_historial': 'Historial de diferencias',
    'notificaciones': 'Notificaciones',
    'dispositivos_push': 'Dispositivos vinculados',
    'claves_ia': 'Claves de IA administradas',
    'procedencias_paciente': 'Procedencias registradas',
  };
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await _repo.detalle(widget.entidad, widget.id);
      if (mounted) setState(() => _relaciones = r);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'No se pudieron consultar las relaciones.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminar() async {
    if (_guardando || _relaciones?['puede_eliminar'] != true) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _repo.eliminar(
        widget.entidad,
        widget.id,
        _relaciones?['version'] as String?,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is PostgrestException
              ? e.message
              : 'No llegó confirmación. Actualiza la lista antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refs = (_relaciones?['relaciones'] as List? ?? []).cast<Map>();
    final permitido = _relaciones?['puede_eliminar'] == true;
    return PopScope(
      canPop: !_guardando,
      child: DialogoAdaptable(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FranjaPedidos(
                titulo: widget.eliminar
                    ? 'Confirmar eliminación'
                    : 'Detalle del registro',
                icono: widget.eliminar
                    ? Icons.delete_outline_rounded
                    : Icons.visibility_outlined,
              ),
              const SizedBox(height: 18),
              Text(
                widget.nombre,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              for (final dato in widget.datos.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${dato.key}: ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: dato.value),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              const FranjaPedidos(
                titulo: 'Registros relacionados',
                icono: Icons.account_tree_outlined,
              ),
              const SizedBox(height: 14),
              if (_cargando) const Center(child: CircularProgressIndicator()),
              if (!_cargando && _relaciones != null) ...[
                if (refs.isEmpty) const Text('0 registros relacionados.'),
                for (final r in refs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_nombres[r['tabla']] ?? r['tabla']}: ${r['cantidad']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        for (final a in r['areas'] as List? ?? [])
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${a['area']}: ${a['cantidad']}'),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Auditoría administrativa conservada: ${_relaciones!['auditoria_conservada']} registros.',
                ),
                if (!permitido) ...[
                  const SizedBox(height: 12),
                  MensajesApp.nota(
                    _relaciones!['motivo'] as String,
                    tipo: TipoMensaje.advertencia,
                  ),
                ],
                if (widget.eliminar && permitido) ...[
                  const SizedBox(height: 14),
                  MensajesApp.nota(
                    'Se eliminará este registro sin uso. La auditoría se conserva. Esta acción no se puede deshacer.',
                    tipo: TipoMensaje.advertencia,
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                MensajesApp.nota(_error!, tipo: TipoMensaje.error),
                TextButton.icon(
                  onPressed: _guardando ? null : _cargar,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar relaciones'),
                ),
              ],
              const SizedBox(height: 20),
              AccionesAdaptables(
                acciones: [
                  OutlinedButton(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(widget.eliminar ? 'Cancelar' : 'Cerrar'),
                  ),
                  if (widget.eliminar)
                    FilledButton.icon(
                      onPressed: _cargando || _guardando || !permitido
                          ? null
                          : _eliminar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        _guardando ? 'Eliminando…' : 'Eliminar registro',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResumenRelacionesGestion extends StatelessWidget {
  final Map<String, dynamic>? datos;
  const ResumenRelacionesGestion({super.key, required this.datos});
  @override
  Widget build(BuildContext context) {
    if (datos == null) {
      return const Text('Actualiza la vista para consultar los vínculos.');
    }
    final refs = datos!['relaciones'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FranjaPedidos(
          titulo: 'Registros relacionados',
          icono: Icons.account_tree_outlined,
        ),
        const SizedBox(height: 12),
        if (refs.isEmpty) const Text('0 registros relacionados.'),
        for (final r in refs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_DetalleRegistroState._nombres[r['tabla']] ?? r['tabla']}: ${r['cantidad']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final a in r['areas'] as List? ?? [])
                  Text('${a['area']}: ${a['cantidad']}'),
              ],
            ),
          ),
        Text(
          'Auditoría administrativa conservada: ${datos!['auditoria_conservada']} registros.',
        ),
        if (datos!['motivo'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: MensajesApp.nota(
              datos!['motivo'] as String,
              tipo: TipoMensaje.advertencia,
            ),
          ),
      ],
    );
  }
}

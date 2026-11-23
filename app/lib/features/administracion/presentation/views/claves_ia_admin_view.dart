import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../almacen/data/services/medicamento_ia_service.dart';
import '../../data/claves_ia_repository.dart';
import '../widgets/catalogo_estilo.dart';

class ClavesIaAdminView extends StatefulWidget {
  const ClavesIaAdminView({super.key});
  @override
  State<ClavesIaAdminView> createState() => _ClavesIaAdminViewState();
}

class _ClavesIaAdminViewState extends State<ClavesIaAdminView> {
  final _repo = ClavesIaRepository();
  List<ClaveIa> _claves = [];
  bool _cargando = true, _operando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _esAdmin) _cargar();
    });
  }

  bool get _esAdmin {
    final user = context.read<AuthViewModel>().currentUser;
    return user?.activo == true && user?.rol == UserRole.administrador;
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await MedicamentoIaService.limpiarCredencialesLocalesAntiguas();
      final claves = await _repo.listar();
      if (mounted) {
        setState(() {
          _claves = claves;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ClavesIaRepository.mensajeError(e);
          _cargando = false;
        });
      }
    }
  }

  Future<void> _operar(String accion, ClaveIa clave) async {
    final eliminar = accion == 'ELIMINAR';
    final confirmar = await MensajesApp.confirmar(
      context,
      titulo: eliminar ? 'Eliminar clave' : 'Usar esta clave',
      mensaje: eliminar
          ? '¿Eliminar “${clave.nombre}”?${clave.activa ? ' El reconocimiento por IA quedará sin una clave activa hasta que elijas otra.' : ''} Su registro de auditoría se conserva.'
          : '“${clave.nombre}” será la clave utilizada en los próximos reconocimientos. Las demás quedarán guardadas sin uso.',
      accion: eliminar ? 'Eliminar clave' : 'Usar clave',
      destructivo: eliminar,
    );
    if (!confirmar || !mounted) return;
    setState(() => _operando = true);
    try {
      await _repo.gestionar(accion, id: clave.id);
      if (!mounted) return;
      MensajesApp.mostrar(
        context,
        eliminar ? 'Clave eliminada.' : 'Clave en uso actualizada.',
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        MensajesApp.mostrar(
          context,
          ClavesIaRepository.mensajeError(e),
          tipo: TipoMensaje.error,
        );
      }
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  Future<void> _editar([ClaveIa? clave]) async {
    final guardada = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioClave(clave: clave, repo: _repo),
    );
    if (guardada == true && mounted) {
      // El guardado ya terminó: un fallo al refrescar no debe presentarse como fallo al guardar.
      MensajesApp.mostrar(
        context,
        clave == null ? 'Clave añadida de forma segura.' : 'Clave actualizada.',
      );
      await _cargar();
    }
  }

  Future<void> _comprobarConexion() async {
    setState(() => _operando = true);
    try {
      final modelos = await MedicamentoIaService()
          .descubrirModelosDisponibles();
      if (!mounted) return;
      MensajesApp.mostrar(
        context,
        modelos.isEmpty
            ? 'La clave respondió, pero no tiene modelos de reconocimiento habilitados.'
            : 'Conexión con Gemini verificada.',
        tipo: modelos.isEmpty ? TipoMensaje.advertencia : TipoMensaje.exito,
      );
    } catch (e) {
      if (mounted) {
        MensajesApp.mostrar(
          context,
          e is MedicamentoIaException
              ? e.message
              : 'No se pudo verificar la conexión. Intenta nuevamente.',
          tipo: TipoMensaje.error,
        );
      }
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} · ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_esAdmin) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('Acceso exclusivo de Administrador.')),
        ),
      );
    }
    return Theme(
      data: CatalogoEstilo.tema(context),
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/admin')),
          toolbarHeight: DisenoAdaptable.altoCabecera(context),
          title: const Text('Claves de IA'),
        ),
        body: SafeArea(
          child: ContenidoAdaptable(
            anchoMaximo: 800,
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: CatalogoEstilo.pastel,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.key_rounded,
                              color: CatalogoEstilo.rojo,
                              size: 32,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Reconocimiento con Gemini',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Administra las claves que utiliza Almacén para reconocer medicamentos. Se guardan cifradas y nunca se muestran.',
                              style: TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        MensajesApp.nota(_error!, tipo: TipoMensaje.error),
                        TextButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Volver a cargar'),
                        ),
                      ] else ...[
                        FilledButton.icon(
                          onPressed: _operando ? null : () => _editar(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Añadir clave'),
                        ),
                        if (_claves.any((c) => c.activa)) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _operando ? null : _comprobarConexion,
                            icon: const Icon(Icons.wifi_tethering_rounded),
                            label: Text(
                              _operando ? 'Procesando…' : 'Comprobar conexión',
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_claves.isEmpty)
                          MensajesApp.nota(
                            'Todavía no hay claves. Añade la primera para activar el reconocimiento.',
                          )
                        else if (!_claves.any((c) => c.activa))
                          MensajesApp.nota(
                            'No hay una clave en uso. Elige una para activar el reconocimiento.',
                            tipo: TipoMensaje.advertencia,
                          ),
                        for (final clave in _claves) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: clave.activa
                                    ? CatalogoEstilo.rojo.withValues(alpha: .4)
                                    : const Color(0xFFE5E5EA),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: CatalogoEstilo.pastel,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.key_rounded,
                                        color: CatalogoEstilo.rojo,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            clave.nombre,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            clave.activa
                                                ? 'En uso'
                                                : 'Guardada',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: clave.activa
                                                  ? CatalogoEstilo.rojo
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.lock_rounded,
                                      size: 20,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Creada: ${_fecha(clave.creada)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Última edición: ${_fecha(clave.actualizada)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 14),
                                AccionesAdaptables(
                                  anchoMinimo: 140,
                                  acciones: [
                                    if (!clave.activa)
                                      OutlinedButton.icon(
                                        onPressed: _operando
                                            ? null
                                            : () => _operar('ACTIVAR', clave),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        label: const Text('Usar clave'),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: _operando
                                          ? null
                                          : () => _editar(clave),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Editar'),
                                    ),
                                    TextButton.icon(
                                      onPressed: _operando
                                          ? null
                                          : () => _operar('ELIMINAR', clave),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FormularioClave extends StatefulWidget {
  final ClaveIa? clave;
  final ClavesIaRepository repo;
  const _FormularioClave({this.clave, required this.repo});
  @override
  State<_FormularioClave> createState() => _FormularioClaveState();
}

class _FormularioClaveState extends State<_FormularioClave> {
  late final _nombre = TextEditingController(text: widget.clave?.nombre ?? '');
  final _secreto = TextEditingController();
  bool _guardando = false;
  String? _error;
  @override
  void dispose() {
    _nombre.dispose();
    _secreto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    final secreto = _secreto.text.trim();
    if (nombre.length < 2 || nombre.length > 60) {
      setState(() => _error = 'Escribe un nombre de 2 a 60 caracteres.');
      return;
    }
    if ((widget.clave == null || secreto.isNotEmpty) &&
        (secreto.length < 20 ||
            secreto.length > 200 ||
            secreto.contains(RegExp(r'\s')))) {
      setState(() => _error = 'Ingresa una clave válida, sin espacios.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repo.gestionar(
        widget.clave == null ? 'CREAR' : 'EDITAR',
        id: widget.clave?.id,
        nombre: nombre,
        clave: secreto.isEmpty ? null : secreto,
      );
      _secreto.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ClavesIaRepository.mensajeError(e);
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: AlertaAdaptable(
      title: Text(
        widget.clave == null ? 'Añadir clave de Gemini' : 'Editar clave',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nombre,
            enabled: !_guardando,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Nombre de la clave',
              hintText: 'Ej. Cuenta principal',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secreto,
            enabled: !_guardando,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(
              labelText: widget.clave == null
                  ? 'Clave de API'
                  : 'Nueva clave (opcional)',
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.clave == null
                ? 'La primera clave se activa automáticamente. Las siguientes quedan guardadas hasta que elijas usarlas.'
                : 'Deja vacía la nueva clave para conservar la actual. La clave guardada no se puede revelar.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            MensajesApp.nota(_error!, tipo: TipoMensaje.error),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: const Icon(Icons.lock_outline),
          label: Text(_guardando ? 'Guardando…' : 'Guardar clave'),
        ),
      ],
    ),
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../../core/widgets/menu_modulos.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../almacen/data/services/medicamento_ia_service.dart';
import '../../data/claves_ia_repository.dart';
import '../widgets/catalogo_estilo.dart';

ThemeData _temaClaves(BuildContext context) {
  final base = CatalogoEstilo.tema(context);
  final borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE3E3E9)),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: Colors.white,
      border: borde,
      enabledBorder: borde,
      focusedBorder: borde.copyWith(
        borderSide: const BorderSide(color: CatalogoEstilo.rojo, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CatalogoEstilo.rojo,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: CatalogoEstilo.rojo,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: Color(0xFFE9BBBB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: CatalogoEstilo.rojo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

Widget _accionIcono(String etiqueta, IconData icono, VoidCallback? onPressed) =>
    IconButton.filledTonal(
      tooltip: etiqueta,
      onPressed: onPressed,
      icon: Icon(icono),
      style: IconButton.styleFrom(
        backgroundColor: CatalogoEstilo.pastel,
        foregroundColor: CatalogoEstilo.rojo,
      ),
    );

class _ComprobacionClaveDialog extends StatefulWidget {
  const _ComprobacionClaveDialog();
  @override
  State<_ComprobacionClaveDialog> createState() =>
      _ComprobacionClaveDialogState();
}

class _ComprobacionClaveDialogState extends State<_ComprobacionClaveDialog> {
  Timer? _cierre;
  bool _cargando = true, _exito = false;
  String _mensaje = 'Estamos verificando la conexión segura con Gemini.';
  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    var exito = false;
    String mensaje;
    try {
      final modelos = await MedicamentoIaService()
          .descubrirModelosDisponibles();
      exito = modelos.isNotEmpty;
      mensaje = exito
          ? 'Comprobación exitosa. Tu API key está lista para el reconocimiento.'
          : 'La API key respondió, pero no tiene modelos de reconocimiento habilitados.';
    } catch (e) {
      mensaje = e is MedicamentoIaException
          ? e.message
          : 'No se pudo verificar la conexión. Intenta nuevamente.';
    }
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _exito = exito;
      _mensaje = mensaje;
    });
    _cierre = Timer(Duration(seconds: exito ? 3 : 7), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _cierre?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DialogoAdaptable(
    anchoMaximo: 400,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _cargando
                ? const SizedBox(
                    key: ValueKey('cargando'),
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(
                    _exito
                        ? Icons.verified_rounded
                        : Icons.error_outline_rounded,
                    key: ValueKey(_exito),
                    size: 56,
                    color: _exito
                        ? const Color(0xFF23713B)
                        : CatalogoEstilo.rojo,
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            _cargando
                ? 'Comprobando API key'
                : _exito
                ? 'API key verificada'
                : 'Revisa tu conexión o clave',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          _accionIcono(
            'Cerrar',
            Icons.close_rounded,
            () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}

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
      builder: (_) => Theme(
        data: _temaClaves(context),
        child: _FormularioClave(clave: clave, repo: _repo),
      ),
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
    if (_operando) return;
    setState(() => _operando = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Theme(
          data: _temaClaves(context),
          child: const _ComprobacionClaveDialog(),
        ),
      );
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} · ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

  Widget _resumen(String titulo, int cantidad, IconData icono) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFECE3E3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: CatalogoEstilo.rojo, size: 26),
        const SizedBox(height: 12),
        Text(
          '$cantidad',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: CatalogoEstilo.rojo,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Future<void> _verDetalle(ClaveIa clave) async {
    if (_operando) return;
    final accion = await showDialog<String>(
      context: context,
      builder: (ctx) => Theme(
        data: _temaClaves(context),
        child: AlertaAdaptable(
          title: Text(clave.nombre),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MensajesApp.nota(
                'La clave está cifrada y no se puede revelar. ${clave.activa ? 'Se utiliza para el reconocimiento.' : 'Está guardada y no se utiliza actualmente.'}',
              ),
              const SizedBox(height: 18),
              const Text(
                'Fecha de creación',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(_fecha(clave.creada), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              const Text(
                'Última edición',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _fecha(clave.actualizada),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                if (!clave.activa)
                  _accionIcono(
                    'Usar clave',
                    Icons.check_circle_rounded,
                    () => Navigator.pop(ctx, 'ACTIVAR'),
                  ),
                _accionIcono(
                  'Editar clave',
                  Icons.edit_rounded,
                  () => Navigator.pop(ctx, 'EDITAR'),
                ),
                _accionIcono(
                  'Eliminar clave',
                  Icons.delete_outline_rounded,
                  () => Navigator.pop(ctx, 'ELIMINAR'),
                ),
                _accionIcono(
                  'Cerrar',
                  Icons.close_rounded,
                  () => Navigator.pop(ctx),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (accion == 'EDITAR') {
      await _editar(clave);
    } else if (accion == 'ACTIVAR' || accion == 'ELIMINAR') {
      await _operar(accion!, clave);
    }
  }

  Widget _tarjetaClave(ClaveIa clave) => Semantics(
    button: true,
    label:
        '${clave.nombre}, ${clave.activa ? 'en uso' : 'guardada'}. Ver detalles y opciones.',
    child: Material(
      color: CatalogoEstilo.pastel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: clave.activa
              ? CatalogoEstilo.rojo.withValues(alpha: .35)
              : Colors.white,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _operando ? null : () => _verDetalle(clave),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 190),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    size: 36,
                    color: CatalogoEstilo.rojo,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  clave.nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: clave.activa
                        ? const Color(0xFFE4F2E8)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    clave.activa ? 'En uso' : 'Guardada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: clave.activa
                          ? const Color(0xFF23713B)
                          : const Color(0xFF64646D),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Editada ${_fecha(clave.actualizada).split(' · ').first}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64646D),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(
                  Icons.more_horiz_rounded,
                  size: 22,
                  color: CatalogoEstilo.rojo,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

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
      data: _temaClaves(context),
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
                        CuadriculaPanel(
                          esResumen: true,
                          children: [
                            _resumen(
                              'Claves registradas',
                              _claves.length,
                              Icons.key_rounded,
                            ),
                            _resumen(
                              'En uso',
                              _claves.where((c) => c.activa).length,
                              Icons.verified_user_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        AccionesAdaptables(
                          anchoMinimo: 140,
                          acciones: [
                            FilledButton.icon(
                              onPressed: _operando ? null : () => _editar(),
                              icon: const Icon(Icons.add_moderator_rounded),
                              label: const Text('Añadir clave'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _operando || !_claves.any((c) => c.activa)
                                  ? null
                                  : _comprobarConexion,
                              icon: const Icon(Icons.verified_user_rounded),
                              label: const Text('Comprobar'),
                            ),
                          ],
                        ),
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
                        if (_claves.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Mis claves',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Toca una tarjeta para ver sus fechas y opciones.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64646D),
                            ),
                          ),
                          const SizedBox(height: 14),
                          CuadriculaPanel(
                            children: [
                              for (final clave in _claves) _tarjetaClave(clave),
                            ],
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
        Wrap(
          spacing: 12,
          alignment: WrapAlignment.end,
          children: [
            _accionIcono(
              'Cancelar',
              Icons.close_rounded,
              _guardando ? null : () => Navigator.pop(context),
            ),
            IconButton.filled(
              tooltip: _guardando ? 'Guardando clave' : 'Guardar clave',
              style: IconButton.styleFrom(
                backgroundColor: CatalogoEstilo.rojo,
                foregroundColor: Colors.white,
              ),
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

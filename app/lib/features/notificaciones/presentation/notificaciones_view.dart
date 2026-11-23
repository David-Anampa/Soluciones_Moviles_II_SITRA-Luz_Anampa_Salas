import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/menu_modulos.dart';
import '../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../auth/domain/entities/user_entity.dart';

class NotificacionesView extends StatefulWidget {
  final String? avisoId;
  const NotificacionesView({super.key, this.avisoId});
  @override
  State<NotificacionesView> createState() => _NotificacionesViewState();
}

class _NotificacionesViewState extends State<NotificacionesView> {
  final _service = NotificationService.instance;
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  String? _error;
  String? _result;
  bool _loading = true;
  bool _busy = false;
  bool _more = false;
  int _revision = 0;
  int _generation = 0;
  static const _columns =
      'id,titulo,mensaje,origen,creado_en,leido_en,envio_estado';

  @override
  void initState() {
    super.initState();
    _revision = _service.revision;
    _service.addListener(_changed);
    unawaited(_load());
  }

  void _changed() {
    if (_revision != _service.revision) {
      _revision = _service.revision;
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant NotificacionesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avisoId != widget.avisoId) unawaited(_load());
  }

  Future<void> _load({bool append = false}) async {
    final generation = ++_generation;
    final user = _db.auth.currentUser?.id;
    if (user == null) return;
    final offset = append ? _items.length : 0;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _db
          .from('notificaciones')
          .select(_columns)
          .eq('usuario_id', user)
          .order('creado_en', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + 19);
      Map<String, dynamic>? selected;
      if (widget.avisoId != null) {
        selected = await _db
            .from('notificaciones')
            .select(_columns)
            .eq('usuario_id', user)
            .eq('id', widget.avisoId!)
            .maybeSingle();
        if (selected != null && selected['leido_en'] == null) {
          await _db.rpc('leer_notificacion', params: {'p_id': selected['id']});
          selected['leido_en'] = DateTime.now().toUtc().toIso8601String();
        }
      }
      if (!mounted ||
          generation != _generation ||
          user != _db.auth.currentUser?.id) {
        return;
      }
      setState(() {
        for (final row in rows) {
          if (row['id'] == selected?['id']) {
            row['leido_en'] = selected?['leido_en'];
          }
        }
        _items = append ? [..._items, ...rows] : rows;
        _selected = selected;
        _more = rows.length == 20;
        if (widget.avisoId != null && selected == null) {
          _error = 'Este aviso no está disponible para tu cuenta.';
        }
      });
      await _service.refreshUnread();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _error = 'No se pudo cargar la bandeja. Desliza para reintentar.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _run(bool test) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = test
          ? 'El aviso se enviará en 5 segundos después de activar los permisos. Pulsa Inicio de Android si quieres verlo fuera de la app.'
          : null;
    });
    final result = test
        ? await _service.sendTest()
        : await _service.registerDevice() ??
              'Avisos activados en este dispositivo.';
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  Future<void> _open(Map<String, dynamic> item) async {
    try {
      await _db.rpc('leer_notificacion', params: {'p_id': item['id']});
      if (!mounted) return;
      setState(() {
        item['leido_en'] ??= DateTime.now().toUtc().toIso8601String();
        _selected = item;
      });
      await _service.refreshUnread();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo marcar el aviso como leído. Intenta nuevamente.',
        );
      }
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final color = switch (user?.rol.dbValue) {
      'ALMACEN' => AppColors.almacenColor,
      'FARMACIA' => AppColors.farmaciaColor,
      'JEFATURA_FARMACIA' => AppColors.jefaturaColor,
      _ => AppColors.primary,
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          tooltip: 'Volver al inicio',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (user != null) context.go(AppRoutes.routeForRole(user.rol));
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CabeceraMenu(
                      titulo: 'Tus avisos, en un solo lugar',
                      icono: Icons.notifications_active_rounded,
                      color: color,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListenableBuilder(
                              listenable: _service,
                              builder: (context, _) => Row(
                                children: [
                                  Icon(
                                    _service.registered
                                        ? Icons.notifications_active_rounded
                                        : Icons.notifications_outlined,
                                    color: color,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _service.registered
                                          ? 'Este dispositivo está conectado'
                                          : 'Activa los avisos en este dispositivo',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (_service.unread > 0)
                                    Badge(label: Text('${_service.unread}')),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Prueba la conexión sin crear pedidos. Los avisos leídos no cambian las solicitudes pendientes.',
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _busy ? null : () => _run(false),
                                  icon: const Icon(
                                    Icons.notifications_none_rounded,
                                  ),
                                  label: const Text('Activar avisos'),
                                ),
                                FilledButton.icon(
                                  onPressed: _busy ? null : () => _run(true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: color,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.send_rounded),
                                  label: const Text(
                                    'Probar en este dispositivo',
                                  ),
                                ),
                              ],
                            ),
                            if (_busy)
                              const Padding(
                                padding: EdgeInsets.only(top: 14),
                                child: LinearProgressIndicator(),
                              ),
                            if (_result != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(_result!),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    if (_selected != null) ...[
                      const SizedBox(height: 20),
                      Card(
                        color: color.withValues(alpha: .08),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selected!['titulo'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(_selected!['mensaje'] as String),
                              const SizedBox(height: 12),
                              Text(_date(_selected!['creado_en'])),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    CabeceraMenu(
                      titulo: 'Historial de avisos',
                      icono: Icons.history_rounded,
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    if (_items.isEmpty && !_loading && _error == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.mark_email_read_outlined,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 12),
                            Text('Aún no tienes notificaciones.'),
                          ],
                        ),
                      ),
                    for (final item in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _open(item),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withValues(
                                      alpha: .10,
                                    ),
                                    child: Icon(
                                      item['leido_en'] == null
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_none_rounded,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['titulo'] as String,
                                          style: TextStyle(
                                            fontWeight: item['leido_en'] == null
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          item['origen'] as String,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 5,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.schedule_rounded,
                                              size: 14,
                                            ),
                                            Text(
                                              _date(item['creado_en']),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (item['envio_estado'] == 'error')
                                          const Text(
                                            'Envío pendiente de revisión',
                                            style: TextStyle(
                                              color: AppColors.error,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (item['leido_en'] == null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 6,
                                        top: 6,
                                      ),
                                      child: Badge(backgroundColor: color),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_more && !_loading)
                      TextButton.icon(
                        onPressed: () => _load(append: true),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Ver más avisos'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    super.dispose();
  }
}

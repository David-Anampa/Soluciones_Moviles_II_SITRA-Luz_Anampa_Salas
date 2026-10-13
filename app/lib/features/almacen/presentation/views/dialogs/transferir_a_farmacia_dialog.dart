import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/lote_entity.dart';
import '../../../domain/entities/stock_almacen_entity.dart';
import '../../viewmodels/almacen_viewmodel.dart';

/// Diálogo para transferir stock de Almacén General a Farmacia Central.
class TransferirAFarmaciaDialog extends StatefulWidget {
  final List<StockAlmacenEntity> inventario;
  final StockAlmacenEntity? itemInicial;

  const TransferirAFarmaciaDialog({
    super.key,
    required this.inventario,
    this.itemInicial,
  });

  @override
  State<TransferirAFarmaciaDialog> createState() =>
      _TransferirAFarmaciaDialogState();
}

class _TransferirAFarmaciaDialogState extends State<TransferirAFarmaciaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();
  final _motivoController = TextEditingController(text: 'Reposición de stock para dispensación');

  StockAlmacenEntity? _selectedStock;

  @override
  void initState() {
    super.initState();
    if (widget.itemInicial != null) {
      _selectedStock = widget.itemInicial;
    } else if (widget.inventario.isNotEmpty) {
      // Filtrar aquellos que tengan stock disponible > 0
      final disponibles = widget.inventario.where((i) => i.cantidad > 0).toList();
      if (disponibles.isNotEmpty) {
        _selectedStock = disponibles.first;
      }
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  void _establecerCantidad(int cantidad) {
    if (_selectedStock == null) return;
    final max = _selectedStock!.cantidad;
    final valor = cantidad > max ? max : cantidad;
    _cantidadController.text = valor.toString();
  }

  Future<void> _ejecutarTransferencia() async {
    if (!_formKey.currentState!.validate() || _selectedStock == null) return;

    final cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
    if (cantidad <= 0 || cantidad > _selectedStock!.cantidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cantidad debe ser mayor a 0 y menor o igual al stock disponible.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final vm = context.read<AlmacenViewModel>();
    final exito = await vm.transferirStockAFarmacia(
      loteId: _selectedStock!.loteId,
      medicamentoId: _selectedStock!.medicamento.id,
      cantidad: cantidad,
      motivo: _motivoController.text.trim(),
    );

    if (!mounted) return;

    if (exito) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Transferencia de $cantidad unidades a Farmacia Central completada.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${vm.errorMessage ?? "No se pudo transferir"}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<AlmacenViewModel>().isSaving;
    final disponibles = widget.inventario.where((i) => i.cantidad > 0).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transferencia a Farmacia',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Movimiento físico entre depósitos',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Diagrama visual Origen -> Destino
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ORIGEN', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        Text('Almacén General', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.almacenColor)),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('DESTINO', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        Text('Farmacia Central', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.farmaciaColor)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Selector de Medicamento/Lote
              if (disponibles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No hay medicamentos con stock disponible en Almacén.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedStock?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Medicamento y Lote *',
                    prefixIcon: Icon(Icons.medication_rounded),
                  ),
                  items: disponibles.map((item) {
                    return DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        '${item.medicamento.nombreComercial} (Lote: ${item.lote.numeroLote} - Stock: ${item.cantidad})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      setState(() {
                        _selectedStock = disponibles.firstWhere((i) => i.id == id);
                      });
                    }
                  },
                ),

              if (_selectedStock != null) ...[
                const SizedBox(height: 12),

                // Resumen del Lote seleccionado
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Stock Físico en Almacén:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            '${_selectedStock!.cantidad} unidades',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.almacenColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Semáforo FEFO:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            _selectedStock!.lote.etiquetaFefo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _selectedStock!.lote.estadoFefo == EstadoFefo.critico ||
                                      _selectedStock!.lote.estadoFefo == EstadoFefo.vencido
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Cantidad a transferir
                TextFormField(
                  controller: _cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cantidad a Transferir *',
                    hintText: 'Máximo: ${_selectedStock!.cantidad}',
                    prefixIcon: const Icon(Icons.numbers_rounded),
                    suffixText: 'unidades',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Mayor a 0';
                    if (n > _selectedStock!.cantidad) {
                      return 'Supera el stock (${_selectedStock!.cantidad})';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // Atajos rápidos de cantidad (proporción uniforme al ancho del diálogo)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _establecerCantidad(10),
                        child: const Text(
                          '+10',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _establecerCantidad(25),
                        child: const Text(
                          '+25',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _establecerCantidad(50),
                        child: const Text(
                          '+50',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.primary.withOpacity(0.08),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _establecerCantidad(_selectedStock!.cantidad),
                        child: const Text(
                          'Todo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Motivo / Justificación
                TextFormField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Justificación',
                    hintText: 'Ej: Reposición de guardia, Pedido urgente',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          onPressed: isSaving || disponibles.isEmpty ? null : _ejecutarTransferencia,
          icon: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded),
          label: Text(isSaving ? 'TRANSFERIENDO...' : 'TRANSFERIR A FARMACIA'),
        ),
      ],
    );
  }
}

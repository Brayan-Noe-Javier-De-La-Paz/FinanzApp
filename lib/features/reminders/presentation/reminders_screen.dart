import 'package:finanzapp/features/reminders/data/reminder_repository.dart';
import 'package:finanzapp/features/transactions/data/transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart'; // <--- AGREGAR ESTO

// ... (resto de tu código)
// ... tus otros imports
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _reminderRepo = ReminderRepository();
  final _transactionRepo = TransactionRepository();

  Future<void> _pedirPermisos() async {
    // 1. Permiso de Notificaciones (Campanita)
    var statusNotif = await Permission.notification.status;
    if (!statusNotif.isGranted) {
      await Permission.notification.request();
    }
  }

  List<Map<String, dynamic>> _recordatorios = [];

  // Listas para el formulario de pago
  List<Map<String, dynamic>> _cuentas = [];
  List<Map<String, dynamic>> _categorias = [];

  double _saldoActual = 0.0;
  double _totalDeuda = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    setState(() => _isLoading = true);
    try {
      // 1. Cargar TODO en paralelo (Recordatorios, Saldo, Cuentas, Categorías)
      final results = await Future.wait([
        _reminderRepo.getRecordatoriosPendientes(),
        _transactionRepo.obtenerBalanceTotal(),
        _transactionRepo.getCuentas(),
        _transactionRepo.getCategorias(),
      ]);

      final listaRecordatorios = results[0] as List<Map<String, dynamic>>;
      final saldo = results[1] as double;
      final cuentas = results[2] as List<Map<String, dynamic>>;
      final categorias = results[3] as List<Map<String, dynamic>>;

      double deuda = 0;
      for (var r in listaRecordatorios) {
        deuda += (r['monto'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _recordatorios = listaRecordatorios;
          _saldoActual = saldo;
          _totalDeuda = deuda;
          _cuentas = cuentas;
          _categorias = categorias;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNCIÓN CLAVE: PROCESAR EL PAGO ---
  Future<bool> _confirmarYPagar(Map<String, dynamic> recordatorio) async {
    // Variables para capturar la selección del usuario
    String? idCuentaPago = _cuentas.isNotEmpty ? _cuentas.first['id'] : null;
    String? idCategoriaPago = _categorias.firstWhere(
        (c) => c['tipo'] == 'GASTO',
        orElse: () => _categorias.first)['id'];

    // Mostrar Diálogo
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Obligar a elegir
      builder: (ctx) => StatefulBuilder(
        // StatefulBuilder para actualizar los dropdowns dentro del diálogo
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text("Pagar: ${recordatorio['titulo']}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("¿Con qué dinero vas a pagar esto?"),
                const SizedBox(height: 20),

                // Dropdown Cuentas
                DropdownButtonFormField<String>(
                  initialValue: idCuentaPago,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: "Cuenta / Billetera",
                      prefixIcon: Icon(Icons.account_balance_wallet)),
                  items: _cuentas
                      .map((c) => DropdownMenuItem(
                          value: c['id'] as String, child: Text(c['nombre'])))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => idCuentaPago = v),
                ),
                const SizedBox(height: 10),

                // Dropdown Categoría (Para que salga bien en la gráfica)
                DropdownButtonFormField<String>(
                  initialValue: idCategoriaPago,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: "Categoría del Gasto",
                      prefixIcon: Icon(Icons.category)),
                  items: _categorias
                      .where((c) =>
                          c['tipo'] ==
                          'GASTO') // Solo mostrar categorías de gasto
                      .map((c) => DropdownMenuItem(
                          value: c['id'] as String, child: Text(c['nombre'])))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => idCategoriaPago = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, false), // Cancelar (No borrar)
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                onPressed: () =>
                    Navigator.pop(ctx, true), // Confirmar (Borrar y Pagar)
                child: const Text("PAGAR AHORA"),
              ),
            ],
          );
        },
      ),
    );

    if (confirmar == true && idCuentaPago != null && idCategoriaPago != null) {
      // --- LA MAGIA OCURRE AQUÍ ---
      try {
        // 1. Crear la transacción de Gasto Real
        await _transactionRepo.crearTransaccion(
          accountId: idCuentaPago!,
          categoryId: idCategoriaPago!,
          amount: (recordatorio['monto'] as num).toDouble(),
          type: 'GASTO',
          description: "Pago de: ${recordatorio['titulo']}",
          date: DateTime.now(),
        );

        // 2. Marcar el recordatorio como pagado (ya no pendiente)
        await _reminderRepo.marcarComoPagado(recordatorio['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("¡Deuda pagada y registrada!"),
                backgroundColor: Colors.green),
          );
        }
        if (mounted) {
          _cargarDatosCompletos(); // <--- AGREGA ESTO: Recalcula Deuda y Saldo Libre arriba
        }

        return true; // Permitir que el Dismissible borre la fila visualmente
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        return false;
      }
    }

    return false; // Si canceló, la fila regresa a su lugar
  }

  Future<bool> _confirmarYEliminar(Map<String, dynamic> item) async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("¿Eliminar Recordatorio?"),
            content: Text(
                "Se borrará '${item['titulo']}' de tus pendientes. Esta acción no se puede deshacer."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false), // No borrar
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  // Llama a tu repositorio para borrar
                  try {
                    // Asumo que tienes este método en tu repo, si no, agrégalo:
                    // await _client.from('recordatorios').delete().eq('id', id);
                    await _reminderRepo.eliminarRecordatorio(item['id']);

                    // También intentamos cancelar la notificación local si existe
                    // (Opcional, pero recomendado)
                    // await NotificationService().cancelarNotificacion(item['id_notificacion']);

                    if (mounted) {
                      Navigator.pop(ctx, true); // Sí borrar
                      _cargarDatosCompletos(); // Recargar saldo y lista
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Eliminado")));
                    }
                  } catch (e) {
                    print(e);
                    Navigator.pop(ctx, false);
                  }
                },
                child: const Text("Eliminar"),
              ),
            ],
          ),
        ) ??
        false; // Si toca fuera del diálogo, retorna false
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final saldoProyectado = _saldoActual - _totalDeuda;
    final esCritico = saldoProyectado < 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Compromisos"),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- TARJETA DE SIMULACIÓN ---
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: esCritico
                            ? Colors.red
                            : Colors.green.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text("Capacidad Económica Real",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _DatoResumen(
                              "Saldo", _saldoActual, Colors.blue, currency),
                          const Text("-",
                              style:
                                  TextStyle(fontSize: 20, color: Colors.grey)),
                          _DatoResumen(
                              "Deudas", _totalDeuda, Colors.red, currency),
                          const Text("=",
                              style:
                                  TextStyle(fontSize: 20, color: Colors.grey)),
                          _DatoResumen("Libre", saldoProyectado,
                              esCritico ? Colors.red : Colors.green, currency),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(),
// Botón temporal para probar si el sistema está vivo

                // --- LISTA INTELIGENTE ---
                Expanded(
                  child: _recordatorios.isEmpty
                      ? Center(
                          child: Text("¡Todo pagado! 🎉",
                              style: TextStyle(color: theme.disabledColor)))
                      : // Reemplaza tu ListView.builder con esto:

                      ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _recordatorios.length,
                          itemBuilder: (context, index) {
                            final item = _recordatorios[index];
                            final fecha = DateTime.parse(item['fecha_limite']);
                            final diasRestantes =
                                fecha.difference(DateTime.now()).inDays;

                            Color colorUrgencia = diasRestantes < 0
                                ? Colors.red
                                : (diasRestantes < 3
                                    ? Colors.orange
                                    : Colors.green);

                            return Dismissible(
                              key: Key(item['id']
                                  .toString()), // Asegúrate que sea String único

                              // 1. CAMBIO: Permitimos deslizar a ambos lados
                              direction: DismissDirection.horizontal,

                              // 2. FONDO DERECHA -> IZQUIERDA (ELIMINAR) 🔴
                              secondaryBackground: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12)),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text("ELIMINAR",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(width: 10),
                                    Icon(Icons.delete, color: Colors.white),
                                  ],
                                ),
                              ),

                              // 3. FONDO IZQUIERDA -> DERECHA (PAGAR) 🟢
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12)),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Row(children: [
                                  Icon(Icons.payment, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text("PAGAR AHORA",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))
                                ]),
                              ),

                              // 4. LÓGICA DE DECISIÓN
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  // Deslizó a la derecha -> PAGAR
                                  return await _confirmarYPagar(item);
                                } else {
                                  // Deslizó a la izquierda -> ELIMINAR
                                  return await _confirmarYEliminar(item);
                                }
                              },

                              child: Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        colorUrgencia.withOpacity(0.1),
                                    child: Icon(Icons.calendar_today,
                                        color: colorUrgencia, size: 20),
                                  ),
                                  title: Text(item['titulo'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(diasRestantes < 0
                                      ? "Venció hace ${diasRestantes.abs()} días"
                                      : "Vence en $diasRestantes días"),
                                  trailing: Text(currency.format(item['monto']),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      // Mantenemos el botón flotante para crear nuevos
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoCrear(context),
        label: const Text("Nuevo Compromiso"),
        icon: const Icon(Icons.add_alert),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ... (Mantén aquí el método _mostrarDialogoCrear que ya tenías)
  void _mostrarDialogoCrear(BuildContext context) {
    final tituloCtrl = TextEditingController();
    final montoCtrl = TextEditingController();

    // Solo necesitamos la fecha, la hora ya no importa
    DateTime fechaSelect = DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Agregar Compromiso"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(
                          labelText: "Título (Ej: Renta, Netflix)"),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: montoCtrl,
                      decoration:
                          const InputDecoration(labelText: "Monto a pagar"),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 20),

                    // --- SOLO SELECCIONAR FECHA ---
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.grey),
                        const SizedBox(width: 10),
                        const Text("Vence:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: fechaSelect,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setStateDialog(() => fechaSelect = picked);
                            }
                          },
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(fechaSelect),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    if (tituloCtrl.text.isEmpty || montoCtrl.text.isEmpty) {
                      return;
                    }

                    // Aseguramos que la fecha se guarde a las 12:00 PM para evitar problemas de zona horaria
                    final fechaFinal = DateTime(
                      fechaSelect.year,
                      fechaSelect.month,
                      fechaSelect.day,
                      12,
                      0,
                      0,
                    );

                    // Guardar en BD
                    await _reminderRepo.crearRecordatorio(
                      titulo: tituloCtrl.text,
                      monto: double.parse(montoCtrl.text),
                      fechaLimite: fechaFinal,
                      esRecurrente: false,
                    );

                    // ¡YA NO HAY NOTIFICACIONES LOCALES AQUÍ!
                    // El servidor de Supabase se encargará de avisar mañana.

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _cargarDatosCompletos(); // Recargar lista
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Compromiso guardado. FinanzApp te avisará cuando venza.")),
                      );
                    }
                  },
                  child: const Text("Guardar"),
                )
              ],
            );
          },
        );
      },
    );
  }
}

class _DatoResumen extends StatelessWidget {
  final String label;
  final double monto;
  final Color color;
  final NumberFormat fmt;
  const _DatoResumen(this.label, this.monto, this.color, this.fmt);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(fmt.format(monto),
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ],
    );
  }
}

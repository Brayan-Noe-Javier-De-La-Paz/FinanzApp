import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../data/transaction_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum Ordenamiento { masReciente, masAntiguo, mayorMonto, menorMonto }

class _HistoryScreenState extends State<HistoryScreen> {
  final _repository = TransactionRepository();

  // Datos Crudos (Originales)
  List<Map<String, dynamic>> _todosLosMovimientos = [];
  List<Map<String, dynamic>> _cuentas =
      []; // <--- NUEVO: Lista de cuentas para el filtro

  // Datos Filtrados (Para mostrar)
  List<Map<String, dynamic>> _movimientosVisibles = [];

  bool _isLoading = true;

  // ESTADO DE LOS FILTROS
  Ordenamiento _ordenActual = Ordenamiento.masReciente;
  String _filtroTipo = 'TODOS'; // TODOS, INGRESO, GASTO
  String _filtroCuentaId = 'TODAS'; // <--- NUEVO: Filtro por ID de cuenta

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // Cargamos Historial y Cuentas en paralelo
      final resultados = await Future.wait([
        _repository.obtenerHistorialCompleto(),
        _repository.getCuentas(),
      ]);

      if (mounted) {
        setState(() {
          _todosLosMovimientos = resultados[0];
          _cuentas = resultados[1];

          _aplicarFiltros(); // Ordenamos inicialmente
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback por si Future.wait falla con tipos, hacemos carga secuencial segura
      try {
        final historial = await _repository.obtenerHistorialCompleto();
        final cuentas = await _repository.getCuentas();
        if (mounted) {
          setState(() {
            _todosLosMovimientos = historial;
            _cuentas = cuentas;
            _aplicarFiltros();
            _isLoading = false;
          });
        }
      } catch (e2) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Lógica de Filtrado y Ordenamiento
  void _aplicarFiltros() {
    List<Map<String, dynamic>> temp = List.from(_todosLosMovimientos);

    // 1. Filtrar por Tipo (Ingreso/Gasto)
    if (_filtroTipo != 'TODOS') {
      temp = temp.where((m) => m['tipo'] == _filtroTipo).toList();
    }

    // 2. Filtrar por Cuenta (NUEVO)
    if (_filtroCuentaId != 'TODAS') {
      temp = temp.where((m) => m['id_cuenta'] == _filtroCuentaId).toList();
    }

    // 3. Ordenar
    temp.sort((a, b) {
      final fechaA = DateTime.parse(a['fecha_transaccion']);
      final fechaB = DateTime.parse(b['fecha_transaccion']);
      final montoA = (a['monto'] as num).toDouble();
      final montoB = (b['monto'] as num).toDouble();

      switch (_ordenActual) {
        case Ordenamiento.masReciente:
          return fechaB.compareTo(fechaA); // Descendente
        case Ordenamiento.masAntiguo:
          return fechaA.compareTo(fechaB); // Ascendente
        case Ordenamiento.mayorMonto:
          return montoB.compareTo(montoA); // Descendente
        case Ordenamiento.menorMonto:
          return montoA.compareTo(montoB); // Ascendente
      }
    });

    setState(() {
      _movimientosVisibles = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('dd MMM yyyy', 'es_MX');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial"),
        centerTitle: true,
        actions: [
          // BOTÓN DE ORDENAR
          PopupMenuButton<Ordenamiento>(
            icon: const Icon(Icons.sort),
            tooltip: "Ordenar por...",
            onSelected: (Ordenamiento result) {
              setState(() => _ordenActual = result);
              _aplicarFiltros();
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<Ordenamiento>>[
              const PopupMenuItem(
                  value: Ordenamiento.masReciente,
                  child: Text('Más recientes')),
              const PopupMenuItem(
                  value: Ordenamiento.masAntiguo, child: Text('Más antiguos')),
              const PopupMenuItem(
                  value: Ordenamiento.mayorMonto, child: Text('Mayor monto')),
              const PopupMenuItem(
                  value: Ordenamiento.menorMonto, child: Text('Menor monto')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ZONA DE FILTROS
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 5))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. FILTRO TIPO (Ingreso/Gasto)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _FilterChipPropio(
                        label: "Todos",
                        isSelected: _filtroTipo == 'TODOS',
                        onSelected: () {
                          setState(() => _filtroTipo = 'TODOS');
                          _aplicarFiltros();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChipPropio(
                        label: "Ingresos",
                        isSelected: _filtroTipo == 'INGRESO',
                        color: Colors.green,
                        onSelected: () {
                          setState(() => _filtroTipo = 'INGRESO');
                          _aplicarFiltros();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChipPropio(
                        label: "Gastos",
                        isSelected: _filtroTipo == 'GASTO',
                        color: Colors.red,
                        onSelected: () {
                          setState(() => _filtroTipo = 'GASTO');
                          _aplicarFiltros();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 2. FILTRO CUENTAS (Nueva Fila)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text("Cuenta: ",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey)),
                      const SizedBox(width: 5),

                      // Chip "Todas"
                      _FilterChipPropio(
                        label: "Todas",
                        isSelected: _filtroCuentaId == 'TODAS',
                        color: Colors.blueGrey,
                        onSelected: () {
                          setState(() => _filtroCuentaId = 'TODAS');
                          _aplicarFiltros();
                        },
                      ),
                      const SizedBox(width: 8),

                      // Chips Dinámicos de tus Cuentas
                      ..._cuentas.map((c) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _FilterChipPropio(
                            label: c['nombre'],
                            isSelected: _filtroCuentaId == c['id'],
                            color: Theme.of(context).primaryColor,
                            onSelected: () {
                              setState(() => _filtroCuentaId = c['id']);
                              _aplicarFiltros();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // LISTA
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _movimientosVisibles.isEmpty
                    ? const Center(child: Text("No se encontraron movimientos"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _movimientosVisibles.length,
                        itemBuilder: (context, index) {
                          final mov = _movimientosVisibles[index];
                          final esGasto = (mov['tipo'] == 'GASTO');
                          final categoria = mov['categorias'];
                          final fecha =
                              DateTime.parse(mov['fecha_transaccion']);
                          final cuenta = mov['cuentas'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: esGasto
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                child: Icon(
                                  _getIconData(categoria?['codigo_icono']),
                                  color: esGasto ? Colors.red : Colors.green,
                                ),
                              ),
                              title: Text(categoria?['nombre'] ?? 'General',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "${dateFormat.format(fecha)} • ${mov['descripcion'] ?? ''}"),
                                  // Nombre de la cuenta
                                  if (cuenta != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.account_balance_wallet,
                                              size: 12,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(cuenta['nombre'],
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontStyle: FontStyle.italic)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Text(
                                "${esGasto ? '-' : '+'}${currencyFormat.format(mov['monto'])}",
                                style: TextStyle(
                                  color: esGasto ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onLongPress: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (ctxSheet) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Barra decorativa superior
                                        Container(
                                          width: 40, height: 5,
                                          margin: const EdgeInsets.only(bottom: 20),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        // Opción: Editar
                                        ListTile(
                                          leading: const Icon(Icons.edit, color: Colors.blue),
                                          title: const Text("Editar movimiento"),
                                          onTap: () async {
                                            Navigator.pop(ctxSheet); // Cierra el menú inferior
                                            final recargar = await context.push('/add-transaction', extra: mov);
                                            if (recargar == true) _cargarDatos();
                                          },
                                        ),
                                        // Opción: Eliminar
                                        ListTile(
                                          leading: const Icon(Icons.delete, color: Colors.red),
                                          title: const Text("Eliminar registro", style: TextStyle(color: Colors.red)),
                                          onTap: () {
                                            Navigator.pop(ctxSheet); // Cierra el menú inferior
                                            // 3. LA CONFIRMACIÓN FINAL
                                            _mostrarDialogoConfirmacionEliminar(context, mov);
                                          },
                                        ),
                                        ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String? code) {
    switch (code) {
      case 'fastfood':
        return Icons.fastfood;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'home':
        return Icons.home;
      case 'movie':
        return Icons.movie;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'attach_money':
        return Icons.attach_money;
      case 'business_center':
        return Icons.business_center;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'flight':
        return Icons.flight;
      default:
        return Icons.category;
    }
  }
  void _mostrarDialogoConfirmacionEliminar(BuildContext context, Map<String, dynamic> mov) {
    showDialog(
      context: context,
      builder: (ctxDialog) => AlertDialog(
        title: const Text("¿Eliminar movimiento?"),
        content: const Text("Esta acción no se puede deshacer. Tu saldo se ajustará automáticamente para reflejar este cambio."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctxDialog),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctxDialog); // 1. Cerramos el diálogo rápido para dar sensación de fluidez
              
              try {
                // 2. Llamamos al cerebro matemático
                await _repository.eliminarTransaccion(mov['id']);
        
                // 3. Recargamos la interfaz para que el usuario vea su saldo regresar
                _cargarDatos();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Movimiento eliminado y saldo restaurado ✅")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Hubo un error al eliminar. Intenta de nuevo.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Sí, eliminar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Widget de Chip Reutilizable
class _FilterChipPropio extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color color;

  const _FilterChipPropio({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
          color: isSelected ? color : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      checkmarkColor: color,
      backgroundColor: Colors.grey[100],
      side: BorderSide(color: isSelected ? color : Colors.transparent),
    );
  }
  
}

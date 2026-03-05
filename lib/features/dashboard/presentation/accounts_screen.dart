import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../transactions/data/transaction_repository.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _repository = TransactionRepository();
  List<Map<String, dynamic>> _cuentas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
  }

  Future<void> _cargarCuentas() async {
    setState(() => _isLoading = true);
    try {
      // USAMOS LA FUNCIÓN QUE CALCULA EL SALDO REAL (igual que en el Home)
      final cuentas = await _repository.obtenerSaldosPorCuenta();
      if (mounted) setState(() { _cuentas = cuentas; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarCuenta(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("¿Eliminar $nombre?"),
        content: const Text("⚠️ CUIDADO: Se borrarán también todas las transacciones asociadas a esta cuenta."),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => ctx.pop(true), child: const Text("ELIMINAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar == true) {
      await _repository.eliminarCuenta(id);
      _cargarCuentas(); // Recargamos la lista
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Scaffold(
      appBar: AppBar(title: const Text("Administrar Cuentas")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _cuentas.length,
            itemBuilder: (context, index) {
              final c = _cuentas[index];
              final esCredito = c['es_credito'] == true;
              // Usamos saldo_actual (que viene del cálculo)
              final saldoReal = c['saldo_actual']; 
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esCredito ? Colors.red[100] : Colors.green[100],
                    child: Icon(
                      esCredito ? Icons.credit_card : Icons.account_balance_wallet,
                      color: esCredito ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(c['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(esCredito ? "Crédito" : "Efectivo/Débito"),
                  
                  // Mostramos el Saldo Real
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currencyFormat.format(saldoReal),
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 15,
                          color: esCredito ? Colors.red : Colors.green
                        ),
                      ),
                      // MENÚ DE OPCIONES (Editar / Borrar)
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final recargar = await context.push('/add-account', extra: c);
                            if (recargar == true) _cargarCuentas();
                          } else if (value == 'delete') {
                            _eliminarCuenta(c['id'], c['nombre']);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text("Editar")]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text("Eliminar", style: TextStyle(color: Colors.red))]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final recargar = await context.push('/add-account');
          if (recargar == true) _cargarCuentas();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
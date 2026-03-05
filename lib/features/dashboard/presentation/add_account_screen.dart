import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../transactions/data/transaction_repository.dart';

class AddAccountScreen extends StatefulWidget {
  final Map<String, dynamic>? cuentaEditar; // <--- NUEVO

  const AddAccountScreen({super.key, this.cuentaEditar});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _repository = TransactionRepository();
  final _nombreController = TextEditingController();
  final _saldoController = TextEditingController();

  bool _esCredito = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.cuentaEditar != null) {
      // MODO EDICIÓN: Llenamos los datos
      _nombreController.text = widget.cuentaEditar!['nombre'];
      // Ojo: Aquí mostramos el saldo BASE (inicial), no el calculado con gastos,
      // para no confundir al modificar la base.
      _saldoController.text = widget.cuentaEditar!['saldo'].toString();
      _esCredito = widget.cuentaEditar!['es_credito'] == true;
    }
  }

  Future<void> _guardar() async {
    if (_nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Ponle un nombre")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final saldo = double.tryParse(_saldoController.text) ?? 0.0;

      if (widget.cuentaEditar != null) {
        // ACTUALIZAR
        await _repository.editarCuenta(
          id: widget.cuentaEditar!['id'],
          nombre: _nombreController.text,
          saldoInicial: saldo,
          esCredito: _esCredito,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Cuenta actualizada")));
        }
      } else {
        // CREAR
        await _repository.crearCuenta(
          nombre: _nombreController.text,
          saldoInicial: saldo,
          esCredito: _esCredito,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Cuenta creada")));
        }
      }

      if (mounted) context.pop(true); // Regresar y recargar
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.cuentaEditar != null;

    return Scaffold(
      appBar: AppBar(title: Text(esEdicion ? "Editar Cuenta" : "Nueva Cuenta")),
      // 1. El formulario deslizable
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: "Nombre",
                prefixIcon: Icon(Icons.account_balance),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text("¿Es Tarjeta de Crédito?"),
              subtitle: const Text("Marca esto si es una cuenta de deuda."),
              value: _esCredito,
              onChanged: (val) {
                setState(() {
                  _esCredito = val;
                  if (_esCredito) {
                    _saldoController.text = "0.00";
                  }
                });
              },
              secondary: Icon(_esCredito
                  ? Icons.credit_card
                  : Icons.account_balance_wallet),
            ),

            const SizedBox(height: 10),

            Visibility(
              visible: !_esCredito,
              child: Column(
                children: [
                  TextField(
                    controller: _saldoController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Saldo Inicial (Lo que tienes ya)",
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // ❌ AQUÍ BORRAMOS EL Spacer() ❌
            // Dejamos un espacio fijo grande al final por si el usuario scrollea
            const SizedBox(height: 100),
          ],
        ),
      ),
      // 👇 2. EL BOTÓN SE QUEDA FIJO ABAJO 👇
      bottomSheet: Container(
        padding: const EdgeInsets.all(24.0),
        color: Theme.of(context)
            .scaffoldBackgroundColor, // Para que el fondo combine
        width: double.infinity,
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _guardar,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : Text(esEdicion ? "ACTUALIZAR" : "CREAR CUENTA"),
          ),
        ),
      ),
    );
  }
}

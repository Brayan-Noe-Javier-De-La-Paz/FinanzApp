import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // <--- ASEGÚRATE DE TENER ESTE IMPORT
import '../data/transaction_repository.dart';
import 'package:flutter/services.dart'; // <--- Para los InputFormatters

class AddTransactionScreen extends StatefulWidget {
  final Map<String, dynamic>? params; 

  const AddTransactionScreen({super.key, this.params});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _repository = TransactionRepository();
  
  final _montoController = TextEditingController();
  final _descController = TextEditingController();
  
  // VARIABLES DE ESTADO
  String _modo = 'GASTO'; 
  String? _idCuentaSeleccionada;      
  String? _idCuentaOrigenAbono;       
  String? _idCategoriaSeleccionada;
  
  // AQUÍ ESTÁ LA VARIABLE QUE FALTABA 👇
  DateTime _fechaSeleccionada = DateTime.now(); 

  bool _cuentaFija = false; 
  bool _isLoading = false;

  List<Map<String, dynamic>> _todasLasCuentas = [];
  List<Map<String, dynamic>> _todasLasCategorias = [];

  @override
  void initState() {
    super.initState();
    // Procesar parámetros iniciales
    if (widget.params != null) {
      // 1. Si es edición
      if (widget.params!['id'] != null) {
         final t = widget.params!;
         _modo = t['tipo'];
         _montoController.text = t['monto'].toString();
         _descController.text = t['descripcion'] ?? '';
         _idCuentaSeleccionada = t['id_cuenta'];
         _idCategoriaSeleccionada = t['id_categoria'];
         _fechaSeleccionada = DateTime.parse(t['fecha_transaccion']); // Cargar fecha existente
      } 
      // 2. Si es nuevo flujo
      else {
        _modo = widget.params!['tipo'] ?? 'GASTO';
        if (widget.params!['cuenta_fija_id'] != null) {
          _idCuentaSeleccionada = widget.params!['cuenta_fija_id'];
          _cuentaFija = true;
        }
        if (widget.params!['cuenta_destino_id'] != null) {
          _idCuentaSeleccionada = widget.params!['cuenta_destino_id'];
          _cuentaFija = true;
        }
      }
    }
    _cargarListas();
  }

  Future<void> _cargarListas() async {
    final cuentas = await _repository.getCuentas();
    final categorias = await _repository.getCategorias();
    
    if (mounted) {
      setState(() {
        _todasLasCuentas = cuentas;
        _todasLasCategorias = categorias;
        
        // Auto-selección inteligente
        if (_idCuentaSeleccionada == null && _todasLasCuentas.isNotEmpty) {
           _idCuentaSeleccionada = _todasLasCuentas.first['id'];
        }
        if (_modo == 'ABONO' && _todasLasCuentas.isNotEmpty) {
           try {
             _idCuentaOrigenAbono = _todasLasCuentas.firstWhere((c) => c['es_credito'] == false)['id'];
           } catch (e) { /* No hay cuentas debito */ }
        }
      });
    }
  }

  Future<void> _guardar() async {
    if (_montoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Falta el monto")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final monto = double.parse(_montoController.text);
      final desc = _descController.text.isEmpty 
          ? (_modo == 'ABONO' ? 'Pago de Tarjeta' : 'Movimiento') 
          : _descController.text;

      if (_modo == 'ABONO') {
        if (_idCuentaOrigenAbono == null) throw "Selecciona de dónde sale el dinero";
        
        // 1. Restar del Origen -> GASTO (Usamos la fecha seleccionada)
        await _repository.crearTransaccion(
          accountId: _idCuentaOrigenAbono!,
          categoryId: null, 
          amount: monto,
          type: 'GASTO', 
          description: "Pago a Tarjeta: $desc",
          date: _fechaSeleccionada, // <--- USAMOS LA FECHA ELEGIDA
        );

        // 2. Sumar al Destino -> INGRESO (Usamos la fecha seleccionada)
        await _repository.crearTransaccion(
          accountId: _idCuentaSeleccionada!, 
          categoryId: null, 
          amount: monto,
          type: 'INGRESO', 
          description: "Abono recibido",
          date: _fechaSeleccionada, // <--- USAMOS LA FECHA ELEGIDA
        );

      } else {
        // Lógica Normal (Edición o Creación)
        if (_idCategoriaSeleccionada == null) throw "Selecciona una categoría";
        
        if (widget.params != null && widget.params!['id'] != null) {
           // EDITAR EXISTENTE
           await _repository.editarTransaccion(
            id: widget.params!['id'],
            accountId: _idCuentaSeleccionada!,
            categoryId: _idCategoriaSeleccionada!,
            amount: monto,
            type: _modo,
            description: desc,
            date: _fechaSeleccionada, // <--- USAMOS LA FECHA ELEGIDA
          );
        } else {
           // CREAR NUEVO
           await _repository.crearTransaccion(
            accountId: _idCuentaSeleccionada!,
            categoryId: _idCategoriaSeleccionada!,
            amount: monto,
            type: _modo,
            description: desc,
            date: _fechaSeleccionada, // <--- USAMOS LA FECHA ELEGIDA
          );
        }
      }

      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAbono = _modo == 'ABONO';
    
    // Títulos y Colores
    String titulo = "Nuevo Movimiento";
    Color colorTema = Colors.blue;
    if (_modo == 'INGRESO') { titulo = "Nuevo Ingreso"; colorTema = Colors.green; }
    if (_modo == 'GASTO') { titulo = "Nuevo Gasto"; colorTema = Colors.red; }
    if (esAbono) { titulo = "Abonar a Tarjeta"; colorTema = Colors.blueAccent; }

    // Filtros
    final cuentasOrigenDisponibles = _todasLasCuentas.where((c) => c['es_credito'] == false).toList();
    final categoriasVisibles = _todasLasCategorias.where((c) => c['tipo'] == (_modo == 'ABONO' ? 'GASTO' : _modo)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(titulo), backgroundColor: colorTema),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            
            // 1. MONTO
      // 1. MONTO
            TextField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              // --- AGREGAMOS ESTO ---
              inputFormatters: [
                // Solo permite números y un punto
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), 
              ],
              // ---------------------
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: colorTema),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                prefixText: "\$ ",
                border: InputBorder.none,
                hintText: "0.00",
              ),
            ),
            const Divider(),
            const SizedBox(height: 20),

            // 2. FORMULARIO
            if (esAbono) ...[
              const Text("¿De dónde sale el dinero?", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _idCuentaOrigenAbono,
                decoration: const InputDecoration(
                  labelText: "Cuenta Origen (Débito)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
                items: cuentasOrigenDisponibles.map((c) => DropdownMenuItem(
                  value: c['id'].toString(),
                  child: Text("${c['nombre']} (\$${c['saldo']})"), 
                )).toList(),
                onChanged: (val) => setState(() => _idCuentaOrigenAbono = val),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.arrow_downward),
              const SizedBox(height: 20),
               ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text("Destino (Tarjeta)"),
                subtitle: Text(_getNombreCuenta(_idCuentaSeleccionada)),
                tileColor: Colors.grey[100],
              ),

            ] else ...[
              // Selector de Cuenta
              if (!_cuentaFija) 
                DropdownButtonFormField<String>(
                  initialValue: _idCuentaSeleccionada,
                  decoration: const InputDecoration(labelText: "Cuenta", border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance_wallet)),
                  items: _todasLasCuentas.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nombre']))).toList(),
                  onChanged: (val) => setState(() => _idCuentaSeleccionada = val),
                )
              else 
                ListTile(
                  leading: Icon(_modo == 'GASTO' ? Icons.credit_card : Icons.account_balance),
                  title: Text(_modo == 'GASTO' ? "Pagando con:" : "Cuenta:"),
                  subtitle: Text(_getNombreCuenta(_idCuentaSeleccionada), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              
              const SizedBox(height: 20),

              // Selector de Categoría
              DropdownButtonFormField<String>(
                initialValue: _idCategoriaSeleccionada,
                decoration: const InputDecoration(labelText: "Categoría", border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                items: categoriasVisibles.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nombre']))).toList(),
                onChanged: (val) => setState(() => _idCategoriaSeleccionada = val),
              ),
            ],

            const SizedBox(height: 20),

            
            // 3. DESCRIPCIÓN
            TextField(
              controller: _descController,
              // --- AGREGAMOS ESTO ---
              maxLength: 50, // Muestra contador 0/50 y bloquea si pasas
              inputFormatters: [
                 // Opcional: Si quieres bloquear emojis para evitar problemas en PDF
                 // FilteringTextInputFormatter.deny(RegExp(r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])')),
              ],
              // ---------------------
              decoration: const InputDecoration(
                labelText: "Nota / Descripción", 
                prefixIcon: Icon(Icons.note), 
                border: OutlineInputBorder(),
                counterText: "", // Oculta el contador visual si no te gusta (o quítalo para ver 10/50)
              ),
            ),

            const SizedBox(height: 20),

            // 4. SELECTOR DE FECHA (RECUPERADO)
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaSeleccionada,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(), // ✅ El límite es el "Ahora"
                  locale: const Locale('es', 'ES'), // Si falla, quita esta línea de locale
                );
                if (picked != null) {
                  setState(() => _fechaSeleccionada = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Fecha",
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 30),
            
            // 5. BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _guardar,
                style: ElevatedButton.styleFrom(backgroundColor: colorTema),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(esAbono ? "REALIZAR ABONO" : "GUARDAR $_modo", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNombreCuenta(String? id) {
    if (id == null) return "...";
    final c = _todasLasCuentas.firstWhere((element) => element['id'] == id, orElse: () => {'nombre': 'Desconocida'});
    return c['nombre'];
  }
  @override
  void dispose() {
    _montoController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
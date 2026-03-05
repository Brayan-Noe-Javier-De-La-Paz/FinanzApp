import 'package:flutter/material.dart';
import '/features/transactions/data/transaction_repository.dart'; // Ajusta la ruta si es necesario

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> with SingleTickerProviderStateMixin {
  final _repository = TransactionRepository();
  List<Map<String, dynamic>> _categorias = [];
  bool _isLoading = true;
  late TabController _tabController;

  final Color _colorNaranja = const Color(0xFFFD5F00);

  // Lista de íconos disponibles para elegir
  final List<String> _iconosDisponibles = [
    'category', 'fastfood', 'restaurant', 'directions_car', 'flight', 
    'home', 'movie', 'local_hospital', 'school', 'business_center', 
    'shopping_cart', 'attach_money', 'computer', 'fitness_center'
  ];

  // Paleta de colores para las categorías
  final List<String> _coloresDisponibles = [
    '#F44336', '#E91E63', '#9C27B0', '#3F51B5', '#2196F3', 
    '#4CAF50', '#FF9800', '#FF5722', '#795548', '#607D8B'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarCategorias();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    setState(() => _isLoading = true);
    try {
      final categorias = await _repository.getCategorias();
      setState(() {
        _categorias = categorias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al cargar")));
    }
  }

  // --- MODAL PARA CREAR / EDITAR ---
  void _mostrarModalCategoria({Map<String, dynamic>? categoriaActual, required String tipo}) {
    final bool esEdicion = categoriaActual != null;
    final TextEditingController nombreController = TextEditingController(text: esEdicion ? categoriaActual['nombre'] : '');
    String iconoSeleccionado = esEdicion ? categoriaActual['codigo_icono'] : 'category';
    String colorSeleccionado = esEdicion ? categoriaActual['color_hex'] : _coloresDisponibles[0];
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, // Evita que el teclado lo tape
              left: 20, right: 20, top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(esEdicion ? "Editar Categoría" : "Nueva Categoría ($tipo)", 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // 1. NOMBRE
                  TextField(
                    controller: nombreController,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 20,
                    decoration: const InputDecoration(labelText: "Nombre de la categoría", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),

                  // 2. SELECCIÓN DE ÍCONO
                  const Text("Elige un ícono:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _iconosDisponibles.length,
                      itemBuilder: (context, index) {
                        final iconoCode = _iconosDisponibles[index];
                        final estaSeleccionado = iconoSeleccionado == iconoCode;
                        return GestureDetector(
                          onTap: () => setStateModal(() => iconoSeleccionado = iconoCode),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: estaSeleccionado ? _colorNaranja.withOpacity(0.2) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: estaSeleccionado ? _colorNaranja : Colors.grey.withOpacity(0.3)),
                            ),
                            child: Icon(_getIconData(iconoCode), color: estaSeleccionado ? _colorNaranja : Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. SELECCIÓN DE COLOR
                  const Text("Elige un color:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _coloresDisponibles.length,
                      itemBuilder: (context, index) {
                        final hex = _coloresDisponibles[index];
                        final color = Color(int.parse(hex.replaceAll('#', '0xFF')));
                        final estaSeleccionado = colorSeleccionado == hex;
                        return GestureDetector(
                          onTap: () => setStateModal(() => colorSeleccionado = hex),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: estaSeleccionado ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: estaSeleccionado ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : [],
                            ),
                            child: estaSeleccionado ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 4. BOTÓN GUARDAR
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _colorNaranja),
                      onPressed: guardando ? null : () async {
                        if (nombreController.text.trim().isEmpty) return;
                        setStateModal(() => guardando = true);

                        try {
                          if (esEdicion) {
                            await _repository.editarCategoria(
                              id: categoriaActual['id'],
                              nombre: nombreController.text.trim(),
                              codigoIcono: iconoSeleccionado,
                              colorHex: colorSeleccionado,
                            );
                          } else {
                            await _repository.crearCategoria(
                              nombre: nombreController.text.trim(),
                              tipo: tipo,
                              codigoIcono: iconoSeleccionado,
                              colorHex: colorSeleccionado,
                            );
                          }
                          
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            _cargarCategorias(); // Recargar lista
                          }
                        } catch (e) {
                          setStateModal(() => guardando = false);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al guardar", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                        }
                      },
                      child: guardando 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(esEdicion ? "ACTUALIZAR" : "CREAR", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dividimos las listas filtrándolas matemáticamente
    final gastos = _categorias.where((c) => c['tipo'] == 'GASTO').toList();
    final ingresos = _categorias.where((c) => c['tipo'] == 'INGRESO').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Categorías"),
        backgroundColor: _colorNaranja,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          tabs: const [
            Tab(text: "GASTOS", icon: Icon(Icons.arrow_upward)),
            Tab(text: "INGRESOS", icon: Icon(Icons.arrow_downward)),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _colorNaranja))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListaCategorias(gastos),
                _buildListaCategorias(ingresos),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _colorNaranja,
        onPressed: () {
          // Detectamos en qué pestaña está para crear el tipo correcto
          final tipoActual = _tabController.index == 0 ? 'GASTO' : 'INGRESO';
          _mostrarModalCategoria(tipo: tipoActual);
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nueva", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Helper para pintar la lista (reutilizable para ambas pestañas)
  Widget _buildListaCategorias(List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) return const Center(child: Text("No hay categorías en esta sección"));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final cat = lista[index];
        Color colorCat = Colors.grey;
        try {
          colorCat = Color(int.parse(cat['color_hex'].replaceAll('#', '0xFF')));
        } catch (e) {} // Fallback gris

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorCat.withOpacity(0.2),
              child: Icon(_getIconData(cat['codigo_icono']), color: colorCat),
            ),
            title: Text(cat['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _mostrarModalCategoria(categoriaActual: cat, tipo: cat['tipo']), // Abre modal de edición
            ),
          ),
        );
      },
    );
  }

  IconData _getIconData(String? code) {
    switch (code) {
      case 'fastfood': return Icons.fastfood;
      case 'restaurant': return Icons.restaurant;
      case 'directions_car': return Icons.directions_car;
      case 'home': return Icons.home;
      case 'movie': return Icons.movie;
      case 'local_hospital': return Icons.local_hospital;
      case 'school': return Icons.school;
      case 'attach_money': return Icons.attach_money;
      case 'business_center': return Icons.business_center;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'flight': return Icons.flight;
      case 'computer': return Icons.computer;
      case 'fitness_center': return Icons.fitness_center;
      default: return Icons.category;
    }
  }
}
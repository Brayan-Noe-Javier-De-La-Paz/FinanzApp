import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

// 👇 Ajusta esta ruta a donde tengas tu main.dart 👇
import '../../main.dart'; 

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final supabase = Supabase.instance.client;
  
  final TextEditingController _nombreController = TextEditingController();
  String _monedaSeleccionada = '\$';
  String _temaSeleccionado = 'system'; // 'system', 'light', o 'dark'
  
  bool _isLoading = false;
  final Color _colorNaranja = const Color(0xFFFD5F00);

  @override
  void initState() {
    super.initState();
    _cargarDatosActuales();
  }

  void _cargarDatosActuales() {
    final user = supabase.auth.currentUser;
    final metadata = user?.userMetadata ?? {};

    setState(() {
      _nombreController.text = metadata['full_name'] ?? '';
      _monedaSeleccionada = metadata['currency'] ?? '\$';
      _temaSeleccionado = metadata['theme'] ?? 'system';
    });
  }

  Future<void> _guardarPreferencias() async {
    if (_nombreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El nombre no puede estar vacío 🛑")),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // 1. Guardar en Supabase
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nombreController.text.trim(),
            'currency': _monedaSeleccionada,
            'theme': _temaSeleccionado,
          },
        ),
      );
      
      // 2. Avisarle al "Megáfono" global (main.dart) para cambiar el color
      if (_temaSeleccionado == 'dark') {
        appThemeNotifier.value = ThemeMode.dark;
      } else if (_temaSeleccionado == 'light') {
        appThemeNotifier.value = ThemeMode.light;
      } else {
        appThemeNotifier.value = ThemeMode.system;
      }
      
      if (mounted) {
       // context.pop(); // Regresar a la pantalla anterior
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Preferencias actualizadas correctamente ✅")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al guardar", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tus Preferencias"),
        backgroundColor: _colorNaranja,
        foregroundColor: Colors.white,
      ),
      // Usamos ListView para que sea scrolleable y se vea estructurado
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          
          // --- SECCIÓN 1: PERFIL ---
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text("PERFIL PÚBLICO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _nombreController,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Nombre visible",
                      prefixIcon: Icon(Icons.person_outline),
                      border: InputBorder.none, // Quitamos el borde para que se fusione con la tarjeta
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 30),

          // --- SECCIÓN 2: AJUSTES DE LA APP ---
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text("AJUSTES DE LA APLICACIÓN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Moneda
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _monedaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: "Moneda Principal",
                      prefixIcon: Icon(Icons.attach_money),
                      border: InputBorder.none,
                    ),
                    items: const [
                      DropdownMenuItem(value: '\$', child: Text('Pesos / Dólares (\$)' )),
                      DropdownMenuItem(value: '€', child: Text('Euros (€)' )),
                      DropdownMenuItem(value: '£', child: Text('Libras (£)' )),
                      DropdownMenuItem(value: 'S/', child: Text('Soles (S/)' )),
                    ],
                    onChanged: (val) => setState(() => _monedaSeleccionada = val!),
                  ),
                  
                  const Divider(height: 30),
                  
                  // Tema (El nuevo selector de 3 opciones)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _temaSeleccionado,
                    decoration: const InputDecoration(
                      labelText: "Tema Visual",
                      prefixIcon: Icon(Icons.palette_outlined),
                      border: InputBorder.none,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('Seguir al sistema (Teléfono)')),
                      DropdownMenuItem(value: 'light', child: Text('Modo Claro ☀️')),
                      DropdownMenuItem(value: 'dark', child: Text('Modo Oscuro 🌙')),
                    ],
                    onChanged: (val) => setState(() => _temaSeleccionado = val!),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 40),

          // --- BOTÓN DE GUARDAR ---
          SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorNaranja,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _isLoading ? null : _guardarPreferencias,
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
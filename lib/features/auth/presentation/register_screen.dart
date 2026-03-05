import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController(); // Nuevo: Para el nombre
  bool _isLoading = false;

  Future<void> _registrarse() async {
    // 1. Validaciones (igual que antes)
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      _mostrarError("Por favor llena todos los campos");
      return;
    }
    if (password != confirmPassword) {
      _mostrarError("Las contraseñas no coinciden");
      return;
    }
    if (password.length < 6) {
      _mostrarError("La contraseña debe tener al menos 6 caracteres");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // PASO 1: Crear usuario en Supabase Auth
      final AuthResponse res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name}, // Metadata opcional
      );
      
      final user = res.user;

      if (user != null) {
        // PASO 2: Crear el PERFIL (Obligatorio por tu base de datos)
        // Usamos upsert: si ya existe (por algún trigger automático), actualiza el nombre.
        // Si no existe, lo crea. Esto evita el error de llave foránea.
        await supabase.from('perfiles').upsert({
          'id': user.id,
          'email': email,
          'nombre_completo': name,
          'simbolo_moneda': '\$', // Valor por defecto según tu esquema
        });

        // PASO 3: Crear la CUENTA INICIAL (Ajustado a tu esquema REAL)
        await supabase.from('cuentas').insert({
          'id_usuario': user.id,      
          'nombre': 'Efectivo',       
          'saldo': 0.00,              
          'es_credito': false         
          // NOTA: Eliminamos 'color', 'icono', 'tipo' porque NO existen en tu tabla cuentas
        });
      }

      // Éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Cuenta creada correctamente!")),
        );
        context.go('/home');
      }

    } on AuthException catch (e) {
      _mostrarError(e.message);
    } catch (e) {
      print("Error detallado: $e"); // Míralo en la consola si falla
      _mostrarError("Error en el registro: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyMedium?.color),
          onPressed: () => context.pop(), // Regresar al Login
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.person_add_alt_1, size: 60, color: theme.primaryColor),
              const SizedBox(height: 20),
              Text("Crear Cuenta", style: theme.textTheme.headlineMedium),
              const SizedBox(height: 30),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: "Nombre Completo",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Correo Electrónico",
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: "Contraseña",
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: "Confirmar Contraseña",
                          prefixIcon: Icon(Icons.verified_user),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registrarse,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "REGISTRARME",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
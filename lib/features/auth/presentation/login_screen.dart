import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _iniciarSesion() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Intentamos loguear con Supabase
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Si funciona, el Router en main.dart detectará la sesión 
      // y nos llevará al Home automáticamente.
      if (mounted) {
        context.go('/home');
      }

    } on AuthException catch (e) {
      // Error específico de autenticación (ej: contraseña mala)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Error genérico
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ocurrió un error inesperado"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos los colores del tema actual (Claro u Oscuro)
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // El fondo ya se pone solo gracias a tu AppTheme
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Logo o Icono
          Hero(
  tag: 'app_logo',
  // CAMBIAMOS A Image.asset PARA PNGs
  child: Image.asset(
    Theme.of(context).brightness == Brightness.dark
        ? 'assets/logos/logo_dark.png'   // <-- Ojo a la extensión .png
        : 'assets/logos/logo_light.png', // <-- Ojo a la extensión .png
    height: 150,
  ),
),
              const SizedBox(height: 20),
              
              Text(
                "FinanzApp",
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                "Tu asistente financiero inteligente",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 40),

              // 2. Tarjeta del Formulario
              Card(
                // El color de la tarjeta cambia según el modo (Blanco o Azul Oscuro)
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
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
                      const SizedBox(height: 30),

                      // Botón de Acción (Naranja)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _iniciarSesion,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "INGRESAR",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 3. Link a Registro
              TextButton(
                onPressed: () {
                  context.push('/register'); // Navegar a la pantalla de registro
                },
                child: Text(
                  "¿No tienes cuenta? Regístrate aquí",
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
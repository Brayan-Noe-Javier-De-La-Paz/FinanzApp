import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class SeguridadScreen extends StatefulWidget {
  const SeguridadScreen({super.key});

  @override
  State<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends State<SeguridadScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // 🔑 DIÁLOGO PARA CAMBIAR CONTRASEÑA
  Future<void> _mostrarDialogoPassword() async {
    final passwordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool obscureText = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Cambiar Contraseña"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Ingresa tu nueva contraseña. Mínimo 6 caracteres.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscureText,
                  decoration: InputDecoration(
                    labelText: "Nueva Contraseña",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setStateDialog(() => obscureText = !obscureText),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordCtrl,
                  obscureText: obscureText,
                  decoration: const InputDecoration(
                    labelText: "Confirmar Contraseña",
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFD5F00), foregroundColor: Colors.white),
                onPressed: () async {
                  if (passwordCtrl.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La contraseña es muy corta")));
                    return;
                  }
                  if (passwordCtrl.text != confirmPasswordCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Las contraseñas no coinciden")));
                    return;
                  }

                  Navigator.pop(ctx); // Cierra el diálogo
                  await _actualizarDatos(password: passwordCtrl.text);
                },
                child: const Text("Actualizar"),
              ),
            ],
          );
        },
      ),
    );
  }

  // 📧 DIÁLOGO PARA CAMBIAR CORREO
  Future<void> _mostrarDialogoCorreo() async {
    final correoCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cambiar Correo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Te enviaremos un enlace de confirmación a tu nueva dirección para validar el cambio.", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: correoCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Nuevo Correo Electrónico",
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFD5F00), foregroundColor: Colors.white),
            onPressed: () async {
              if (!correoCtrl.text.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ingresa un correo válido")));
                return;
              }
              Navigator.pop(ctx);
              await _actualizarDatos(email: correoCtrl.text.trim());
            },
            child: const Text("Enviar Enlace"),
          ),
        ],
      ),
    );
  }

  // 🚀 EL MOTOR DE ACTUALIZACIÓN (Se comunica con Supabase)
  Future<void> _actualizarDatos({String? password, String? email}) async {
    setState(() => _isLoading = true);
    try {
      if (password != null) {
        await supabase.auth.updateUser(UserAttributes(password: password));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Contraseña actualizada exitosamente"), backgroundColor: Colors.green));
      } 
      
      if (email != null) {
        await supabase.auth.updateUser(UserAttributes(email: email));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📧 Enlace enviado. Revisa la bandeja del nuevo correo."), backgroundColor: Colors.blue));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seguridad y Acceso"),
        backgroundColor: const Color(0xFFFD5F00),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFD5F00)))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text("CREDENCIALES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.email, color: Colors.white)),
                      title: const Text("Correo Electrónico"),
                      subtitle: Text(user?.email ?? "Sin correo"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _mostrarDialogoCorreo,
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.password, color: Colors.white)),
                      title: const Text("Contraseña"),
                      subtitle: const Text("••••••••"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _mostrarDialogoPassword,
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
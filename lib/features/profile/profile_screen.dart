import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart'; // Ajusta la ruta de los puntos suspensivos según dónde esté tu main.dart
import 'package:image_picker/image_picker.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  String? _avatarUrl; // Para guardar el link de la foto
  bool _subiendoFoto = false; // Para mostrar una ruedita de carga
  String _nombre = 'Cargando...';
  String _email = 'Cargando...';
  final Color _colorNaranja = const Color(0xFFFD5F00);

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

 void _cargarDatosUsuario() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _nombre = user.userMetadata?['full_name'] ?? 'Usuario FinanzApp';
        _email = user.email ?? 'Sin correo';
        _avatarUrl = user.userMetadata?['avatar_url']; // <-- LEEMOS LA FOTO
      });
    }
  }

  Future<void> _cerrarSesion() async {
    await supabase.auth.signOut();
    if (mounted) context.go('/login');
  }
// --- NUEVA FUNCIÓN: Subir Foto de Perfil ---
  Future<void> _cambiarFotoPerfil() async {
    final ImagePicker picker = ImagePicker();
    
    // 1. Abrir la galería (calidad al 30% para que suba rápido y no gaste datos)
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30);
    if (image == null) return; // Si el usuario se arrepiente y cierra la galería

    setState(() => _subiendoFoto = true);

    try {
      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last;
      final user = supabase.auth.currentUser!;
      
      // Creamos un nombre único para el archivo basado en su ID y la hora
      final filePath = '${user.id}/perfil_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // 2. Subir al disco duro de Supabase (Bucket 'avatars')
      await supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(upsert: true), // Permite sobreescribir
      );

      // 3. Obtener el link público de la foto recién subida
      final imageUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      // 4. Guardar ese link en los metadatos del usuario
      await supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': imageUrl}),
      );

      // 5. Refrescar la pantalla
      setState(() {
        _avatarUrl = imageUrl;
        _subiendoFoto = false;
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto actualizada ✅")));

    } catch (e) {
      setState(() => _subiendoFoto = false);
      print("💥 ERROR AL SUBIR FOTO: $e"); // <-- Esto lo imprimirá en tu consola
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e", style: const TextStyle(color: Colors.white)), // <-- Te lo mostrará en pantalla
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4), // Le damos más tiempo para leerlo
          )
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Un color de fondo sutil para las tarjetas de opciones
    final cardColor = isDark ? const Color(0xFF1B3A52) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        // 👇 TUS ÍCONOS NARANJAS EN LA BARRA SUPERIOR 👇
        iconTheme: IconThemeData(color: _colorNaranja),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: _colorNaranja,
            onPressed: () {
              // Futura pantalla de ayuda o FAQ
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Centro de ayuda próximamente")),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- 1. CABECERA DEL PERFIL ---
// --- 1. CABECERA DEL PERFIL ---
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _subiendoFoto ? null : _cambiarFotoPerfil,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: _colorNaranja.withOpacity(0.2),
                          // Si hay foto, la mostramos. Si no, mostramos la inicial.
                          backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                          child: _subiendoFoto
                              ? const CircularProgressIndicator(color: Colors.white)
                              : (_avatarUrl == null
                                  ? Text(
                                      _nombre.isNotEmpty ? _nombre[0].toUpperCase() : 'U',
                                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _colorNaranja),
                                    )
                                  : null),
                        ),
                        // Un pequeño ícono de cámara para que el usuario sepa que puede editarla
                        if (!_subiendoFoto)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: _colorNaranja, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                      ],
                    ),
                  ),
                  
                  // 👇 ESTOS TEXTOS Y CIERRES FALTABAN 👇
                  const SizedBox(height: 16),
                  Text(
                    _nombre,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: TextStyle(fontSize: 16, color: Theme.of(context).disabledColor), // Se usa el theme del context
                  ),
                ],
              ),
            ),
            // 👆 HASTA AQUÍ 👆

            const SizedBox(height: 40),
            

            // --- 2. SECCIÓN DE CONFIGURACIONES ---
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  _OpcionPerfil(
                    icono: Icons.person_outline,
                    colorIcono: _colorNaranja,
                    titulo: "Datos Personales",
                    subtitulo: "Edita tu nombre y preferencias",
                    onTap: () async {
                      // Usamos push y recargamos el perfil al volver por si cambió su nombre
                      await context.push('/preferences');
                      _cargarDatosUsuario(); // <-- Llama a tu función que recarga el nombre en el Perfil
                    },
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 20),
                  _OpcionPerfil(
                    icono: Icons.category_outlined,
                    colorIcono: _colorNaranja,
                    titulo: "Administrar Categorías",
                    subtitulo: "Crea o modifica tus categorías de gastos",
                      onTap: () {
                      context.push('/manage-categories');
                    },
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 20),
                  _OpcionPerfil(
                    icono: Icons.lock_outline,
                    colorIcono: _colorNaranja,
                    titulo: "Seguridad",
                    subtitulo: "Cambiar contraseña y protección",
                    onTap: () => context.push('/seguridad'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- 3. BOTÓN DE CERRAR SESIÓN ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text("Cerrar Sesión",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _cerrarSesion,
              ),
            ),

            const SizedBox(height: 20),
            Text("FinanzApp v1.0.0",
                style: TextStyle(color: theme.disabledColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // --- NUEVA FUNCIÓN: Panel de Preferencias ---
  
}

// --- WIDGET REUTILIZABLE PARA LAS OPCIONES ---
class _OpcionPerfil extends StatelessWidget {
  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _OpcionPerfil({
    required this.icono,
    required this.colorIcono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });
// --- NUEVA FUNCIÓN: Editar Datos Personales ---

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorIcono.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icono, color: colorIcono),
      ),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitulo, style: const TextStyle(fontSize: 12)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}

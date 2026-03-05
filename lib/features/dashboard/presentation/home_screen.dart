import 'package:finanzapp/features/transactions/data/transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Para detectar kIsWeb
import 'dart:async'; // Para poder "escuchar" el internet en vivo
import 'package:connectivity_plus/connectivity_plus.dart';
import '/config/network_service.dart'; // Asegúrate de que la ruta coincida con donde guardaste tu archivo
import '/core/sync_service.dart'; // Ajusta la ruta a donde guardaste tu sync_service.dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = TransactionRepository();
  final PageController _pageController =
      PageController(viewportFraction: 0.9); // <--- VARIABLE DE CLASE
  // Variables de Estado
  bool _isLoading = true;
  List<Map<String, dynamic>> _movimientos = []; // Todos los movimientos
  String _nombreUsuario = 'Usuario';
  String? _avatarUrl;
  late StreamSubscription<List<ConnectivityResult>> _suscripcionInternet;
  bool _mostroAvisoDesconexion = false; // Para que no nos llene de mensajes repetidos
  // CAROUSEL
  List<Map<String, dynamic>> _cuentasCalculadas = [];
  int _paginaActual = 0;

 @override
  void initState() {
    super.initState();
   _arrancarMotor(); 
    _cargarDatos();
    
    // 👇 NUEVO: ESCUCHAR EL INTERNET EN VIVO 👇
    _suscripcionInternet = NetworkService().onConnectivityChanged.listen((List<ConnectivityResult> resultados) {
      final sinInternet = resultados.contains(ConnectivityResult.none);
      
      if (sinInternet) {
        _mostroAvisoDesconexion = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [Icon(Icons.wifi_off, color: Colors.white), SizedBox(width: 10), Text("Sin conexión. Modo Offline activado.")]),
              backgroundColor: Colors.red,
              duration: Duration(days: 365), // Se queda en pantalla hasta que regrese el internet
            ),
          );
        }
      } else {
        // Solo mostramos "Conexión restaurada" si antes se había caído
        if (_mostroAvisoDesconexion && mounted) {
          _mostroAvisoDesconexion = false;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [Icon(Icons.wifi, color: Colors.white), SizedBox(width: 10), Text("¡Conexión restaurada! Sincronizando...")]),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // 🔥 MAGIA HÍBRIDA: Arrancamos el motor automáticamente
          SyncService.instance.sincronizarTodo().then((_) {
             // Cuando termine de sincronizar, refrescamos la pantalla
             if (mounted) _cargarDatos();
          });
        }
      }
    });
  }
Future<void> _arrancarMotor() async {
    // Ponemos la ruedita de carga
    setState(() => _isLoading = true); 
    
    // Ejecutamos la sincronización completa
    await SyncService.instance.sincronizarTodo();
    
    // Una vez que terminó, ahora sí cargamos los datos en la pantalla
    if (mounted) {
      _cargarDatos(); 
    }
  }
  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final cuentas = await _repository.obtenerSaldosPorCuenta();
      final movimientos = await _repository.obtenerUltimosMovimientos();

      double totalGlobal = 0;
      for (var c in cuentas) {
        totalGlobal += (c['saldo_actual'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _cuentasCalculadas = [
            {
              'id': 'global',
              'nombre': 'Patrimonio Total',
              'saldo_actual': totalGlobal,
              'es_global': true,
              'es_credito': false,
            },
            ...cuentas
          ];
          _movimientos = movimientos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata ?? {};
      _nombreUsuario = metadata['full_name'] ?? 'Usuario';
      _avatarUrl = metadata['avatar_url'];
    }
  }

  Future<void> _cerrarSesion() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    // --- LÓGICA DE FILTRADO (LA MAGIA) ---
    List<Map<String, dynamic>> movimientosAMostrar = [];

    if (!_isLoading && _cuentasCalculadas.isNotEmpty) {
      // Aseguramos que el índice sea válido
      if (_paginaActual >= _cuentasCalculadas.length) {
        _paginaActual = 0;
      }

      final cuentaActual = _cuentasCalculadas[_paginaActual];

      if (cuentaActual['es_global'] == true) {
        // Si es la tarjeta Global, mostramos TODO
        movimientosAMostrar = _movimientos;
      } else {
        // Si es una tarjeta específica, filtramos por su ID
        movimientosAMostrar = _movimientos
            .where((m) => m['id_cuenta'] == cuentaActual['id'])
            .toList();
      }
    }
    // -------------------------------------

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Builder(builder: (context) {
          final user = Supabase.instance.client.auth.currentUser;
          final nombre = user?.userMetadata?['full_name'] ?? 'Usuario';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hola, $nombre", style: theme.textTheme.bodySmall),
              const Text("Tus Finanzas",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          );
        }),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_active),
              tooltip: "Compromisos",
              onPressed: () => context.push('/reminders'),
              color: const Color(0xFFFD5F00)),
          IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => context.push('/stats'),
              color: const Color(0xFFFD5F00)),

          // Botón Mis Cuentas con recarga
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            color: const Color(0xFFFD5F00),
            tooltip: "Mis Cuentas",
            onPressed: () async {
              await context.push('/accounts');
              _cargarDatos(); // Recargamos al volver
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () async {
                // Usamos await para que la app "espere" a que regreses del Perfil
                await context.push('/profile');
                // Al regresar, recargamos los datos por si cambiaste la foto o el nombre
                if (mounted) _cargarDatos();
              },
              child: CircleAvatar(
                radius: 16, // Tamaño miniatura perfecto para la barra superior
                backgroundColor: const Color(0xFFFD5F00).withOpacity(0.2),
                backgroundImage:
                    _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null
                    ? Text(
                        _nombreUsuario.isNotEmpty
                            ? _nombreUsuario[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Color(0xFFFD5F00),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      )
                    : null, // Si hay foto, no mostramos texto
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CARRUSEL (MODIFICADO CON FLECHAS WEB)
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  children: [
                    SizedBox(
                      height: 240,
                      // ENVOLVEMOS EN STACK PARA PONER FLECHAS ENCIMA
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PageView.builder(
                            controller:
                                _pageController, // <--- USAMOS LA VARIABLE
                            itemCount: _cuentasCalculadas.length,
                            onPageChanged: (index) {
                              setState(() => _paginaActual = index);
                            },
                            itemBuilder: (context, index) {
                              final cuenta = _cuentasCalculadas[index];
                              final esGlobal = cuenta['es_global'] == true;
                              final esCredito = cuenta['es_credito'] == true;
                              final saldo = cuenta['saldo_actual'];

                              // 1. EL FONDO: Ahora TODAS las tarjetas usan el fondo oscuro elegante
                              final Color colorFondoUniforme = isDark
                                  ? const Color(0xFF1B3A52)
                                  : const Color(0xFF092032);

                              // 2. EL BORDE: Aquí definimos el color de la línea del borde
                              Color colorBorde = Colors
                                  .transparent; // La global no lleva borde (o es invisible)
                              if (!esGlobal) {
                                if (esCredito) {
                                  colorBorde = const Color(
                                      0xFFC0392B); // Borde Rojo para TDC
                                } else {
                                  colorBorde = const Color(
                                      0xFF27AE60); // Borde Verde para Débito/Efectivo
                                }
                              }

                              return Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color:
                                      colorFondoUniforme, // Aplicamos el fondo oscuro
                                  borderRadius: BorderRadius.circular(24),
                                  // 👇 AQUÍ ESTÁ LA MAGIA DEL DISEÑO: El borde de color 👇
                                  border: Border.all(
                                    color: colorBorde,
                                    width:
                                        2.0, // Grosor del borde (puedes subirlo a 3.0 si lo quieres más grueso)
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                        color: colorBorde.withOpacity(
                                            0.3), // Opcional: El brillo de la sombra también toma el color de la tarjeta
                                        blurRadius: 15,
                                        offset: const Offset(0, 5)),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      cuenta['nombre'],
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      currencyFormat.format(saldo),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 25),

                                    // LOGICA DE BOTONES (TUS BOTONES SIGUEN IGUAL Y SE VERÁN GENIALES SOBRE EL FONDO OSCURO)
                                    if (esGlobal)
                                      Row(
// ... De aquí para abajo tus botones siguen exactamente igual ...
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _BotonAccion(
                                            icono: Icons.arrow_downward,
                                            texto: "Ingreso",
                                            color: Colors.greenAccent,
                                            onTap: () async {
                                              final recargar = await context
                                                  .push(
                                                      '/add-transaction',
                                                      extra: {
                                                    'tipo': 'INGRESO'
                                                  });
                                              if (recargar == true)
                                                _cargarDatos();
                                            },
                                          ),
                                          Container(
                                              width: 1,
                                              height: 40,
                                              color: Colors.white24),
                                          _BotonAccion(
                                            icono: Icons.arrow_upward,
                                            texto: "Gasto",
                                            color: const Color(0xFFFD5F00),
                                            onTap: () async {
                                              final recargar = await context
                                                  .push('/add-transaction',
                                                      extra: {'tipo': 'GASTO'});
                                              if (recargar == true)
                                                _cargarDatos();
                                            },
                                          ),
                                        ],
                                      )
                                    else if (esCredito)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _BotonAccion(
                                            icono: Icons.payment,
                                            texto: "Abonar",
                                            color: Colors.blueAccent,
                                            onTap: () async {
                                              final recargar = await context
                                                  .push('/add-transaction',
                                                      extra: {
                                                    'tipo': 'ABONO',
                                                    'cuenta_destino_id':
                                                        cuenta['id']
                                                  });
                                              if (recargar == true)
                                                _cargarDatos();
                                            },
                                          ),
                                          Container(
                                              width: 1,
                                              height: 40,
                                              color: Colors.white24),
                                          _BotonAccion(
                                            icono: Icons.shopping_bag,
                                            texto: "Compra",
                                            color: const Color(0xFFFD5F00),
                                            onTap: () async {
                                              final recargar = await context
                                                  .push('/add-transaction',
                                                      extra: {
                                                    'tipo': 'GASTO',
                                                    'cuenta_fija_id':
                                                        cuenta['id']
                                                  });
                                              if (recargar == true)
                                                _cargarDatos();
                                            },
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _BotonAccion(
                                            icono: Icons.arrow_downward,
                                            texto: "Ingreso",
                                            color: Colors.greenAccent,
                                            onTap: () async {
                                              final recargar = await context
                                                  .push('/add-transaction',
                                                      extra: {
                                                    'tipo': 'INGRESO',
                                                    'cuenta_fija_id':
                                                        cuenta['id']
                                                  });
                                              if (recargar == true)
                                                _cargarDatos();
                                            },
                                          ),
                                          Container(
                                              width: 1,
                                              height: 40,
                                              color: Colors.white24),
                                          _BotonAccion(
                                            icono: Icons.arrow_upward,
                                            texto: "Gasto",
                                            color: const Color(0xFFFD5F00),
                                            onTap: () async {
                                              final recargar = await context
                                                  .push('/add-transaction',
                                                      extra: {
                                                    'tipo': 'GASTO',
                                                    'cuenta_fija_id':
                                                        cuenta['id']
                                                  });
                                              if (recargar == true)
                                                _cargarDatos();
                                            },
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // --- FLECHAS DE NAVEGACIÓN (SOLO WEB/PC) ---
                          if (kIsWeb && _paginaActual > 0)
                            Positioned(
                              left: 10,
                              child: IconButton(
                                onPressed: () {
                                  _pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut);
                                },
                                icon: const CircleAvatar(
                                  backgroundColor: Colors.white70,
                                  child: Icon(Icons.arrow_back_ios_new,
                                      size: 20, color: Colors.black87),
                                ),
                              ),
                            ),

                          if (kIsWeb &&
                              _paginaActual < _cuentasCalculadas.length - 1)
                            Positioned(
                              right: 10,
                              child: IconButton(
                                onPressed: () {
                                  _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut);
                                },
                                icon: const CircleAvatar(
                                  backgroundColor: Colors.white70,
                                  child: Icon(Icons.arrow_forward_ios,
                                      size: 20, color: Colors.black87),
                                ),
                              ),
                            ),
                          // -------------------------------------------
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Puntos indicadores
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:
                          List.generate(_cuentasCalculadas.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _paginaActual == index ? 12 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _paginaActual == index
                                ? theme.primaryColor
                                : Colors.grey.withOpacity(0.3),
                          ),
                        );
                      }),
                    ),
                  ],
                ),

              const SizedBox(height: 30),

              // EL RESTO SIGUE IGUAL (TÍTULOS Y LISTA)...
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _paginaActual == 0
                          ? "Recientes (Todos)"
                          : "Movimientos Cuenta",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => context.push('/history'),
                      child: const Text("Ver todo"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. LISTA DE MOVIMIENTOS (FILTRADA)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: movimientosAMostrar.isEmpty && !_isLoading
                    ? _buildEmptyState(theme, esFiltro: _paginaActual != 0)
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: movimientosAMostrar.length,
                        itemBuilder: (context, index) {
                          // ... TU CÓDIGO DE LA LISTA SIGUE IGUAL AQUÍ ...
                          // (Lo dejo abreviado para que encaje, pero usa tu código original del Card)
                          final mov = movimientosAMostrar[index];
                          final esGasto =
                              (mov['tipo']?.toString().toUpperCase() ??
                                      'GASTO') ==
                                  'GASTO';
                          final categoria = mov['categorias'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                              subtitle: Text(mov['descripcion'] ?? ''),
                              trailing: Text(
                                "${esGasto ? '-' : '+'}${currencyFormat.format(mov['monto'] ?? 0)}",
                                style: TextStyle(
                                  color: esGasto ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              //. MANTENER PRESIONADO: Abre el menú de opciones premium
                              onLongPress: () {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  builder: (ctxSheet) => SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Barra decorativa superior
                                          Container(
                                            width: 40,
                                            height: 5,
                                            margin: const EdgeInsets.only(
                                                bottom: 20),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.grey.withOpacity(0.5),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          // Opción: Editar
                                          ListTile(
                                            leading: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            title:
                                                const Text("Editar movimiento"),
                                            onTap: () async {
                                              Navigator.pop(
                                                  ctxSheet); // Cierra el menú inferior
                                              final recargar = await context
                                                  .push('/add-transaction',
                                                      extra: mov);
                                              if (recargar == true)
                                                _cargarDatos();
                                            },
                                          ),
                                          // Opción: Eliminar
                                          ListTile(
                                            leading: const Icon(Icons.delete,
                                                color: Colors.red),
                                            title: const Text(
                                                "Eliminar registro",
                                                style: TextStyle(
                                                    color: Colors.red)),
                                            onTap: () {
                                              Navigator.pop(
                                                  ctxSheet); // Cierra el menú inferior
                                              // 3. LA CONFIRMACIÓN FINAL
                                              _mostrarDialogoConfirmacionEliminar(
                                                  context, mov);
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
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chat'),
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }

  // Helpers
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

  Widget _buildEmptyState(ThemeData theme, {bool esFiltro = false}) {
    return Container(
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 50, color: theme.disabledColor),
          const SizedBox(height: 10),
          Text(
              esFiltro
                  ? "Sin movimientos en esta cuenta"
                  : "Aún no tienes movimientos",
              style: TextStyle(color: theme.disabledColor)),
        ],
      ),
    );
  }

  void _mostrarDialogoConfirmacionEliminar(
      BuildContext context, Map<String, dynamic> mov) {
    showDialog(
      context: context,
      builder: (ctxDialog) => AlertDialog(
        title: const Text("¿Eliminar movimiento?"),
        content: const Text(
            "Esta acción no se puede deshacer. Tu saldo se ajustará automáticamente para reflejar este cambio."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctxDialog),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(
                  ctxDialog); // 1. Cerramos el diálogo rápido para dar sensación de fluidez

              try {
                // 2. Llamamos al cerebro matemático
                await _repository.eliminarTransaccion(mov['id']);

                // 3. Recargamos la interfaz para que el usuario vea su saldo regresar
                _cargarDatos();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text("Movimiento eliminado y saldo restaurado ✅")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "Hubo un error al eliminar. Intenta de nuevo.",
                            style: TextStyle(color: Colors.white)),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Sí, eliminar",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback onTap;

  const _BotonAccion(
      {required this.icono,
      required this.texto,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(height: 4),
            Text(texto,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

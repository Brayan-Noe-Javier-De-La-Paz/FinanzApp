import 'package:finanzapp/features/transactions/data/transaction_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finanzapp/features/reports/pdf_service.dart'; // Asegúrate que esta ruta sea correcta

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _repository = TransactionRepository();
  List<Map<String, dynamic>> _datos = [];
  bool _isLoading = true;
  double _totalGastado = 0.0;
  
  // 1. NUEVO: Variable para controlar el mes que vemos
  DateTime _fechaFiltro = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // 2. NUEVO: Función para cambiar mes
// 2. NUEVO: Función para cambiar mes (CON EXORCISMO 👻)
  void _cambiarMes(int meses) {
    setState(() {
      _fechaFiltro = DateTime(_fechaFiltro.year, _fechaFiltro.month + meses, 1);
      _isLoading = true;
      // 🔥 EXORCISMO 1: Vaciamos los datos del mes anterior INMEDIATAMENTE
      _datos = [];
      _totalGastado = 0.0;
    });
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final datos = await _repository.obtenerGastosPorMes(_fechaFiltro.month, _fechaFiltro.year);
      
      double total = 0;
      for (var d in datos) {
        // 🔥 PROTECCIÓN: tryParse evita crasheos si la base de datos devuelve un formato raro
        total += double.tryParse((d['monto'] ?? d['total']).toString()) ?? 0.0; 
      }

      if (mounted) {
        setState(() {
          _datos = datos;
          _totalGastado = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // 🔥 EXORCISMO 2: Si SQLite o Supabase fallan, aseguramos que la pantalla quede en 0
          _datos = [];
          _totalGastado = 0.0;
        });
      }
      print("💥 Error cargando stats: $e");
    }
  }

  // Ayudante para convertir Hex String (#FFFFFF) a Color
  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    try {
      return Color(int.parse("0x$hex"));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('MMMM yyyy', 'es_MX'); // Ej: FEBRERO 2026

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gastos del Mes"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
            IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Exportar Reporte",
            onPressed: () async {
              // 1. Configuración de Tema
              final esModoOscuro = Theme.of(context).brightness == Brightness.dark;

              // 2. Selector de Rango de Fechas
              final DateTimeRange? rangoSeleccionado = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                saveText: "ACEPTAR",
                helpText: "SELECCIONA EL PERIODO",
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: esModoOscuro
                          ? const ColorScheme.dark(primary: Color(0xFFFD5F00), onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white)
                          : const ColorScheme.light(primary: Color(0xFF092032), onPrimary: Colors.white, onSurface: Colors.black), dialogTheme: DialogThemeData(backgroundColor: esModoOscuro ? const Color(0xFF1E1E1E) : Colors.white),
                    ),
                    child: child!,
                  );
                },
              );

              if (rangoSeleccionado == null) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Generando reporte del ${DateFormat('dd/MM').format(rangoSeleccionado.start)} al ${DateFormat('dd/MM').format(rangoSeleccionado.end)}...")),
              );

              try {
                // 3. RECUPERAMOS LA LÓGICA DE DATOS (ESTO ES LO QUE FALTABA)
                // Usamos obtenerHistorialCompleto para asegurar que traemos todo, no solo los ultimos 5
                final todosLosMovimientos = await _repository.obtenerHistorialCompleto(); 

                // 4. FILTRADO POR FECHA
                final movimientosFiltrados = todosLosMovimientos.where((m) {
                  if (m['fecha_transaccion'] == null) return false;
                  final fecha = DateTime.parse(m['fecha_transaccion']);
                  
                  // Lógica para incluir el día completo (desde las 00:00 del inicio hasta las 23:59 del fin)
                  return fecha.isAfter(rangoSeleccionado.start.subtract(const Duration(seconds: 1))) && 
                         fecha.isBefore(rangoSeleccionado.end.add(const Duration(days: 1)));
                }).toList();

                if (movimientosFiltrados.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay movimientos en esas fechas.")));
                  return;
                }

                // 5. CÁLCULO DE TOTALES PARA EL PDF
                double ingresos = 0;
                double gastos = 0;
                
                for (var m in movimientosFiltrados) {
                  final monto = double.tryParse(m['monto'].toString()) ?? 0;
                  // Ajuste para detectar si es Gasto (compatible con tu lógica nueva y vieja)
                  final tipo = m['tipo']?.toString().toUpperCase() ?? 'GASTO';
                  final esGasto = tipo == 'GASTO' || tipo == 'COMPRA'; 
                  
                  if (esGasto) {
                    gastos += monto;
                  } else {
                    ingresos += monto;
                  }
                }

                // 6. LLAMADA AL SERVICIO PDF (ESTO ABRE LA VENTANA)
                await PdfService().generarYDescargarReporte(movimientosFiltrados, ingresos, gastos);
                
              } catch (e) {
                print("Error PDF: $e");
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al generar PDF: $e")));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 4. NUEVO: SELECTOR DE MES TRANSPARENTE
          // Se adapta al modo oscuro/claro automáticamente
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _cambiarMes(-1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    dateFormat.format(_fechaFiltro).toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Bloqueamos ir al futuro si es el mes actual
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (_fechaFiltro.month == DateTime.now().month && _fechaFiltro.year == DateTime.now().year)
                      ? null // Deshabilitado si es el mes actual
                      : () => _cambiarMes(1),
                ),
              ],
            ),
          ),

          // CONTENIDO PRINCIPAL (Tu código original)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _datos.isEmpty
                    ? _buildEmptyState(theme)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // EL GRÁFICO (PIE CHART)
                            SizedBox(
                              height: 250,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 60,
                                      sections: _generarSecciones(),
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("Total", style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        currencyFormat.format(_totalGastado),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // LA LEYENDA
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text("Desglose por Categoría", style: theme.textTheme.titleMedium)
                            ),
                            const SizedBox(height: 10),
                            
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _datos.length,
                              itemBuilder: (context, index) {
                                final dato = _datos[index];
                                // Ajuste para soportar nombres de claves nuevos o viejos
                                final totalDato = (dato['monto'] ?? dato['total'] as num).toDouble();
                                final porcentaje = (_totalGastado == 0) ? 0.0 : (totalDato / _totalGastado * 100);
                                final color = _hexToColor(dato['color_hex'] ?? dato['color']); 
                                final nombre = dato['categoria'] ?? dato['nombre'];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: CircleAvatar(backgroundColor: color, radius: 10),
                                    title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text("${porcentaje.toStringAsFixed(1)}% del total"),
                                    trailing: Text(
                                      currencyFormat.format(totalDato),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generarSecciones() {
    return _datos.map((dato) {
      final totalDato = (dato['monto'] ?? dato['total'] as num).toDouble();
      final color = _hexToColor(dato['color_hex'] ?? dato['color']);
      final porcentaje = (_totalGastado == 0) ? 0.0 : (totalDato / _totalGastado * 100);

      return PieChartSectionData(
        color: color,
        value: totalDato,
        title: '${porcentaje.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    }).toList();
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 80, color: theme.disabledColor),
          const SizedBox(height: 20),
          Text("No hay gastos este mes", style: TextStyle(color: theme.disabledColor)),
        ],
      ),
    );
  }
}
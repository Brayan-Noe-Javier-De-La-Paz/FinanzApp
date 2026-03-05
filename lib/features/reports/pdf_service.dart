import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  // Función principal que llama la UI
  Future<void> generarYDescargarReporte(List<Map<String, dynamic>> movimientos,
      double totalIngresos, double totalGastos) async {
    try {
      // 1. Crear el documento PDF
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      );

      // 2. Cargar fuentes y Datos
      final currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
      final now = DateTime.now();
      final fechaTitulo =
          DateFormat('MMMM yyyy', 'es_MX').format(now).toUpperCase();

      // 3. Definir colores de tu marca
      final colorPrimario = PdfColor.fromHex("#092032");
      final colorAcento = PdfColor.fromHex("#FD5F00");

      // 4. Construir la página
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),

          // ENCABEZADO
          header: (context) =>
              _buildHeader(context, colorPrimario, fechaTitulo),

          // CONTENIDO PRINCIPAL
          build: (context) => [
            // 🛡️ CORRECCIÓN 1: Usar Expanded en lugar de anchos fijos para evitar crasheos
            pw.SizedBox(height: 20),
            pw.Row(
              children: [
                pw.Expanded(
                    child: _buildResumenCard(
                        "INGRESOS", totalIngresos, PdfColors.green)),
                pw.SizedBox(width: 10), // Espacio entre tarjetas
                pw.Expanded(
                    child: _buildResumenCard(
                        "GASTOS", totalGastos, PdfColors.red)),
                pw.SizedBox(width: 10),
                pw.Expanded(
                    child: _buildResumenCard(
                        "BALANCE", totalIngresos - totalGastos, colorPrimario)),
              ],
            ),

            pw.SizedBox(height: 30),
            pw.Text("Detalle de Movimientos",
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(color: colorAcento),
            pw.SizedBox(height: 10),

            // 🛡️ CORRECCIÓN 2: Proteger la tabla por si no hay movimientos
            if (movimientos.isEmpty)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Text("No hay movimientos en este periodo.",
                      style: const pw.TextStyle(color: PdfColors.grey)),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Categoría', 'Descripción', 'Monto'],
                data: movimientos.map((m) {
                  // Protección de FECHA
                  String fechaTexto = 'Sin fecha';
                  try {
                    if (m['fecha_transaccion'] != null) {
                      final fecha =
                          DateTime.parse(m['fecha_transaccion'].toString());
                      fechaTexto = DateFormat('dd/MM/yyyy').format(fecha);
                    }
                  } catch (e) {
                    fechaTexto = 'Error Fecha';
                  }

                  // Protección de TEXTOS
                  final categoria =
                      m['categorias']?['nombre']?.toString() ?? 'General';
                  final descripcion =
                      m['descripcion']?.toString() ?? 'Sin descripción';

                  // Protección de MONTO
                  double montoVal = 0.0;
                  try {
                    montoVal = double.parse(m['monto'].toString());
                  } catch (e) {
                    montoVal = 0.0;
                  }

                  final esGasto =
                      (m['tipo']?.toString().toUpperCase() ?? 'GASTO') ==
                          'GASTO';
                  final signo = esGasto ? '-' : '+';

                  return [
                    fechaTexto,
                    categoria,
                    descripcion,
                    "$signo ${currency.format(montoVal)}",
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                    color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: colorPrimario),
                rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.grey300))),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {3: pw.Alignment.centerRight},
              ),
          ],

          // PIE DE PÁGINA
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              "Página ${context.pageNumber} de ${context.pagesCount} - Generado por FinanzApp",
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
            ),
          ),
        ),
      );

      // 5. ¡LANZAR!
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Reporte_FinanzApp_$fechaTitulo',
      );
    } catch (e, stacktrace) {
      // 🛡️ CORRECCIÓN 3: Si algo explota, te avisará en la consola en lugar de congelarse
      print("🚨 ERROR FATAL GENERANDO PDF: $e");
      print(stacktrace);
    }
  }

  // Widget auxiliar para el Encabezado
  pw.Widget _buildHeader(pw.Context context, PdfColor color, String fecha) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("FinanzApp",
                style: pw.TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text("REPORTE MENSUAL",
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 14)),
          ],
        ),
        pw.Text(fecha,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2, color: color),
      ],
    );
  }

  // Widget auxiliar para las tarjetas de resumen
  pw.Widget _buildResumenCard(String titulo, double monto, PdfColor color) {
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return pw.Container(
      // ❌ QUITAMOS EL WIDTH FIJO DE 150 PARA EVITAR DESBORDAMIENTOS
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        children: [
          pw.Text(titulo,
              style: pw.TextStyle(
                  color: color, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(currency.format(monto),
              style: pw.TextStyle(
                  color: color, fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}

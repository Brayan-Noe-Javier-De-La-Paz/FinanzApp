import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiRepository {
  // 🔒 Leemos la llave secreta desde la bóveda (.env)
  final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  final _supabase = Supabase.instance.client;

  Future<String> enviarMensaje(String mensajeUsuario) async {
    try {
      // 1. Obtener el contexto financiero (Últimos 50 movimientos)
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('transacciones')
          .select('monto, tipo, descripcion, fecha_transaccion, categorias(nombre)')
          .eq('id_usuario', userId)
          .order('fecha_transaccion', ascending: false)
          .limit(50); // Le damos buen contexto sin saturar

      // 2. Formatear los datos como texto para que la IA los entienda
      String contextoFinanciero = "Aquí están mis datos financieros recientes:\n";
      for (var t in response) {
        final cat = t['categorias']?['nombre'] ?? 'General';
        final tipo = t['tipo'];
        final monto = t['monto'];
        final desc = t['descripcion'];
        contextoFinanciero += "- $tipo de \$$monto en $cat ($desc)\n";
      }

      // 3. Configurar Gemini (Asegúrate de tener saldo/cuota en Google AI Studio)
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', 
        apiKey: apiKey, // <-- Ya está usando la llave de la bóveda correctamente
      );

      // 4. Crear el Prompt Maestro (Instrucciones de personalidad)
      final promptSistema = '''
        Actúa como un asesor financiero experto, amable y sarcástico (estilo Iron Man pero financiero).
        Tu nombre es "FinanzAI".
        Analiza el siguiente contexto financiero del usuario y responde su pregunta.
        Sé breve y directo. Si gasta mucho, regáñalo un poco. Si ahorra, felicítalo.
        
        $contextoFinanciero
        
        Pregunta del usuario: $mensajeUsuario
      ''';

      final content = [Content.text(promptSistema)];
      final aiResponse = await model.generateContent(content);

      return aiResponse.text ?? "Lo siento, no pude analizar tus datos ahora.";

    } catch (e) {
      return "Error conectando con tu cerebro financiero: $e";
    }
  }
}
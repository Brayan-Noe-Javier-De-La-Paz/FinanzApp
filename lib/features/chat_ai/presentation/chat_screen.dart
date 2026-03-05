import 'package:finanzapp/features/chat_ai/data/ai_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repository = AiRepository();
  final _textController = TextEditingController();
  final List<Map<String, String>> _mensajes = []; // { 'emisor': 'user'|'ia', 'texto': '...' }
  bool _isLoading = false;

  Future<void> _enviarMensaje() async {
    final texto = _textController.text.trim();
    if (texto.isEmpty) return;

    // 1. Mostrar mensaje del usuario inmediatamente
    setState(() {
      _mensajes.add({'emisor': 'user', 'texto': texto});
      _isLoading = true;
      _textController.clear();
    });

    // 2. Obtener respuesta de Gemini
    final respuestaIA = await _repository.enviarMensaje(texto);

    // 3. Mostrar respuesta de la IA
    if (mounted) {
      setState(() {
        _mensajes.add({'emisor': 'ia', 'texto': respuestaIA});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber), // Icono IA
            SizedBox(width: 10),
            Text("Asistente FinanzAI"),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // --- ÁREA DE CHAT ---
          Expanded(
            child: _mensajes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.psychology, size: 80, color: theme.disabledColor),
                        const SizedBox(height: 20),
                        Text(
                          "Pregúntame sobre tus gastos...",
                          style: TextStyle(color: theme.disabledColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _mensajes.length,
                    itemBuilder: (context, index) {
                      final msg = _mensajes[index];
                      final esUsuario = msg['emisor'] == 'user';

                      return Align(
                        alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(15),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            // Burbuja Verde (Usuario) vs Burbuja Gris/Azul (IA)
                            color: esUsuario 
                                ? theme.primaryColor 
                                : (isDark ? const Color(0xFF1E2D3D) : Colors.grey[200]),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: esUsuario ? const Radius.circular(15) : Radius.zero,
                              bottomRight: esUsuario ? Radius.zero : const Radius.circular(15),
                            ),
                          ),
                          child: Text(
                            msg['texto']!,
                            style: TextStyle(
                              color: esUsuario 
                                  ? Colors.white 
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // --- INDICADOR DE "ESCRIBIENDO..." ---
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Analizando finanzas...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ),

          // --- CAJA DE TEXTO ---
          Container(
            padding: const EdgeInsets.all(10),
            color: theme.cardTheme.color,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: "¿En qué gasté más este mes?",
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _enviarMensaje(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: theme.primaryColor,
                  onPressed: _enviarMensaje,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
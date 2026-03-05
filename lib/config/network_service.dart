import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  // Patrón Singleton para usar la misma instancia en toda la app
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();

  // 1. Función de chequeo rápido: ¿Hay internet en ESTE preciso momento?
  Future<bool> hasInternet() async {
    final List<ConnectivityResult> connectivityResult = await _connectivity.checkConnectivity();
    
    // Si la lista NO contiene 'none', significa que tenemos WiFi, Datos o Ethernet
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false; // Estamos desconectados (Modo Avión o sin señal)
    }
    return true; // ¡Tenemos internet!
  }

  // 2. El "Megáfono" (Stream): Para escuchar en vivo cuando el internet va y viene
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _connectivity.onConnectivityChanged;
}
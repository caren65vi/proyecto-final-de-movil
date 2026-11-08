import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/asistencia.dart';
import '../models/asistencia_model.dart';

/// Habla con las Cloud Functions de asistencia y lee las asistencias.
class AsistenciaDatasource {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Llama una función y devuelve la respuesta como mapa
  Future<Map<String, dynamic>> _llamar(
    String nombre,
    Map<String, dynamic> datos,
  ) async {
    final resultado = await _functions.httpsCallable(nombre).call(datos);
    return Map<String, dynamic>.from(resultado.data as Map);
  }

  Future<({String sesionId, String token})> abrirSesion(String grupoId) async {
    final r = await _llamar('abrirSesion', {'grupoId': grupoId});
    return (sesionId: r['sesionId'] as String, token: r['token'] as String);
  }

  Future<String> renovarQR(String grupoId, String sesionId) async {
    final r = await _llamar('renovarQR', {
      'grupoId': grupoId,
      'sesionId': sesionId,
    });
    return r['token'] as String;
  }

  Future<void> cerrarSesion(String grupoId, String sesionId) async {
    await _llamar('cerrarSesion', {'grupoId': grupoId, 'sesionId': sesionId});
  }

  Future<void> registrarAsistencia({
    required String grupoId,
    required String sesionId,
    required String token,
    required double latitud,
    required double longitud,
  }) async {
    await _llamar('registrarAsistenciaQR', {
      'grupoId': grupoId,
      'sesionId': sesionId,
      'token': token,
      'latitud': latitud,
      'longitud': longitud,
    });
  }

  DocumentReference<Map<String, dynamic>> _sesion(
    String grupoId,
    String sesionId,
  ) => _db
      .collection('grupos')
      .doc(grupoId)
      .collection('sesiones')
      .doc(sesionId);

  Stream<List<Asistencia>> asistencias(String grupoId, String sesionId) =>
      _sesion(grupoId, sesionId)
          .collection('asistencias')
          .snapshots()
          .map((s) => s.docs.map(AsistenciaModel.fromDocument).toList());

  /// Token actual del QR. El servidor lo cambia cada vez que un estudiante
  /// registra su asistencia, así cada estudiante usa un código distinto.
  Stream<String> tokenQR(String grupoId, String sesionId) =>
      _sesion(grupoId, sesionId)
          .collection('privado')
          .doc('qr')
          .snapshots()
          .map((s) => s.data()?['token'] as String? ?? '')
          .where((token) => token.isNotEmpty);
}

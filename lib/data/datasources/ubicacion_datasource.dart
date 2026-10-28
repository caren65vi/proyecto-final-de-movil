import 'package:geolocator/geolocator.dart';

import '../../domain/repositories/curso_repository.dart';

/// Habla con el GPS del celular.
class UbicacionDatasource {
  // Pide permiso si hace falta y lee la posición actual
  Future<({double latitud, double longitud})> obtenerUbicacionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const CursoError('Activa la ubicación (GPS) del celular');
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw const CursoError(
        'Ceiba necesita permiso de ubicación para fijar el lugar del curso',
      );
    }

    final posicion = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return (latitud: posicion.latitude, longitud: posicion.longitude);
  }
}

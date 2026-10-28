import 'dart:async';

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

    // Los errores del GPS se traducen a mensajes para el docente
    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return (latitud: posicion.latitude, longitud: posicion.longitude);
    } on TimeoutException {
      throw const CursoError(
        'No se pudo obtener la ubicación. Sal a un lugar abierto e intenta de nuevo',
      );
    } on LocationServiceDisabledException {
      // También ocurre si se rechaza "Precisión de ubicación" de Google
      throw const CursoError(
        'Activa la ubicación del celular (y su precisión) para fijar el curso',
      );
    } on PermissionDeniedException {
      throw const CursoError(
        'Ceiba necesita permiso de ubicación para fijar el lugar del curso',
      );
    }
  }
}

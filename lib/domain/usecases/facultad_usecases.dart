import '../entities/facultad.dart';
import '../repositories/facultad_repository.dart';

/// Casos de uso de facultades: validan los datos y llaman al repositorio.

class ObtenerFacultades {
  final FacultadRepository repositorio;
  ObtenerFacultades(this.repositorio);

  Stream<List<Facultad>> call() => repositorio.facultades();
}

class CrearFacultad {
  final FacultadRepository repositorio;
  CrearFacultad(this.repositorio);

  static const largoMaximo = 80;

  Future<Facultad> call(String nombre, String docenteUid) async {
    // Quita espacios de más: "  Ciencias   Básicas " → "Ciencias Básicas"
    final limpio = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpio.isEmpty) {
      throw const FacultadError('Escribe el nombre de la facultad');
    }
    if (limpio.length > largoMaximo) {
      throw const FacultadError(
        'El nombre no puede tener más de $largoMaximo caracteres',
      );
    }
    final id = Facultad.idDesde(limpio);
    if (id.isEmpty) {
      throw const FacultadError('El nombre debe tener letras o números');
    }
    return repositorio.crearFacultad(
      id: id,
      nombre: limpio,
      docenteUid: docenteUid,
    );
  }
}

class EliminarFacultad {
  final FacultadRepository repositorio;
  EliminarFacultad(this.repositorio);

  Future<void> call(String id) => repositorio.eliminarFacultad(id);
}

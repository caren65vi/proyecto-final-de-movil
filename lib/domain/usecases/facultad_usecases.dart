import '../entities/facultad.dart';
import '../entities/programa.dart';
import '../repositories/facultad_repository.dart';

/// Casos de uso de facultades y programas: validan los datos y llaman al
/// repositorio.

/// Largo máximo del nombre de una facultad o un programa.
const largoMaximoNombre = 80;

/// Quita espacios de más ("  Ciencias   Básicas " → "Ciencias Básicas") y
/// valida el nombre. Devuelve el nombre limpio y su ID.
({String nombre, String id}) _validarNombre(String nombre, String que) {
  final limpio = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty) {
    throw FacultadError('Escribe el nombre $que');
  }
  if (limpio.length > largoMaximoNombre) {
    throw const FacultadError(
      'El nombre no puede tener más de $largoMaximoNombre caracteres',
    );
  }
  final id = Facultad.idDesde(limpio);
  if (id.isEmpty) {
    throw const FacultadError('El nombre debe tener letras o números');
  }
  return (nombre: limpio, id: id);
}

class ObtenerFacultades {
  final FacultadRepository repositorio;
  ObtenerFacultades(this.repositorio);

  Stream<List<Facultad>> call() => repositorio.facultades();
}

class CrearFacultad {
  final FacultadRepository repositorio;
  CrearFacultad(this.repositorio);

  static const largoMaximo = largoMaximoNombre;

  Future<Facultad> call(String nombre, String docenteUid) async {
    final valido = _validarNombre(nombre, 'de la facultad');
    return repositorio.crearFacultad(
      id: valido.id,
      nombre: valido.nombre,
      docenteUid: docenteUid,
    );
  }
}

/// Elimina una facultad solo si ya no tiene programas: si se borrara con
/// programas, esos programas (y los estudiantes en ellos) quedarían sueltos.
class EliminarFacultad {
  final FacultadRepository repositorio;
  EliminarFacultad(this.repositorio);

  Future<void> call(String id) async {
    final programas = await repositorio.contarProgramas(id);
    if (programas > 0) {
      throw FacultadError(
        'Primero elimina sus $programas '
        '${programas == 1 ? 'programa' : 'programas'}',
      );
    }
    await repositorio.eliminarFacultad(id);
  }
}

// ---------- Programas ----------

class ObtenerProgramas {
  final FacultadRepository repositorio;
  ObtenerProgramas(this.repositorio);

  Stream<List<Programa>> call(String facultadId) =>
      repositorio.programas(facultadId);
}

class CrearPrograma {
  final FacultadRepository repositorio;
  CrearPrograma(this.repositorio);

  Future<Programa> call(
    String facultadId,
    String nombre,
    String docenteUid,
  ) async {
    final valido = _validarNombre(nombre, 'del programa');
    return repositorio.crearPrograma(
      facultadId: facultadId,
      id: valido.id,
      nombre: valido.nombre,
      docenteUid: docenteUid,
    );
  }
}

class EliminarPrograma {
  final FacultadRepository repositorio;
  EliminarPrograma(this.repositorio);

  Future<void> call(String facultadId, String programaId) =>
      repositorio.eliminarPrograma(facultadId, programaId);
}

/// El estudiante elige su facultad y su programa; el programa debe ser
/// de esa facultad.
class AsignarProgramaEstudiante {
  final FacultadRepository repositorio;
  AsignarProgramaEstudiante(this.repositorio);

  Future<void> call({
    required String uid,
    required Facultad facultad,
    required Programa programa,
  }) async {
    if (programa.facultadId != facultad.id) {
      throw const FacultadError('Ese programa no es de la facultad elegida');
    }
    await repositorio.asignarProgramaEstudiante(
      uid: uid,
      facultad: facultad,
      programa: programa,
    );
  }
}

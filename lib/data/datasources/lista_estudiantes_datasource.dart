import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../../domain/entities/estudiante_inscrito.dart';
import '../../domain/repositories/curso_repository.dart';

/// Lee la lista de estudiantes de un archivo Excel (.xlsx) o .csv.
/// La primera fila son los títulos: correo (obligatorio), nombre y código.
class ListaEstudiantesDatasource {
  // Abre el selector de archivos; null si el docente cancela
  Future<({String nombreArchivo, List<EstudianteInscrito> estudiantes})?>
  importarEstudiantes() async {
    final archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (archivo == null) return null;

    final bytes = await archivo.readAsBytes();
    final filas = archivo.extension?.toLowerCase() == 'csv'
        ? _leerCsv(bytes)
        : _leerExcel(bytes);
    return (nombreArchivo: archivo.name, estudiantes: _aEstudiantes(filas));
  }

  // Filas de la primera hoja del Excel, como texto
  List<List<String>> _leerExcel(List<int> bytes) {
    final Excel libro;
    try {
      libro = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const CursoError('No se pudo leer el archivo Excel');
    }
    if (libro.tables.isEmpty) return [];
    final hoja = libro.tables.values.first;
    return [
      for (final fila in hoja.rows)
        [for (final celda in fila) celda?.value?.toString().trim() ?? ''],
    ];
  }

  // Filas del CSV; acepta "," o ";" (Excel en español guarda con ";")
  List<List<String>> _leerCsv(List<int> bytes) {
    final texto = utf8
        .decode(bytes, allowMalformed: true)
        .replaceFirst('\uFEFF', '');
    final lineas = texto
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lineas.isEmpty) return [];
    final separador = lineas.first.contains(';') ? ';' : ',';
    return [
      for (final linea in lineas)
        [
          for (final celda in linea.split(separador))
            celda.trim().replaceAll('"', ''),
        ],
    ];
  }

  // Busca las columnas por su título y arma la lista sin repetidos
  List<EstudianteInscrito> _aEstudiantes(List<List<String>> filas) {
    if (filas.isEmpty) return [];

    final titulos = [for (final t in filas.first) _sinTildes(t.toLowerCase())];
    int columna(List<String> nombres) =>
        titulos.indexWhere((t) => nombres.any(t.contains));

    final colCorreo = columna(['correo', 'email', 'e-mail']);
    final colNombre = columna(['nombre']);
    final colCodigo = columna(['codigo']);
    if (colCorreo == -1) {
      throw const CursoError(
        'La primera fila del archivo debe tener una columna "correo"',
      );
    }

    String celda(List<String> fila, int col) =>
        col >= 0 && col < fila.length ? fila[col].trim() : '';

    final porCorreo = <String, EstudianteInscrito>{};
    for (final fila in filas.skip(1)) {
      final correo = celda(fila, colCorreo).toLowerCase();
      if (!correo.contains('@')) continue;
      final codigo = celda(fila, colCodigo);
      porCorreo[correo] = EstudianteInscrito(
        correo: correo,
        nombre: celda(fila, colNombre),
        codigoEstudiante: codigo.isEmpty ? null : codigo,
      );
    }
    return porCorreo.values.toList();
  }

  String _sinTildes(String texto) => texto
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../../domain/entities/estudiante_inscrito.dart';
import '../../domain/entities/resultado_importacion.dart';
import '../../domain/repositories/curso_repository.dart';

/// Lee la lista de estudiantes de un archivo Excel (.xlsx) o .csv.
///
/// Formato (el de la universidad): una fila de títulos y debajo un
/// estudiante por fila. Columnas:
///   PROGRAMA           opcional
///   CODIGOESTUDIANTE   opcional
///   MAIL_INST          obligatoria (también sirve "correo" o "email")
///   NOMBRECOMPLETO     obligatoria (también sirve "nombre")
class ListaEstudiantesDatasource {
  // Abre el selector de archivos; null si el docente cancela
  Future<ResultadoImportacion?> importarEstudiantes() async {
    final archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (archivo == null) return null;

    final bytes = await archivo.readAsBytes();
    final filas = archivo.extension?.toLowerCase() == 'csv'
        ? _leerCsv(bytes)
        : _leerExcel(bytes);
    final leido = leerFilas(filas);
    return ResultadoImportacion(
      nombreArchivo: archivo.name,
      estudiantes: leido.estudiantes,
      omitidas: leido.omitidas,
    );
  }

  // Filas de la primera hoja del Excel, como texto
  List<List<String>> _leerExcel(List<int> bytes) {
    final Excel libro;
    try {
      libro = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const CursoError(
        'No se pudo leer el archivo. Guárdalo como Excel (.xlsx) o CSV '
        'e inténtalo de nuevo.',
      );
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
        .replaceFirst('﻿', '');
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

  static final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // Títulos aceptados para cada columna (sin tildes, minúscula, sin espacios)
  static const _titulosCorreo = ['mail_inst', 'mail', 'correo', 'email'];
  static const _titulosNombre = ['nombrecompleto', 'nombre'];
  static const _titulosCodigo = ['codigoestudiante', 'codigo'];

  /// Convierte las filas del archivo en estudiantes. Es pública para probarla
  /// sin abrir el selector de archivos.
  static ({
    List<EstudianteInscrito> estudiantes,
    List<({int fila, String motivo})> omitidas,
  })
  leerFilas(List<List<String>> filas) {
    final noVacias = filas.where((f) => f.any((c) => c.trim().isNotEmpty));
    if (noVacias.isEmpty) {
      throw const CursoError('El archivo está vacío.');
    }

    String normal(String t) =>
        _sinTildes(t.toLowerCase()).replaceAll(RegExp(r'[\s\-]+'), '');
    int columna(List<String> titulos, List<String> aceptados) =>
        titulos.indexWhere((t) => aceptados.any(t.contains));

    // La fila de títulos es la primera (de las 10 primeras) que tenga correo
    var filaTitulos = -1;
    var titulos = <String>[];
    for (var i = 0; i < filas.length && i < 10; i++) {
      final candidatos = [for (final t in filas[i]) normal(t)];
      if (columna(candidatos, _titulosCorreo) != -1) {
        filaTitulos = i;
        titulos = candidatos;
        break;
      }
    }

    final colCorreo = filaTitulos == -1 ? -1 : columna(titulos, _titulosCorreo);
    final colNombre = filaTitulos == -1 ? -1 : columna(titulos, _titulosNombre);
    if (colCorreo == -1 || colNombre == -1) {
      final encontrados = noVacias.first
          .where((t) => t.trim().isNotEmpty)
          .map((t) => t.trim())
          .join(', ');
      final faltan = [
        if (colCorreo == -1) '"MAIL_INST" (correo institucional)',
        if (colNombre == -1) '"NOMBRECOMPLETO"',
      ].join(' y ');
      throw CursoError(
        'Falta la columna $faltan.\n\n'
        'Columnas encontradas en el archivo: $encontrados',
      );
    }
    // La columna PROGRAMA se acepta pero no se usa: el estudiante elige su
    // programa (enlazado a su facultad) al registrarse o en su perfil
    final colCodigo = columna(titulos, _titulosCodigo);

    String celda(List<String> fila, int col) => col >= 0 && col < fila.length
        ? fila[col].replaceAll(RegExp(r'\s+'), ' ').trim()
        : '';

    final porCorreo = <String, EstudianteInscrito>{};
    final omitidas = <({int fila, String motivo})>[];
    for (var i = filaTitulos + 1; i < filas.length; i++) {
      final fila = filas[i];
      if (fila.every((c) => c.trim().isEmpty)) continue; // fila vacía
      final numero = i + 1; // como en Excel
      final correo = celda(fila, colCorreo).toLowerCase();
      if (correo.isEmpty) {
        omitidas.add((fila: numero, motivo: 'no tiene correo'));
        continue;
      }
      if (!_correoValido.hasMatch(correo)) {
        omitidas.add((fila: numero, motivo: 'correo no válido ($correo)'));
        continue;
      }
      if (porCorreo.containsKey(correo)) {
        omitidas.add((fila: numero, motivo: 'correo repetido ($correo)'));
        continue;
      }
      final codigo = _codigo(celda(fila, colCodigo));
      porCorreo[correo] = EstudianteInscrito(
        correo: correo,
        nombre: celda(fila, colNombre),
        codigoEstudiante: codigo.isEmpty ? null : codigo,
      );
    }

    if (porCorreo.isEmpty) {
      throw CursoError(
        omitidas.isEmpty
            ? 'El archivo no tiene estudiantes debajo de los títulos.'
            : 'Ninguna fila tiene un correo válido. '
                  'Revisa la columna MAIL_INST.',
      );
    }
    return (estudiantes: porCorreo.values.toList(), omitidas: omitidas);
  }

  // Excel guarda los códigos como número: "4245172970.0" → "4245172970"
  static String _codigo(String valor) {
    final entero = RegExp(r'^(\d+)\.0+$').firstMatch(valor);
    return entero != null ? entero.group(1)! : valor;
  }

  static String _sinTildes(String texto) => texto
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

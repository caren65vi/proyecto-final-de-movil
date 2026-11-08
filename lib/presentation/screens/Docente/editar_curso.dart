import 'package:flutter/material.dart';

import '../../../domain/entities/curso.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../theme/app_colors.dart';

/// Edita nombre, facultad, grupo, aula, meta de asistencia y radio.
class EditarCursoScreen extends StatefulWidget {
  const EditarCursoScreen({
    super.key,
    required this.curso,
    required this.editarCurso,
  });

  final Curso curso;
  final EditarCurso editarCurso;

  @override
  State<EditarCursoScreen> createState() => _EditarCursoScreenState();
}

class _EditarCursoScreenState extends State<EditarCursoScreen> {
  late final _nombre = TextEditingController(text: widget.curso.nombreMateria);
  late final _facultad = TextEditingController(text: widget.curso.facultad);
  late final _grupo = TextEditingController(text: widget.curso.numeroGrupo);
  late final _aula = TextEditingController(text: widget.curso.aula);
  late final _meta = TextEditingController(
    text: (widget.curso.metaAsistencia * 100).round().toString(),
  );
  late final _radio = TextEditingController(
    text: widget.curso.radioMetros.toString(),
  );
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_nombre, _facultad, _grupo, _aula, _meta, _radio]) {
      c.dispose();
    }
    super.dispose();
  }

  void _mostrar(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardar() async {
    final meta = int.tryParse(_meta.text.trim());
    final radio = int.tryParse(_radio.text.trim());
    if (meta == null || meta < 1 || meta > 100) {
      _mostrar('La meta debe ser un número entre 1 y 100');
      return;
    }
    if (radio == null || radio < 10) {
      _mostrar('El radio debe ser de al menos 10 metros');
      return;
    }

    // Se copia el curso cambiando solo lo que se editó
    final c = widget.curso;
    final editado = Curso(
      id: c.id,
      nombreMateria: _nombre.text.trim(),
      facultad: _facultad.text.trim(),
      numeroGrupo: _grupo.text.trim(),
      aula: _aula.text.trim(),
      docenteUid: c.docenteUid,
      docenteNombre: c.docenteNombre,
      fechaInicio: c.fechaInicio,
      fechaFin: c.fechaFin,
      horario: c.horario,
      latitud: c.latitud,
      longitud: c.longitud,
      radioMetros: radio,
      metaAsistencia: meta / 100,
      totalEstudiantes: c.totalEstudiantes,
    );

    setState(() => _guardando = true);
    try {
      await widget.editarCurso(editado);
      if (!mounted) return;
      Navigator.pop(context);
    } on CursoError catch (e) {
      _mostrar(e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _campo(
    String etiqueta,
    TextEditingController controller, {
    bool numero = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: numero ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: etiqueta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Editar curso'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _campo('Nombre del curso', _nombre),
          _campo('Facultad', _facultad),
          _campo('Número de grupo', _grupo),
          _campo('Aula', _aula),
          _campo('Meta de asistencia (%)', _meta, numero: true),
          _campo('Radio permitido (metros)', _radio, numero: true),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}

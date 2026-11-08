import 'package:flutter/material.dart';

import '../../../domain/entities/curso.dart';
import '../../../domain/entities/estudiante_inscrito.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../theme/app_colors.dart';

/// Detalle de un grupo: datos del curso y estudiantes con su asistencia.
class DetalleCursoScreen extends StatefulWidget {
  const DetalleCursoScreen({
    super.key,
    required this.grupoId,
    required this.cursoRepository,
  });

  final String grupoId;
  final CursoRepository cursoRepository;

  @override
  State<DetalleCursoScreen> createState() => _DetalleCursoScreenState();
}

class _DetalleCursoScreenState extends State<DetalleCursoScreen> {
  late final Stream<Curso> _curso;
  late final Stream<List<EstudianteInscrito>> _estudiantes;

  @override
  void initState() {
    super.initState();
    _curso = ObtenerCurso(widget.cursoRepository)(widget.grupoId);
    _estudiantes = ObtenerEstudiantes(widget.cursoRepository)(widget.grupoId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Curso>(
      stream: _curso,
      builder: (context, snapCurso) {
        final curso = snapCurso.data;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            title: Text(curso?.nombreMateria ?? 'Curso'),
          ),
          body: curso == null
              ? Center(
                  child: snapCurso.hasError
                      ? Text('${snapCurso.error}')
                      : const CircularProgressIndicator(),
                )
              : _buildContenido(curso),
        );
      },
    );
  }

  Widget _buildContenido(Curso curso) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Cabecera(curso: curso),
        const SizedBox(height: 24),
        const Text(
          'Estudiantes',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<EstudianteInscrito>>(
          stream: _estudiantes,
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(
                '${snap.error}',
                style: const TextStyle(color: AppColors.error),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final lista = snap.data!;
            if (lista.isEmpty) {
              return const Text('Este curso aún no tiene estudiantes');
            }
            return Column(
              children: [
                for (final e in lista)
                  _FilaEstudiante(estudiante: e, meta: curso.metaAsistencia),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Datos principales del curso.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.curso});

  final Curso curso;

  static const _dias = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final horario = curso.horario
        .map((b) => '${_dias[b.dia]} ${b.inicio}–${b.fin}')
        .join('  ·  ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GRUPO ${curso.numeroGrupo} • ${curso.aula}',
            style: const TextStyle(
              color: AppColors.primaryFixed,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            curso.nombreMateria,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            curso.facultad,
            style: const TextStyle(color: AppColors.primaryFixed),
          ),
          const SizedBox(height: 12),
          Text(
            horario,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${curso.totalEstudiantes} estudiantes · '
            'Meta ${(curso.metaAsistencia * 100).round()} %',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Un estudiante con su porcentaje de asistencia.
class _FilaEstudiante extends StatelessWidget {
  const _FilaEstudiante({required this.estudiante, required this.meta});

  final EstudianteInscrito estudiante;
  final double meta;

  @override
  Widget build(BuildContext context) {
    final cumple = estudiante.porcentaje >= meta;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          estudiante.nombre.isEmpty ? estudiante.correo : estudiante.nombre,
        ),
        subtitle: Text(estudiante.correo),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cumple
                ? AppColors.attendancePresent
                : AppColors.attendanceWarning,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${(estudiante.porcentaje * 100).round()} %',
            style: TextStyle(
              color: cumple
                  ? AppColors.attendancePresentText
                  : AppColors.attendanceWarningText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

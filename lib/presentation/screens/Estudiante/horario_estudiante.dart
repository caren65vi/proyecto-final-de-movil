import 'package:flutter/material.dart';

import '../../../domain/entities/bloque_horario.dart';
import '../../../domain/entities/materia_estudiante.dart';
import '../../theme/app_colors.dart';

/// Pestaña de horario del estudiante: semana actual y cronograma del día.
class HorarioEstudiante extends StatefulWidget {
  const HorarioEstudiante({super.key, required this.materias});

  final List<MateriaEstudiante> materias;

  @override
  State<HorarioEstudiante> createState() => _HorarioEstudianteState();
}

class _HorarioEstudianteState extends State<HorarioEstudiante> {
  static const _diasCortos = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];
  static const _diasLargos = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  late final DateTime _hoy;
  late final List<DateTime> _semana; // de lunes a sábado
  late DateTime _diaSeleccionado;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final lunes = _hoy.subtract(Duration(days: _hoy.weekday - 1));
    _semana = List.generate(6, (i) => lunes.add(Duration(days: i)));

    // El domingo no está en la semana: se selecciona el lunes
    _diaSeleccionado = _hoy.weekday == DateTime.sunday ? lunes : _hoy;
  }

  // Ej. "Lunes, 24 de Marzo"
  String _fechaLarga(DateTime d) =>
      '${_diasLargos[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]}';

  // Clases del día seleccionado, ordenadas por hora de inicio
  List<({MateriaEstudiante materia, BloqueHorario bloque})> get _clasesDelDia {
    final clases = [
      for (final materia in widget.materias)
        for (final bloque in materia.curso.horario)
          if (bloque.dia == _diaSeleccionado.weekday)
            (materia: materia, bloque: bloque),
    ];
    clases.sort((a, b) => a.bloque.inicio.compareTo(b.bloque.inicio));
    return clases;
  }

  @override
  Widget build(BuildContext context) {
    final clases = _clasesDelDia;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          _fechaLarga(_diaSeleccionado),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),

        // Días de la semana
        Row(
          children: [
            for (var i = 0; i < _semana.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _DiaSemana(
                  nombre: _diasCortos[i],
                  numero: _semana[i].day,
                  seleccionado: _semana[i] == _diaSeleccionado,
                  esHoy: _semana[i] == _hoy,
                  onTap: () => setState(() => _diaSeleccionado = _semana[i]),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 24),

        // Cronograma del día seleccionado
        const Text(
          'Cronograma de Clases',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),

        if (clases.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Column(
              children: [
                Icon(Icons.event_available, size: 40, color: AppColors.outline),
                SizedBox(height: 8),
                Text(
                  'No tienes clases este día',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          for (final clase in clases) ...[
            _ClaseDelDia(materia: clase.materia, bloque: clase.bloque),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// Una clase del cronograma: hora a la izquierda, materia y aula a la derecha.
class _ClaseDelDia extends StatelessWidget {
  final MateriaEstudiante materia;
  final BloqueHorario bloque;

  const _ClaseDelDia({required this.materia, required this.bloque});

  @override
  Widget build(BuildContext context) {
    final curso = materia.curso;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(
                  bloque.inicio,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  bloque.fin,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 3,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  curso.nombreMateria,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Aula ${curso.aula} · ${curso.docenteNombre}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaSemana extends StatelessWidget {
  final String nombre;
  final int numero;
  final bool seleccionado;
  final bool esHoy;
  final VoidCallback onTap;

  const _DiaSemana({
    required this.nombre,
    required this.numero,
    required this.seleccionado,
    required this.esHoy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = seleccionado ? Colors.white : AppColors.textPrimary;

    return Material(
      color: seleccionado ? AppColors.primaryDark : AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      elevation: seleccionado ? 2 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                nombre,
                style: TextStyle(
                  color: seleccionado ? Colors.white : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$numero',
                style: TextStyle(
                  color: colorTexto,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              // Punto que marca el día de hoy
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: esHoy ? colorTexto : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

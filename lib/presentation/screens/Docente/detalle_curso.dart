import 'package:flutter/material.dart';

import '../../../domain/entities/bloque_horario.dart';
import '../../../domain/entities/curso.dart';
import '../../../domain/entities/estudiante_inscrito.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

/// Gestionar clase: próximas sesiones del curso y estudiantes matriculados.
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

  final _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _curso = ObtenerCurso(widget.cursoRepository)(widget.grupoId);
    _estudiantes = ObtenerEstudiantes(widget.cursoRepository)(widget.grupoId);
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  late final _agregar = AgregarEstudiante(widget.cursoRepository);
  late final _quitar = QuitarEstudiante(widget.cursoRepository);

  void _mostrar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // La toma de asistencia (QR) todavía no está construida
  void _iniciarClase() =>
      _mostrar('La toma de asistencia estará disponible pronto');

  Future<void> _mostrarAgregar() async {
    final correo = TextEditingController();
    final nombre = TextEditingController();
    final codigo = TextEditingController();
    try {
      final agregar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Agregar estudiante'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo institucional',
                  ),
                ),
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                ),
                TextField(
                  controller: codigo,
                  decoration: const InputDecoration(
                    labelText: 'Código (opcional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      );
      if (agregar != true || !mounted) return;

      await _agregar(
        widget.grupoId,
        correo: correo.text,
        nombre: nombre.text,
        codigo: codigo.text,
      );
      _mostrar('Estudiante agregado');
    } on CursoError catch (e) {
      _mostrar(e.mensaje);
    } finally {
      correo.dispose();
      nombre.dispose();
      codigo.dispose();
    }
  }

  Future<void> _confirmarQuitar(EstudianteInscrito estudiante) async {
    final quitar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar estudiante'),
        content: Text('¿Quitar a ${estudiante.correo} de este curso?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (quitar != true || !mounted) return;
    try {
      await _quitar(widget.grupoId, estudiante.correo);
    } on CursoError catch (e) {
      _mostrar(e.mensaje);
    }
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
            titleSpacing: 0,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/ceiba_logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestionar Clase',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (curso != null)
                        Text(
                          'Grupo ${curso.numeroGrupo} • ${curso.aula}',
                          overflow: TextOverflow.ellipsis,
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
          ),
          body: curso == null
              ? Center(
                  child: snapCurso.hasError
                      ? Text('${snapCurso.error}')
                      : const CircularProgressIndicator(),
                )
              : _buildContenido(curso),
          bottomNavigationBar: curso == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _BotonVerde(
                      icono: Icons.edit,
                      texto: 'Editar Curso',
                      alto: 52,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.editarCurso,
                        arguments: curso,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildContenido(Curso curso) {
    final sesiones = _proximasSesiones(curso);
    final finalizado = sesiones.isNotEmpty && sesiones.every((s) => s.finalizado);
    // La primera que no está en curso ni finalizada es la "próxima"
    final indiceProxima =
        sesiones.indexWhere((s) => !s.enCurso && !s.finalizado);
    debugPrint(
      '[DetalleCurso] ${curso.id} inicio=${curso.fechaInicio} '
      'fin=${curso.fechaFin} horario=${curso.horario.length} bloques',
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ---------- Horario de clase ----------
        const _TituloSeccion(
          icono: Icons.calendar_month_outlined,
          texto: 'Horario de Clase',
        ),
        const SizedBox(height: 12),
        if (curso.horario.isEmpty)
          const _TextoVacio(
            'Este curso no tiene horarios. Agrégalos en "Editar Curso".',
          )
        else if (sesiones.isEmpty)
          const _TextoVacio(
            'Ningún día del horario cae dentro del período del curso. '
            'Revisa las fechas en "Editar Curso".',
          ),
        if (finalizado) ...[
          _Aviso(
            'El curso terminó el ${_fechaCorta(curso.fechaFin)}. '
            'Para dictar más clases cambia el período en "Editar Curso".',
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < sesiones.length; i++) ...[
          _TarjetaSesion(
            sesion: sesiones[i],
            aula: curso.aula,
            esProxima: i == indiceProxima,
            onIniciar: _iniciarClase,
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 12),

        // ---------- Alumnos matriculados ----------
        StreamBuilder<List<EstudianteInscrito>>(
          stream: _estudiantes,
          builder: (context, snap) {
            final lista = snap.data ?? const <EstudianteInscrito>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: _TituloSeccion(
                        icono: Icons.groups_outlined,
                        texto: 'Alumnos Matriculados',
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${lista.length} estudiantes',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _BotonVerde(
                      icono: Icons.person_add_alt_1,
                      texto: 'Agregar\nAlumno',
                      alto: 40,
                      onPressed: _mostrarAgregar,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Buscador(
                  controller: _busquedaController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                ..._buildEstudiantes(snap, lista, curso),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildEstudiantes(
    AsyncSnapshot<List<EstudianteInscrito>> snap,
    List<EstudianteInscrito> lista,
    Curso curso,
  ) {
    if (snap.hasError) {
      return [
        Text('${snap.error}', style: const TextStyle(color: AppColors.error)),
      ];
    }
    if (!snap.hasData) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (lista.isEmpty) {
      return const [_TextoVacio('Este curso aún no tiene estudiantes')];
    }

    // Busca por nombre, código o correo
    final texto = _busquedaController.text.trim().toLowerCase();
    final filtrados = texto.isEmpty
        ? lista
        : lista.where((e) {
            return e.nombre.toLowerCase().contains(texto) ||
                (e.codigoEstudiante ?? '').toLowerCase().contains(texto) ||
                e.correo.contains(texto);
          }).toList();
    if (filtrados.isEmpty) {
      return const [_TextoVacio('Ningún estudiante coincide con la búsqueda')];
    }

    return [
      for (final e in filtrados) ...[
        _FilaEstudiante(
          estudiante: e,
          meta: curso.metaAsistencia,
          onQuitar: () => _confirmarQuitar(e),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}

// ---------- Cálculo de las próximas sesiones ----------

/// Una clase concreta: la fecha en que cae un bloque del horario.
class _Sesion {
  final DateTime fecha;
  final BloqueHorario bloque;
  final bool enCurso;
  final bool finalizado; // el período del curso ya terminó

  const _Sesion({
    required this.fecha,
    required this.bloque,
    this.enCurso = false,
    this.finalizado = false,
  });
}

const _mesesCortos = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

// Ej. "14 Jun 2026"
String _fechaCorta(DateTime d) =>
    '${d.day} ${_mesesCortos[d.month - 1]} ${d.year}';

DateTime _conHora(DateTime dia, String hora) {
  final partes = hora.split(':');
  return DateTime(
    dia.year,
    dia.month,
    dia.day,
    int.parse(partes[0]),
    int.parse(partes[1]),
  );
}

/// La siguiente vez que se dicta cada bloque, ordenadas por fecha.
/// Si el curso ya terminó, la última vez que se dictó (marcada finalizada).
List<_Sesion> _proximasSesiones(Curso curso) {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final inicio = DateTime(
    curso.fechaInicio.year,
    curso.fechaInicio.month,
    curso.fechaInicio.day,
  );
  final fin = DateTime(
    curso.fechaFin.year,
    curso.fechaFin.month,
    curso.fechaFin.day,
  );
  // Si el curso aún no empieza, se cuenta desde su primer día
  final desde = hoy.isBefore(inicio) ? inicio : hoy;

  final sesiones = <_Sesion>[];
  for (final bloque in curso.horario) {
    var dia = desde.add(Duration(days: (bloque.dia - desde.weekday + 7) % 7));
    // Si la clase de hoy ya terminó, se pasa a la otra semana
    if (!_conHora(dia, bloque.fin).isAfter(ahora)) {
      dia = dia.add(const Duration(days: 7));
    }
    if (dia.isAfter(fin)) {
      // Última vez que cayó ese día dentro del período
      final ultima =
          fin.subtract(Duration(days: (fin.weekday - bloque.dia + 7) % 7));
      if (ultima.isBefore(inicio)) continue; // ese día nunca cae en el período
      sesiones.add(_Sesion(fecha: ultima, bloque: bloque, finalizado: true));
      continue;
    }
    final enCurso = !ahora.isBefore(_conHora(dia, bloque.inicio)) &&
        ahora.isBefore(_conHora(dia, bloque.fin));
    sesiones.add(_Sesion(fecha: dia, bloque: bloque, enCurso: enCurso));
  }
  sesiones.sort(
    (a, b) => _conHora(a.fecha, a.bloque.inicio)
        .compareTo(_conHora(b.fecha, b.bloque.inicio)),
  );
  return sesiones;
}

// ---------- Widgets ----------

/// Aviso amarillo con un icono de información.
class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: AppColors.onTertiaryContainer,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 20, color: AppColors.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TextoVacio extends StatelessWidget {
  const _TextoVacio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

/// Botón verde oscuro con icono (Iniciar clase, Agregar Alumno, Editar Curso).
class _BotonVerde extends StatelessWidget {
  const _BotonVerde({
    required this.icono,
    required this.texto,
    required this.onPressed,
    this.alto = 44,
  });

  final IconData icono;
  final String texto;
  final VoidCallback? onPressed; // null = deshabilitado
  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        icon: Icon(icono, size: 18),
        label: Text(texto, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Tarjeta de una sesión: fecha, estado, hora, aula y botón de iniciar.
class _TarjetaSesion extends StatelessWidget {
  const _TarjetaSesion({
    required this.sesion,
    required this.aula,
    required this.esProxima,
    required this.onIniciar,
  });

  final _Sesion sesion;
  final String aula;
  final bool esProxima;
  final VoidCallback onIniciar;

  static const _diasCortos = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
  static const _diasLargos = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  // "07:00" → "07:00 AM", "14:30" → "02:30 PM"
  static String _hora12(String hora) {
    final partes = hora.split(':');
    final h = int.parse(partes[0]);
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:${partes[1]} '
        '${h < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final colorBorde = sesion.enCurso
        ? AppColors.primary
        : sesion.finalizado
            ? AppColors.outlineVariant
            : AppColors.tertiary;
    final indiceDia = sesion.fecha.weekday - 1;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: colorBorde),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // Fecha: "LUN / 07"
                        Container(
                          width: 44,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _diasCortos[indiceDia],
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                sesion.fecha.day.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _diasLargos[indiceDia],
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (sesion.enCurso)
                                    const _Etiqueta(
                                      texto: 'En sesión',
                                      fondo: AppColors.attendancePresent,
                                      color: AppColors.attendancePresentText,
                                    )
                                  else if (sesion.finalizado)
                                    const _Etiqueta(
                                      texto: 'Finalizado',
                                      fondo: AppColors.surfaceContainer,
                                      color: AppColors.textSecondary,
                                    )
                                  else if (esProxima)
                                    const _Etiqueta(
                                      texto: 'Próxima sesión',
                                      fondo: AppColors.tertiaryFixed,
                                      color: AppColors.onTertiaryContainer,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_hora12(sesion.bloque.inicio)} – '
                                '${_hora12(sesion.bloque.fin)} • $aula',
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
                    const SizedBox(height: 12),
                    _BotonVerde(
                      icono: Icons.play_arrow_rounded,
                      texto: 'Iniciar clase',
                      onPressed: sesion.finalizado ? null : onIniciar,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.texto,
    required this.fondo,
    required this.color,
  });

  final String texto;
  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Buscador extends StatelessWidget {
  const _Buscador({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o código institucional...',
        hintStyle: const TextStyle(color: AppColors.outline, fontSize: 13),
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.surfaceLow,
        contentPadding: EdgeInsets.zero,
        constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
        border: borde,
        enabledBorder: borde,
        focusedBorder: borde.copyWith(
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Un estudiante: iniciales, nombre, código, asistencia y botón de quitar.
class _FilaEstudiante extends StatelessWidget {
  const _FilaEstudiante({
    required this.estudiante,
    required this.meta,
    required this.onQuitar,
  });

  final EstudianteInscrito estudiante;
  final double meta;
  final VoidCallback onQuitar;

  // Colores del círculo de iniciales (fondo, texto)
  static const _coloresAvatar = [
    (AppColors.primaryFixed, AppColors.primary),
    (AppColors.secondaryFixed, AppColors.secondary),
    (AppColors.tertiaryFixed, AppColors.onTertiaryContainer),
    (AppColors.surfaceHigh, AppColors.textSecondary),
  ];

  String get _nombre =>
      estudiante.nombre.trim().isEmpty ? estudiante.correo : estudiante.nombre;

  // "Sofía Alvarado" → "SA"
  String get _iniciales {
    final partes = _nombre
        .replaceAll(',', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    final primera = partes.first[0];
    final segunda = partes.length > 1 ? partes[1][0] : '';
    return (primera + segunda).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cumple = estudiante.porcentaje >= meta;
    final porcentaje = (estudiante.porcentaje * 100).round();
    final colores =
        _coloresAvatar[estudiante.correo.hashCode % _coloresAvatar.length];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colores.$1,
            child: Text(
              _iniciales,
              style: TextStyle(
                color: colores.$2,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: 'ID: '
                            '${estudiante.codigoEstudiante ?? estudiante.correo}'
                            ' • ',
                      ),
                      TextSpan(
                        text: cumple
                            ? '$porcentaje% asist.'
                            : '$porcentaje% alerta',
                        style: TextStyle(
                          color: cumple
                              ? AppColors.attendancePresentText
                              : AppColors.attendanceWarningText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar',
            color: AppColors.error,
            icon: const Icon(Icons.delete_outline),
            onPressed: onQuitar,
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/entities/materia_estudiante.dart';
import '../../../domain/entities/usuario.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../../domain/usecases/facultad_usecases.dart';
import '../../../domain/usecases/inscripcion_usecases.dart';
import '../../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import 'asistencia_estudiante.dart';
import 'horario_estudiante.dart';
import 'perfil_estudiante.dart';

/// Pantalla de inicio del estudiante: saludo, buscador, filtro por día y cursos.
class HomeEstudianteScreen extends StatefulWidget {
  const HomeEstudianteScreen({
    super.key,
    required this.usuario,
    required this.cerrarSesion,
    required this.obtenerMisMaterias,
    required this.enlazarCuenta,
    required this.obtenerFacultades,
    required this.obtenerProgramas,
    required this.asignarPrograma,
  });

  final Usuario usuario;
  final CerrarSesion cerrarSesion;
  final ObtenerMisMaterias obtenerMisMaterias;
  final EnlazarCuenta enlazarCuenta;

  // Para que el estudiante elija su facultad y programa en el Perfil
  final ObtenerFacultades obtenerFacultades;
  final ObtenerProgramas obtenerProgramas;
  final AsignarProgramaEstudiante asignarPrograma;

  @override
  State<HomeEstudianteScreen> createState() => _HomeEstudianteScreenState();
}

class _HomeEstudianteScreenState extends State<HomeEstudianteScreen> {
  // 0 = Cursos, 1 = Horario, 2 = Asistencia, 3 = Perfil
  int _pestana = 0;

  final _busquedaController = TextEditingController();

  // Filtro por día: null = todos
  String? _diaSeleccionado;

  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  late final Stream<List<MateriaEstudiante>> _materiasStream;

  @override
  void initState() {
    super.initState();
    _materiasStream = widget
        .obtenerMisMaterias(widget.usuario.correo)
        .asBroadcastStream();
    _escucharMaterias();
    _enlazarCuenta();
  }

  // Materias del estudiante (las comparten las pestañas Cursos y Horario)
  StreamSubscription<List<MateriaEstudiante>>? _suscripcion;
  List<MateriaEstudiante> _materias = const [];
  bool _cargando = true;
  String? _error;

  // Título de la cabecera según la pestaña (Cursos y Horario solo llevan el logo)
  String? get _tituloCabecera => switch (_pestana) {
    2 => 'Asistencia',
    3 => 'Mi Perfil',
    _ => null,
  };

  // Primer nombre para el saludo (ej. "Camilo Pérez" → "Camilo")
  String get _primerNombre => widget.usuario.nombre.trim().split(' ').first;

  void _escucharMaterias() {
    _suscripcion = _materiasStream.listen(
      (materias) {
        if (!mounted) return;
        setState(() {
          _materias = materias;
          _cargando = false;
          _error = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _error = e.toString();
        });
      },
    );
  }

  // Guarda el uid en las inscripciones; si falla, la app sigue funcionando
  Future<void> _enlazarCuenta() async {
    try {
      await widget.enlazarCuenta(widget.usuario.correo, widget.usuario.uid);
    } catch (e) {
      debugPrint('No se pudo enlazar la cuenta: $e');
    }
  }

  // Materias que cumplen la búsqueda y el filtro por día
  List<MateriaEstudiante> get _materiasFiltradas {
    final texto = _busquedaController.text.trim().toLowerCase();
    final dia = _diaSeleccionado == null
        ? null
        : _dias.indexOf(_diaSeleccionado!) + 1;
    return _materias.where((m) {
      final c = m.curso;
      final coincideTexto =
          texto.isEmpty ||
          c.nombreMateria.toLowerCase().contains(texto) ||
          c.docenteNombre.toLowerCase().contains(texto);
      final coincideDia = dia == null || c.horario.any((b) => b.dia == dia);
      return coincideTexto && coincideDia;
    }).toList();
  }

  // Abre el escáner con los cursos para mostrar la clase en curso
  void _abrirEscaner() => Navigator.pushNamed(
    context,
    AppRoutes.escanearQR,
    arguments: [for (final m in _materias) m.curso],
  );

  @override
  void dispose() {
    _suscripcion?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  // Cierra la sesión en Firebase y deja solo el login en la pila
  // (si la sesión se restauró al abrir la app, el login no está debajo)
  Future<void> _cerrarSesion() async {
    await widget.cerrarSesion();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Solo se sale con "Cerrar sesión" del perfil, no con el botón atrás
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: AppColors.primary.withValues(alpha: 0.08),
          automaticallyImplyLeading: false,
          titleSpacing: 16,
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
              // En Asistencia y Perfil la cabecera lleva el nombre de la sección
              if (_tituloCabecera != null) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CEIBA',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        height: 1,
                      ),
                    ),
                    Text(
                      _tituloCabecera!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Notificaciones',
              onPressed: () {},
              color: AppColors.textSecondary,
              icon: const Icon(Icons.notifications_outlined, size: 22),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: IndexedStack(
          index: _pestana,
          children: [
            _buildCursos(),
            HorarioEstudiante(materias: _materiasStream),
            AsistenciaEstudiante(
              materias: _materias,
              cargando: _cargando,
              error: _error,
            ),
            PerfilEstudiante(
              usuario: widget.usuario,
              onCerrarSesion: _cerrarSesion,
              obtenerFacultades: widget.obtenerFacultades,
              obtenerProgramas: widget.obtenerProgramas,
              asignarPrograma: widget.asignarPrograma,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _abrirEscaner,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: (i) => setState(() => _pestana = i),
          backgroundColor: AppColors.surfaceContainer,
          indicatorColor: AppColors.primaryFixed,
          height: 64,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Cursos',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Horario',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'Asistencia',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCursos() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Saludo
        Text(
          'Hola, $_primerNombre 👋',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.26,
          ),
        ),

        const SizedBox(height: 16),

        // Buscador
        TextField(
          controller: _busquedaController,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por materia o profesor...',
            hintStyle: const TextStyle(color: AppColors.outline, fontSize: 14),
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: AppColors.surfaceLow,
            contentPadding: EdgeInsets.zero,
            constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Filtro rápido por día
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ChipDia(
                texto: 'Todos',
                seleccionado: _diaSeleccionado == null,
                onTap: () => setState(() => _diaSeleccionado = null),
              ),
              for (final dia in _dias) ...[
                const SizedBox(width: 6),
                _ChipDia(
                  texto: dia,
                  seleccionado: _diaSeleccionado == dia,
                  onTap: () => setState(() => _diaSeleccionado = dia),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        ..._buildListaMaterias(),
      ],
    );
  }

  List<Widget> _buildListaMaterias() {
    if (_cargando) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [_Mensaje(icono: Icons.error_outline, texto: _error!)];
    }
    if (_materias.isEmpty) {
      return const [
        _Mensaje(
          icono: Icons.school_outlined,
          texto: 'Aún no estás inscrito en ninguna materia',
        ),
      ];
    }
    final materias = _materiasFiltradas;
    if (materias.isEmpty) {
      return const [
        _Mensaje(
          icono: Icons.search_off,
          texto: 'Ninguna materia coincide con el filtro',
        ),
      ];
    }
    return [
      for (final materia in materias) ...[
        _TarjetaMateria(materia: materia),
        const SizedBox(height: 12),
      ],
    ];
  }
}

/// Tarjeta de una materia: nombre, docente, horario y asistencia.
class _TarjetaMateria extends StatelessWidget {
  final MateriaEstudiante materia;

  const _TarjetaMateria({required this.materia});

  static const _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final curso = materia.curso;
    final porcentaje = materia.inscripcion.porcentaje;
    final alDia = porcentaje >= curso.metaAsistencia;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  curso.nombreMateria,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Porcentaje de asistencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: alDia
                      ? AppColors.attendancePresent
                      : AppColors.attendanceWarning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(porcentaje * 100).round()} %',
                  style: TextStyle(
                    color: alDia
                        ? AppColors.attendancePresentText
                        : AppColors.attendanceWarningText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${curso.docenteNombre} · Grupo ${curso.numeroGrupo}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          _Dato(icono: Icons.place_outlined, texto: 'Aula ${curso.aula}'),
          for (final bloque in curso.horario) ...[
            const SizedBox(height: 4),
            _Dato(
              icono: Icons.schedule,
              texto:
                  '${_diasCortos[bloque.dia - 1]} ${bloque.inicio} – ${bloque.fin}',
            ),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Dato({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 16, color: AppColors.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Mensaje centrado con un icono (vacío, error, sin resultados).
class _Mensaje extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Mensaje({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(icono, size: 40, color: AppColors.outline),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ChipDia extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipDia({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? AppColors.primary : AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
      elevation: seleccionado ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: TextStyle(
              color: seleccionado ? Colors.white : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

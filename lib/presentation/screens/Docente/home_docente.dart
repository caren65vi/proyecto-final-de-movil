import 'package:flutter/material.dart';

import '../../../domain/entities/curso.dart';
import '../../../domain/entities/usuario.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../theme/app_colors.dart';
import 'crear_curso.dart';
import 'estadisticas_docente.dart';
import 'perfil_docente.dart';

// Tonos del diseño que no están en AppColors
const Color _onPrimaryContainer = Color(0xFF86BEAB);
const Color _onTertiaryContainer = Color(0xFF4E3D00);

/// Pantalla de inicio del docente: saludo, nuevo curso y lista de cursos.
class HomeDocenteScreen extends StatefulWidget {
  const HomeDocenteScreen({
    super.key,
    required this.usuario,
    required this.cerrarSesion,
    required this.cursoRepository,
  });

  final Usuario usuario;
  final CerrarSesion cerrarSesion;
  final CursoRepository cursoRepository;

  @override
  State<HomeDocenteScreen> createState() => _HomeDocenteScreenState();
}

class _HomeDocenteScreenState extends State<HomeDocenteScreen> {
  // 0 = Inicio, 1 = Estadísticas, 2 = Perfil
  int _pestana = 0;

  static const _titulos = ['Inicio', 'Estadísticas', 'Perfil'];

  // Se crea una sola vez para no reiniciar la escucha en cada reconstrucción
  late final Stream<List<Curso>> _misCursos = ObtenerMisCursos(
    widget.cursoRepository,
  )(widget.usuario.uid);

  // Cierra la sesión en Firebase y vuelve al login (la primera pantalla)
  Future<void> _cerrarSesion() async {
    await widget.cerrarSesion();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Solo se sale con "Cerrar sesión", no con el botón atrás
    return PopScope(canPop: false, child: _buildScaffold());
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/ceiba_logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ceiba Docente',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                Text(
                  _titulos[_pestana],
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: switch (_pestana) {
        0 => _buildInicio(),
        1 => const EstadisticasDocente(),
        _ => PerfilDocente(
          usuario: widget.usuario,
          onCerrarSesion: _cerrarSesion,
        ),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.primaryFixed,
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildInicio() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // 1. Bienvenida
        Text(
          'Hola, Prof. ${widget.usuario.nombre}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.26,
          ),
        ),

        const SizedBox(height: 24),

        // 2. Registrar nuevo curso
        _BotonNuevoCurso(onTap: _abrirCrearCurso),

        const SizedBox(height: 24),

        // 3. Mis cursos (se actualiza solo cuando cambian en Firestore)
        StreamBuilder<List<Curso>>(
          stream: _misCursos,
          builder: (context, snapshot) {
            final cursos = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TituloMisCursos(cantidad: cursos?.length),
                const SizedBox(height: 16),
                if (snapshot.hasError)
                  _MensajeLista(
                    icono: Icons.cloud_off,
                    texto: snapshot.error is CursoError
                        ? (snapshot.error as CursoError).mensaje
                        : 'No se pudieron cargar tus cursos.',
                  )
                else if (cursos == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (cursos.isEmpty)
                  const _MensajeLista(
                    icono: Icons.class_outlined,
                    texto: 'Aún no has creado cursos.',
                  )
                else
                  for (final curso in cursos) ...[
                    _TarjetaCurso(curso: curso),
                    const SizedBox(height: 16),
                  ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _abrirCrearCurso() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CrearCursoScreen(
          usuario: widget.usuario,
          cursoRepository: widget.cursoRepository,
        ),
      ),
    );
    if (creado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Curso creado correctamente')),
      );
    }
  }
}

class _TituloMisCursos extends StatelessWidget {
  final int? cantidad;

  const _TituloMisCursos({required this.cantidad});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Mis Cursos',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (cantidad != null && cantidad! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$cantidad',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Aviso centrado para la lista vacía o con error.
class _MensajeLista extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _MensajeLista({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icono, size: 32, color: AppColors.outline),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un curso: grupo y aula, nombre, facultad, fechas y acción.
class _TarjetaCurso extends StatelessWidget {
  final Curso curso;

  const _TarjetaCurso({required this.curso});

  static const _meses = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  // Ej. "10 Feb 2025"
  String _fecha(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final etiqueta = [
      'Grupo ${curso.numeroGrupo}',
      if (curso.aula.isNotEmpty) curso.aula,
    ].join(' • ');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banda lateral institucional
            Container(width: 6, color: AppColors.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      etiqueta.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      curso.nombreMateria,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      curso.facultad,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Fechas de inicio y fin
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Fecha(
                              icono: Icons.event,
                              colorIcono: AppColors.primaryDark,
                              etiqueta: 'Inicio:',
                              fecha: _fecha(curso.fechaInicio),
                            ),
                          ),
                          const Text(
                            '•',
                            style: TextStyle(color: AppColors.outlineVariant),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _Fecha(
                                icono: Icons.event_available,
                                colorIcono: AppColors.attendanceWarningText,
                                etiqueta: 'Fin:',
                                fecha: _fecha(curso.fechaFin),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // TODO: abrir la gestión de la clase cuando exista
                        onPressed: () {},
                        icon: const Icon(Icons.fact_check_outlined, size: 18),
                        label: const Text('Gestionar Clase'),
                      ),
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

class _Fecha extends StatelessWidget {
  final IconData icono;
  final Color colorIcono;
  final String etiqueta;
  final String fecha;

  const _Fecha({
    required this.icono,
    required this.colorIcono,
    required this.etiqueta,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: colorIcono),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$etiqueta ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: fecha),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón destacado para abrir un curso nuevo.
class _BotonNuevoCurso extends StatelessWidget {
  final VoidCallback onTap;

  const _BotonNuevoCurso({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Resplandor decorativo
            Positioned(
              right: -24,
              bottom: -24,
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tertiary.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.tertiary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 26,
                      color: _onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar nuevo curso',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Apertura de grupo, cupos y sílabo',
                          style: TextStyle(
                            color: _onPrimaryContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../domain/entities/usuario.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/auth_usecases.dart';
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

  // Cierra la sesión en Firebase y vuelve al login (la primera pantalla)
  Future<void> _cerrarSesion() async {
    await widget.cerrarSesion();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Solo se sale con "Cerrar sesión", no con el botón atrás
    return PopScope(
      canPop: false,
      child: _buildScaffold(),
    );
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
        _BotonNuevoCurso(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CrearCursoScreen(
                usuario: widget.usuario,
                cursoRepository: widget.cursoRepository,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 3. Mis cursos
        const Text(
          'Mis Cursos',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
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

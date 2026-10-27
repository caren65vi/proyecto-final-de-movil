import 'package:flutter/material.dart';

import '../../../domain/entities/usuario.dart';
import '../../../domain/usecases/auth_usecases.dart';
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
  });

  final Usuario usuario;
  final CerrarSesion cerrarSesion;

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

  // Título de la cabecera según la pestaña (Cursos y Horario solo llevan el logo)
  String? get _tituloCabecera => switch (_pestana) {
        2 => 'Asistencia',
        3 => 'Mi Perfil',
        _ => null,
      };

  // Primer nombre para el saludo (ej. "Camilo Pérez" → "Camilo")
  String get _primerNombre => widget.usuario.nombre.trim().split(' ').first;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  // Cierra la sesión en Firebase y vuelve al login (la primera pantalla)
  Future<void> _cerrarSesion() async {
    await widget.cerrarSesion();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
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
        body: switch (_pestana) {
          0 => _buildCursos(),
          1 => const HorarioEstudiante(),
          2 => const AsistenciaEstudiante(),
          _ => PerfilEstudiante(
              usuario: widget.usuario,
              onCerrarSesion: _cerrarSesion,
            ),
        },
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
      ],
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

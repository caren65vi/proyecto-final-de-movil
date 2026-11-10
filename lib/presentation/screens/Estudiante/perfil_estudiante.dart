import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/facultad.dart';
import '../../../domain/entities/programa.dart';
import '../../../domain/entities/usuario.dart';
import '../../../domain/repositories/facultad_repository.dart';
import '../../../domain/usecases/facultad_usecases.dart';
import '../../theme/app_colors.dart';

// Tonos del diseño que no están en AppColors
const Color _errorContainer = Color(0xFFFFDAD6);
const Color _onErrorContainer = Color(0xFF93000A);

/// Pestaña de perfil del estudiante: identidad, correo y cierre de sesión.
class PerfilEstudiante extends StatelessWidget {
  const PerfilEstudiante({
    super.key,
    required this.usuario,
    required this.onCerrarSesion,
    required this.obtenerFacultades,
    required this.obtenerProgramas,
    required this.asignarPrograma,
  });

  final Usuario usuario;
  final VoidCallback onCerrarSesion;

  // Para elegir la facultad y el programa del estudiante
  final ObtenerFacultades obtenerFacultades;
  final ObtenerProgramas obtenerProgramas;
  final AsignarProgramaEstudiante asignarPrograma;

  // Iniciales del nombre para el avatar (ej. "Camilo Torres" → "CT")
  String get _iniciales {
    final partes = usuario.nombre.trim().split(RegExp(r'\s+'));
    return partes
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
  }

  void _copiarCorreo(BuildContext context) {
    Clipboard.setData(ClipboardData(text: usuario.correo));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Correo copiado')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Tarjeta de identidad
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Arco decorativo
              Positioned(
                top: -48,
                right: -48,
                child: Container(
                  width: 144,
                  height: 144,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primaryFixed,
                          child: Text(
                            _iniciales,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryDark,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        usuario.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Información académica
        const Text(
          'Información Académica',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.alternate_email,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Correo Institucional',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      usuario.correo,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copiar correo',
                onPressed: () => _copiarCorreo(context),
                color: AppColors.outline,
                icon: const Icon(Icons.content_copy, size: 18),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Facultad y programa al que pertenece
        _TarjetaPrograma(
          usuario: usuario,
          obtenerFacultades: obtenerFacultades,
          obtenerProgramas: obtenerProgramas,
          asignarPrograma: asignarPrograma,
        ),

        const SizedBox(height: 24),

        // Cierre de sesión
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _errorContainer,
              foregroundColor: _onErrorContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onCerrarSesion,
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('Cerrar Sesión'),
          ),
        ),
      ],
    );
  }
}

/// Facultad y programa del estudiante, con un botón para elegirlos.
/// Guarda lo elegido aquí mismo para mostrarlo sin volver a iniciar sesión.
class _TarjetaPrograma extends StatefulWidget {
  const _TarjetaPrograma({
    required this.usuario,
    required this.obtenerFacultades,
    required this.obtenerProgramas,
    required this.asignarPrograma,
  });

  final Usuario usuario;
  final ObtenerFacultades obtenerFacultades;
  final ObtenerProgramas obtenerProgramas;
  final AsignarProgramaEstudiante asignarPrograma;

  @override
  State<_TarjetaPrograma> createState() => _TarjetaProgramaState();
}

class _TarjetaProgramaState extends State<_TarjetaPrograma> {
  late String? _facultadId = widget.usuario.facultadId;
  late String? _facultad = widget.usuario.facultadNombre;
  late String? _programa = widget.usuario.programaNombre;

  Future<void> _elegir() async {
    final elegido = await showDialog<({Facultad facultad, Programa programa})>(
      context: context,
      builder: (_) => _DialogoPrograma(
        uid: widget.usuario.uid,
        facultadInicial: _facultadId,
        obtenerFacultades: widget.obtenerFacultades,
        obtenerProgramas: widget.obtenerProgramas,
        asignarPrograma: widget.asignarPrograma,
      ),
    );
    if (elegido == null || !mounted) return;
    setState(() {
      _facultadId = elegido.facultad.id;
      _facultad = elegido.facultad.nombre;
      _programa = elegido.programa.nombre;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Programa guardado')));
  }

  @override
  Widget build(BuildContext context) {
    final tiene = _programa != null && _facultad != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.school_outlined,
              size: 20,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Facultad y Programa',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  tiene ? _programa! : 'Sin programa',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  tiene ? _facultad! : 'Elige tu facultad y tu programa',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _elegir,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: Text(tiene ? 'Cambiar' : 'Elegir'),
          ),
        ],
      ),
    );
  }
}

/// Dos listas: primero la facultad y luego un programa de esa facultad.
/// Al guardar devuelve lo elegido.
class _DialogoPrograma extends StatefulWidget {
  const _DialogoPrograma({
    required this.uid,
    required this.facultadInicial,
    required this.obtenerFacultades,
    required this.obtenerProgramas,
    required this.asignarPrograma,
  });

  final String uid;
  final String? facultadInicial;
  final ObtenerFacultades obtenerFacultades;
  final ObtenerProgramas obtenerProgramas;
  final AsignarProgramaEstudiante asignarPrograma;

  @override
  State<_DialogoPrograma> createState() => _DialogoProgramaState();
}

class _DialogoProgramaState extends State<_DialogoPrograma> {
  late final Stream<List<Facultad>> _facultades = widget.obtenerFacultades();
  late String? _facultadId = widget.facultadInicial;
  Stream<List<Programa>>? _programas;
  String? _programaId;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_facultadId != null) {
      _programas = widget.obtenerProgramas(_facultadId!);
    }
  }

  void _cambiarFacultad(String? id) {
    setState(() {
      _facultadId = id;
      _programaId = null;
      _programas = id == null ? null : widget.obtenerProgramas(id);
    });
  }

  Future<void> _guardar(
    List<Facultad> facultades,
    List<Programa> programas,
  ) async {
    final facultad = facultades.where((f) => f.id == _facultadId).firstOrNull;
    final programa = programas.where((p) => p.id == _programaId).firstOrNull;
    if (facultad == null || programa == null) {
      setState(() => _error = 'Elige la facultad y el programa');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.asignarPrograma(
        uid: widget.uid,
        facultad: facultad,
        programa: programa,
      );
      if (mounted) {
        Navigator.pop(context, (facultad: facultad, programa: programa));
      }
    } on FacultadError catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Facultad>>(
      stream: _facultades,
      builder: (context, snapFacultades) {
        final facultades = snapFacultades.data ?? const <Facultad>[];
        // Si la facultad guardada ya no existe, no se preselecciona
        final facultadValida = facultades.any((f) => f.id == _facultadId)
            ? _facultadId
            : null;
        return StreamBuilder<List<Programa>>(
          stream: _programas,
          builder: (context, snapProgramas) {
            final programas = facultadValida == null
                ? const <Programa>[]
                : (snapProgramas.data ?? const <Programa>[]);
            final programaValido = programas.any((p) => p.id == _programaId)
                ? _programaId
                : null;
            final sinProgramas =
                facultadValida != null &&
                snapProgramas.data != null &&
                programas.isEmpty;
            return AlertDialog(
              title: const Text('Mi facultad y programa'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (snapFacultades.data == null && !snapFacultades.hasError)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (facultades.isEmpty)
                    const Text(
                      'Todavía no hay facultades. Pídele a tu docente que '
                      'las cree.',
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey('facultad-$facultadValida'),
                      initialValue: facultadValida,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Facultad'),
                      items: [
                        for (final f in facultades)
                          DropdownMenuItem(value: f.id, child: Text(f.nombre)),
                      ],
                      onChanged: _guardando ? null : _cambiarFacultad,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('programa-$facultadValida-$programaValido'),
                      initialValue: programaValido,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Programa',
                        helperText: sinProgramas
                            ? 'Esta facultad aún no tiene programas'
                            : null,
                      ),
                      items: [
                        for (final p in programas)
                          DropdownMenuItem(value: p.id, child: Text(p.nombre)),
                      ],
                      onChanged: _guardando || facultadValida == null
                          ? null
                          : (id) => setState(() => _programaId = id),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: _guardando || programaValido == null
                      ? null
                      : () => _guardar(facultades, programas),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

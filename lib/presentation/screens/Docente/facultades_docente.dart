import 'package:flutter/material.dart';

import '../../../domain/entities/facultad.dart';
import '../../../domain/entities/usuario.dart';
import '../../../domain/repositories/facultad_repository.dart';
import '../../../domain/usecases/facultad_usecases.dart';
import '../../theme/app_colors.dart';

/// Pantalla para ver, crear y eliminar facultades / carreras.
/// Las facultades son compartidas: todos los docentes las ven al crear un curso,
/// pero cada docente solo puede eliminar las que creó.
class FacultadesScreen extends StatefulWidget {
  const FacultadesScreen({
    super.key,
    required this.usuario,
    required this.obtenerFacultades,
    required this.crearFacultad,
    required this.eliminarFacultad,
  });

  final Usuario usuario;
  final ObtenerFacultades obtenerFacultades;
  final CrearFacultad crearFacultad;
  final EliminarFacultad eliminarFacultad;

  @override
  State<FacultadesScreen> createState() => _FacultadesScreenState();
}

class _FacultadesScreenState extends State<FacultadesScreen> {
  late final Stream<List<Facultad>> _facultades = widget.obtenerFacultades();

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _nueva() async {
    final creada = await mostrarDialogoNuevaFacultad(
      context,
      crearFacultad: widget.crearFacultad,
      docenteUid: widget.usuario.uid,
    );
    if (creada != null && mounted) _aviso('Facultad "${creada.nombre}" creada');
  }

  Future<void> _eliminar(Facultad facultad) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar facultad'),
        content: Text(
          '¿Eliminar "${facultad.nombre}"?\n\n'
          'Los cursos que ya la usan la conservan; solo deja de aparecer '
          'al crear cursos nuevos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await widget.eliminarFacultad(facultad.id);
      if (mounted) _aviso('Facultad eliminada');
    } on FacultadError catch (e) {
      if (mounted) _aviso(e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Facultades',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nueva,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva facultad'),
      ),
      body: StreamBuilder<List<Facultad>>(
        stream: _facultades,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Mensaje(
              icono: Icons.cloud_off,
              texto: snapshot.error is FacultadError
                  ? (snapshot.error as FacultadError).mensaje
                  : 'No se pudieron cargar las facultades.',
            );
          }
          final lista = snapshot.data;
          if (lista == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (lista.isEmpty) {
            return const _Mensaje(
              icono: Icons.apartment_outlined,
              texto:
                  'Aún no hay facultades.\n'
                  'Crea la primera con el botón "Nueva facultad".',
            );
          }
          return ListView.separated(
            // Espacio abajo para que el botón no tape la última
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final facultad = lista[i];
              final esMia = facultad.creadaPor == widget.usuario.uid;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.apartment_outlined,
                        size: 20,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            facultad.nombre,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (esMia)
                            const Text(
                              'Creada por ti',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (esMia)
                      IconButton(
                        tooltip: 'Eliminar',
                        onPressed: () => _eliminar(facultad),
                        color: AppColors.attendanceWarningText,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Abre el diálogo para crear una facultad. Devuelve la facultad creada,
/// o null si el docente cancela. Se usa aquí y en el formulario de crear curso.
Future<Facultad?> mostrarDialogoNuevaFacultad(
  BuildContext context, {
  required CrearFacultad crearFacultad,
  required String docenteUid,
}) {
  return showDialog<Facultad>(
    context: context,
    builder: (_) => _DialogoNuevaFacultad(
      crearFacultad: crearFacultad,
      docenteUid: docenteUid,
    ),
  );
}

class _DialogoNuevaFacultad extends StatefulWidget {
  const _DialogoNuevaFacultad({
    required this.crearFacultad,
    required this.docenteUid,
  });

  final CrearFacultad crearFacultad;
  final String docenteUid;

  @override
  State<_DialogoNuevaFacultad> createState() => _DialogoNuevaFacultadState();
}

class _DialogoNuevaFacultadState extends State<_DialogoNuevaFacultad> {
  final _nombre = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final creada = await widget.crearFacultad(
        _nombre.text,
        widget.docenteUid,
      );
      if (mounted) Navigator.pop(context, creada);
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
    return AlertDialog(
      title: const Text('Nueva facultad'),
      content: TextField(
        controller: _nombre,
        autofocus: true,
        enabled: !_guardando,
        maxLength: CrearFacultad.largoMaximo,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _guardando ? null : _guardar(),
        decoration: InputDecoration(
          hintText: 'Ej. Facultad de Ingeniería',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }
}

/// Aviso centrado para la lista vacía o con error.
class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: AppColors.outline),
            const SizedBox(height: 12),
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
      ),
    );
  }
}

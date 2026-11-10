import 'package:flutter/material.dart';

import '../../../domain/entities/facultad.dart';
import '../../../domain/entities/programa.dart';
import '../../../domain/entities/usuario.dart';
import '../../../domain/repositories/facultad_repository.dart';
import '../../../domain/usecases/facultad_usecases.dart';
import '../../theme/app_colors.dart';

/// Pantalla para ver, crear y eliminar facultades y sus programas.
/// Son compartidas: todos los docentes las ven (y los estudiantes eligen
/// su programa), pero cada docente solo puede eliminar lo que creó.
class FacultadesScreen extends StatefulWidget {
  const FacultadesScreen({
    super.key,
    required this.usuario,
    required this.obtenerFacultades,
    required this.crearFacultad,
    required this.eliminarFacultad,
    required this.obtenerProgramas,
    required this.crearPrograma,
    required this.eliminarPrograma,
  });

  final Usuario usuario;
  final ObtenerFacultades obtenerFacultades;
  final CrearFacultad crearFacultad;
  final EliminarFacultad eliminarFacultad;
  final ObtenerProgramas obtenerProgramas;
  final CrearPrograma crearPrograma;
  final EliminarPrograma eliminarPrograma;

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

  Future<void> _nuevaFacultad() async {
    final creada = await mostrarDialogoNuevaFacultad(
      context,
      crearFacultad: widget.crearFacultad,
      docenteUid: widget.usuario.uid,
    );
    if (creada != null && mounted) _aviso('Facultad "${creada.nombre}" creada');
  }

  Future<void> _nuevoPrograma(Facultad facultad) async {
    final creado = await showDialog<Programa>(
      context: context,
      builder: (_) => _DialogoNombre<Programa>(
        titulo: 'Nuevo programa',
        subtitulo: facultad.nombre,
        ejemplo: 'Ej. Ingeniería de Sistemas',
        guardar: (nombre) =>
            widget.crearPrograma(facultad.id, nombre, widget.usuario.uid),
      ),
    );
    if (creado != null && mounted) _aviso('Programa "${creado.nombre}" creado');
  }

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
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
    return si == true;
  }

  Future<void> _eliminarFacultad(Facultad facultad) async {
    final si = await _confirmar(
      'Eliminar facultad',
      '¿Eliminar "${facultad.nombre}"?\n\n'
          'Los cursos que ya la usan la conservan; solo deja de aparecer '
          'al crear cursos nuevos.',
    );
    if (!si) return;
    try {
      await widget.eliminarFacultad(facultad.id);
      if (mounted) _aviso('Facultad eliminada');
    } on FacultadError catch (e) {
      if (mounted) _aviso(e.mensaje);
    }
  }

  Future<void> _eliminarPrograma(Programa programa) async {
    final si = await _confirmar(
      'Eliminar programa',
      '¿Eliminar "${programa.nombre}"?\n\n'
          'Los estudiantes que ya lo eligieron lo conservan en su perfil.',
    );
    if (!si) return;
    try {
      await widget.eliminarPrograma(programa.facultadId, programa.id);
      if (mounted) _aviso('Programa eliminado');
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
          'Facultades y Programas',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaFacultad,
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
              return _TarjetaFacultad(
                key: ValueKey(facultad.id),
                facultad: facultad,
                docenteUid: widget.usuario.uid,
                programas: widget.obtenerProgramas(facultad.id),
                onNuevoPrograma: () => _nuevoPrograma(facultad),
                onEliminar: () => _eliminarFacultad(facultad),
                onEliminarPrograma: _eliminarPrograma,
              );
            },
          );
        },
      ),
    );
  }
}

/// Una facultad que se despliega para mostrar sus programas.
class _TarjetaFacultad extends StatefulWidget {
  const _TarjetaFacultad({
    super.key,
    required this.facultad,
    required this.docenteUid,
    required this.programas,
    required this.onNuevoPrograma,
    required this.onEliminar,
    required this.onEliminarPrograma,
  });

  final Facultad facultad;
  final String docenteUid;
  final Stream<List<Programa>> programas;
  final VoidCallback onNuevoPrograma;
  final VoidCallback onEliminar;
  final ValueChanged<Programa> onEliminarPrograma;

  @override
  State<_TarjetaFacultad> createState() => _TarjetaFacultadState();
}

class _TarjetaFacultadState extends State<_TarjetaFacultad> {
  // Se guarda para no abrir otra consulta en cada build
  late final Stream<List<Programa>> _programas = widget.programas;

  @override
  Widget build(BuildContext context) {
    final facultad = widget.facultad;
    final esMia = facultad.creadaPor == widget.docenteUid;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: StreamBuilder<List<Programa>>(
        stream: _programas,
        builder: (context, snapshot) {
          final programas = snapshot.data ?? const <Programa>[];
          final cantidad = snapshot.data == null
              ? 'Cargando programas…'
              : '${programas.length} '
                    '${programas.length == 1 ? 'programa' : 'programas'}';
          return ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Container(
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
            title: Text(
              facultad.nombre,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              esMia ? '$cantidad · Creada por ti' : cantidad,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            children: [
              for (final p in programas)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 8),
                  leading: const Icon(
                    Icons.school_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  title: Text(p.nombre),
                  trailing: p.creadaPor == widget.docenteUid
                      ? IconButton(
                          tooltip: 'Eliminar programa',
                          onPressed: () => widget.onEliminarPrograma(p),
                          color: AppColors.attendanceWarningText,
                          icon: const Icon(Icons.delete_outline, size: 20),
                        )
                      : null,
                ),
              if (snapshot.data != null && programas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Esta facultad todavía no tiene programas.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: widget.onNuevoPrograma,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar programa'),
                  ),
                  const Spacer(),
                  if (esMia)
                    TextButton.icon(
                      onPressed: widget.onEliminar,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.attendanceWarningText,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar facultad'),
                    ),
                ],
              ),
            ],
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
    builder: (_) => _DialogoNombre<Facultad>(
      titulo: 'Nueva facultad',
      ejemplo: 'Ej. Facultad de Ingeniería',
      guardar: (nombre) => crearFacultad(nombre, docenteUid),
    ),
  );
}

/// Diálogo con un solo campo de nombre; [guardar] crea el elemento y
/// el diálogo lo devuelve al cerrarse. Muestra los errores sin cerrarse.
class _DialogoNombre<T> extends StatefulWidget {
  const _DialogoNombre({
    required this.titulo,
    required this.ejemplo,
    required this.guardar,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final String ejemplo;
  final Future<T> Function(String nombre) guardar;

  @override
  State<_DialogoNombre<T>> createState() => _DialogoNombreState<T>();
}

class _DialogoNombreState<T> extends State<_DialogoNombre<T>> {
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
      final creado = await widget.guardar(_nombre.text);
      if (mounted) Navigator.pop(context, creado);
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
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitulo != null) ...[
            Text(
              widget.subtitulo!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _nombre,
            autofocus: true,
            enabled: !_guardando,
            maxLength: largoMaximoNombre,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _guardando ? null : _guardar(),
            decoration: InputDecoration(
              hintText: widget.ejemplo,
              errorText: _error,
            ),
          ),
        ],
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

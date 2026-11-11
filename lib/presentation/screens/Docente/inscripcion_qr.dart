import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../domain/entities/curso.dart';
import '../../../domain/entities/estudiante_inscrito.dart';
import '../../../domain/repositories/curso_repository.dart';
import '../../../domain/usecases/curso_usecases.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mensaje_error.dart';

const _logo = 'assets/images/ceiba_logo.png';

// El servidor vence el código a los 5 minutos; se renueva antes
const _renovarCada = Duration(minutes: 4);

/// Respuesta de la pantalla cuando el docente prefiere escribir los datos.
const agregarAMano = 'manual';

/// El docente muestra un QR y los estudiantes lo escanean para inscribirse
/// al curso. No pide ubicación. Cada código sirve para un solo estudiante:
/// después de usarse cambia, y la pantalla muestra el nuevo.
///
/// Al salir devuelve cuántos se inscribieron, o [agregarAMano].
class InscripcionQrScreen extends StatefulWidget {
  const InscripcionQrScreen({
    super.key,
    required this.curso,
    required this.inscripcionQR,
    required this.obtenerEstudiantes,
  });

  final Curso curso;
  final InscripcionQR inscripcionQR;
  final ObtenerEstudiantes obtenerEstudiantes;

  @override
  State<InscripcionQrScreen> createState() => _InscripcionQrScreenState();
}

class _InscripcionQrScreenState extends State<InscripcionQrScreen> {
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _renovacion;

  String? _token;
  String? _error;

  // Correos que ya estaban al abrir; los demás son los que entraron ahora
  Set<String>? _yaInscritos;
  List<EstudianteInscrito> _nuevos = const [];

  String get _grupoId => widget.curso.id!;

  @override
  void initState() {
    super.initState();
    _abrir();
    _subs.add(
      widget.inscripcionQR
          .token(_grupoId)
          .listen((token) => _alCambiarToken(token), onError: _alFallar),
    );
    _subs.add(
      widget
          .obtenerEstudiantes(_grupoId)
          .listen(_alCambiarLista, onError: _alFallar),
    );
    _renovacion = Timer.periodic(_renovarCada, (_) => _abrir());
  }

  @override
  void dispose() {
    _renovacion?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _abrir() async {
    try {
      final token = await widget.inscripcionQR.abrir(_grupoId);
      _alCambiarToken(token);
    } catch (e) {
      _alFallar(e);
    }
  }

  void _alCambiarToken(String token) {
    if (!mounted || token == _token) return;
    setState(() {
      _token = token;
      _error = null;
    });
  }

  void _alCambiarLista(List<EstudianteInscrito> lista) {
    if (!mounted) return;
    setState(() {
      _yaInscritos ??= {for (final e in lista) e.correo};
      _nuevos = [
        for (final e in lista)
          if (!_yaInscritos!.contains(e.correo)) e,
      ];
    });
  }

  void _alFallar(Object error) {
    if (!mounted) return;
    setState(
      () => _error = error is CursoError
          ? error.mensaje
          : 'No se pudo generar el código. Revisa tu conexión.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final curso = widget.curso;
    final grupo = curso.numeroGrupo.trim();

    return PopScope(
      canPop: false,
      // El botón atrás también devuelve cuántos se inscribieron
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _nuevos.length);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(_logo, width: 32, height: 32),
              ),
              const SizedBox(width: 8),
              const Text(
                'Inscribir estudiantes',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              curso.nombreMateria,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (grupo.isNotEmpty)
              Text(
                'Grupo $grupo',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: _VistaQr(
                  datos: _token == null
                      ? null
                      : InscripcionQR.contenido(_grupoId, _token!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              MensajeError(texto: _error!),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _abrir,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const _Paso(
              icono: Icons.phone_android,
              texto:
                  'El estudiante abre Ceiba y en Cursos toca '
                  '"Inscribirme a una clase".',
            ),
            const _Paso(
              icono: Icons.qr_code_scanner,
              texto:
                  'Escanea este código. No necesita estar en el salón '
                  'ni activar la ubicación.',
            ),
            const _Paso(
              icono: Icons.autorenew,
              texto:
                  'El código cambia cada vez que alguien se inscribe, '
                  'así cada estudiante usa uno distinto.',
            ),
            const SizedBox(height: 16),
            _buildNuevos(),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, agregarAMano),
                child: const Text(
                  '¿El estudiante no tiene la app? Agrégalo a mano',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _nuevos.length),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNuevos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_reg, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Inscritos ahora',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_nuevos.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_nuevos.isEmpty)
            const Text(
              'Aquí aparecerán los estudiantes a medida que se inscriban.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            for (final e in _nuevos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                ),
                title: Text(e.nombre.isEmpty ? e.correo : e.nombre),
                subtitle: e.nombre.isEmpty ? null : Text(e.correo),
              ),
        ],
      ),
    );
  }
}

/// Una instrucción con su icono.
class _Paso extends StatelessWidget {
  const _Paso({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El QR con el logo al centro; mientras no hay código, un indicador.
class _VistaQr extends StatelessWidget {
  const _VistaQr({required this.datos});

  final String? datos;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: datos == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                alignment: Alignment.center,
                children: [
                  QrImageView(
                    data: datos!,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    // Alta corrección de errores para que el logo no estorbe
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.primary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceLow, width: 4),
                    ),
                    child: ClipOval(child: Image.asset(_logo)),
                  ),
                ],
              ),
      ),
    );
  }
}

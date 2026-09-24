import 'package:flutter/widgets.dart';

import 'jitsi_meet_view_stub.dart'
    if (dart.library.html) 'jitsi_meet_view_web.dart' as impl;

/// Devuelve la vista de videollamada Jitsi embebida.
///
/// * **Web**: iframe real con `HtmlElementView` (`meet.jit.si/<sala>`).
/// * **Otras plataformas**: marcador con botón para abrir la sala en la app
///   externa (`url_launcher`), ya que el iframe solo aplica a web.
///
/// Aviso ePHI/HIPAA: por ahora se usa **Jitsi público** (`meet.jit.si`), que
/// no es apto para ePHI real (sin BAA). Migrar a Jitsi self-hosted + Jibri o
/// JaaS con BAA cuando se requiera cumplimiento pleno.
Widget buildJitsiMeetView({required String salaUrl}) =>
    impl.buildJitsiMeetView(salaUrl);

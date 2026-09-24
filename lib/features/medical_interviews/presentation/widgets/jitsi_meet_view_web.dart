import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Vista web: iframe de Jitsi embebido con `HtmlElementView`.
Widget buildJitsiMeetView(String salaUrl) {
  const viewType = 'meraki-jitsi-meet';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
    iframe.src = salaUrl;
    iframe.allow =
        'camera; microphone; fullscreen; display-capture; autoplay; clipboard-write';
    iframe.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%';
    return iframe;
  });
  return const HtmlElementView(viewType: viewType);
}

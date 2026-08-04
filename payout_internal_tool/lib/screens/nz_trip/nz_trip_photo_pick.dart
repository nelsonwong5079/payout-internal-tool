import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

/// Web-only image pick. Must be called from a user tap without prior awaits —
/// Safari/iOS ignore file inputs opened after an async gap (e.g. after a sheet pop).
Future<Uint8List?> pickImageBytesWeb({required bool fromCamera}) {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;
  // On mobile Safari this opens the camera; without it, the photo library.
  if (fromCamera) {
    input.setAttribute('capture', 'environment');
  }

  final completer = Completer<Uint8List?>();
  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? focusSub;
  var settled = false;

  void finish(Uint8List? bytes) {
    if (settled) return;
    settled = true;
    changeSub?.cancel();
    focusSub?.cancel();
    input.remove();
    if (!completer.isCompleted) completer.complete(bytes);
  }

  changeSub = input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      finish(null);
      return;
    }
    try {
      final bytes = await _readAndCompress(files.first);
      finish(bytes);
    } catch (_) {
      finish(null);
    }
  });

  // Cancel: system picker closed without a file.
  focusSub = html.window.onFocus.listen((_) {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!settled && (input.files == null || input.files!.isEmpty)) {
        finish(null);
      }
    });
  });

  input.style
    ..position = 'fixed'
    ..left = '-9999px'
    ..top = '0'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0';
  html.document.body?.append(input);
  // Synchronous click — still inside the user gesture.
  input.click();

  return completer.future.timeout(
    const Duration(minutes: 3),
    onTimeout: () {
      finish(null);
      return null;
    },
  );
}

Future<Uint8List> _readAndCompress(html.File file) async {
  final objectUrl = html.Url.createObjectUrl(file);
  try {
    final img = html.ImageElement(src: objectUrl);
    final loaded = Completer<void>();
    img.onLoad.listen((_) {
      if (!loaded.isCompleted) loaded.complete();
    });
    img.onError.listen((_) {
      if (!loaded.isCompleted) {
        loaded.completeError(Exception('Could not decode image'));
      }
    });
    await loaded.future;

    final naturalW = (img.naturalWidth == 0 ? img.width : img.naturalWidth) ?? 1;
    final naturalH =
        (img.naturalHeight == 0 ? img.height : img.naturalHeight) ?? 1;
    const maxSide = 1200.0;
    final scale = math.min(1.0, maxSide / math.max(naturalW, naturalH));
    final w = math.max(1, (naturalW * scale).round());
    final h = math.max(1, (naturalH * scale).round());

    final canvas = html.CanvasElement(width: w, height: h);
    canvas.context2D.drawImageScaled(img, 0, 0, w, h);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.72);
    const prefix = 'data:image/jpeg;base64,';
    if (!dataUrl.startsWith(prefix)) {
      throw Exception('Could not compress image');
    }
    return base64Decode(dataUrl.substring(prefix.length));
  } finally {
    html.Url.revokeObjectUrl(objectUrl);
  }
}

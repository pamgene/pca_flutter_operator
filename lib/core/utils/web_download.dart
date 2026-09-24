import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Triggers a browser file download with the given content and filename.
/// WASM-compatible (uses package:web, not dart:html).
void downloadFile(String content, String filename) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv'),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();

  web.URL.revokeObjectURL(url);
}

/// Triggers a browser PNG download from raw PNG bytes.
/// WASM-compatible.
void downloadPng(Uint8List bytes, String filename) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename.endsWith('.png') ? filename : '$filename.png';
  anchor.click();

  web.URL.revokeObjectURL(url);
}

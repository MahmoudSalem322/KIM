import 'package:web/web.dart' as web;

void updateDocumentLanguage(String languageCode) {
  web.document.documentElement?.setAttribute('lang', languageCode);
  // Flutter owns RTL/LTR inside its view. HTML direction must remain LTR:
  // the engine's absolutely positioned accessibility host uses LTR coordinates.
}

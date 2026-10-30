import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Puts [text] on the phone's clipboard and says so.
Future<void> copyText(BuildContext context, String text, String what) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('تم نسخ $what: $text')));
}

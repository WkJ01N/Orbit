/// Replaces `{key}` placeholders; empty [template] falls back to [fallback].
String applyNotificationTemplate(
  String? template,
  String fallback,
  Map<String, String> variables,
) {
  if (template == null || template.trim().isEmpty) {
    return fallback;
  }
  var result = template;
  for (final entry in variables.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}

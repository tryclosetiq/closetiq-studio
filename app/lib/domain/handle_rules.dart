/// Same handle rules as `handle_is_valid` in the SQL migrations.
const reservedHandles = <String>{
  "admin",
  "api",
  "app",
  "account",
  "auth",
  "closet",
  "closetiq",
  "create",
  "go",
  "help",
  "home",
  "insights",
  "login",
  "pricing",
  "schedule",
  "signup",
  "storefront",
  "support",
  "www",
};

String normalizeHandle(String value) {
  return value.trim().replaceFirst(RegExp(r"^@"), "").toLowerCase();
}

bool handleIsValid(String value) {
  final handle = normalizeHandle(value);
  return RegExp(r"^[a-z0-9_]{3,30}$").hasMatch(handle) && !reservedHandles.contains(handle);
}

String? handleError(String value) {
  final handle = normalizeHandle(value);
  if (handle.isEmpty) return "Choose a storefront handle.";
  if (reservedHandles.contains(handle)) return "That handle is reserved.";
  if (!RegExp(r"^[a-z0-9_]{3,30}$").hasMatch(handle)) {
    return "Use 3–30 letters, numbers or underscores.";
  }
  return null;
}

enum InputScript { empty, bangla, latin, unsupported }

InputScript detectInputScript(String input) {
  var hasLatinLetter = false;
  var hasContent = false;
  for (var index = 0; index < input.length; index++) {
    final codeUnit = input.codeUnitAt(index);
    if (codeUnit >= 0x0980 && codeUnit <= 0x09FF) return InputScript.bangla;
    if (_isLatinLetter(codeUnit)) {
      hasLatinLetter = true;
      hasContent = true;
    } else if (!_isWhitespace(codeUnit)) {
      hasContent = true;
    }
  }
  if (hasLatinLetter) return InputScript.latin;
  return hasContent ? InputScript.unsupported : InputScript.empty;
}

bool _isLatinLetter(int codeUnit) =>
    (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
    (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
    (codeUnit >= 0x00C0 && codeUnit <= 0x024F);

bool _isWhitespace(int codeUnit) =>
    String.fromCharCode(codeUnit).trim().isEmpty;

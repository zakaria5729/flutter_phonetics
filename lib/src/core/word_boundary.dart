/// Author: Zakaria Hossain
/// Description: Word boundary detection utilities for context-sensitive rules.
library;

bool startsWord(String text, int index) =>
    index <= 0 || _isSeparator(text.codeUnitAt(index - 1));

bool endsWord(String text, int end) =>
    end >= text.length || _isSeparator(text.codeUnitAt(end));

bool _isSeparator(int codeUnit) => codeUnit == 0x20 || codeUnit == 0x2D;

import Foundation

/// Converts a string containing Hanzi (Chinese characters) to Pinyin with tone diacritics.
/// Non-Hanzi characters are left unchanged.
func toPinyin(_ hanzi: String) -> String {
    guard !hanzi.isEmpty else { return hanzi }

    // CFStringTransform works on a mutable copy.
    let mutable = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, hanzi as CFString)!

    // MandarinLatin: converts Hanzi to Pinyin with tone diacritics (nǐ hǎo etc.)
    CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)

    // We intentionally do NOT strip combining marks so tones are preserved.
    return mutable as String
}

/// Returns true if the string contains any CJK unified ideograph characters.
func containsHanzi(_ text: String) -> Bool {
    return text.unicodeScalars.contains { scalar in
        // CJK Unified Ideographs: U+4E00–U+9FFF
        // CJK Extension A: U+3400–U+4DBF
        // CJK Extension B and beyond are also common but these cover the vast majority.
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF) ||
               (v >= 0x3400 && v <= 0x4DBF) ||
               (v >= 0x20000 && v <= 0x2A6DF)
    }
}

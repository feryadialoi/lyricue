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
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF) ||
               (v >= 0x3400 && v <= 0x4DBF) ||
               (v >= 0x20000 && v <= 0x2A6DF)
    }
}

func isHanziCharacter(_ c: Character) -> Bool {
    return c.unicodeScalars.contains { scalar in
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF) ||
               (v >= 0x3400 && v <= 0x4DBF) ||
               (v >= 0x20000 && v <= 0x2A6DF)
    }
}

/// Splits a lyric line into tokens: each Hanzi character is its own token,
/// consecutive non-Hanzi characters are grouped into one token.
struct LyricToken {
    let text: String
    let pinyin: String  // empty for non-Hanzi tokens
}

func tokenize(_ line: String) -> [LyricToken] {
    var tokens: [LyricToken] = []
    var nonHanziBuffer = ""

    for char in line {
        if isHanziCharacter(char) {
            if !nonHanziBuffer.isEmpty {
                tokens.append(LyricToken(text: nonHanziBuffer, pinyin: ""))
                nonHanziBuffer = ""
            }
            let pinyin = toPinyin(String(char))
            tokens.append(LyricToken(text: String(char), pinyin: pinyin))
        } else {
            nonHanziBuffer.append(char)
        }
    }

    if !nonHanziBuffer.isEmpty {
        tokens.append(LyricToken(text: nonHanziBuffer, pinyin: ""))
    }

    return tokens
}

import Foundation

// MARK: - Script detection

enum CharScript {
    case hanzi       // Chinese: U+4E00–U+9FFF, U+3400–U+4DBF, U+F900–U+FAFF, U+20000–U+2A6DF
    case kanji       // Japanese kanji shares the CJK block — disambiguated by context (see tokenize)
    case hiragana    // U+3040–U+309F
    case katakana    // U+30A0–U+30FF
    case hangul      // U+AC00–U+D7AF, U+1100–U+11FF
    case other
}

private func scriptOf(_ scalar: Unicode.Scalar) -> CharScript {
    let v = scalar.value
    if (v >= 0x3040 && v <= 0x309F) { return .hiragana }
    if (v >= 0x30A0 && v <= 0x30FF) { return .katakana }
    if (v >= 0xAC00 && v <= 0xD7AF) || (v >= 0x1100 && v <= 0x11FF) { return .hangul }
    if (v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3400 && v <= 0x4DBF) ||
       (v >= 0xF900 && v <= 0xFAFF) || (v >= 0x20000 && v <= 0x2A6DF) { return .hanzi }
    return .other
}

private func scriptOf(_ char: Character) -> CharScript {
    // Use the dominant scalar in the character.
    for scalar in char.unicodeScalars {
        let s = scriptOf(scalar)
        if s != .other { return s }
    }
    return .other
}

// MARK: - Phonetic annotation

/// Returns the phonetic reading for a single character or short string.
/// Chinese → Pinyin with tones, Japanese kana/kanji → Hiragana reading,
/// Korean → Revised Romanization. Returns empty string for non-annotatable input.
func phoneticAnnotation(for text: String, script: CharScript) -> String {
    guard !text.isEmpty else { return "" }
    let mutable = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, text as CFString)!

    switch script {
    case .hanzi:
        // Mandarin Latin gives toned pinyin: 你 → nǐ
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)

    case .hiragana, .katakana, .kanji:
        // Step 1: Kanji/Katakana → Hiragana via tokenizer reading
        let reading = japaneseReading(for: text)
        // Step 2: Hiragana → Latin romaji
        let readingMutable = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, reading as CFString)!
        CFStringTransform(readingMutable, nil, kCFStringTransformLatinHiragana, true) // reverse = Hiragana→Latin
        CFStringTransform(readingMutable, nil, kCFStringTransformStripCombiningMarks, false)
        return (readingMutable as String).lowercased()

    case .hangul:
        // Hangul → Revised Romanization
        CFStringTransform(mutable, nil, kCFStringTransformLatinHangul, true) // reverse = Hangul→Latin
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)

    case .other:
        return ""
    }

    return mutable as String
}

/// Uses CFStringTokenizer with Japanese locale to get the phonetic reading
/// (Hiragana) of a kanji or mixed Japanese string.
private func japaneseReading(for text: String) -> String {
    let cfText = text as CFString
    let range = CFRangeMake(0, CFStringGetLength(cfText))
    let locale = Locale(identifier: "ja") as CFLocale
    let tokenizer = CFStringTokenizerCreate(
        kCFAllocatorDefault,
        cfText,
        range,
        kCFStringTokenizerUnitWordBoundary,
        locale
    )

    var reading = ""
    while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
        if let latin = CFStringTokenizerCopyCurrentTokenAttribute(
            tokenizer,
            kCFStringTokenizerAttributeLatinTranscription
        ) as? String {
            // Convert the Latin transcription back to Hiragana for display
            let m = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, latin as CFString)!
            CFStringTransform(m, nil, kCFStringTransformLatinHiragana, false)
            reading += m as String
        } else {
            // Fallback: token is already kana, append as-is
            let tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            if let sub = (text as NSString).substring(with: NSRange(location: tokenRange.location, length: tokenRange.length)) as String? {
                reading += sub
            }
        }
    }

    return reading.isEmpty ? text : reading
}

// MARK: - Annotatable script check

/// Returns true if the line contains any character that can be phonetically annotated.
func containsAnnotatableScript(_ text: String) -> Bool {
    return text.unicodeScalars.contains { scriptOf($0) != .other }
}

// MARK: - Tokenizer

/// A run of characters that share the same annotation treatment.
struct LyricToken {
    let text: String
    let pinyin: String  // phonetic annotation; empty for non-annotatable tokens
}

/// Splits a lyric line into tokens.
///
/// Rules:
/// - Each CJK/Kanji character is its own token (one annotation per character).
/// - Consecutive Hiragana/Katakana characters are grouped (they form one mora each but
///   CFStringTokenizer handles the reading as a unit; we keep runs together for display).
/// - Each Hangul syllable block is its own token.
/// - Consecutive non-annotatable characters (Latin, punctuation, spaces) are one token
///   with no annotation.
///
/// Japanese detection heuristic: if the line contains any Hiragana or Katakana,
/// CJK characters in that line are treated as Kanji (Japanese) rather than Hanzi (Chinese).
func tokenize(_ line: String) -> [LyricToken] {
    let isJapaneseLine = line.unicodeScalars.contains {
        let s = scriptOf($0); return s == .hiragana || s == .katakana
    }

    var tokens: [LyricToken] = []
    var otherBuffer = ""
    var kanaBuffer = ""  // accumulate consecutive kana for a single reading

    func flushOther() {
        if !otherBuffer.isEmpty {
            tokens.append(LyricToken(text: otherBuffer, pinyin: ""))
            otherBuffer = ""
        }
    }

    func flushKana() {
        if !kanaBuffer.isEmpty {
            let reading = phoneticAnnotation(for: kanaBuffer, script: .hiragana)
            tokens.append(LyricToken(text: kanaBuffer, pinyin: reading))
            kanaBuffer = ""
        }
    }

    for char in line {
        let script = scriptOf(char)

        switch script {
        case .hanzi where isJapaneseLine, .kanji:
            // Japanese kanji — get reading via tokenizer, one character at a time
            flushOther()
            flushKana()
            let reading = phoneticAnnotation(for: String(char), script: .kanji)
            tokens.append(LyricToken(text: String(char), pinyin: reading))

        case .hanzi:
            // Chinese hanzi
            flushOther()
            flushKana()
            let pinyin = phoneticAnnotation(for: String(char), script: .hanzi)
            tokens.append(LyricToken(text: String(char), pinyin: pinyin))

        case .hiragana, .katakana:
            flushOther()
            kanaBuffer.append(char)

        case .hangul:
            flushOther()
            flushKana()
            let roman = phoneticAnnotation(for: String(char), script: .hangul)
            tokens.append(LyricToken(text: String(char), pinyin: roman))

        case .other:
            flushKana()
            otherBuffer.append(char)
        }
    }

    flushOther()
    flushKana()

    return tokens
}

// MARK: - Legacy shims (used by LyricsViewModel)

func containsHanzi(_ text: String) -> Bool { containsAnnotatableScript(text) }
func toPinyin(_ text: String) -> String { phoneticAnnotation(for: text, script: .hanzi) }

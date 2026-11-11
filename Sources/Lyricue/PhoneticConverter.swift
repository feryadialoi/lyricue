import Foundation

// MARK: - Script detection

enum CharScript {
    case hanzi
    case hiragana   // U+3040–U+309F
    case katakana   // U+30A0–U+30FF
    case hangul     // U+AC00–U+D7AF, U+1100–U+11FF
    case other
}

private func scriptOf(_ scalar: Unicode.Scalar) -> CharScript {
    let v = scalar.value
    if v >= 0x3040 && v <= 0x309F { return .hiragana }
    if v >= 0x30A0 && v <= 0x30FF { return .katakana }
    if (v >= 0xAC00 && v <= 0xD7AF) || (v >= 0x1100 && v <= 0x11FF) { return .hangul }
    if (v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3400 && v <= 0x4DBF) ||
       (v >= 0xF900 && v <= 0xFAFF) || (v >= 0x20000 && v <= 0x2A6DF) { return .hanzi }
    return .other
}

private func scriptOf(_ char: Character) -> CharScript {
    for scalar in char.unicodeScalars {
        let s = scriptOf(scalar)
        if s != .other { return s }
    }
    return .other
}

private func isJapaneseLine(_ line: String) -> Bool {
    line.unicodeScalars.contains { scriptOf($0) == .hiragana || scriptOf($0) == .katakana }
}

// MARK: - LyricToken

struct LyricToken {
    let text: String
    let pinyin: String  // phonetic annotation; empty for non-annotatable tokens
}

// MARK: - Tokenize entry point

func tokenize(_ line: String) -> [LyricToken] {
    if isJapaneseLine(line) {
        return tokenizeJapanese(line)
    } else {
        return tokenizeCJKAndHangul(line)
    }
}

// MARK: - Japanese tokenization (word-level via CFStringTokenizer)

/// For Japanese lines, run CFStringTokenizer on the whole line so it gets
/// correct word-context readings (e.g. 強く → つよく, not 強 → きょう).
/// Each word token becomes one display unit: reading shown above the word text.
private func tokenizeJapanese(_ line: String) -> [LyricToken] {
    let nsLine = line as NSString
    let cfLine = line as CFString
    let fullRange = CFRangeMake(0, CFStringGetLength(cfLine))
    let locale = Locale(identifier: "ja") as CFLocale

    let tokenizer = CFStringTokenizerCreate(
        kCFAllocatorDefault,
        cfLine,
        fullRange,
        kCFStringTokenizerUnitWordBoundary,
        locale
    )

    var tokens: [LyricToken] = []
    var cursor = 0  // tracks position in the original string for gap detection

    while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
        let tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
        let loc = tokenRange.location
        let len = tokenRange.length

        // Emit any gap between cursor and this token as an unannotated token.
        if loc > cursor {
            let gap = nsLine.substring(with: NSRange(location: cursor, length: loc - cursor))
            if !gap.isEmpty {
                tokens.append(LyricToken(text: gap, pinyin: ""))
            }
        }
        cursor = loc + len

        let tokenText = nsLine.substring(with: NSRange(location: loc, length: len))

        // Get the Latin transcription (romaji) for this word token.
        let reading: String
        if let latin = CFStringTokenizerCopyCurrentTokenAttribute(
            tokenizer,
            kCFStringTokenizerAttributeLatinTranscription
        ) as? String {
            // Convert Latin → Hiragana, then Hiragana → clean romaji
            let hiragana = latinToHiragana(latin)
            reading = hiraganaToRomaji(hiragana)
        } else {
            // Pure kana token — convert directly to romaji
            reading = hiraganaToRomaji(tokenText)
        }

        // Only annotate if the token contains at least one non-Latin scriptable char.
        let needsAnnotation = tokenText.unicodeScalars.contains { scriptOf($0) != .other }
        tokens.append(LyricToken(text: tokenText, pinyin: needsAnnotation ? reading : ""))
    }

    // Emit trailing gap (e.g. punctuation after last token).
    let totalLen = nsLine.length
    if cursor < totalLen {
        let tail = nsLine.substring(with: NSRange(location: cursor, length: totalLen - cursor))
        if !tail.isEmpty {
            tokens.append(LyricToken(text: tail, pinyin: ""))
        }
    }

    return tokens
}

private func latinToHiragana(_ latin: String) -> String {
    let m = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, latin as CFString)!
    CFStringTransform(m, nil, kCFStringTransformLatinHiragana, false)
    return m as String
}

private func hiraganaToRomaji(_ hiragana: String) -> String {
    let m = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, hiragana as CFString)!
    CFStringTransform(m, nil, kCFStringTransformLatinHiragana, true)
    CFStringTransform(m, nil, kCFStringTransformStripCombiningMarks, false)
    // CFStringTransform uses "~tsu" to mark gemination (っ); replace with doubled consonant.
    var result = (m as String).lowercased()
    result = result.replacingOccurrences(of: "~tsu", with: "")  // drop orphaned っ at end of token
    return result
}

// MARK: - Chinese + Korean tokenization (per character)

private func tokenizeCJKAndHangul(_ line: String) -> [LyricToken] {
    var tokens: [LyricToken] = []
    var otherBuffer = ""

    func flushOther() {
        if !otherBuffer.isEmpty {
            tokens.append(LyricToken(text: otherBuffer, pinyin: ""))
            otherBuffer = ""
        }
    }

    for char in line {
        switch scriptOf(char) {
        case .hanzi:
            flushOther()
            let pinyin = chinesePinyin(String(char))
            tokens.append(LyricToken(text: String(char), pinyin: pinyin))

        case .hangul:
            flushOther()
            let roman = koreanRomanization(String(char))
            tokens.append(LyricToken(text: String(char), pinyin: roman))

        default:
            otherBuffer.append(char)
        }
    }

    flushOther()
    return tokens
}

private func chinesePinyin(_ text: String) -> String {
    let m = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, text as CFString)!
    CFStringTransform(m, nil, kCFStringTransformMandarinLatin, false)
    return m as String
}

private func koreanRomanization(_ text: String) -> String {
    let m = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, text as CFString)!
    CFStringTransform(m, nil, kCFStringTransformLatinHangul, true)
    CFStringTransform(m, nil, kCFStringTransformStripCombiningMarks, false)
    return (m as String).lowercased()
}

// MARK: - Annotatable check

func containsAnnotatableScript(_ text: String) -> Bool {
    text.unicodeScalars.contains { scriptOf($0) != .other }
}

// MARK: - Legacy shims (used by LyricsViewModel)

func containsHanzi(_ text: String) -> Bool { containsAnnotatableScript(text) }
func toPinyin(_ text: String) -> String { chinesePinyin(text) }

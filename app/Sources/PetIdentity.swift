import Foundation

struct PetIdentity {
    static let defaultName = "hejo"
    static func subject(_ name:String)->String { name + (hasFinal(name) ? "이":"가") }
    static func greeting(_ name:String)->String { name + (hasFinal(name) ? "과":"와") + " 함께" }
    private static func hasFinal(_ name:String)->Bool {
        guard let scalar=name.unicodeScalars.last,(0xAC00...0xD7A3).contains(scalar.value) else{return false}
        return (scalar.value-0xAC00)%28 != 0
    }
    static let maximumLength = 20
    static func normalized(_ input: String) -> String {
        input.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").precomposedStringWithCanonicalMapping
    }
    static func validationMessage(for input: String) -> String? {
        let name = normalized(input)
        if name.isEmpty { return "펫 이름을 입력해 주세요." }
        if name.count > maximumLength { return "이름은 \(maximumLength)자까지 입력할 수 있어요." }
        if name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && $0 != "\u{200D}" }) {
            return "표시할 수 있는 문자로 이름을 입력해 주세요."
        }
        return nil
    }
}

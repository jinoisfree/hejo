import Foundation

struct PetIdentity {
    static let defaultName = "hejo"
    static func subject(_ name:String)->String { name + (hasFinal(name) ? "이":"가") }
    static func greeting(_ name:String)->String { name + (hasFinal(name) ? "과":"와") + " 함께" }
    private static func hasFinal(_ name:String)->Bool {
        guard let scalar=name.unicodeScalars.last,(0xAC00...0xD7A3).contains(scalar.value) else{return false}
        return (scalar.value-0xAC00)%28 != 0
    }
    static func normalized(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let name = String(String(String.UnicodeScalarView(clean)).prefix(20))
        return name.isEmpty ? defaultName : name
    }
}

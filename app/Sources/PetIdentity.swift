import Foundation

struct PetIdentity {
    static let defaultName = "hejo"
    static func normalized(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let name = String(String(String.UnicodeScalarView(clean)).prefix(20))
        return name.isEmpty ? defaultName : name
    }
}

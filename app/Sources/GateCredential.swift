import Foundation
import Security

protocol GateCredentialStore {
    func read(account: String) -> String?
    func save(_ token: String, account: String) -> Bool
    func delete(account: String)
}
/// Generic password data goes directly to Keychain, without command parsing or process arguments.
struct GateKeychain: GateCredentialStore {
    static let service = "io.github.hermes-hejo.hejo.gate-token"
    enum Operation {case read, save, delete}
    var operation: (Operation, String, Data?) -> (Bool, Data?) = Self.system
    private func valid(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 512 && value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }
    private func validValue(_ value:String,account:String)->Bool {
        account == "saved-login-password" ? !value.isEmpty && value.utf8.count<=16384:valid(value)
    }
    private static func system(_ action:Operation,_ account:String,_ value:Data?)->(Bool,Data?) {
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account]
        switch action {
        case .read:
            var match=query;match[kSecReturnData as String]=true;match[kSecMatchLimit as String]=kSecMatchLimitOne
            var result:CFTypeRef?
            let status=SecItemCopyMatching(match as CFDictionary,&result)
            return(status==errSecSuccess,result as? Data)
        case .save:
            guard let value else {return(false,nil)}
            let attrs=[kSecValueData as String:value]
            var status=SecItemUpdate(query as CFDictionary,attrs as CFDictionary)
            if status==errSecItemNotFound {
                status=SecItemAdd(query.merging(attrs){$1} as CFDictionary,nil)
                if status==errSecDuplicateItem {status=SecItemUpdate(query as CFDictionary,attrs as CFDictionary)}
            }
            return(status==errSecSuccess,nil)
        case .delete:return(SecItemDelete(query as CFDictionary)==errSecSuccess,nil)
        }
    }
    func read(account: String) -> String? {
        guard valid(account) else {return nil}
        let (ok,data)=operation(.read,account,nil)
        guard ok,let data,let value=String(data:data,encoding:.utf8),validValue(value,account:account) else {return nil}
        return value
    }
    func save(_ token: String, account: String) -> Bool {
        guard valid(account),validValue(token,account:account),operation(.save,account,Data(token.utf8)).0 else {return false}
        return read(account:account)==token
    }
    func delete(account: String) {if valid(account) {_=operation(.delete,account,nil)}}
}

import Foundation

enum WorkState: String, Codable {
    case idle, running, waiting, responded, failed, interrupted, unknown
    var label: String {
        switch self {
        case .idle: return "대기"
        case .running: return "작업 중"
        case .waiting: return "확인 필요"
        case .responded: return "응답 종료"
        case .failed: return "오류"
        case .interrupted: return "중단됨"
        case .unknown: return "상태 확인 필요"
        }
    }
    var row: Int {
        switch self {
        case .running: return 7
        case .waiting: return 6
        case .responded: return 3
        case .failed: return 5
        default: return 0
        }
    }
}

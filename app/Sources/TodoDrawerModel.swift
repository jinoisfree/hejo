import Foundation

/// A memory-only projection of notices and the team-kit ledger. Never writes tasks.
@MainActor final class TodoDrawerModel {
    enum Filter: String, CaseIterable { case all = "전체", question = "답 요청", deadline = "마감", alert = "알림" }
    /// The gate names the source kind; this is its owner-facing name. An unknown kind shows nothing.
    nonisolated static let originNames=["notion":"노션","calendar":"일정","reminder":"미리알림","slack":"슬랙","notes":"메모","gmail":"메일"]
    struct Notice: Equatable { let messageID: String, thread: String }
    struct Deadline: Equatable {
        let employee: String, id: String, title: String, due: String
        var deadlineAt: String?, url: URL?, origin: String?, notice: Notice?
        init?(_ row: [String: Any]) {
            guard let employee=row["employee"] as? String,let id=row["id"] as? String,
                  let title=row["title"] as? String,let due=row["due"] as? String else{return nil}
            self.employee=employee;self.id=id;self.title=title;self.due=due
            deadlineAt=row["deadline_at"] as? String;url=(row["url"] as? String).flatMap(URL.init(string:))
            origin=(row["origin"] as? String).flatMap{TodoDrawerModel.originNames[$0]}
            if let value=row["notice"] as? [String:Any],let message=value["message_id"] as? String,let thread=value["thread"] as? String {
                notice=Notice(messageID:message,thread:thread)
            }
        }
    }
    struct DeadlineRef: Equatable { let employee: String, id: String }
    struct Card: Equatable {
        let id: String, kind: Filter, title: String, employee: String, name: String, badge: String, time: String
        var key: ConversationKey?, messageID: String?, url: URL?
        var order: Date, urgent: Bool
        /// Deadline cards only: what to close, and whether a click has anywhere to go.
        var deadlineRef: DeadlineRef?, linked = true
    }
    struct Snapshot: Equatable {
        var urgent: [Card] = [], rest: [Card] = []
        var counts: [Filter: Int] = [:]
        var available = false, failed = false
        /// Title of the deadline closing in five seconds (undo line), and whether a close just failed.
        var undoTitle: String?, closeFailed = false
        var total: Int { counts[.all] ?? 0 }
        var empty: Bool { urgent.isEmpty && rest.isEmpty }
        var warning: String? { failed ? "마감을 읽지 못했어요. 잠시 뒤 다시 볼게요." : nil }
        var closeWarning: String? { closeFailed ? "마감을 닫지 못했어요. 다시 해 주세요." : nil }
    }
    private(set) var deadlines: [Deadline] = []
    private(set) var available = false, failed = false
    func receive(_ frame: [String: Any]) {
        if frame["type"] as? String == "error" || frame["available"] as? Bool == false {
            deadlines=[];available=false;failed=false;return
        }
        available=true
        if frame["reason"] != nil { failed=true;return }
        deadlines=(frame["items"] as? [[String:Any]] ?? []).compactMap(Deadline.init)
        failed = !(frame["failed"] as? [String] ?? []).isEmpty
    }
    func snapshot(_ model: ConversationModel, filter: Filter = .all, now: Date, calendar: Calendar = .current, hidden: Set<String> = []) -> Snapshot {
        var cards: [Card] = [], seen=Set<String>()
        let muted=model.muted
        let rooms=model.rooms.map(\.id)+(model.home.settings.muted == true ? []:[HomeRoom.id])
        for room in rooms where !muted.contains(room) {
            for notice in model.notices(room,now:now) {
                for id in notice.messages {
                    guard let message=model.messages[id],!muted.contains(message.key.employee),seen.insert(id).inserted else{continue}
                    let kind: Filter = notice.questions ? .question:.alert
                    let stamp=ThreadTools.date(message.timestamp),minutes=max(0,Int(now.timeIntervalSince(stamp)/60))
                    let relative=minutes<1 ? "방금" : minutes<60 ? "\(minutes)분 전" : minutes<1440 ? "\(minutes/60)시간 전":"\(minutes/1440)일 전"
                    cards.append(Card(id:id,kind:kind,title:IslandModel.firstLine(message.text,limit:300),employee:message.speaker,
                        name:model.name(message.speaker),badge:kind.rawValue,time:relative,key:message.key,messageID:id,
                        order:stamp,urgent:notice.questions))
                }
            }
        }
        if available {
            for item in deadlines {
                let bits=item.due.split(separator:"-").compactMap{Int($0)}
                guard bits.count==3,let due=calendar.date(from:DateComponents(year:bits[0],month:bits[1],day:bits[2])) else{continue}
                let days=calendar.dateComponents([.day],from:calendar.startOfDay(for:now),to:calendar.startOfDay(for:due)).day ?? 0
                let id="deadline:"+item.employee+":"+item.id
                guard !hidden.contains(id) else{continue}
                let badge=(days==0 ? "D-DAY":days>0 ? "D-\(days)":"D+\(-days)")+(item.origin.map{" · "+$0} ?? "")
                let message=item.notice.flatMap{model.messages[$0.messageID]}
                var text="\(bits[1])월 \(bits[2])일까지"
                if days==0,let at=item.deadlineAt {
                    let hour=calendar.component(.hour,from:ThreadTools.date(at));text="오늘 \(hour)시까지"
                }
                cards.append(Card(id:id,kind:.deadline,title:item.title,employee:item.employee,
                    name:model.name(item.employee),badge:badge,time:text,key:message?.key,messageID:message?.id,url:item.url,order:due,urgent:days<=1,
                    deadlineRef:DeadlineRef(employee:item.employee,id:item.id),linked:message != nil || item.url != nil))
            }
        }
        func sorted(_ input:[Card])->[Card] {
            let rank:[Filter:Int]=[.deadline:0,.question:1,.alert:2]
            return input.sorted { a,b in
                if a.kind != b.kind {return rank[a.kind,default:3]<rank[b.kind,default:3]}
                if a.order != b.order {return a.kind == .alert ? a.order>b.order:a.order<b.order}
                return a.id<b.id
            }
        }
        var counts=Dictionary(uniqueKeysWithValues:Filter.allCases.map{($0,0)})
        for card in cards {counts[card.kind,default:0]+=1};counts[.all]=cards.count
        let shown=cards.filter{filter == .all || $0.kind == filter}
        return Snapshot(urgent:sorted(shown.filter(\.urgent)),rest:sorted(shown.filter{!$0.urgent}),counts:counts,available:available,failed:failed)
    }
}

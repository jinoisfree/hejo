import AppKit
import Darwin

final class FailedPasswordStore:GateCredentialStore {
    func read(account:String)->String? {nil}
    func save(_ token:String,account:String)->Bool {false}
    func delete(account:String) {}
}

@MainActor func review56Tests() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:root)}
    var failures:[String]=[]
    func expect(_ value:Bool,_ message:String) {if !value {failures.append(message)}}
    let store=try LocalStore(directory:root.appendingPathComponent("reset")),state=MemberState(store:store)
    try store.update {$0.memberStates=["":StateDocument(rev:9,items:["pin:old":StateEntry(v:"1",at:20,dev:"a")])]}
    try state.set(["zone:unsent":"2"],at:30)
    var restored=StateDocument(rev:1,items:["pin:new":StateEntry(v:"1",at:1,dev:"b")])
    state.fetch={_ in restored};state.push={edits in restored.rev+=1;restored.items=MemberState.merge(restored.items,edits);return restored}
    await state.sync()
    expect(state.document.rev==2 && state.value("pin:old")==nil && state.value("pin:new")=="1" && state.value("zone:unsent")=="2","IR03 revision rollback replaces baseline, sends only outbox")
    var polls=0
    state.connect(fetch:{_ in restored},push:{_ in restored},wait:{_ in polls+=1;await Task.yield();return(restored,true)})
    await pause(0.05);state.disconnect();expect(polls<=1,"IR03 successful immediate wait must have a minimum interval")
    let rejected=MemberState(store:try LocalStore(directory:root.appendingPathComponent("ignored")))
    try rejected.set(["title:alpha":"local"],at:1)
    var gets=0,bad=false
    let winner=StateDocument(rev:1,items:["title:alpha":StateEntry(v:"remote",at:100,dev:"b")])
    rejected.fetch={_ in gets+=1;return winner};rejected.push={_ in StateDocument(rev:2,items:winner.items)};rejected.onFailure={if $0 {bad=true}}
    await rejected.sync();expect(gets>=2 && bad && rejected.value("title:alpha")=="remote","IR04 ignored write refetches and reports failure")
    let stale=MemberState(store:try LocalStore(directory:root.appendingPathComponent("stale")))
    try stale.store.update {$0.memberStates=["":StateDocument(rev:1,items:["hide:alpha":StateEntry(v:"1",at:1e30,dev:"future")])]}
    var refreshed=0,staleWarning=false
    stale.fetch={_ in refreshed+=1;return StateDocument(rev:2,items:["hide:alpha":StateEntry(v:"1",at:100,dev:"remote")])}
    stale.push={_ in StateDocument()};stale.onFailure={if $0 {staleWarning=true}}
    try stale.set(["hide:alpha":nil],at:1);try? await waitFor(0.5) {refreshed>0 && stale.document.items["hide:alpha"]?.at==100}
    expect(staleWarning && stale.document.items["hide:alpha"]?.at==100,"IR04 locally rejected edit also refetches and warns")
    let a=try ConversationModel(store:LocalStore(directory:root.appendingPathComponent("a"))),b=try ConversationModel(store:LocalStore(directory:root.appendingPathComponent("b")))
    a.toggleSection("1");b.toggleSection("2")
    let combined=MemberState.merge(a.memberState.pending,b.memberState.pending)
    try a.store.update {$0.memberStates=["":StateDocument(rev:1,items:combined)];$0.pendingState=[:]}
    expect(a.sidebar.sections.first{$0.id=="1"}?.open==true && a.sidebar.sections.first{$0.id=="2"}?.open==true,"IR05 independent sections do not overwrite each other")
    let login=LoginWindow(client:GateClient(store:try LocalStore(directory:root.appendingPathComponent("login")),credentials:MemoryCredentials()))
    var warned=false;login.onPasswordSaveFailure={_ in warned=true};login.passwords=FailedPasswordStore();login.keepPassword.state = .on;login.password.stringValue="fixture! password+한글";login.rememberChoices()
    expect(warned && !login.message.stringValue.isEmpty,"password save failure is visible")
    var bytes:Data?
    let keychain=GateKeychain(operation:{operation,_,data in
        switch operation {case .save:bytes=data;return(true,nil);case .read:return(true,bytes);case .delete:bytes=nil;return(true,nil)}
    })
    let secret=" !한글\"+\\ & fixture \n"
    expect(keychain.save(secret,account:LoginWindow.passwordEntry) && keychain.read(account:LoginWindow.passwordEntry)==secret,"symbol passwords preserve exact UTF8 bytes without Keychain access")
    expect(!keychain.save(secret,account:"gate-token"),"gate tokens keep their restricted format")
    a.editSection("1",name:"Fixture")
    expect(a.sidebar.sections.first{$0.id=="1"}?.name=="Fixture" && a.sidebar.sections.first{$0.id=="1"}?.open==true,"IR05 definition decodes without an open field")
    expect(a.memberState.value("layout:sections")?.contains("\"open\"")==false,"IR05 definitions no longer contain collapse flags")
    // Reopening an already registered received file also applies the security attribute.
    let downloads=root.appendingPathComponent("Downloads"),fs=try LocalStore(directory:root.appendingPathComponent("file")),credentials=MemoryCredentials(),client=GateClient(store:fs,credentials:credentials)
    _=try? await client.receive(["v":1,"type":"welcome","token":"fixture-token","device_id":"fixture","employees":[],"head_seq":0])
    let id=UUID().uuidString.lowercased(),file=MessageFile(fileID:id,name:"sample.txt",mime:"text/plain",size:7),date=Date(timeIntervalSince1970:1)
    try fs.append(["type":"message","seq":1,"msg_id":UUID().uuidString.lowercased(),"employee":"alpha","files":[["file_id":id,"name":"sample.txt","size":7]]])
    try fs.update {$0.address="127.0.0.1:1"}
    let http=GateHTTP(client:client,downloads:downloads),target=http.downloads.destination(room:"alpha",name:file.name,date:date,id:id)
    try FileManager.default.createDirectory(at:downloads,withIntermediateDirectories:true);try Data("fixture".utf8).write(to:target)
    do {let opened=try await http.openedFile(file,employee:"alpha",date:date);expect(getxattr(opened.url.path,"com.apple.quarantine",nil,0,0,0)>0,"received attachment is quarantined")}
    catch {failures.append("received file fixture: \(error)")}
    let freshUpdate=try await review56Update();expect(freshUpdate,"IR06 cached install rechecks current release")
    try check(failures.isEmpty,failures.joined(separator:"; "))
    print("REVIEW56_UNIT_PASS")
}

@MainActor final class Review56Installer:UpdateInstalling {
    var isBusy=false,version:String?
    var onFailure:((Error)->Void)?,onChange:(()->Void)?
    func begin(_ release:UpdateRelease) throws {version=release.version;isBusy=true}
    func stop() {}
}
@MainActor func review56Update() async throws ->Bool {
    let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[UpdateHTTP.self]
    var version="0.2.1",requests=0,consent=false
    UpdateHTTP.response={_ in requests+=1;let repo="sample/hejo",base="https://github.com/\(repo)/releases/download/v\(version)/"
        return(200,try! JSONSerialization.data(withJSONObject:["tag_name":"v"+version,"draft":false,"prerelease":false,"assets":[["id":1,"name":"appcast.xml","state":"uploaded","size":100,"browser_download_url":base+"appcast.xml"],["id":2,"name":"hejo-\(version)-arm64.zip","state":"uploaded","size":4096,"browser_download_url":base+"hejo-\(version)-arm64.zip"]]]))}
    let suite="hejo-review-"+UUID().uuidString,defaults=UserDefaults(suiteName:suite)!,installer=Review56Installer()
    defer {defaults.removePersistentDomain(forName:suite)}
    let app=AppUpdate(defaults:defaults,client:UpdateReleaseClient(configuration:config,repository:"sample/hejo"),installer:installer,installed:{true},current:{("0.2.0","2")},present:{_ in consent ? .alertFirstButtonReturn:.alertThirdButtonReturn})
    defer {app.stop()}
    app.checkNow();try await waitFor {app.knownRelease != nil}
    version="0.2.2";consent=true;app.checkNow();try await waitFor {installer.version != nil}
    return requests==2 && installer.version=="0.2.2"
}

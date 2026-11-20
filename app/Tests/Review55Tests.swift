import AppKit

@MainActor func review55Tests() async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),model=try ConversationModel(store:store)
    try model.memberState.join(member:"owner",hub:"fixture",legacy:[:])
    var failures:[String]=[]
    try model.apply(["v":1,"type":"welcome","employees":[["id":"alpha","name":"Fixture","aliases":[]]]])
    for seq in 1...30 {try model.apply(controlFrame(seq))}
    try model.apply(["v":1,"type":"sync_done","more":false,"through":30])
    if model.memberState.pending["read:alpha"] != nil {failures.append("IR-02 seeded before first hub state")}
    model.memberState.fetch={_ in StateDocument(rev:1,items:["read:alpha":StateEntry(v:"10",at:1,dev:"fixture")])}
    model.memberState.push={changes in StateDocument(rev:2,items:changes)}
    await model.memberState.sync()
    if model.memberState.read("read:alpha") != 10 {failures.append("IR-02 remote unread overwritten")}
    let credentials=MemoryCredentials();credentials.token="fixture-credential"
    let client=GateClient(store:store,credentials:credentials)
    _=try? await client.receive(["v":1,"type":"auth_rejected","reason":"unknown"])
    if credentials.token == nil {failures.append("IR-S02 transient rejection erased credentials")}
    _=try? await client.receive(["v":1,"type":"auth_rejected","reason":"revoked"])
    if credentials.token != nil {failures.append("IR-S02 explicit revocation retained credentials")}
    try check(failures.isEmpty,failures.joined(separator:"; "))
    print("REVIEW55_UNIT_PASS")
}

@MainActor func review55Network(_ args:[String]) async throws {
    let store=try LocalStore(directory:URL(fileURLWithPath:args[2]))
    let client=GateClient(store:store,credentials:MemoryCredentials()),controller=try testConversation(client:client)
    try client.pair(address:args[3],code:"fixture-code",device:"Fixture")
    defer {client.stop()}
    let room="11111111-1111-4111-8111-111111111111",key=ConversationKey(employee:room,thread:controlThread)
    try await waitFor {controller.canSend && controller.model.typingPeople[key]?["beta"] != nil}
    var bad:[String]=[]
    for text in ["/stop",ThreadTools.undo,"승인","선택: 하나"] {
        if text == "/stop" {await controller.stop(key)} else {_=await controller.sendText(text,key:key)}
        try await waitFor {controller.model.timeline(key).contains{$0.role=="owner" && $0.text==text}}
        if controller.model.timeline(key).last(where:{$0.role=="owner" && $0.text==text})?.speaker != "beta" {bad.append(text)}
    }
    try check(controller.sendFields(key)["employee"] as? String == "alpha","IR01 ordinary unmentioned reply still uses lead")
    try check(bad.isEmpty,"IR01 controls and answers target working/question employee: \(bad)")
    print("REVIEW55_NETWORK_PASS")
}

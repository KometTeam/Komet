import CallKit
import Foundation
import Flutter
import AVFoundation
import WebRTC

final class KometCallKit: NSObject, CXProviderDelegate {
  static let shared = KometCallKit()

  private let provider: CXProvider
  private let callController = CXCallController()
  private var activeCalls: [String: UUID] = [:]
  private var callData: [String: [String: Any]] = [:]
  private var answeredCalls: Set<String> = []
  private var outgoingCalls: Set<String> = []
  private var pendingEvents: [[String: Any]] = []
  static var eventSink: FlutterEventSink?

  private let nameQueue = DispatchQueue(
    label: "ru.komet.app.caller-names",
    attributes: .concurrent,
  )
  private var _callerNames: [Int: String] = [:]
  private var _callerPhones: [Int: Int] = [:]
  private let namesKey = "komet_caller_names_v1"
  private let phonesKey = "komet_caller_phones_v1"

  private override init() {
    let config = CXProviderConfiguration(localizedName: "Komet")
    config.supportsVideo = true
    config.maximumCallGroups = 1
    config.maximumCallsPerCallGroup = 1
    provider = CXProvider(configuration: config)
    super.init()
    provider.setDelegate(self, queue: nil)
    loadCallerCache()
  }

  func attach(_ sink: FlutterEventSink?) {
    Self.eventSink = sink
    guard let sink = sink else { return }
    let queued = pendingEvents
    pendingEvents.removeAll()
    guard !queued.isEmpty else { return }
    DispatchQueue.main.async {
      for event in queued { sink(event) }
    }
  }

  private func loadCallerCache() {
    let defaults = UserDefaults.standard
    if let names = defaults.dictionary(forKey: namesKey) {
      for (k, v) in names {
        if let id = Int(k), let s = v as? String, !s.isEmpty {
          _callerNames[id] = s
        }
      }
    }
    if let phones = defaults.dictionary(forKey: phonesKey) {
      for (k, v) in phones {
        if let id = Int(k), let n = (v as? NSNumber)?.intValue, n > 0 {
          _callerPhones[id] = n
        }
      }
    }
  }

  func syncCallerNames(_ names: [Int: String], phones: [Int: Int]) {
    nameQueue.sync(flags: .barrier) {
      _callerNames = names
      _callerPhones = phones
    }
    let namesPlist = names.reduce(into: [String: String]()) { $0["\($1.key)"] = $1.value }
    let phonesPlist = phones.reduce(into: [String: NSNumber]()) {
      $0["\($1.key)"] = NSNumber(value: $1.value)
    }
    let defaults = UserDefaults.standard
    defaults.set(namesPlist, forKey: namesKey)
    defaults.set(phonesPlist, forKey: phonesKey)
  }

  private func cachedName(_ id: Int) -> String? {
    nameQueue.sync { _callerNames[id] }
  }

  private func cachedPhone(_ id: Int) -> Int? {
    nameQueue.sync { _callerPhones[id] }
  }

  private func makeHandle(
    callerId: Int?,
    fallback: String,
    isVideo: Bool
  ) -> (CXHandle, Bool) {
    if let id = callerId {
      if let name = cachedName(id), !name.isEmpty {
        return (CXHandle(type: .generic, value: name), isVideo)
      }
      if let phone = cachedPhone(id), phone > 0 {
        return (CXHandle(type: .phoneNumber, value: "+\(phone)"), isVideo)
      }
    }
    return (CXHandle(type: .generic, value: fallback), isVideo)
  }

  func reportIncomingCall(
    conversationId: String,
    callerName: String,
    isVideo: Bool,
    vcp: String? = nil,
    callerId: Int? = nil
  ) {
    let uuid: UUID
    if let existing = activeCalls[conversationId] {
      uuid = existing
    } else {
      uuid = UUID(uuidString: conversationId) ?? UUID()
      activeCalls[conversationId] = uuid
    }

    var data: [String: Any] = [
      "conversationId": conversationId,
      "vcp": vcp ?? (callData[conversationId]?["vcp"] as? String ?? ""),
      "iv": isVideo ? "true" : "false",
      "userName": callerName,
    ]
    if let callerId = callerId {
      data["callerId"] = callerId
      data["suid"] = String(callerId)
    } else if let existing = callData[conversationId]?["callerId"] as? Int {
      data["callerId"] = existing
      data["suid"] = String(existing)
    }
    callData[conversationId] = data

    let (handle, video) = makeHandle(
      callerId: callerId,
      fallback: callerName,
      isVideo: isVideo,
    )
    let update = CXCallUpdate()
    update.remoteHandle = handle
    update.hasVideo = video
    provider.reportNewIncomingCall(with: uuid, update: update) { _ in }
  }

  func reportOutgoingCall(
    conversationId: String,
    callerName: String,
    callerId: Int? = nil,
    isVideo: Bool = false
  ) {
    let uuid = uuidFor(conversationId)
    activeCalls[conversationId] = uuid
    outgoingCalls.insert(conversationId)
    let (handle, video) = makeHandle(callerId: callerId, fallback: callerName, isVideo: isVideo)
    let action = CXStartCallAction(call: uuid, handle: handle)
    action.isVideo = video
    let transaction = CXTransaction(action: action)
    callController.request(transaction) { [weak self] error in
      if let error = error {
        print("KometCallKit: start outgoing call failed: \(error)")
      } else {
        let update = CXCallUpdate()
        update.remoteHandle = handle
        update.hasVideo = video
        self?.provider.reportCall(with: uuid, updated: update)
      }
    }
  }

  func cancelIncoming() {
    let toEnd = activeCalls.filter { !answeredCalls.contains($0.key) }
    for (key, uuid) in toEnd {
      provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
      activeCalls.removeValue(forKey: key)
      callData.removeValue(forKey: key)
      outgoingCalls.remove(key)
    }
  }

  func endCall(conversationId: String) {
    guard let uuid = activeCalls.removeValue(forKey: conversationId) else { return }
    provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
    callData.removeValue(forKey: conversationId)
    answeredCalls.remove(conversationId)
    outgoingCalls.remove(conversationId)
  }

  func endAllCalls() {
    let uuids = Array(activeCalls.values)
    for uuid in uuids {
      provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
    }
    activeCalls.removeAll()
    callData.removeAll()
    answeredCalls.removeAll()
    outgoingCalls.removeAll()
  }

  func startCallWithUUID(
    conversationId: String,
    callerName: String,
    isVideo: Bool,
    callerId: Int? = nil
  ) {
    let uuid = uuidFor(conversationId)
    activeCalls[conversationId] = uuid
    let (handle, video) = makeHandle(
      callerId: callerId,
      fallback: callerName,
      isVideo: isVideo,
    )
    let update = CXCallUpdate()
    update.remoteHandle = handle
    update.hasVideo = video
    provider.reportCall(with: uuid, updated: update)
  }

  private func uuidFor(_ conversationId: String) -> UUID {
    if let existing = activeCalls[conversationId] { return existing }
    return UUID(uuidString: conversationId) ?? UUID()
  }

  private func sendEvent(_ action: String, data: [String: Any]? = nil) {
    var event: [String: Any] = ["action": action]
    if let data = data {
      if let jsonData = try? JSONSerialization.data(withJSONObject: data),
         let jsonStr = String(data: jsonData, encoding: .utf8) {
        event["data"] = jsonStr
      }
    }
    if Self.eventSink == nil {
      pendingEvents.append(event)
      return
    }
    DispatchQueue.main.async {
      Self.eventSink?(event)
    }
  }

  func providerDidReset(_ provider: CXProvider) {
    activeCalls.removeAll()
    callData.removeAll()
    answeredCalls.removeAll()
    outgoingCalls.removeAll()
  }

  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    let rtc = RTCAudioSession.sharedInstance()
    rtc.useManualAudio = true
    rtc.isAudioEnabled = true
    rtc.audioSessionDidActivate(audioSession)
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    let rtc = RTCAudioSession.sharedInstance()
    rtc.isAudioEnabled = false
    rtc.audioSessionDidDeactivate(audioSession)
    rtc.useManualAudio = false
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    let conversationId = activeCalls.first(where: { $0.value == action.callUUID })?.key
    action.fulfill()
    guard let conversationId = conversationId else { return }
    answeredCalls.insert(conversationId)
    sendEvent("answer", data: callData[conversationId])
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    let conversationId = activeCalls.first(where: { $0.value == action.callUUID })?.key
    action.fulfill()
    guard let conversationId = conversationId else { return }
    let data = callData[conversationId]
    if answeredCalls.contains(conversationId) || outgoingCalls.contains(conversationId) {
      sendEvent("hangup")
    } else {
      sendEvent("ended", data: data)
      // #***! сброс из шторки: не зависим от живого Dart-движка
      KometNotifications.shared.postCallDecline(conversationId: conversationId)
    }
    answeredCalls.remove(conversationId)
    outgoingCalls.remove(conversationId)
    activeCalls.removeValue(forKey: conversationId)
    callData.removeValue(forKey: conversationId)
  }

  func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    action.fulfill()
  }
}
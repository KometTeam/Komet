import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ShareViewModel: ObservableObject {
  @Published var files: [KometSharedFile] = []
  @Published var progress: Double?
  @Published var caption = ""
  @Published var sending = false
  @Published var error: String?
}

final class ShareViewController: NSViewController {
  private let queue = DispatchQueue(label: "ru.komet.app.share-extension")
  private let viewModel = ShareViewModel()
  private weak var context: NSExtensionContext?
  private var store: KometShareStore?
  private var draft: KometShareDraft?

  override func loadView() {
    view = NSHostingView(
      rootView: ShareSheetView(
        model: viewModel,
        onSend: { self.send() },
        onCancel: { self.cancel() }
      )
    )
  }

  override func beginRequest(with context: NSExtensionContext) {
    self.context = context
    preferredContentSize = NSSize(width: 420, height: 280)
    let providers = context.inputItems
      .compactMap { $0 as? NSExtensionItem }
      .flatMap { $0.attachments ?? [] }
    viewModel.progress = providers.isEmpty ? nil : 0
    stage(providers: providers, index: 0)
  }

  private func stage(providers: [NSItemProvider], index: Int) {
    queue.async {
      guard index < providers.count else {
        DispatchQueue.main.async { self.viewModel.progress = nil }
        return
      }
      self.load(provider: providers[index]) { file, text in
        DispatchQueue.main.async {
          if let file {
            self.viewModel.files.append(file)
          }
          if let text, !text.isEmpty {
            let existing = self.viewModel.caption
            self.viewModel.caption = existing.isEmpty ? text : "\(existing)\n\(text)"
          }
          self.viewModel.progress = Double(index + 1) / Double(providers.count)
        }
        self.stage(providers: providers, index: index + 1)
      }
    }
  }

  private func load(
    provider: NSItemProvider,
    completion: @escaping (KometSharedFile?, String?) -> Void
  ) {
    let types = provider.registeredTypeIdentifiers
    let fileSharing =
      provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
      || provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
      || provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
      || provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier)
      || (provider.hasItemConformingToTypeIdentifier(UTType.data.identifier)
        && !provider.hasItemConformingToTypeIdentifier(UTType.text.identifier))

    if fileSharing,
      let type = types.first(where: { type in
        guard let uttype = UTType(type) else { return false }
        return uttype.conforms(to: .image) || uttype.conforms(to: .movie)
          || uttype.conforms(to: .audio) || uttype.conforms(to: .data)
      })
    {
      stageFile(provider: provider, type: type, completion: completion)
      return
    }

    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      _ = provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
        let text: String?
        switch item {
        case let url as URL: text = url.absoluteString
        case let string as String: text = string
        default: text = nil
        }
        completion(nil, text)
      }
      return
    }

    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      _ = provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
        completion(nil, item as? String)
      }
      return
    }

    completion(nil, nil)
  }

  private func stageFile(
    provider: NSItemProvider,
    type: String,
    completion: @escaping (KometSharedFile?, String?) -> Void
  ) {
    _ = provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, _ in
      guard let self, let url else {
        self?.loadData(provider: provider, type: type, completion: completion)
        return
      }
      do {
        try self.storeDraft()
        guard let store = self.store, let draft = self.draft else {
          throw URLError(.badServerResponse)
        }
        let file = try store.copyFile(
          at: url,
          suggestedName: provider.suggestedName,
          typeIdentifier: type,
          into: draft
        )
        try? FileManager.default.removeItem(at: url)
        completion(file, nil)
      } catch {
        try? FileManager.default.removeItem(at: url)
        self.loadData(provider: provider, type: type, completion: completion)
      }
    }
  }

  private func loadData(
    provider: NSItemProvider,
    type: String,
    completion: @escaping (KometSharedFile?, String?) -> Void
  ) {
    _ = provider.loadDataRepresentation(forTypeIdentifier: type) { [weak self] data, _ in
      guard let self, let data else {
        completion(nil, nil)
        return
      }
      do {
        try self.storeDraft()
        guard let store = self.store, let draft = self.draft else {
          throw URLError(.badServerResponse)
        }
        let file = try store.saveData(
          data,
          suggestedName: provider.suggestedName,
          typeIdentifier: type,
          into: draft
        )
        completion(file, nil)
      } catch {
        completion(nil, nil)
      }
    }
  }

  private func storeDraft() throws {
    guard store == nil else { return }
    store = try KometShareStore()
    draft = try store?.beginRequest()
  }

  private func send() {
    let files = viewModel.files
    let caption = viewModel.caption.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !files.isEmpty || !caption.isEmpty else { return }
    viewModel.sending = true
    queue.async {
      do {
        guard let store = self.store, let draft = self.draft else {
          throw URLError(.badServerResponse)
        }
        _ = try store.commit(
          draft,
          files: files,
          text: caption.isEmpty ? nil : caption,
          subject: nil
        )
        let context = self.context
        DispatchQueue.main.async {
          if let url = URL(string: "komet://share/pending"), let context {
            context.open(url) { _ in
              context.completeRequest(returningItems: [], completionHandler: nil)
            }
          } else {
            context?.completeRequest(returningItems: [], completionHandler: nil)
          }
        }
      } catch {
        let message =
          (error as? KometShareError)?.errorDescription
          ?? error.localizedDescription
        DispatchQueue.main.async {
          self.viewModel.sending = false
          self.viewModel.error = message
        }
      }
    }
  }

  private func cancel() {
    queue.async {
      if let draft = self.draft {
        self.store?.discard(draft)
        self.draft = nil
      }
      DispatchQueue.main.async {
        self.context?.completeRequest(returningItems: [], completionHandler: nil)
      }
    }
  }
}

private struct ShareSheetView: View {
  @ObservedObject var model: ShareViewModel
  let onSend: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "paperplane.fill")
          .foregroundStyle(.tint)
        Text("Komet")
          .font(.system(size: 15, weight: .semibold))
        Spacer()
      }
      if let progress = model.progress {
        ProgressView(value: progress)
      }
      if model.files.isEmpty {
        if model.progress == nil {
          Text("Нет вложений")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
      } else {
        List(model.files, id: \.relativePath) { file in
          HStack(spacing: 8) {
            Image(systemName: "doc.fill")
              .foregroundStyle(.secondary)
              .font(.system(size: 12))
            Text(file.name)
              .font(.system(size: 13))
              .lineLimit(1)
              .truncationMode(.middle)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 2)
        }
        .listStyle(.plain)
      }
      if let error = model.error {
        Text(error)
          .font(.system(size: 12))
          .foregroundStyle(.red)
      }
      TextField("Подпись", text: $model.caption)
        .textFieldStyle(.roundedBorder)
        .disabled(model.sending)
      Spacer(minLength: 0)
      HStack {
        Button("Отмена", action: onCancel)
          .keyboardShortcut(.cancelAction)
          .disabled(model.sending)
        Spacer()
        Button(model.sending ? "Отправка…" : "Открыть в Komet", action: onSend)
          .keyboardShortcut(.defaultAction)
          .disabled(model.sending || model.progress != nil)
      }
    }
    .padding(16)
    .frame(minWidth: 380, minHeight: 260)
  }
}
import UIKit
import MobileCoreServices
import ImageIO

final class ShareViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UITextViewDelegate {
  private let worker = DispatchQueue(label: "ru.komet.app.share-extension")
  private let titleLabel = UILabel()
  private let messageLabel = UILabel()
  private let spinner = UIActivityIndicatorView(style: .large)
  private let button = UIButton(type: .system)
  private let statusStack = UIStackView()
  private let pickerStack = UIStackView()
  private let accountButton = UIButton(type: .system)
  private let outboxButton = UIButton(type: .system)
  private let accountRow = UIStackView()
  private let summaryRow = UIStackView()
  private let summaryLabel = UILabel()
  private let thumbnailView = UIImageView()
  private let captionView = UITextView()
  private let captionPlaceholder = UILabel()
  private let searchBar = UISearchBar()
  private let tableView = UITableView(frame: .zero, style: .plain)
  private let sendButton = UIButton(type: .system)
  private let progressView = UIProgressView(progressViewStyle: .default)
  private var pickerBottom: NSLayoutConstraint?
  private var keyboardOverlap: CGFloat = 0
  private var accountStore: KometShareAccounts?
  private var accounts: [KometShareAccount] = []
  private var selectedAccount: KometShareAccount?
  private var selectedChat: KometShareChat?
  private var outgoing: KometOutgoingShare?
  private var previousShares: [KometOutgoingShare] = []
  private var sending = false
  private var canRetry = false
  private var store: KometShareStore?
  private var draft: KometShareDraft?
  private var providers: [NSItemProvider] = []
  private var files: [KometSharedFile] = []
  private var texts: [String] = []
  private var subject: String?
  private var index = 0
  private var progress: Progress?
  private var cancelled = false
  private var completed = false
  private var started = false

  #if DEBUG
  func configurePreview(accounts: [KometShareAccount], files: [KometSharedFile], text: String, image: UIImage?) {
    started = true
    loadViewIfNeeded()
    self.accounts = accounts
    self.files = files
    selectedAccount = accounts.first
    captionView.text = text
    captionPlaceholder.isHidden = !text.isEmpty
    summaryLabel.text = files.isEmpty ? "Текст или ссылка" : files.count == 1 ? files[0].name : "Вложений: \(files.count)"
    thumbnailView.image = image
    thumbnailView.isHidden = image == nil
    spinner.stopAnimating()
    statusStack.isHidden = true
    pickerStack.isHidden = false
    refreshPicker()
  }
  #endif

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    titleLabel.text = "Отправить в Komet"
    titleLabel.font = .preferredFont(forTextStyle: .title2)
    titleLabel.adjustsFontForContentSizeCategory = true
    titleLabel.textAlignment = .center
    titleLabel.numberOfLines = 0
    messageLabel.font = .preferredFont(forTextStyle: .body)
    messageLabel.adjustsFontForContentSizeCategory = true
    messageLabel.textAlignment = .center
    messageLabel.numberOfLines = 0
    messageLabel.textColor = .secondaryLabel
    messageLabel.text = "Подготавливаем вложения…"
    button.setTitle("Отмена", for: .normal)
    button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    button.addTarget(self, action: #selector(close), for: .touchUpInside)
    statusStack.axis = .vertical
    statusStack.spacing = 20
    for child in [spinner, titleLabel, messageLabel, progressView, button] {
      statusStack.addArrangedSubview(child)
    }
    statusStack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(statusStack)
    NSLayoutConstraint.activate([
      statusStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
      statusStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
      statusStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
      statusStack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      statusStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
    ])
    progressView.isHidden = true
    configurePicker()
    preferredContentSize = CGSize(width: 420, height: 660)
    spinner.startAnimating()
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func configurePicker() {
    let cancelButton = UIButton(type: .system)
    cancelButton.setTitle("Отмена", for: .normal)
    cancelButton.addTarget(self, action: #selector(close), for: .touchUpInside)
    let heading = UILabel()
    heading.text = "Отправить в Komet"
    heading.font = .preferredFont(forTextStyle: .headline)
    heading.textAlignment = .center
    let spacer = UIView()
    let navigation = UIStackView(arrangedSubviews: [cancelButton, heading, spacer])
    navigation.alignment = .center
    navigation.spacing = 8
    spacer.widthAnchor.constraint(equalTo: cancelButton.widthAnchor).isActive = true
    navigation.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    accountButton.contentHorizontalAlignment = .leading
    accountButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
    accountButton.setTitleColor(.secondaryLabel, for: .disabled)
    accountButton.addTarget(self, action: #selector(chooseAccount), for: .touchUpInside)
    outboxButton.setTitle("Неотправленные", for: .normal)
    outboxButton.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
    outboxButton.addTarget(self, action: #selector(showOutbox), for: .touchUpInside)
    accountRow.addArrangedSubview(accountButton)
    accountRow.addArrangedSubview(outboxButton)
    accountRow.spacing = 12
    let accountHeight = accountRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
    accountHeight.priority = .defaultHigh
    accountHeight.isActive = true
    accountButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
    thumbnailView.contentMode = .scaleAspectFill
    thumbnailView.clipsToBounds = true
    thumbnailView.layer.cornerRadius = 8
    thumbnailView.widthAnchor.constraint(equalToConstant: 56).isActive = true
    let thumbnailHeight = thumbnailView.heightAnchor.constraint(equalToConstant: 56)
    thumbnailHeight.priority = .defaultHigh
    thumbnailHeight.isActive = true
    thumbnailView.isHidden = true
    summaryLabel.font = .preferredFont(forTextStyle: .subheadline)
    summaryLabel.textColor = .secondaryLabel
    summaryLabel.numberOfLines = 2
    summaryRow.addArrangedSubview(thumbnailView)
    summaryRow.addArrangedSubview(summaryLabel)
    summaryRow.alignment = .center
    summaryRow.spacing = 12
    captionView.font = .preferredFont(forTextStyle: .body)
    captionView.backgroundColor = .secondarySystemBackground
    captionView.layer.cornerRadius = 10
    captionView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
    captionView.accessibilityLabel = "Сообщение или подпись"
    captionView.delegate = self
    let captionHeight = captionView.heightAnchor.constraint(equalToConstant: 74)
    captionHeight.priority = .defaultHigh
    captionHeight.isActive = true
    captionPlaceholder.text = "Сообщение или подпись…"
    captionPlaceholder.font = .preferredFont(forTextStyle: .body)
    captionPlaceholder.textColor = .placeholderText
    captionPlaceholder.translatesAutoresizingMaskIntoConstraints = false
    captionPlaceholder.isUserInteractionEnabled = false
    captionView.addSubview(captionPlaceholder)
    NSLayoutConstraint.activate([
      captionPlaceholder.leadingAnchor.constraint(equalTo: captionView.leadingAnchor, constant: 13),
      captionPlaceholder.topAnchor.constraint(equalTo: captionView.topAnchor, constant: 10)
    ])
    searchBar.placeholder = "Поиск чата или контакта"
    searchBar.searchBarStyle = .minimal
    searchBar.delegate = self
    let keyboardToolbar = UIToolbar()
    keyboardToolbar.items = [
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(dismissKeyboard))
    ]
    keyboardToolbar.sizeToFit()
    captionView.inputAccessoryView = keyboardToolbar
    tableView.dataSource = self
    tableView.delegate = self
    tableView.keyboardDismissMode = .onDrag
    tableView.tableFooterView = UIView()
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 58
    sendButton.setTitle("Выберите получателя", for: .normal)
    sendButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    sendButton.layer.cornerRadius = 12
    sendButton.backgroundColor = .systemBlue
    sendButton.setTitleColor(.white, for: .normal)
    sendButton.setTitleColor(.tertiaryLabel, for: .disabled)
    sendButton.addTarget(self, action: #selector(sendSelected), for: .touchUpInside)
    sendButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    sendButton.isEnabled = false
    pickerStack.axis = .vertical
    pickerStack.spacing = 8
    for child in [navigation, accountRow, summaryRow, captionView, searchBar, tableView, sendButton] {
      pickerStack.addArrangedSubview(child)
    }
    pickerStack.translatesAutoresizingMaskIntoConstraints = false
    pickerStack.isHidden = true
    view.addSubview(pickerStack)
    let bottom = pickerStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
    pickerBottom = bottom
    NSLayoutConstraint.activate([
      pickerStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
      pickerStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      pickerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
      bottom
    ])
  }

  @objc private func keyboardChanged(_ notification: Notification) {
    guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
    let local = view.convert(frame, from: nil)
    keyboardOverlap = local.maxY >= view.bounds.maxY - 1
      ? max(0, view.bounds.maxY - local.minY - view.safeAreaInsets.bottom) : 0
    pickerBottom?.constant = -12 - keyboardOverlap
    updateEditingLayout()
    let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
    UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
  }

  private func updateEditingLayout() {
    let hasKeyboard = keyboardOverlap > 0
    accountRow.isHidden = hasKeyboard
    summaryRow.isHidden = hasKeyboard
    captionView.isHidden = hasKeyboard && searchBar.searchTextField.isFirstResponder
    searchBar.isHidden = hasKeyboard && captionView.isFirstResponder
  }

  @objc private func dismissKeyboard() {
    view.endEditing(true)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    begin()
  }

  private func begin() {
    let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
    for item in items {
      appendText(item.attributedContentText?.string)
      if subject == nil { subject = item.attributedTitle?.string }
      providers.append(contentsOf: item.attachments ?? [])
    }
    guard providers.count <= KometShareStore.maximumAttachments else {
      fail(KometShareError.tooManyAttachments)
      return
    }
    worker.async {
      let result = Result { () -> (KometShareStore, KometShareDraft) in
        let store = try KometShareStore()
        return (store, try store.beginRequest())
      }
      DispatchQueue.main.async {
        switch result {
        case .success(let (store, draft)):
          self.store = store
          self.draft = draft
          if self.cancelled {
            self.worker.async { store.discard(draft) }
          } else {
            self.processNext()
          }
        case .failure(let error):
          if !self.cancelled { self.fail(error) }
        }
      }
    }
  }

  private func processNext() {
    guard !cancelled, let store = store, let draft = draft else { return }
    guard index < providers.count else {
      preparePicker(store: store, draft: draft)
      return
    }
    let provider = providers[index]
    messageLabel.text = "Подготавливаем вложение \(index + 1) из \(providers.count)…"
    if provider.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
      progress = nil
      provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { item, error in
        let result = Result { () -> KometSharedFile in
          if let error = error { throw error }
          guard let url = item as? URL else { throw KometShareError.unsupportedAttachment }
          return try self.worker.sync {
            try store.copyFile(at: url, suggestedName: provider.suggestedName, typeIdentifier: nil, into: draft)
          }
        }
        DispatchQueue.main.async { self.receivedFile(result) }
      }
      return
    }
    let types = provider.registeredTypeIdentifiers
    let fileType = types.first {
      Self.conforms($0, to: kUTTypeImage) || Self.conforms($0, to: kUTTypeMovie) ||
        Self.conforms($0, to: kUTTypeAudio)
    } ?? types.first {
      Self.conforms($0, to: kUTTypeData) && !Self.conforms($0, to: kUTTypeText) &&
        !Self.conforms($0, to: kUTTypeURL)
    }
    if let type = fileType {
      loadFile(provider: provider, type: type, store: store, draft: draft)
    } else if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
      loadText(provider: provider, type: kUTTypeURL as String)
    } else if let textType = types.first(where: { Self.conforms($0, to: kUTTypeText) }) {
      if let name = provider.suggestedName, !(name as NSString).pathExtension.isEmpty {
        loadFile(provider: provider, type: textType, store: store, draft: draft)
      } else {
        loadText(provider: provider, type: textType)
      }
    } else {
      fail(KometShareError.unsupportedAttachment)
    }
  }

  private func loadFile(
    provider: NSItemProvider, type: String, store: KometShareStore, draft: KometShareDraft
  ) {
    progress = provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
      if let url = url {
        let result = Result {
          try self.worker.sync {
            try store.copyFile(
              at: url, suggestedName: provider.suggestedName, typeIdentifier: type, into: draft
            )
          }
        }
        DispatchQueue.main.async { self.receivedFile(result) }
      } else {
        DispatchQueue.main.async {
          guard !self.cancelled else { return }
          self.loadData(provider: provider, type: type, store: store, draft: draft)
        }
      }
    }
  }

  private func loadData(
    provider: NSItemProvider, type: String, store: KometShareStore, draft: KometShareDraft
  ) {
    progress = provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
      if let data = data {
        let result = Result {
          try self.worker.sync {
            try store.saveData(data, suggestedName: provider.suggestedName, typeIdentifier: type, into: draft)
          }
        }
        DispatchQueue.main.async { self.receivedFile(result) }
      } else if Self.conforms(type, to: kUTTypeImage) {
        DispatchQueue.main.async {
          guard !self.cancelled else { return }
          self.loadImage(provider: provider, type: type, store: store, draft: draft)
        }
      } else {
        DispatchQueue.main.async { self.fail(error ?? KometShareError.unreadableAttachment) }
      }
    }
  }

  private func loadImage(
    provider: NSItemProvider, type: String, store: KometShareStore, draft: KometShareDraft
  ) {
    progress = nil
    provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
      let result = Result { () -> KometSharedFile in
        if let error = error { throw error }
        guard let image = item as? UIImage, let data = image.pngData() else {
          throw KometShareError.unreadableAttachment
        }
        let name = provider.suggestedName.map { ($0 as NSString).deletingPathExtension + ".png" }
        return try self.worker.sync {
          try store.saveData(data, suggestedName: name, typeIdentifier: kUTTypePNG as String, into: draft)
        }
      }
      DispatchQueue.main.async { self.receivedFile(result) }
    }
  }

  private func loadText(provider: NSItemProvider, type: String) {
    progress = nil
    provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
      let result = Result { () -> String in
        if let error = error { throw error }
        if let url = item as? URL { return url.absoluteString }
        if let text = item as? String { return text }
        if let text = item as? NSAttributedString { return text.string }
        if let data = item as? Data, let text = String(data: data, encoding: .utf8) { return text }
        throw KometShareError.unsupportedAttachment
      }
      DispatchQueue.main.async {
        guard !self.cancelled else { return }
        switch result {
        case .success(let text):
          self.appendText(text)
          self.index += 1
          self.processNext()
        case .failure(let error):
          self.fail(error)
        }
      }
    }
  }

  private func receivedFile(_ result: Result<KometSharedFile, Error>) {
    guard !cancelled else { return }
    switch result {
    case .success(let file):
      files.append(file)
      index += 1
      processNext()
    case .failure(let error):
      fail(error)
    }
  }

  private func appendText(_ value: String?) {
    guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty, !texts.contains(text) else { return }
    texts.append(text)
  }

  private func preparePicker(store: KometShareStore, draft: KometShareDraft) {
    let files = self.files
    let text = texts.joined(separator: "\n")
    guard !files.isEmpty || !text.isEmpty else { fail(KometShareError.emptyRequest); return }
    worker.async {
      let result = Result { () -> ([KometSharedFile], KometShareAccounts, [KometShareAccount], [KometOutgoingShare], UIImage?) in
        let accounts = try KometShareAccounts()
        let saved = try accounts.accounts()
        let prepared = try KometShareSender.prepareImages(files, in: draft)
        let image = prepared.first.flatMap { self.thumbnail(for: draft.directoryURL.appendingPathComponent($0.relativePath)) }
        return (prepared, accounts, saved, try store.outgoingShares(), image)
      }
      DispatchQueue.main.async {
        guard !self.cancelled else { return }
        switch result {
        case .success(let (files, accountStore, accounts, previous, image)):
          self.files = files
          self.accountStore = accountStore
          self.accounts = accounts
          self.previousShares = previous
          self.selectedAccount = accounts.first
          self.captionView.text = text
          self.captionPlaceholder.isHidden = !text.isEmpty
          self.summaryLabel.text = files.isEmpty ? "Текст или ссылка" : files.count == 1 ? files[0].name : "Вложений: \(files.count)"
          self.thumbnailView.image = image
          self.thumbnailView.isHidden = image == nil
          self.spinner.stopAnimating()
          self.statusStack.isHidden = true
          self.pickerStack.isHidden = false
          self.refreshPicker()
        case .failure(let error):
          self.fail(error)
        }
      }
    }
  }

  private func thumbnail(for url: URL) -> UIImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 168
          ] as CFDictionary) else { return nil }
    return UIImage(cgImage: image)
  }

  private var visibleChats: [KometShareChat] {
    let query = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return selectedAccount?.chats.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) } ?? []
  }

  private func refreshPicker() {
    accountButton.setTitle(selectedAccount.map { $0.name + (accounts.count > 1 ? " ▾" : "") } ?? "Нет аккаунта", for: .normal)
    accountButton.isEnabled = accounts.count > 1
    outboxButton.isHidden = previousShares.isEmpty
    let hasContent = !files.isEmpty || !captionView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    sendButton.isEnabled = selectedChat != nil && selectedChat?.disabledReason == nil && hasContent
    sendButton.setTitle(selectedChat.map { "Отправить • " + $0.title } ?? "Выберите получателя", for: .normal)
    tableView.reloadData()
    if visibleChats.isEmpty {
      let empty = UILabel()
      empty.numberOfLines = 0
      empty.textAlignment = .center
      empty.font = .preferredFont(forTextStyle: .body)
      empty.textColor = .secondaryLabel
      empty.text = accounts.isEmpty
        ? "Откройте Komet один раз, чтобы загрузить ваши аккаунты и чаты. Затем вернитесь к отправке."
        : selectedAccount?.chats.isEmpty == true ? "В этом аккаунте пока нет доступных чатов. Обновите список в Komet." : "Чаты не найдены"
      tableView.backgroundView = empty
    } else {
      tableView.backgroundView = nil
    }
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { visibleChats.count }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let chat = visibleChats[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "chat") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "chat")
    cell.textLabel?.text = chat.title
    cell.textLabel?.font = .preferredFont(forTextStyle: .body)
    cell.textLabel?.textColor = chat.disabledReason == nil ? .label : .secondaryLabel
    cell.detailTextLabel?.text = chat.disabledReason
    cell.detailTextLabel?.numberOfLines = 0
    cell.detailTextLabel?.textColor = .secondaryLabel
    cell.accessoryType = selectedChat?.id == chat.id ? .checkmark : .none
    cell.selectionStyle = chat.disabledReason == nil ? .default : .none
    cell.imageView?.image = UIImage(systemName: chat.type.uppercased() == "DIALOG" ? "person.crop.circle" : "person.2.circle")
    cell.imageView?.tintColor = .secondaryLabel
    cell.accessibilityTraits = chat.disabledReason == nil ? .button : .notEnabled
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let chat = visibleChats[indexPath.row]
    guard chat.disabledReason == nil else { return }
    selectedChat = chat
    view.endEditing(true)
    refreshPicker()
  }

  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { refreshPicker() }
  func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) { updateEditingLayout() }
  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
  func textViewDidBeginEditing(_ textView: UITextView) { updateEditingLayout() }
  func textViewDidChange(_ textView: UITextView) {
    captionPlaceholder.isHidden = !textView.text.isEmpty
    let hasContent = !files.isEmpty || !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    sendButton.isEnabled = selectedChat != nil && selectedChat?.disabledReason == nil && hasContent
  }

  @objc private func chooseAccount() {
    let alert = UIAlertController(title: "Аккаунт", message: nil, preferredStyle: .actionSheet)
    for account in accounts {
      alert.addAction(UIAlertAction(title: account.name, style: .default) { _ in
        self.selectedAccount = account
        self.selectedChat = nil
        self.searchBar.text = ""
        self.refreshPicker()
      })
    }
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
    presentSheet(alert, source: accountButton)
  }

  private func presentSheet(_ alert: UIAlertController, source: UIView) {
    alert.popoverPresentationController?.sourceView = source
    alert.popoverPresentationController?.sourceRect = source.bounds
    present(alert, animated: true)
  }

  @objc private func sendSelected() {
    guard !sending, let store = store, let draft = draft,
          let account = selectedAccount, let chat = selectedChat, chat.disabledReason == nil else { return }
    let files = self.files
    let text = captionView.text
    view.endEditing(true)
    showSending()
    worker.async {
      do {
        let outgoing = try store.prepareOutgoing(draft, files: files, text: text, accountID: account.id, chatID: chat.id, chatTitle: chat.title)
        DispatchQueue.main.async {
          self.draft = nil
          self.outgoing = outgoing
          self.sendOutgoing(outgoing)
        }
      } catch {
        DispatchQueue.main.async {
          self.sending = false
          self.fail(error)
        }
      }
    }
  }

  private func showSending() {
    sending = true
    canRetry = false
    pickerStack.isHidden = true
    statusStack.isHidden = false
    titleLabel.text = "Отправляем в Komet"
    messageLabel.text = "Подключаемся…"
    spinner.startAnimating()
    progressView.progress = 0
    progressView.isHidden = false
    button.isEnabled = false
    button.setTitle("Отправляем…", for: .normal)
    isModalInPresentation = true
  }

  private func sendOutgoing(_ outgoing: KometOutgoingShare) {
    guard let store = store, let accountStore = accountStore else { return }
    worker.async {
      var attempted = false
      do {
        let credentials = try accountStore.authorizedCredentials(accountID: outgoing.accountID, chatID: outgoing.chatID)
        let request = try store.outgoingRequest(outgoing)
        _ = try store.updateOutgoing(outgoing, status: "sending", message: nil)
        attempted = true
        let result = try KometShareSender.send(credentials: credentials, request: request) { message, progress, phase in
          DispatchQueue.main.async {
            self.messageLabel.text = phase == "uploading" && progress != nil
              ? message + " \(Int((progress! * 100).rounded()))%" : message
            self.progressView.isHidden = progress == nil
            if let progress = progress { self.progressView.setProgress(Float(progress), animated: true) }
          }
        }
        var message = result.status == "sent" ? "Вложения отправлены в «\(outgoing.chatTitle)»." : result.message
        if let token = result.refreshedToken, let oldToken = credentials["token"] as? String {
          do {
            try accountStore.updateToken(accountID: outgoing.accountID, previousToken: oldToken, refreshedToken: token)
          } catch {
            message += "\n\nОткройте Komet, чтобы обновить доступ к аккаунту."
          }
        }
        var confirmed = outgoing
        confirmed.status = result.status
        confirmed.message = message
        let updated = (try? store.updateOutgoing(outgoing, status: result.status, message: message)) ?? confirmed
        if result.status == "sent" { try? store.removeOutgoing(id: outgoing.id) }
        DispatchQueue.main.async { self.finishSending(updated) }
      } catch {
        let status = attempted ? "unknown" : "failed"
        let message = attempted
          ? "Не удалось подтвердить отправку. Проверьте чат в Komet перед повторной отправкой."
          : error.localizedDescription
        var fallback = outgoing
        fallback.status = status
        fallback.message = message
        let updated = (try? store.updateOutgoing(outgoing, status: status, message: message)) ?? fallback
        DispatchQueue.main.async { self.finishSending(updated) }
      }
    }
  }

  private func finishSending(_ outgoing: KometOutgoingShare) {
    self.outgoing = outgoing
    sending = false
    isModalInPresentation = false
    completed = outgoing.status == "sent"
    canRetry = outgoing.status == "failed" || outgoing.status == "prepared"
    spinner.stopAnimating()
    progressView.isHidden = true
    titleLabel.text = completed ? "Отправлено" : canRetry ? "Не удалось отправить" : "Нужна проверка отправки"
    messageLabel.text = outgoing.message ?? (completed ? "Вложения отправлены в «\(outgoing.chatTitle)»." : "Проверьте чат в Komet. Вложения сохранены в разделе «Неотправленные»; автоматической повторной отправки не будет.")
    if !completed && !canRetry {
      messageLabel.text = (messageLabel.text ?? "") + "\n\nАвтоматической повторной отправки не будет."
    }
    button.isEnabled = true
    button.setTitle(canRetry ? "Повторить" : "Готово", for: .normal)
    if canRetry {
      let closeButton = UIButton(type: .system)
      closeButton.setTitle(draft == nil ? "Закрыть" : "К текущей отправке", for: .normal)
      closeButton.addTarget(self, action: #selector(closeWithoutRetry), for: .touchUpInside)
      closeButton.tag = 901
      statusStack.arrangedSubviews.first(where: { $0.tag == 901 })?.removeFromSuperview()
      statusStack.addArrangedSubview(closeButton)
    } else {
      statusStack.arrangedSubviews.first(where: { $0.tag == 901 })?.removeFromSuperview()
    }
    UIAccessibility.post(notification: .announcement, argument: titleLabel.text)
  }

  @objc private func showOutbox() {
    let alert = UIAlertController(title: "Неотправленные", message: "Повтор возможен только после подтверждённой ошибки. При неизвестном результате сначала проверьте чат.", preferredStyle: .actionSheet)
    for share in previousShares {
      let state = share.status == "failed" || share.status == "prepared" ? "Ошибка" : share.status == "sent" ? "Отправлено" : "Проверьте чат"
      alert.addAction(UIAlertAction(title: "\(share.chatTitle) • \(state)", style: .default) { _ in self.showPreviousShare(share) })
    }
    alert.addAction(UIAlertAction(title: "Закрыть", style: .cancel))
    presentSheet(alert, source: outboxButton)
  }

  private func showPreviousShare(_ share: KometOutgoingShare) {
    let message = share.message ?? "Предыдущая отправка была прервана. Проверьте чат в Komet перед повторной отправкой."
    let alert = UIAlertController(title: share.chatTitle, message: message, preferredStyle: .alert)
    if share.status == "failed" || share.status == "prepared" {
      alert.addAction(UIAlertAction(title: "Повторить отправку", style: .default) { _ in
        self.outgoing = share
        self.showSending()
        self.sendOutgoing(share)
      })
    }
    alert.addAction(UIAlertAction(title: "Удалить сохранённые вложения", style: .destructive) { _ in
      guard let store = self.store else { return }
      self.worker.async {
        do {
          try store.removeOutgoing(id: share.id)
          let previous = try store.outgoingShares()
          DispatchQueue.main.async { self.previousShares = previous; self.refreshPicker() }
        } catch {
          DispatchQueue.main.async { self.messageAlert(error.localizedDescription) }
        }
      }
    })
    alert.addAction(UIAlertAction(title: "Назад", style: .cancel))
    present(alert, animated: true)
  }

  private func messageAlert(_ message: String) {
    let alert = UIAlertController(title: "Komet", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Готово", style: .default))
    present(alert, animated: true)
  }

  private func fail(_ error: Error) {
    guard !cancelled else { return }
    if let store = store, let draft = draft {
      worker.async { store.discard(draft) }
      self.draft = nil
    }
    sending = false
    isModalInPresentation = false
    pickerStack.isHidden = true
    statusStack.isHidden = false
    spinner.stopAnimating()
    progressView.isHidden = true
    titleLabel.text = "Не удалось передать"
    messageLabel.text = error.localizedDescription
    button.isEnabled = true
    button.setTitle("Закрыть", for: .normal)
  }

  @objc private func close() {
    guard !sending else { return }
    if canRetry, let outgoing = outgoing {
      statusStack.arrangedSubviews.first(where: { $0.tag == 901 })?.removeFromSuperview()
      showSending()
      sendOutgoing(outgoing)
      return
    }
    closeWithoutRetry()
  }

  @objc private func closeWithoutRetry() {
    guard !sending else { return }
    if draft != nil, outgoing != nil {
      outgoing = nil
      completed = false
      canRetry = false
      statusStack.arrangedSubviews.first(where: { $0.tag == 901 })?.removeFromSuperview()
      statusStack.isHidden = true
      pickerStack.isHidden = false
      if let store = store {
        worker.async {
          let previous = (try? store.outgoingShares()) ?? []
          DispatchQueue.main.async { self.previousShares = previous; self.refreshPicker() }
        }
      }
      return
    }
    if completed {
      extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
      return
    }
    cancelled = true
    progress?.cancel()
    if let store = store, let draft = draft {
      worker.async { store.discard(draft) }
      self.draft = nil
    }
    extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
  }

  private static func conforms(_ type: String, to parent: CFString) -> Bool {
    UTTypeConformsTo(type as CFString, parent)
  }
}

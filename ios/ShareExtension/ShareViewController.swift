import UIKit
import CryptoKit
import MobileCoreServices
import ImageIO

private func kometInitials(_ name: String) -> String {
  name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()
}

final class ShareViewController: UIViewController,
  UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
  UITextFieldDelegate, UITextViewDelegate {

  private let worker = DispatchQueue(label: "ru.komet.app.share-extension")

  private let spinner = UIActivityIndicatorView(style: .large)
  private let statusTitle = UILabel()
  private let statusMessage = UILabel()
  private let statusButton = UIButton(type: .system)
  private let statusStack = UIStackView()

  private let pickerStack = UIStackView()
  private let headerBar = UIView()
  private let titleSpacer = UIView()
  private let searchBox = UIView()
  private let searchLeadingButton = UIButton(type: .system)
  private let searchField = UITextField()
  private let titleBlock = UIStackView()
  private let headerTitle = UILabel()
  private let headerSubtitle = UILabel()
  private let accountAvatarButton = UIButton(type: .system)
  private let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
  private var accountMenu: KometShareAccountMenu?

  private let bottomArea = UIView()
  private let bottomStack = UIStackView()
  private let composePanel = UIView()
  private let composeStack = UIStackView()
  private let panelProgress = UIProgressView(progressViewStyle: .bar)
  private let thumbnailView = UIImageView()
  private let previewLabel = UILabel()
  private let previewRow = UIStackView()
  private let captionArea = UIView()
  private let captionView = UITextView()
  private let captionPlaceholder = UILabel()
  private var captionHeight: NSLayoutConstraint?
  private let sendButton = UIButton(type: .custom)
  private let sendIcon = UIImageView()
  private let sendSpinner = UIActivityIndicatorView(style: .medium)
  private let sendBadge = UIView()
  private let sendBadgeLabel = UILabel()
  private let cancelButton = UIButton(type: .system)

  private var bottomBottom: NSLayoutConstraint?
  private var keyboardOverlap: CGFloat = 0

  private var accountStore: KometShareAccounts?
  private var accounts: [KometShareAccount] = []
  private var selectedAccount: KometShareAccount?
  private var previousShares: [KometOutgoingShare] = []
  private var sending = false
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
  private var retryBatch: [KometOutgoingShare] = []
  private var selectedTargets = Set<String>()
  private let avatarCache = NSCache<NSString, UIImage>()
  private let shareTheme = KometShareTheme.load()
  private let palette: KometSharePalette
  private var searchMode = false
  private var gridWidth: CGFloat = 0
  private var captionWidthObserved: CGFloat = 0
  private var appliedIsDark = false

  static let storyTargetID = "-1"
  static let savedTargetID = "0"

  private struct Target {
    let id: String
    let title: String
    let kind: Kind
    let avatarName: String?
    let avatarUrl: String?

    enum Kind {
      case story
      case saved
      case chat
    }
  }

  private var targets: [Target] { pickerTargets(from: selectedAccount) }

  private var selectedTargetsInOrder: [Target] {
    let selected = selectedTargets
    return targets.filter { selected.contains($0.id) }
  }

  #if DEBUG
  func configurePreview(accounts: [KometShareAccount], files: [KometSharedFile], text: String, image: UIImage?) {
    started = true
    loadViewIfNeeded()
    applyTheme(force: true)
    self.accounts = accounts
    self.files = files
    selectedAccount = accounts.first
    captionView.text = text
    captionPlaceholder.isHidden = !text.isEmpty
    updateCaptionHeight()
    thumbnailView.image = image
    refreshSummary()
    spinner.stopAnimating()
    statusStack.isHidden = true
    bottomArea.isHidden = false
    pickerStack.isHidden = false
    refreshPicker()
    updatePanel()
  }
  #endif

  init() {
    palette = shareTheme.palette
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    palette.text.kometResolved(for: traitCollection).isLightColor ? .lightContent : .darkContent
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    overrideUserInterfaceStyle = shareTheme.interfaceStyleOverride
    view.backgroundColor = palette.surface
    view.layer.cornerRadius = 30
    view.layer.cornerCurve = .continuous
    view.layer.masksToBounds = true
    configureStatus()
    configureBottomPanel()
    configurePicker()
    preferredContentSize = CGSize(width: 420, height: 660)
    spinner.startAnimating()
    applyTheme(force: true)
    let outsideTap = UITapGestureRecognizer(target: self, action: #selector(outsideTapped(_:)))
    outsideTap.cancelsTouchesInView = false
    view.addGestureRecognizer(outsideTap)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func traitCollectionDidChange(_ previous: UITraitCollection?) {
    super.traitCollectionDidChange(previous)
    if previous?.userInterfaceStyle != traitCollection.userInterfaceStyle {
      applyTheme(force: false)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let width = collectionView.bounds.width
    if width > 0, width != gridWidth {
      gridWidth = width
      collectionView.collectionViewLayout.invalidateLayout()
    }
    let captionWidth = captionView.bounds.width
    if captionWidth > 0, captionWidth != captionWidthObserved {
      captionWidthObserved = captionWidth
      updateCaptionHeight(animated: false)
    }
    accountAvatarButton.layer.borderColor = palette.hairline.kometResolved(for: traitCollection).cgColor
    sendBadge.layer.borderColor = palette.card.kometResolved(for: traitCollection).cgColor
  }

  private func applyTheme(force: Bool) {
    let isDark = traitCollection.userInterfaceStyle == .dark
    guard force || isDark != appliedIsDark else { return }
    appliedIsDark = isDark
    setNeedsStatusBarAppearanceUpdate()
    collectionView.reloadData()
    panelProgress.progressTintColor = palette.accent
  }

  private func configureStatus() {
    spinner.color = palette.accent
    statusTitle.font = .kometDisplay(19, weight: .semibold)
    statusTitle.textColor = palette.text
    statusTitle.text = "Отправляем в Komet"
    statusMessage.font = .kometBody(15)
    statusMessage.textColor = palette.subtext
    statusMessage.textAlignment = .center
    statusMessage.numberOfLines = 0
    statusMessage.text = "Подготавливаем вложения…"
    statusButton.setTitle("Закрыть", for: .normal)
    statusButton.titleLabel?.font = .kometBody(15, weight: .semibold)
    statusButton.setTitleColor(palette.accent, for: .normal)
    statusButton.addTarget(self, action: #selector(closeWithoutRetry), for: .touchUpInside)
    statusStack.axis = .vertical
    statusStack.spacing = 18
    statusStack.alignment = .center
    for child in [spinner, statusTitle, statusMessage, statusButton] {
      statusStack.addArrangedSubview(child)
    }
    statusStack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(statusStack)
    NSLayoutConstraint.activate([
      statusStack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
      statusStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
      statusStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
      statusStack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28)
    ])
  }

  private func configureBottomPanel() {
    bottomArea.isHidden = true
    bottomStack.axis = .vertical
    bottomStack.spacing = 8
    bottomStack.translatesAutoresizingMaskIntoConstraints = false
    bottomArea.addSubview(bottomStack)

    composePanel.backgroundColor = palette.card
    composePanel.layer.cornerRadius = 20
    composePanel.layer.cornerCurve = .continuous
    composePanel.layer.masksToBounds = true
    composePanel.translatesAutoresizingMaskIntoConstraints = false
    composeStack.axis = .vertical
    composeStack.spacing = 8
    composeStack.isLayoutMarginsRelativeArrangement = true
    composeStack.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 10, right: 10)
    composeStack.translatesAutoresizingMaskIntoConstraints = false
    composePanel.addSubview(composeStack)

    panelProgress.progressTintColor = palette.accent
    panelProgress.trackTintColor = .clear
    panelProgress.isHidden = true
    panelProgress.translatesAutoresizingMaskIntoConstraints = false
    panelProgress.heightAnchor.constraint(equalToConstant: 3).isActive = true

    thumbnailView.contentMode = .scaleAspectFill
    thumbnailView.clipsToBounds = true
    thumbnailView.layer.cornerRadius = 12
    thumbnailView.layer.cornerCurve = .continuous
    thumbnailView.translatesAutoresizingMaskIntoConstraints = false
    thumbnailView.widthAnchor.constraint(equalToConstant: 42).isActive = true
    thumbnailView.heightAnchor.constraint(equalToConstant: 42).isActive = true
    thumbnailView.isHidden = true
    previewLabel.font = .kometBody(12, weight: .medium)
    previewLabel.textColor = palette.subtext
    previewLabel.numberOfLines = 1
    previewRow.axis = .horizontal
    previewRow.alignment = .center
    previewRow.spacing = 10
    previewRow.addArrangedSubview(thumbnailView)
    previewRow.addArrangedSubview(previewLabel)
    previewRow.isHidden = true

    captionArea.translatesAutoresizingMaskIntoConstraints = false
    captionView.font = .kometBody(15)
    captionView.backgroundColor = .clear
    captionView.textColor = palette.text
    captionView.tintColor = palette.accent
    captionView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    captionView.textContainer.lineFragmentPadding = 0
    captionView.isScrollEnabled = false
    captionView.accessibilityLabel = "Сообщение или подпись"
    captionView.delegate = self
    captionView.translatesAutoresizingMaskIntoConstraints = false
    captionArea.addSubview(captionView)
    captionHeight = captionArea.heightAnchor.constraint(equalToConstant: 34)
    captionHeight?.priority = .defaultHigh
    captionHeight?.isActive = true
    captionPlaceholder.font = .kometBody(15)
    captionPlaceholder.textColor = palette.subtext
    captionPlaceholder.text = "Сообщение или подпись…"
    captionPlaceholder.isHidden = true
    captionPlaceholder.isUserInteractionEnabled = false
    captionPlaceholder.translatesAutoresizingMaskIntoConstraints = false
    captionArea.addSubview(captionPlaceholder)
    NSLayoutConstraint.activate([
      captionView.topAnchor.constraint(equalTo: captionArea.topAnchor),
      captionView.bottomAnchor.constraint(equalTo: captionArea.bottomAnchor),
      captionView.leadingAnchor.constraint(equalTo: captionArea.leadingAnchor),
      captionView.trailingAnchor.constraint(equalTo: captionArea.trailingAnchor),
      captionPlaceholder.leadingAnchor.constraint(equalTo: captionArea.leadingAnchor),
      captionPlaceholder.topAnchor.constraint(equalTo: captionArea.topAnchor, constant: 8)
    ])

    sendButton.backgroundColor = palette.accent
    sendButton.layer.cornerRadius = 24
    sendButton.addTarget(self, action: #selector(sendSelected), for: .touchUpInside)
    sendButton.isEnabled = false
    sendButton.alpha = 0.45
    sendButton.accessibilityLabel = "Отправить"
    sendButton.translatesAutoresizingMaskIntoConstraints = false
    sendButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
    sendButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
    sendIcon.image = UIImage(
      systemName: "arrow.up",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
    )
    sendIcon.tintColor = palette.onAccent
    sendIcon.contentMode = .center
    sendIcon.translatesAutoresizingMaskIntoConstraints = false
    sendIcon.isUserInteractionEnabled = false
    sendButton.addSubview(sendIcon)
    sendSpinner.color = palette.onAccent
    sendSpinner.isHidden = true
    sendSpinner.translatesAutoresizingMaskIntoConstraints = false
    sendButton.addSubview(sendSpinner)
    sendBadge.backgroundColor = palette.onAccent
    sendBadge.layer.cornerRadius = 10
    sendBadge.layer.borderWidth = 2
    sendBadge.isHidden = true
    sendBadge.translatesAutoresizingMaskIntoConstraints = false
    sendBadgeLabel.font = .kometBody(11, weight: .bold)
    sendBadgeLabel.textColor = palette.accent
    sendBadgeLabel.textAlignment = .center
    sendBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
    sendBadgeLabel.isUserInteractionEnabled = false
    sendBadge.addSubview(sendBadgeLabel)
    sendButton.addSubview(sendBadge)

    sendIcon.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor).isActive = true
    sendIcon.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor).isActive = true
    sendSpinner.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor).isActive = true
    sendSpinner.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor).isActive = true
    NSLayoutConstraint.activate([
      sendBadge.centerXAnchor.constraint(equalTo: sendButton.trailingAnchor, constant: -10),
      sendBadge.centerYAnchor.constraint(equalTo: sendButton.topAnchor, constant: 10),
      sendBadge.widthAnchor.constraint(equalToConstant: 20),
      sendBadge.heightAnchor.constraint(equalToConstant: 20),
      sendBadgeLabel.centerXAnchor.constraint(equalTo: sendBadge.centerXAnchor),
      sendBadgeLabel.centerYAnchor.constraint(equalTo: sendBadge.centerYAnchor)
    ])

    cancelButton.setTitle("Отмена", for: .normal)
    cancelButton.titleLabel?.font = .kometBody(16, weight: .semibold)
    cancelButton.setTitleColor(palette.accent, for: .normal)
    cancelButton.backgroundColor = palette.tonal
    cancelButton.layer.cornerRadius = 14
    cancelButton.layer.cornerCurve = .continuous
    cancelButton.layer.masksToBounds = true
    cancelButton.addTarget(self, action: #selector(closeWithoutRetry), for: .touchUpInside)
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    cancelButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

    let composeRow = UIStackView(arrangedSubviews: [captionArea, sendButton])
    composeRow.axis = .horizontal
    composeRow.alignment = .bottom
    composeRow.spacing = 10

    composeStack.addArrangedSubview(panelProgress)
    composeStack.addArrangedSubview(previewRow)
    composeStack.addArrangedSubview(composeRow)

    composePanel.isHidden = true
    bottomStack.addArrangedSubview(composePanel)
    bottomStack.addArrangedSubview(cancelButton)

    bottomArea.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(bottomArea)
    let bottom = bottomArea.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
    bottomBottom = bottom
    NSLayoutConstraint.activate([
      bottom,
      bottomArea.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      bottomArea.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      bottomStack.topAnchor.constraint(equalTo: bottomArea.topAnchor),
      bottomStack.bottomAnchor.constraint(equalTo: bottomArea.bottomAnchor),
      bottomStack.leadingAnchor.constraint(equalTo: bottomArea.leadingAnchor),
      bottomStack.trailingAnchor.constraint(equalTo: bottomArea.trailingAnchor),
      composeStack.topAnchor.constraint(equalTo: composePanel.topAnchor),
      composeStack.bottomAnchor.constraint(equalTo: composePanel.bottomAnchor),
      composeStack.leadingAnchor.constraint(equalTo: composePanel.leadingAnchor),
      composeStack.trailingAnchor.constraint(equalTo: composePanel.trailingAnchor)
    ])
  }

  private func configurePicker() {
    pickerStack.axis = .vertical
    pickerStack.spacing = 6
    pickerStack.distribution = .fill
    pickerStack.isHidden = true
    pickerStack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(pickerStack)

    headerBar.translatesAutoresizingMaskIntoConstraints = false
    titleSpacer.translatesAutoresizingMaskIntoConstraints = false
    titleSpacer.isHidden = true

    titleBlock.axis = .vertical
    titleBlock.alignment = .center
    titleBlock.spacing = 1
    titleBlock.translatesAutoresizingMaskIntoConstraints = false
    titleBlock.isUserInteractionEnabled = false
    headerTitle.font = .kometDisplay(18, weight: .semibold)
    headerTitle.textColor = palette.text
    headerTitle.text = "Поделиться"
    headerTitle.textAlignment = .center
    headerSubtitle.font = .kometBody(13)
    headerSubtitle.textColor = palette.subtext
    headerSubtitle.text = "Выбрать чаты"
    headerSubtitle.textAlignment = .center
    titleBlock.addArrangedSubview(headerTitle)
    titleBlock.addArrangedSubview(headerSubtitle)

    accountAvatarButton.accessibilityLabel = "Сменить аккаунт"
    accountAvatarButton.addTarget(self, action: #selector(chooseAccount), for: .touchUpInside)
    accountAvatarButton.translatesAutoresizingMaskIntoConstraints = false
    accountAvatarButton.layer.borderWidth = 1

    searchBox.backgroundColor = palette.card
    searchBox.layer.cornerRadius = 24
    searchBox.layer.cornerCurve = .continuous
    searchBox.layer.masksToBounds = true
    searchBox.translatesAutoresizingMaskIntoConstraints = false
    searchLeadingButton.setImage(
      UIImage(
        systemName: "magnifyingglass",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
      ),
      for: .normal
    )
    searchLeadingButton.tintColor = palette.subtext
    searchLeadingButton.isUserInteractionEnabled = false
    searchLeadingButton.addTarget(self, action: #selector(backFromSearch), for: .touchUpInside)
    searchLeadingButton.translatesAutoresizingMaskIntoConstraints = false
    searchField.font = .kometBody(16)
    searchField.textColor = palette.text
    searchField.tintColor = palette.accent
    searchField.attributedPlaceholder = NSAttributedString(
      string: "Поиск",
      attributes: [.font: UIFont.kometBody(15), .foregroundColor: palette.subtext]
    )
    searchField.returnKeyType = .search
    searchField.clearButtonMode = .whileEditing
    searchField.delegate = self
    searchField.accessibilityLabel = "Поиск чатов"
    searchField.translatesAutoresizingMaskIntoConstraints = false
    searchField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
    searchBox.addSubview(searchLeadingButton)
    searchBox.addSubview(searchField)

    let flow = UICollectionViewFlowLayout()
    flow.minimumInteritemSpacing = 0
    flow.minimumLineSpacing = 16
    flow.sectionInset = UIEdgeInsets(top: 2, left: 4, bottom: 16, right: 4)
    collectionView.backgroundColor = .clear
    collectionView.collectionViewLayout = flow
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.keyboardDismissMode = .onDrag
    collectionView.alwaysBounceVertical = true
    collectionView.contentInsetAdjustmentBehavior = .never
    collectionView.register(ShareTargetCell.self, forCellWithReuseIdentifier: ShareTargetCell.reuseID)
    collectionView.translatesAutoresizingMaskIntoConstraints = false

    pickerStack.addArrangedSubview(headerBar)
    pickerStack.addArrangedSubview(searchBox)
    pickerStack.addArrangedSubview(collectionView)
    headerBar.addSubview(titleSpacer)
    headerBar.addSubview(titleBlock)
    headerBar.addSubview(accountAvatarButton)

    NSLayoutConstraint.activate([
      pickerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
      pickerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
      pickerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
      pickerStack.bottomAnchor.constraint(equalTo: bottomArea.topAnchor, constant: -6),
      headerBar.heightAnchor.constraint(equalToConstant: 44),
      titleSpacer.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
      titleSpacer.widthAnchor.constraint(equalToConstant: 40),
      titleSpacer.heightAnchor.constraint(equalToConstant: 1),
      titleBlock.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
      titleBlock.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
      titleBlock.leadingAnchor.constraint(greaterThanOrEqualTo: titleSpacer.trailingAnchor, constant: 2),
      titleBlock.trailingAnchor.constraint(lessThanOrEqualTo: accountAvatarButton.leadingAnchor, constant: -8),
      accountAvatarButton.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),
      accountAvatarButton.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
      accountAvatarButton.widthAnchor.constraint(equalToConstant: 40),
      accountAvatarButton.heightAnchor.constraint(equalToConstant: 40),
      searchBox.heightAnchor.constraint(equalToConstant: 48),
      searchLeadingButton.leadingAnchor.constraint(equalTo: searchBox.leadingAnchor, constant: 14),
      searchLeadingButton.centerYAnchor.constraint(equalTo: searchBox.centerYAnchor),
      searchLeadingButton.widthAnchor.constraint(equalToConstant: 24),
      searchLeadingButton.heightAnchor.constraint(equalToConstant: 24),
      searchField.leadingAnchor.constraint(equalTo: searchLeadingButton.trailingAnchor, constant: 10),
      searchField.trailingAnchor.constraint(equalTo: searchBox.trailingAnchor, constant: -14),
      searchField.centerYAnchor.constraint(equalTo: searchBox.centerYAnchor)
    ])
  }

  @objc private func keyboardChanged(_ notification: Notification) {
    guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
    let local = view.convert(frame, from: nil)
    keyboardOverlap = local.maxY >= view.bounds.maxY - 1
      ? max(0, view.bounds.maxY - local.minY - view.safeAreaInsets.bottom) : 0
    bottomBottom?.constant = -10 - keyboardOverlap
    let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
    UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
  }

  @objc private func outsideTapped(_ gesture: UITapGestureRecognizer) {
    var target: UIView? = view.hitTest(gesture.location(in: view), with: nil)
    while let current = target {
      if current is UIControl || current is UITextView || current is UITextField { return }
      target = current.superview
    }
    view.endEditing(true)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    begin()
  }

  // MARK: - загрузка контента

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
    statusMessage.text = "Подготавливаем вложение \(index + 1) из \(providers.count)…"
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
        guard let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.95) else {
          throw KometShareError.unreadableAttachment
        }
        let name = provider.suggestedName.map { ($0 as NSString).deletingPathExtension + ".jpg" }
        return try self.worker.sync {
          try store.saveData(data, suggestedName: name, typeIdentifier: kUTTypeJPEG as String, into: draft)
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
          self.collectionView.isUserInteractionEnabled = true
          self.headerBar.isUserInteractionEnabled = true
          self.composePanel.isUserInteractionEnabled = true
          self.updateCaptionHeight(animated: false)
          self.thumbnailView.image = image
          self.refreshSummary()
          self.spinner.stopAnimating()
          self.statusStack.isHidden = true
          self.bottomArea.isHidden = false
          self.pickerStack.isHidden = false
          self.refreshPicker()
          self.updatePanel()
          self.scheduleAvatarLoads()
        case .failure(let error):
          self.fail(error)
        }
      }
    }
  }

  // MARK: - пикер

  private func refreshSummary() {
    previewLabel.text = shareSummary
    previewRow.isHidden = files.isEmpty
    thumbnailView.isHidden = thumbnailView.image == nil
  }

  private var shareSummary: String {
    if files.isEmpty { return texts.isEmpty ? "Текст или ссылка" : "Текст" }
    return files.count == 1 ? files[0].name : "Вложений: \(files.count)"
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

  private var searchQuery: String {
    searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private var shareRootURL: URL? {
    let group = Bundle.main.object(forInfoDictionaryKey: "KometShareAppGroup") as? String ?? "group.ru.komet.app"
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
    return container.appendingPathComponent("KometShare", isDirectory: true)
  }

  private static func glyphPlaceholder(
    for target: Target,
    accent: UIColor,
    onAccent: UIColor
  ) -> UIImage? {
    switch target.kind {
    case .story: return glyphImage(symbol: "plus", tint: onAccent, background: accent)
    case .saved: return glyphImage(symbol: "bookmark.fill", tint: onAccent, background: accent)
    case .chat: return nil
    }
  }

  private static func glyphImage(symbol: String, tint: UIColor, background: UIColor) -> UIImage {
    let size = CGSize(width: 124, height: 124)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      let rect = CGRect(origin: .zero, size: size)
      background.setFill()
      context.cgContext.fillEllipse(in: rect)
      let configuration = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)
      if let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?
        .withTintColor(tint, renderingMode: .alwaysOriginal) {
        glyph.draw(at: CGPoint(
          x: (size.width - glyph.size.width) / 2,
          y: (size.height - glyph.size.height) / 2
        ))
      }
    }
  }

  private var storyAvailable: Bool {
    guard let account = selectedAccount,
          account.chats.first(where: { $0.id == Self.storyTargetID }) != nil,
          !files.isEmpty,
          files.allSatisfy({ KometShareContentType.isPhoto($0) }) else { return false }
    return true
  }

  private func pickerTargets(from account: KometShareAccount?) -> [Target] {
    guard let account else { return [] }
    var items: [Target] = []
    if storyAvailable, account.chats.first(where: { $0.id == Self.storyTargetID }) != nil {
      items.append(Target(
        id: Self.storyTargetID,
        title: "Ваша история",
        kind: .story,
        avatarName: "own.jpg",
        avatarUrl: account.accountAvatarUrl
      ))
    }
    // #***! первые два получателя: сторис и избранное
    if let favorites = account.chats.first(where: { $0.id == Self.savedTargetID }),
       favorites.disabledReason == nil,
       searchQuery.isEmpty || favorites.title.localizedCaseInsensitiveContains(searchQuery) {
      items.append(Target(
        id: favorites.id,
        title: favorites.title,
        kind: .saved,
        avatarName: favorites.avatar,
        avatarUrl: nil
      ))
    }
    let query = searchQuery
    for chat in account.chats
    where chat.id != Self.storyTargetID && chat.id != Self.savedTargetID && chat.disabledReason == nil {
      if !query.isEmpty && !chat.title.localizedCaseInsensitiveContains(query) { continue }
      items.append(Target(
        id: chat.id,
        title: chat.title,
        kind: .chat,
        avatarName: chat.avatar,
        avatarUrl: chat.avatarUrl
      ))
    }
    return items
  }

  private func refreshPicker() {
    if let account = selectedAccount {
      accountAvatarButton.setKometAvatar(
        image: accountAvatarImage(account),
        initials: kometInitials(account.name),
        palette: palette
      )
    } else {
      accountAvatarButton.setKometAvatar(image: nil, initials: "K", palette: palette)
    }

    if targets.isEmpty {
      let empty = UILabel()
      empty.numberOfLines = 0
      empty.textAlignment = .center
      empty.font = .kometBody(15)
      empty.textColor = palette.subtext
      empty.text = accounts.isEmpty
        ? "Откройте Komet один раз, чтобы загрузить ваши аккаунты и чаты. Затем вернитесь к отправке."
        : selectedAccount?.chats.isEmpty == true
          ? "В этом аккаунте пока нет доступных чатов. Обновите список в Komet."
          : "Ничего не найдено"
      empty.frame = CGRect(x: 0, y: 0, width: max(collectionView.bounds.width, 260), height: 200)
      collectionView.backgroundView = empty
    } else {
      collectionView.backgroundView = nil
    }
    collectionView.reloadData()
  }

  private func updatePanel() {
    let count = selectedTargets.count
    let badgeCount = count > 0 ? count : retryBatch.count
    let panelVisible = sending || count > 0 || !retryBatch.isEmpty
    let hasContent = !files.isEmpty
      || !captionView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let canSend = sending || (!retryBatch.isEmpty && count == 0) || (count > 0 && hasContent)
    headerSubtitle.text = count > 0 ? "Выбрано: \(count)" : "Выбрать чаты"
    sendBadgeLabel.text = badgeCount > 9 ? "9+" : "\(badgeCount)"
    sendBadge.isHidden = !panelVisible || badgeCount == 0
    UIView.animate(withDuration: 0.24, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
      self.composePanel.isHidden = !panelVisible
      self.cancelButton.isHidden = self.sending
      self.view.layoutIfNeeded()
    }
    sendButton.isEnabled = canSend
    sendButton.alpha = canSend ? 1 : 0.45
    sendIcon.isHidden = sending
    sendSpinner.isHidden = !sending
    if sending { sendSpinner.startAnimating() } else { sendSpinner.stopAnimating() }
  }

  private func updateCaptionHeight(animated: Bool = true) {
    let width = captionView.bounds.width
    guard width > 0 else {
      captionPlaceholder.isHidden = !captionView.text.isEmpty
      return
    }
    let fitting = captionView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    let growing = fitting > 88
    if captionView.isScrollEnabled != growing && !growing {
      captionView.contentOffset = .zero
    }
    captionView.isScrollEnabled = growing
    captionHeight?.constant = growing ? 88 : max(34, ceil(fitting))
    captionPlaceholder.isHidden = !captionView.text.isEmpty
    if animated {
      UIView.animate(withDuration: 0.16) { self.view.layoutIfNeeded() }
    }
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    targets.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ShareTargetCell.reuseID, for: indexPath)
    if let cell = cell as? ShareTargetCell {
      let target = targets[indexPath.item]
      cell.configure(
        title: target.title,
        placeholder: Self.glyphPlaceholder(
          for: target,
          accent: palette.accent.kometResolved(for: traitCollection),
          onAccent: palette.onAccent.kometResolved(for: traitCollection)
        ),
        avatar: avatarImage(for: target, account: selectedAccount),
        selected: selectedTargets.contains(target.id),
        palette: palette,
        story: target.kind == .story
      )
    }
    return cell
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let available = collectionView.bounds.width
    let insets = (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
    let columns = max(4, min(8, Int(available / 74)))
    let cellWidth = floor((available - insets.left - insets.right) / CGFloat(columns))
    return CGSize(width: max(64, cellWidth), height: 106)
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let target = targets[indexPath.item]
    collectionView.deselectItem(at: indexPath, animated: false)
    if selectedTargets.contains(target.id) {
      selectedTargets.remove(target.id)
    } else {
      selectedTargets.insert(target.id)
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    refreshSummary()
    updatePanel()
    collectionView.reloadItems(at: [indexPath])
  }

  private func avatarURL(accountID: String, name: String) -> URL? {
    guard !name.isEmpty, let root = shareRootURL else { return nil }
    let safe = name.replacingOccurrences(of: "/", with: "").replacingOccurrences(of: "\\", with: "")
    guard safe == name, !safe.contains("..") else { return nil }
    return root.appendingPathComponent("avatars/\(accountID)/\(safe)")
  }

  private func avatarImage(for target: Target, account: KometShareAccount?) -> UIImage? {
    guard let account else { return nil }
    switch target.kind {
    case .story:
      return accountAvatarImage(account)
    case .saved:
      return target.avatarName.flatMap { fileImage(accountID: account.id, name: $0) }
    case .chat:
      if let name = target.avatarName, let image = fileImage(accountID: account.id, name: name) {
        return image
      }
      guard let url = target.avatarUrl,
            let name = KometShareAvatarLoader.cacheName(chatID: target.id, url: url) else { return nil }
      return KometShareAvatarLoader.shared.cachedImage(accountID: account.id, name: name)
    }
  }

  private func accountAvatarImage(_ account: KometShareAccount) -> UIImage? {
    if let image = fileImage(accountID: account.id, name: "own.jpg") { return image }
    guard let url = account.accountAvatarUrl,
          let name = KometShareAvatarLoader.cacheName(chatID: "account", url: url) else { return nil }
    return KometShareAvatarLoader.shared.cachedImage(accountID: account.id, name: name)
  }

  private func fileImage(accountID: String, name: String) -> UIImage? {
    guard !name.isEmpty, let url = avatarURL(accountID: accountID, name: name) else { return nil }
    let key = "file/\(accountID)/\(name)" as NSString
    if let cached = avatarCache.object(forKey: key) { return cached }
    guard let image = UIImage(contentsOfFile: url.path) else { return nil }
    avatarCache.setObject(image, forKey: key)
    return image
  }

  // #***! заполняем пробелы аватарок из сети: приложение отдаёт ссылку,
  // расширение качает в свой кеш и перезагружает ячейку по готовности
  private func scheduleAvatarLoads() {
    for account in accounts {
      for chat in account.chats {
        switch chat.id {
        case Self.storyTargetID:
          scheduleAccountAvatarLoad(account)
        case Self.savedTargetID:
          continue
        case let id:
          guard chat.disabledReason == nil,
                let url = chat.avatarUrl, URL(string: url) != nil,
                fileImage(accountID: account.id, name: chat.avatar ?? "") == nil else { continue }
          scheduleFetch(account: account, chatID: id, url: url)
        }
      }
      scheduleAccountAvatarLoad(account)
      pruneAvatarCache(account)
    }
  }

  private func scheduleAccountAvatarLoad(_ account: KometShareAccount) {
    guard let url = account.accountAvatarUrl, URL(string: url) != nil,
          accountAvatarImage(account) == nil else { return }
    scheduleFetch(account: account, chatID: "account", url: url) { [weak self] image in
      guard let self, image != nil, self.selectedAccount?.id == account.id else { return }
      self.accountAvatarButton.setKometAvatar(
        image: self.accountAvatarImage(account),
        initials: kometInitials(account.name),
        palette: self.palette
      )
      if let index = self.targets.firstIndex(where: { $0.id == Self.storyTargetID }) {
        self.collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
      }
    }
  }

  private func scheduleFetch(
    account: KometShareAccount,
    chatID: String,
    url: String,
    extraHandler: ((UIImage?) -> Void)? = nil
  ) {
    KometShareAvatarLoader.shared.update(
      accountID: account.id,
      chatID: chatID,
      urlSource: url,
      completion: { [weak self] image in
        guard let self, !self.completed, image != nil else { return }
        if let extraHandler { extraHandler(image) }
        guard self.selectedAccount?.id == account.id,
              let index = self.targets.firstIndex(where: { $0.id == chatID }) else { return }
        self.collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
      }
    )
  }

  private func pruneAvatarCache(_ account: KometShareAccount) {
    var keep = Set<String>()
    for chat in account.chats {
      guard let url = chat.avatarUrl else { continue }
      if let name = KometShareAvatarLoader.cacheName(chatID: chat.id, url: url) {
        keep.insert(name)
      }
    }
    if let own = account.accountAvatarUrl,
       let name = KometShareAvatarLoader.cacheName(chatID: "account", url: own) {
      keep.insert(name)
    }
    KometShareAvatarLoader.shared.prune(accountID: account.id, keep: keep)
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }

  func textFieldDidBeginEditing(_ textField: UITextField) {
    updateSearchMode()
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
    updateSearchMode()
  }

  @objc private func searchTextChanged() {
    refreshPicker()
    updateSearchMode()
  }

  @objc private func backFromSearch() {
    searchField.text = ""
    searchField.resignFirstResponder()
    refreshPicker()
    updateSearchMode()
  }

  private func updateSearchMode() {
    let active = searchField.isFirstResponder || !(searchField.text ?? "").isEmpty
    guard searchMode != active else { return }
    searchMode = active
    if active {
      accountMenu?.close()
      accountMenu = nil
    }
    let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
    searchLeadingButton.setImage(
      UIImage(systemName: active ? "arrow.left" : "magnifyingglass", withConfiguration: configuration),
      for: .normal
    )
    searchLeadingButton.tintColor = active ? palette.text : palette.subtext
    searchLeadingButton.isUserInteractionEnabled = active
  }

  func textViewDidBeginEditing(_ textView: UITextView) {
    captionPlaceholder.isHidden = true
  }

  func textViewDidEndEditing(_ textView: UITextView) {
    captionPlaceholder.isHidden = !textView.text.isEmpty
  }

  func textViewDidChange(_ textView: UITextView) {
    updateCaptionHeight()
    updatePanel()
  }

  @objc private func chooseAccount() {
    if accountMenu != nil {
      accountMenu?.close()
      accountMenu = nil
      return
    }
    guard !accounts.isEmpty || !previousShares.isEmpty else { return }
    let headerFrame = view.convert(accountAvatarButton.bounds, from: accountAvatarButton)
    let anchor = CGPoint(x: headerFrame.maxX, y: headerFrame.maxY)
    let available = bottomArea.frame.minY - 24 - anchor.y
    let maxHeight = max(160, min(view.bounds.height * 0.5, available))
    let menu = KometShareAccountMenu(
      accounts: accounts,
      selectedID: selectedAccount?.id,
      outboxCount: previousShares.count,
      maxHeight: maxHeight,
      palette: palette,
      hairline: palette.hairline.kometResolved(for: traitCollection),
      avatar: { [weak self] account in self?.accountAvatarImage(account) }
    )
    menu.onChoose = { [weak self, weak menu] account in
      menu?.close()
      self?.selectAccount(account)
    }
    menu.onOutbox = { [weak self, weak menu] in
      menu?.close()
      self?.showOutbox()
    }
    menu.onClose = { [weak self] in self?.accountMenu = nil }
    menu.show(in: view, anchor: anchor)
    accountMenu = menu
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  private func selectAccount(_ account: KometShareAccount) {
    selectedAccount = account
    selectedTargets.removeAll()
    if searchMode {
      searchField.text = ""
      searchField.resignFirstResponder()
    }
    updateSearchMode()
    refreshSummary()
    refreshPicker()
    updatePanel()
  }

  // MARK: - отправка

  @objc private func sendSelected() {
    guard !sending else { return }
    if !retryBatch.isEmpty {
      let batch = retryBatch
      retryBatch = []
      beginSending()
      runBatch(batch)
      return
    }
    guard let store = store, let draft = draft,
          let account = selectedAccount, !selectedTargets.isEmpty else { return }
    let chosen = selectedTargetsInOrder
    let files = self.files
    let text = captionView.text
    view.endEditing(true)
    beginSending()
    worker.async {
      do {
        let copies = try (1..<chosen.count).map { _ in try store.duplicateDraft(draft) }
        var outgoings: [KometOutgoingShare] = []
        var drafts: [KometShareDraft] = [draft]
        drafts.append(contentsOf: copies)
        for (offset, target) in chosen.enumerated() {
          outgoings.append(try store.prepareOutgoing(
            drafts[offset],
            files: files,
            text: text,
            accountID: account.id,
            chatID: target.id,
            chatTitle: target.title
          ))
        }
        DispatchQueue.main.async {
          self.draft = nil
          self.runBatch(outgoings)
        }
      } catch {
        DispatchQueue.main.async {
          self.sending = false
          self.fail(error)
        }
      }
    }
  }

  private func beginSending() {
    sending = true
    accountMenu?.close()
    accountMenu = nil
    collectionView.isUserInteractionEnabled = false
    headerBar.isUserInteractionEnabled = false
    composePanel.isUserInteractionEnabled = false
    panelProgress.progress = 0
    panelProgress.isHidden = false
    previewRow.isHidden = false
    updatePanel()
  }

  private func runBatch(_ batch: [KometOutgoingShare]) {
    guard !batch.isEmpty else { return }
    sendBatch(batch, offset: 0, batchCount: batch.count)
  }

  private func sendBatch(_ batch: [KometOutgoingShare], offset: Int, batchCount: Int) {
    guard offset < batch.count else {
      let failed = batch.filter { $0.status != "sent" }
      if failed.isEmpty {
        showKometToast(
          text: batchCount == 1
            ? "Отправлено «\(batch[0].chatTitle)»"
            : "Отправлено в \(batchCount) чатов",
          success: true
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      } else {
        retryBatch = failed.filter { $0.status == "failed" || $0.status == "prepared" }
        restorePanelAfterFailure(message: failed.first?.message ?? "Не удалось отправить")
      }
      return
    }
    let outgoing = batch[offset]
    if batchCount > 1 {
      previewLabel.text = "Отправляем (\(offset + 1) из \(batchCount)): «\(outgoing.chatTitle)»"
    }
    sendOutgoing(outgoing) { [weak self] updated in
      var batch = batch
      batch[offset] = updated
      self?.sendBatch(batch, offset: offset + 1, batchCount: batchCount)
    }
  }

  private func restorePanelAfterFailure(message: String) {
    sending = false
    collectionView.isUserInteractionEnabled = true
    headerBar.isUserInteractionEnabled = true
    composePanel.isUserInteractionEnabled = true
    panelProgress.isHidden = true
    sendButton.isEnabled = true
    refreshSummary()
    updatePanel()
    showKometToast(text: message, success: false)
    UINotificationFeedbackGenerator().notificationOccurred(.error)
    if let store = store {
      worker.async {
        let previous = (try? store.outgoingShares()) ?? []
        DispatchQueue.main.async {
          self.previousShares = previous
          self.updatePanel()
        }
      }
    }
  }

  private func sendOutgoing(_ outgoing: KometOutgoingShare, completion: ((KometOutgoingShare) -> Void)? = nil) {
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
            self.panelProgress.isHidden = progress == nil
            if let progress = progress {
              self.panelProgress.setProgress(Float(progress), animated: true)
            }
          }
        }
        if let token = result.refreshedToken, let oldToken = credentials["token"] as? String {
          try? accountStore.updateToken(accountID: outgoing.accountID, previousToken: oldToken, refreshedToken: token)
        }
        var confirmed = outgoing
        confirmed.status = result.status
        confirmed.message = result.status == "sent" ? "Вложения отправлены в «\(outgoing.chatTitle)»." : result.message
        let updated = (try? store.updateOutgoing(outgoing, status: result.status, message: confirmed.message)) ?? confirmed
        if result.status == "sent" { try? store.removeOutgoing(id: outgoing.id) }
        DispatchQueue.main.async {
          if let completion = completion { completion(updated) }
        }
      } catch {
        let status = attempted ? "unknown" : "failed"
        let message = attempted
          ? "Не удалось подтвердить отправку. Проверьте чат в Komet перед повторной отправкой."
          : error.localizedDescription
        var fallback = outgoing
        fallback.status = status
        fallback.message = message
        let updated = (try? store.updateOutgoing(outgoing, status: status, message: message)) ?? fallback
        DispatchQueue.main.async {
          if let completion = completion { completion(updated) }
        }
      }
    }
  }

  private func showKometToast(text: String, success: Bool) {
    let traits = traitCollection
    let toast = UIView()
    toast.backgroundColor = palette.card
    toast.layer.cornerRadius = 22
    toast.layer.cornerCurve = .continuous
    toast.layer.borderColor = palette.hairline.kometResolved(for: traits).withAlphaComponent(0.7).cgColor
    toast.layer.borderWidth = 0.5
    toast.layer.shadowColor = UIColor.black.cgColor
    toast.layer.shadowOpacity = 0.35
    toast.layer.shadowRadius = 18
    toast.layer.shadowOffset = CGSize(width: 0, height: 8)
    toast.translatesAutoresizingMaskIntoConstraints = false

    let icon = UIView()
    icon.backgroundColor = success ? palette.accent : UIColor.systemRed
    icon.layer.cornerRadius = 15
    icon.translatesAutoresizingMaskIntoConstraints = false
    let check = CAShapeLayer()
    check.strokeColor = palette.onAccent.kometResolved(for: traits).cgColor
    check.lineWidth = 2.4
    check.lineCap = .round
    check.lineJoin = .round
    let errorLine = CAShapeLayer()
    errorLine.strokeColor = UIColor.white.cgColor
    errorLine.lineWidth = 2.4
    errorLine.lineCap = .round
    let iconBounds = CGRect(x: 0, y: 0, width: 30, height: 30)
    if success {
      let checkPath = UIBezierPath()
      checkPath.move(to: CGPoint(x: 8, y: iconBounds.midY + 0.5))
      checkPath.addLine(to: CGPoint(x: 13, y: iconBounds.midY + 5))
      checkPath.addLine(to: CGPoint(x: 22, y: iconBounds.midY - 5.5))
      check.path = checkPath.cgPath
      icon.layer.addSublayer(check)
    } else {
      let cross = UIBezierPath()
      cross.move(to: CGPoint(x: 10, y: 10))
      cross.addLine(to: CGPoint(x: 20, y: 20))
      cross.move(to: CGPoint(x: 20, y: 10))
      cross.addLine(to: CGPoint(x: 10, y: 20))
      errorLine.path = cross.cgPath
      icon.layer.addSublayer(errorLine)
    }

    let label = UILabel()
    label.font = .kometBody(14, weight: .medium)
    label.textColor = palette.text
    label.text = text
    label.numberOfLines = 0

    let stack = UIStackView(arrangedSubviews: [icon, label])
    stack.axis = .horizontal
    stack.alignment = .center
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    toast.addSubview(stack)

    view.addSubview(toast)
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 30),
      icon.heightAnchor.constraint(equalToConstant: 30),
      toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
      toast.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: toast.topAnchor, constant: 11),
      stack.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -11),
      stack.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 14),
      stack.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -14)
    ])
    toast.alpha = 0
    toast.transform = CGAffineTransform(translationX: 0, y: -18)
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
      toast.alpha = 1
      toast.transform = .identity
    }
    let ttl: TimeInterval = success ? 1.1 : 2.6
    DispatchQueue.main.asyncAfter(deadline: .now() + ttl) {
      UIView.animate(withDuration: 0.3, animations: {
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: -18)
      }) { _ in
        toast.removeFromSuperview()
        if success { self.completeSharing() }
      }
    }
  }

  private func completeSharing() {
    completed = true
    extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
  }

  @objc private func showOutbox() {
    let alert = UIAlertController(title: "Неотправленные", message: "Повтор возможен только после подтверждённой ошибки. При неизвестном результате сначала проверьте чат.", preferredStyle: .actionSheet)
    for share in previousShares {
      let state = share.status == "failed" || share.status == "prepared" ? "Ошибка" : share.status == "sent" ? "Отправлено" : "Проверьте чат"
      alert.addAction(UIAlertAction(title: "\(share.chatTitle) • \(state)", style: .default) { _ in self.showPreviousShare(share) })
    }
    alert.addAction(UIAlertAction(title: "Закрыть", style: .cancel))
    presentSheet(alert, source: accountAvatarButton)
  }

  private func presentSheet(_ controller: UIAlertController, source: UIView) {
    controller.popoverPresentationController?.sourceView = source
    controller.popoverPresentationController?.sourceRect = source.bounds
    present(controller, animated: true)
  }

  private func showPreviousShare(_ share: KometOutgoingShare) {
    let message = share.message ?? "Предыдущая отправка была прервана. Проверьте чат в Komet перед повторной отправкой."
    let alert = UIAlertController(title: share.chatTitle, message: message, preferredStyle: .alert)
    if share.status == "failed" || share.status == "prepared" {
      alert.addAction(UIAlertAction(title: "Повторить отправку", style: .default) { _ in
        self.beginSending()
        self.runBatch([share])
      })
    }
    alert.addAction(UIAlertAction(title: "Удалить сохранённые вложения", style: .destructive) { _ in
      guard let store = self.store else { return }
      self.worker.async {
        do {
          try store.removeOutgoing(id: share.id)
          let previous = try store.outgoingShares()
          DispatchQueue.main.async { self.previousShares = previous; self.updatePanel() }
        } catch {
          self.messageAlert(error.localizedDescription)
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
    sendSpinner.stopAnimating()
    pickerStack.isHidden = true
    bottomArea.isHidden = true
    statusStack.isHidden = false
    statusTitle.text = "Не удалось передать"
    statusMessage.text = error.localizedDescription
    spinner.stopAnimating()
    statusButton.isEnabled = true
  }

  @objc private func closeWithoutRetry() {
    guard !sending, !completed else {
      if completed { completeSharing() }
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

private enum KometShareContentType {
  static func isPhoto(_ file: KometSharedFile) -> Bool {
    file.mime.hasPrefix("image/")
      && file.mime != "image/gif"
      && file.mime != "image/svg+xml"
  }
}

final class ShareTargetCell: UICollectionViewCell {
  static let reuseID = "target"

  private var palette: KometSharePalette?
  private var story = false
  private var picked = false

  private let ringView = UIView()
  private let avatarView = UIImageView()
  private let fallbackLabel = UILabel()
  private let titleLabel = UILabel()
  private let badgeView = UIView()
  private let badgeIcon = UIImageView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    isAccessibilityElement = true
    accessibilityTraits = .button
    ringView.layer.cornerRadius = 33.5
    ringView.layer.borderWidth = 2.5
    ringView.isUserInteractionEnabled = false
    ringView.isHidden = true
    ringView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(ringView)
    avatarView.contentMode = .scaleAspectFill
    avatarView.clipsToBounds = true
    avatarView.layer.cornerRadius = 31
    avatarView.layer.masksToBounds = true
    avatarView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(avatarView)
    fallbackLabel.font = .kometBody(22, weight: .semibold)
    fallbackLabel.textAlignment = .center
    fallbackLabel.translatesAutoresizingMaskIntoConstraints = false
    fallbackLabel.isUserInteractionEnabled = false
    avatarView.addSubview(fallbackLabel)
    titleLabel.font = .kometBody(12, weight: .medium)
    titleLabel.textAlignment = .center
    titleLabel.numberOfLines = 2
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(titleLabel)
    badgeView.layer.cornerRadius = 11
    badgeView.layer.borderWidth = 2
    badgeView.isHidden = true
    badgeView.translatesAutoresizingMaskIntoConstraints = false
    badgeView.isUserInteractionEnabled = false
    contentView.addSubview(badgeView)
    badgeIcon.contentMode = .center
    badgeIcon.translatesAutoresizingMaskIntoConstraints = false
    badgeIcon.isUserInteractionEnabled = false
    badgeView.addSubview(badgeIcon)
    NSLayoutConstraint.activate([
      ringView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
      ringView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
      ringView.widthAnchor.constraint(equalToConstant: 67),
      ringView.heightAnchor.constraint(equalToConstant: 67),
      avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
      avatarView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      avatarView.widthAnchor.constraint(equalToConstant: 62),
      avatarView.heightAnchor.constraint(equalToConstant: 62),
      fallbackLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
      fallbackLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
      titleLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 5),
      titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 1),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -1),
      badgeView.centerXAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: -9),
      badgeView.centerYAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: -9),
      badgeView.widthAnchor.constraint(equalToConstant: 22),
      badgeView.heightAnchor.constraint(equalToConstant: 22),
      badgeIcon.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
      badgeIcon.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor),
      badgeIcon.widthAnchor.constraint(equalToConstant: 14),
      badgeIcon.heightAnchor.constraint(equalToConstant: 14)
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    palette = nil
    story = false
    picked = false
    avatarView.image = nil
    avatarView.backgroundColor = .clear
    fallbackLabel.isHidden = true
    ringView.isHidden = true
    badgeView.isHidden = true
  }

  // #***! цвета резолвятся при каждой раскладке: окантовка и шильдик
  // следуют за сменой светлой/тёмной темы; геометрия — только констрейнты
  override func layoutSubviews() {
    super.layoutSubviews()
    guard let palette = palette else { return }
    let traits = traitCollection
    ringView.layer.borderColor = palette.accent.kometResolved(for: traits).cgColor
    badgeView.layer.borderColor = palette.surface.kometResolved(for: traits).cgColor
    badgeIcon.tintColor = palette.onAccent.kometResolved(for: traits)
  }

  func configure(
    title: String,
    placeholder: UIImage?,
    avatar: UIImage?,
    selected: Bool,
    palette: KometSharePalette,
    story: Bool
  ) {
    self.palette = palette
    self.picked = selected
    self.story = story
    badgeView.backgroundColor = palette.accent
    titleLabel.textColor = palette.text
    titleLabel.text = title
    accessibilityLabel = title
    accessibilityValue = selected ? "выбрано" : nil
    if let avatar = avatar {
      avatarView.image = avatar
      avatarView.backgroundColor = .clear
      fallbackLabel.isHidden = true
    } else if let placeholder = placeholder {
      avatarView.image = placeholder
      avatarView.backgroundColor = .clear
      fallbackLabel.isHidden = true
    } else {
      avatarView.image = nil
      avatarView.backgroundColor = palette.accent
      fallbackLabel.isHidden = false
      fallbackLabel.text = String(title.prefix(1)).uppercased()
      fallbackLabel.textColor = palette.onAccent
    }
    let showingRing = story || selected
    ringView.isHidden = !showingRing
    ringView.layer.borderWidth = story ? 2 : 2.5
    badgeView.isHidden = !showingRing
    if story {
      if selected { setBadgeIcon("checkmark") } else { setBadgeIcon("plus") }
    } else {
      setBadgeIcon("checkmark")
    }
    setNeedsLayout()
  }

  private func setBadgeIcon(_ symbol: String) {
    badgeIcon.image = UIImage(
      systemName: symbol,
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
    )
  }
}

final class KometShareAccountMenu: UIView {
  var onChoose: ((KometShareAccount) -> Void)?
  var onOutbox: (() -> Void)?
  var onClose: (() -> Void)?

  private let panel = UIView()
  private let scroll = UIScrollView()
  private let rowsStack = UIStackView()
  private let scrim = UIControl()
  private var closing = false

  init(
    accounts: [KometShareAccount],
    selectedID: String?,
    outboxCount: Int,
    maxHeight: CGFloat,
    palette: KometSharePalette,
    hairline: UIColor,
    avatar: @escaping (KometShareAccount) -> UIImage?
  ) {
    super.init(frame: .zero)
    backgroundColor = .clear
    scrim.backgroundColor = .clear
    scrim.addTarget(self, action: #selector(scrimTapped), for: .touchUpInside)
    scrim.translatesAutoresizingMaskIntoConstraints = false
    addSubview(scrim)

    panel.backgroundColor = palette.card
    panel.layer.cornerRadius = 18
    panel.layer.cornerCurve = .continuous
    panel.layer.borderWidth = 0.5
    panel.layer.borderColor = hairline.cgColor
    panel.layer.shadowColor = UIColor.black.cgColor
    panel.layer.shadowOpacity = 0.22
    panel.layer.shadowRadius = 20
    panel.layer.shadowOffset = CGSize(width: 0, height: 6)
    panel.layer.masksToBounds = false
    panel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(panel)

    scroll.alwaysBounceVertical = true
    scroll.showsVerticalScrollIndicator = false
    scroll.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(scroll)

    rowsStack.axis = .vertical
    rowsStack.spacing = 0
    rowsStack.translatesAutoresizingMaskIntoConstraints = false
    scroll.addSubview(rowsStack)

    var contentHeight: CGFloat = 0
    for account in accounts {
      let row = Self.row(
        title: account.name,
        symbol: nil,
        avatar: avatar(account),
        initials: kometInitials(account.name),
        selected: account.id == selectedID,
        palette: palette
      )
      row.action = { [weak self] in self?.onChoose?(account) }
      rowsStack.addArrangedSubview(row)
      contentHeight += 50
    }
    if outboxCount > 0 {
      let divider = UIView()
      divider.backgroundColor = palette.hairline
      divider.translatesAutoresizingMaskIntoConstraints = false
      divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
      rowsStack.addArrangedSubview(divider)
      contentHeight += 0.5
      let row = Self.row(
        title: "Неотправленные (\(outboxCount))",
        symbol: "tray.full",
        avatar: nil,
        initials: "",
        selected: false,
        palette: palette
      )
      row.action = { [weak self] in self?.onOutbox?() }
      rowsStack.addArrangedSubview(row)
      contentHeight += 50
    }

    NSLayoutConstraint.activate([
      scrim.topAnchor.constraint(equalTo: topAnchor),
      scrim.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
      scroll.topAnchor.constraint(equalTo: panel.topAnchor, constant: 6),
      scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -6),
      scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 6),
      scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -6),
      rowsStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
      rowsStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
      rowsStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
      rowsStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
      rowsStack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
    ])

    let height = min(contentHeight + 12, maxHeight)
    scroll.heightAnchor.constraint(equalToConstant: height).isActive = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  private static func row(
    title: String,
    symbol: String?,
    avatar: UIImage?,
    initials: String,
    selected: Bool,
    palette: KometSharePalette
  ) -> ShareMenuRow {
    let row = ShareMenuRow()
    row.translatesAutoresizingMaskIntoConstraints = false
    row.heightAnchor.constraint(equalToConstant: 50).isActive = true

    let icon = UIView()
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.layer.cornerRadius = 15
    icon.clipsToBounds = true
    if let avatar = avatar {
      let imageView = UIImageView(image: avatar)
      imageView.contentMode = .scaleAspectFill
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.isUserInteractionEnabled = false
      icon.addSubview(imageView)
      NSLayoutConstraint.activate([
        imageView.topAnchor.constraint(equalTo: icon.topAnchor),
        imageView.bottomAnchor.constraint(equalTo: icon.bottomAnchor),
        imageView.leadingAnchor.constraint(equalTo: icon.leadingAnchor),
        imageView.trailingAnchor.constraint(equalTo: icon.trailingAnchor)
      ])
    } else if let symbol = symbol {
      let glyph = UIImageView(image: UIImage(
        systemName: symbol,
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
      ))
      glyph.tintColor = palette.subtext
      glyph.contentMode = .center
      glyph.translatesAutoresizingMaskIntoConstraints = false
      glyph.isUserInteractionEnabled = false
      icon.addSubview(glyph)
      NSLayoutConstraint.activate([
        glyph.topAnchor.constraint(equalTo: icon.topAnchor),
        glyph.bottomAnchor.constraint(equalTo: icon.bottomAnchor),
        glyph.leadingAnchor.constraint(equalTo: icon.leadingAnchor),
        glyph.trailingAnchor.constraint(equalTo: icon.trailingAnchor)
      ])
    } else {
      icon.backgroundColor = palette.accent
      let initialsLabel = UILabel()
      initialsLabel.text = initials
      initialsLabel.font = .kometBody(12, weight: .semibold)
      initialsLabel.textColor = palette.onAccent
      initialsLabel.textAlignment = .center
      initialsLabel.translatesAutoresizingMaskIntoConstraints = false
      initialsLabel.isUserInteractionEnabled = false
      icon.addSubview(initialsLabel)
      NSLayoutConstraint.activate([
        initialsLabel.centerXAnchor.constraint(equalTo: icon.centerXAnchor),
        initialsLabel.centerYAnchor.constraint(equalTo: icon.centerYAnchor)
      ])
    }

    let label = UILabel()
    label.font = .kometBody(15)
    label.textColor = palette.text
    label.text = title
    label.numberOfLines = 1
    label.translatesAutoresizingMaskIntoConstraints = false
    label.isUserInteractionEnabled = false

    row.addSubview(icon)
    row.addSubview(label)
    NSLayoutConstraint.activate([
      icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
      icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 30),
      icon.heightAnchor.constraint(equalToConstant: 30),
      label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
      label.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -14),
      label.centerYAnchor.constraint(equalTo: row.centerYAnchor)
    ])
    if selected {
      let check = UIImageView(image: UIImage(
        systemName: "checkmark",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
      ))
      check.tintColor = palette.accent
      check.translatesAutoresizingMaskIntoConstraints = false
      check.isUserInteractionEnabled = false
      row.addSubview(check)
      NSLayoutConstraint.activate([
        check.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
        check.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        check.widthAnchor.constraint(equalToConstant: 20),
        check.heightAnchor.constraint(equalToConstant: 20)
      ])
      label.trailingAnchor.constraint(lessThanOrEqualTo: check.leadingAnchor, constant: -8).isActive = true
    }
    return row
  }

  func show(in container: UIView, anchor: CGPoint) {
    translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(self)
    let top = panel.topAnchor.constraint(equalTo: topAnchor, constant: anchor.y + 10)
    let trailing = panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(container.bounds.width - anchor.x))
    NSLayoutConstraint.activate([
      top,
      trailing,
      panel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
      panel.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
      topAnchor.constraint(equalTo: container.topAnchor),
      bottomAnchor.constraint(equalTo: container.bottomAnchor),
      leadingAnchor.constraint(equalTo: container.leadingAnchor),
      trailingAnchor.constraint(equalTo: container.trailingAnchor)
    ])
    alpha = 0
    panel.transform = CGAffineTransform(translationX: 0, y: -8)
    container.layoutIfNeeded()
    UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
      self.alpha = 1
      self.panel.transform = .identity
    }
  }

  func close(completion: (() -> Void)? = nil) {
    guard !closing else { return }
    closing = true
    UIView.animate(withDuration: 0.16, animations: {
      self.alpha = 0
      self.panel.transform = CGAffineTransform(translationX: 0, y: -8)
    }) { [weak self] _ in
      self?.removeFromSuperview()
      self?.onClose?()
      completion?()
    }
  }

  @objc private func scrimTapped() {
    close()
  }
}

private final class ShareMenuRow: UIView {
  var action: (() -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)
    addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  @objc private func tapped() {
    action?()
  }
}

// #***! автозагрузка аватарок по ссылкам из снапшота: кеш в app-group,
// обновление с If-None-Match/If-Modified-Since — актуализация при смене аватарок
final class KometShareAvatarLoader {
  static let shared = KometShareAvatarLoader()

  static func cacheName(chatID: String, url: String) -> String? {
    guard !chatID.isEmpty, !url.isEmpty else { return nil }
    return "\(chatID)_\(md5Hex(url)).jpg"
  }

  static func md5Hex(_ value: String) -> String {
    let digest = Insecure.MD5.hash(data: Data(value.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private static let memoryCache = NSCache<NSString, UIImage>()

  private let lock = NSLock()
  private var inFlight = Set<String>()
  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 12
    configuration.timeoutIntervalForResource = 40
    configuration.httpMaximumConnectionsPerHost = 3
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    return URLSession(configuration: configuration)
  }()

  private struct Meta: Codable {
    let url: String
    var etag: String?
    var lastModified: String?
  }

  func cachedImage(accountID: String, name: String) -> UIImage? {
    guard let url = cacheURL(accountID: accountID, name: name) else { return nil }
    let key = "\(accountID)/\(name)" as NSString
    if let cached = Self.memoryCache.object(forKey: key) { return cached }
    guard let image = UIImage(contentsOfFile: url.path) else { return nil }
    Self.memoryCache.setObject(image, forKey: key)
    return image
  }

  func update(
    accountID: String,
    chatID: String,
    urlSource: String,
    completion: @escaping (UIImage?) -> Void
  ) {
    guard let target = URL(string: urlSource),
          let name = Self.cacheName(chatID: chatID, url: urlSource) else {
      completion(nil)
      return
    }
    let key = "\(accountID)/\(chatID)" as String
    lock.lock()
    let busy = inFlight.contains(key)
    if !busy { inFlight.insert(key) }
    lock.unlock()
    guard !busy else { return }
    let cached = cachedImage(accountID: accountID, name: name)
    let previous = readMeta(accountID: accountID, name: name)
    let finished: (UIImage?) -> Void = { [weak self] image in
      self?.lock.lock()
      self?.inFlight.remove(key)
      self?.lock.unlock()
      completion(image)
    }
    var request = URLRequest(url: target)
    if let previous = previous, previous.url == urlSource {
      if let etag = previous.etag {
        request.setValue(etag, forHTTPHeaderField: "If-None-Match")
      }
      if let modified = previous.lastModified {
        request.setValue(modified, forHTTPHeaderField: "If-Modified-Since")
      }
    }
    session.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self else { return }
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      var resolved: UIImage?
      if error == nil, status == 200, let data = data, !data.isEmpty,
         let image = UIImage(data: data) {
        let meta = Meta(
          url: urlSource,
          etag: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag"),
          lastModified: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Last-Modified")
        )
        self.write(accountID: accountID, name: name, data: data, meta: meta)
        resolved = image
      } else if error == nil, status == 304 {
        resolved = cached
      }
      DispatchQueue.main.async { finished(resolved ?? (status == 304 ? cached : nil)) }
    }.resume()
  }

  func prune(accountID: String, keep: Set<String>) {
    guard let directoryURL = cacheDirectoryURL(accountID: accountID) else { return }
    let contents = (try? FileManager.default.contentsOfDirectory(
      at: directoryURL,
      includingPropertiesForKeys: nil
    )) ?? []
    for url in contents {
      let name = url.lastPathComponent
      guard !name.hasSuffix(".meta") else { continue }
      if keep.contains(name) { continue }
      try? FileManager.default.removeItem(at: url)
      try? FileManager.default.removeItem(
        at: directoryURL.appendingPathComponent(
          (name as NSString).deletingPathExtension + ".meta"
        )
      )
      Self.memoryCache.removeObject(forKey: "\(accountID)/\(name)" as NSString)
    }
  }

  private func cacheURL(accountID: String, name: String) -> URL? {
    cacheDirectoryURL(accountID: accountID)?.appendingPathComponent(name)
  }

  private func cacheDirectoryURL(accountID: String) -> URL? {
    let group = Bundle.main.object(forInfoDictionaryKey: "KometShareAppGroup") as? String
      ?? "group.ru.komet.app"
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: group
    ) else { return nil }
    let root = container
      .appendingPathComponent("KometShare", isDirectory: true)
      .appendingPathComponent("avatar-cache", isDirectory: true)
      .appendingPathComponent(accountID, isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func readMeta(accountID: String, name: String) -> Meta? {
    let base = (name as NSString).deletingPathExtension
    guard let metaURL = cacheURL(accountID: accountID, name: "\(base).meta"),
          let data = try? Data(contentsOf: metaURL),
          let meta = try? JSONDecoder().decode(Meta.self, from: data) else { return nil }
    return meta
  }

  private func write(accountID: String, name: String, data: Data, meta: Meta) {
    guard let fileURL = cacheURL(accountID: accountID, name: name) else { return }
    do {
      try data.write(to: fileURL, options: .atomic)
      if let encoded = try? JSONEncoder().encode(meta),
         let metaURL = cacheURL(
           accountID: accountID,
           name: (name as NSString).deletingPathExtension + ".meta"
         ) {
        try encoded.write(to: metaURL, options: .atomic)
      }
      if let image = UIImage(contentsOfFile: fileURL.path) {
        Self.memoryCache.setObject(image, forKey: "\(accountID)/\(name)" as NSString)
      }
    } catch {
      try? FileManager.default.removeItem(at: fileURL)
    }
  }
}
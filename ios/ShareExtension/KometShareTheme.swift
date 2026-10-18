import UIKit

extension UIFont {
  // #***! шрифты Komet: Outfit — заголовки, Inter — основной текст.
  // Семейство в шрифте может называться и по имени файла, и по ps-нейму
  static func kometDisplay(_ size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
    kometFont("Outfit", size: size, fallbackWeight: weight)
  }

  static func kometBody(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
    kometFont("Inter", size: size, fallbackWeight: weight)
  }

  private static func kometFont(
    _ family: String,
    size: CGFloat,
    fallbackWeight: UIFont.Weight
  ) -> UIFont {
    for name in [family, "\(family)-Regular", "\(family)-Medium"] {
      if let font = UIFont(name: name, size: size * (name == family ? 1.02 : 1)) {
        return font
      }
    }
    return .systemFont(ofSize: size, weight: fallbackWeight)
  }
}

extension UIColor {
  var isLightColor: Bool {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
    return 0.299 * red + 0.587 * green + 0.114 * blue > 0.6
  }

  static func kometDynamic(light: UIColor, dark: UIColor) -> UIColor {
    UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
  }
}

extension UIColor {
  func kometResolved(for traits: UITraitCollection) -> UIColor {
    resolvedColor(with: traits)
  }
}

extension UIButton {
  // #***! круглая аватарка аккаунта с инициалами как фолбэком, как в приложении
  // всегда-оригинальный режим рендера: кнопка иначе тонирует картинку системным синим
  func setKometAvatar(image: UIImage?, initials: String, palette: KometSharePalette) {
    if let image = image {
      setTitle(nil, for: .normal)
      setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
      imageView?.contentMode = .scaleAspectFill
      backgroundColor = .clear
    } else {
      setImage(nil, for: .normal)
      setTitle(initials.isEmpty ? "K" : initials, for: .normal)
      titleLabel?.font = .kometBody(15, weight: .semibold)
      setTitleColor(palette.onAccent, for: .normal)
      backgroundColor = palette.accent
    }
    layer.cornerRadius = bounds.width > 0 ? bounds.width / 2 : 20
    clipsToBounds = true
  }
}

struct KometShareThemeVariant {
  let accent: Int
  let onAccent: Int
  let surface: Int
  let card: Int
  let text: Int
  let subtext: Int
  let hairline: Int
}

struct KometSharePalette {
  let accent: UIColor
  let onAccent: UIColor
  let tonal: UIColor
  let surface: UIColor
  let card: UIColor
  let text: UIColor
  let subtext: UIColor
  let hairline: UIColor

  init(light: KometShareThemeVariant, dark: KometShareThemeVariant) {
    func color(_ light: Int, _ dark: Int) -> UIColor {
      .kometDynamic(
        light: KometSharePalette.solid(light),
        dark: KometSharePalette.solid(dark)
      )
    }
    accent = color(light.accent, dark.accent)
    onAccent = color(light.onAccent, dark.onAccent)
    tonal = UIColor.kometDynamic(
      light: KometSharePalette.solid(light.accent).withAlphaComponent(0.14),
      dark: KometSharePalette.solid(dark.accent).withAlphaComponent(0.17)
    )
    surface = color(light.surface, dark.surface)
    card = color(light.card, dark.card)
    text = color(light.text, dark.text)
    subtext = color(light.subtext, dark.subtext)
    hairline = color(light.hairline, dark.hairline)
  }

  private static func solid(_ value: Int) -> UIColor {
    UIColor(
      red: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: 1
    )
  }
}

struct KometShareTheme {
  let system: Bool
  let fixedIsDark: Bool
  let light: KometShareThemeVariant
  let dark: KometShareThemeVariant

  var palette: KometSharePalette {
    KometSharePalette(light: light, dark: dark)
  }

  // #***! при системной теме не форсируем стиль: расширение должно жить
  // вслед за системой, иначе хром и цвета остаются от старой темы
  var interfaceStyleOverride: UIUserInterfaceStyle {
    if system { return .unspecified }
    return fixedIsDark ? .dark : .light
  }

  static let fallback = KometShareTheme(
    system: true,
    fixedIsDark: true,
    light: KometShareThemeVariant(
      accent: 0x4F5BE8, onAccent: 0xFFFFFF, surface: 0xFFFFFF,
      card: 0xEFEFF4, text: 0x1A1A1C, subtext: 0x6C6C70, hairline: 0xC8C8CC
    ),
    dark: KometShareThemeVariant(
      accent: 0xB9B7F8, onAccent: 0x14142A, surface: 0x0D0D10,
      card: 0x1C1C22, text: 0xF5F5F7, subtext: 0x9A9AA2, hairline: 0x2A2A32
    )
  )

  static func load() -> KometShareTheme {
    let group = Bundle.main.object(forInfoDictionaryKey: "KometShareAppGroup") as? String
      ?? "group.ru.komet.app"
    let root = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: group)?
      .appendingPathComponent("KometShare", isDirectory: true)
    guard let root,
          let data = try? Data(contentsOf: root.appendingPathComponent("theme.json")),
          let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let lightRaw = payload["light"] as? [String: Any],
          let darkRaw = payload["dark"] as? [String: Any],
          let light = variant(lightRaw),
          let dark = variant(darkRaw) else {
      return .fallback
    }
    return KometShareTheme(
      system: (payload["system"] as? NSNumber)?.boolValue ?? true,
      fixedIsDark: (payload["current"] as? String) == "dark",
      light: light,
      dark: dark
    )
  }

  private static func variant(_ raw: [String: Any]) -> KometShareThemeVariant? {
    func color(_ key: String) -> Int? {
      guard var hex = raw[key] as? String else { return nil }
      if hex.hasPrefix("#") { hex.removeFirst() }
      guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
      return Int(value)
    }
    guard let accent = color("accent"), let onAccent = color("onAccent"),
          let surface = color("surface"), let card = color("card"),
          let text = color("text"), let subtext = color("subtext"),
          let hairline = color("hairline") else { return nil }
    return KometShareThemeVariant(
      accent: accent, onAccent: onAccent, surface: surface,
      card: card, text: text, subtext: subtext, hairline: hairline
    )
  }
}
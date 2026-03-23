import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/core/config/countries.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'code_confirmation_screen.dart';
import 'select_country_screen.dart';

void _showCustomNotification(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (context) => _CustomNotification(message: message),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1900), () {
    entry.remove();
  });
}

class _CustomNotification extends StatefulWidget {
  final String message;
  const _CustomNotification({required this.message});

  @override
  State<_CustomNotification> createState() => _CustomNotificationState();
}

class _CustomNotificationState extends State<_CustomNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                widget.message,
                style: GoogleFonts.inter(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  late CountryName _selectedCountry;
  bool _isPhoneValid = false;
  bool _isTOSRead = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = countriesByCode['RU'] ?? allCountries.first;
    _checkTOS();
  }

  Future<void> _checkTOS() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isTOSRead = prefs.getBool('IsReadeTOS') ?? false;
      });
    }
  }

  Future<void> _markTOSRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('IsReadeTOS', true);
    if (mounted) {
      setState(() {
        _isTOSRead = true;
      });
    }
  }

  void _showCountryPicker() async {
    final result = await Navigator.push<CountryName>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SelectCountryScreen(selectedCountry: _selectedCountry),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedCountry = result;
        _phoneController.clear();
        _isPhoneValid = false;
      });
    }
  }

  void _showTOS(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        double progress = _isTOSRead ? 1.0 : 0.0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cs = Theme.of(context).colorScheme;
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 1.0,
              snap: true,
              snapSizes: const [0.7, 1.0],
              expand: false,
              builder: (context, scrollController) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Условия использования',
                          style: GoogleFonts.inter(
                            color: cs.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification:
                            (ScrollUpdateNotification notification) {
                              if (_isTOSRead) return false;
                              final metrics = notification.metrics;
                              if (metrics.maxScrollExtent > 0) {
                                double newProgress =
                                    metrics.pixels / metrics.maxScrollExtent;
                                newProgress = newProgress.clamp(0.0, 1.0);
                                if (newProgress >= 0.99 && !_isTOSRead) {
                                  _markTOSRead();
                                  setModalState(() {
                                    progress = 1.0;
                                  });
                                } else {
                                  setModalState(() {
                                    progress = newProgress;
                                  });
                                }
                              }
                              return false;
                            },
                        child: ListView(
                          controller: scrollController,
                          children: [
                            //У мя вопрос а тут точно номера статей верные???
                            Text(
                              'Условия использования неофициального клиента на MAX, именуемым "KometClient" или же "Komet"\n\n'
                              '1. Статус и отношения\n'
                              '1.1. «Komet» (далее — «Приложение») — неофициальное стороннее приложение, не имеющее отношения к ООО «Коммуникационная платформа" (правообладатель сервиса «MAX").\n'
                              '1.2. Разработчики Приложения не являются партнёрами, сотрудниками или аффилированными лицами ООО «Коммуникационная платформа».\n'
                              '1.3. Все упоминания торговых марок «MAX» и связанных сервисов принадлежат их правообладателям.\n\n'
                              '2. Условия использования\n'
                              '2.1. Используя Приложение «Komet», вы:\n'
                              '• Автоматически подтверждаете согласие с официальным Пользовательским соглашением «MAX» (https://legal.max.ru/ps)\n'
                              '• Осознаёте, что использование неофициального клиента может привести к блокировке аккаунта со стороны ООО «Коммуникационная платформа»;\n'
                              '• Принимаете на себя все риски, связанные с использованием Приложения.\n'
                              '2.2. Строго запрещено:\n'
                              '• Использовать Приложение «Komet» для распространения запрещённого контента;\n'
                              '• Осуществлять массовые рассылки (спам);\n'
                              '• Нарушать законодательство РФ и международное право;\n'
                              '• Предпринимать попытки взлома или нарушения работы оригинального сервиса «MAX».\n'
                              '2.3. Техническая реализация соответствует принципу добросовестного использования (свободное использование) и не нарушает исключительные права правообладателя в соответствии с статьёй 1273 ГК РФ.\n'
                              '2.4. Особенности технического взаимодействия:\n'
                              '• Приложение «Komet» использует публично доступные методы взаимодействия с сервисом «MAX», аналогичные веб-версии (https://web.max.ru)\n'
                              '• Все запросы выполняются в рамках добросовестного использования для обеспечения совместимости;\n'
                              '• Разработчики не осуществляют обход технических средств защиты и не декомпилируют оригинальное ПО.\n\n'
                              '3. Технические аспекты\n'
                              '3.1. Приложение «Komet» использует только публично доступные методы взаимодействия с сервисом «MAX» через официальные конечные точки.\n'
                              '3.2. Все запросы выполняются в рамках добросовестного использования (fair use) для обеспечения совместимости.\n'
                              '3.3. Разработчики не несут ответственности за:\n'
                              '• Изменения в API оригинального сервиса;\n'
                              '• Блокировку аккаунтов пользователей;\n'
                              '• Функциональные ограничения, вызванные действиями ООО «Коммуникационная платформа».\n\n'
                              '4. Конфиденциальность\n'
                              '4.1. Приложение «Komet» не хранит и не обрабатывает персональные данные пользователей.\n'
                              '4.2. Все данные авторизации передаются напрямую серверам ООО «Коммуникационная платформа».\n'
                              '4.3. Разработчики не имеют доступа к логинам, паролям, переписке и другим персональным данным пользователей.\n\n'
                              '5. Ответственность и ограничения\n'
                              '5.1. Приложение «Komet» предоставляется «как есть» (as is) без гарантий работоспособности.\n'
                              '5.2. Разработчики вправе прекратить поддержку Приложения в любой момент без объяснения причин.\n\n'
                              '6. Правовые основания\n'
                              '6.1. Разработка и распространение Приложения «Komet» осуществляются в соответствии с:\n'
                              '• Статья 1280.3 ГК РФ — декомпилирование программы для обеспечения совместимости;\n'
                              '• Статья 1229 ГК РФ — ограничения исключительного права в информационных целях;\n'
                              '• Федеральный закон № 149‑ФЗ «Об информации» — использование общедоступной информации;\n'
                              '• Право на межоперабельность (Directive (EU) 2019/790) — обеспечение взаимодействия программ.\n'
                              '6.2. Взаимодействие с сервисом «MAX» осуществляется исключительно через:\n'
                              '• Публичные API‑интерфейсы, доступные через веб‑версию сервиса;\n'
                              '• Методы обратной разработки, разрешённые ст. 1280.3 ГК РФ для целей совместимости;\n'
                              '• Открытые протоколы взаимодействия, не защищённые техническими средствами охраны.\n'
                              '6.3. Приложение «Komet» не обходит технические средства защиты и не нарушает нормальную работу оригинального сервиса, что соответствует требованиям статьи 1299 ГК РФ.\n\n'
                              '7. Заключительные положения\n'
                              '7.1. Используя Приложение «Komet», вы соглашаетесь с тем, что:\n'
                              '• Единственным правомочным способом использования сервиса «MAX» является применение официальных клиентов;\n'
                              '• Все претензии по работе сервиса должны направляться в ООО «Коммуникационная платформа»;\n'
                              '• Разработчики Приложения не несут ответственности за любые косвенные или прямые убытки.\n'
                              '7.2. Настоящее соглашение может быть изменено без предварительного уведомления пользователей.\n\n'
                              '8. Функции безопасности и конфиденциальности\n'
                              '8.1. Приложение «Komet» включает инструменты защиты приватности:\n'
                              '• Подмена данных сессии — для предотвращения отслеживания пользователя с помощью продвинутых инструментов Open‑Source‑Intelligence (OSINT);\n'
                              '• Система прокси‑подключений — для обеспечения безопасности сетевого взаимодействия;\n'
                              '• Ограничение телеметрии — для минимизации передачи диагностических данных.\n'
                              '8.2. Данные функции:\n'
                              '• Направлены исключительно на защиту конфиденциальности пользователей;\n'
                              '• Не используются для обхода систем безопасности оригинального сервиса;\n'
                              '• Реализованы в рамках статьи 152.1 ГК РФ о защите частной жизни.\n'
                              '8.3. Разработчики не несут ответственности за:\n'
                              '• Блокировки, связанные с использованием инструментов конфиденциальности;\n'
                              '• Изменения в работе сервиса при активации данных функций.\n'
                              '8.4. Функции экспорта и импорта сессии\n'
                              '8.4.1. Приложение «Komet» предоставляет возможность экспорта и импорта данных сессии для:\n'
                              '• Обеспечения переносимости данных между устройствами пользователя\n'
                              '• Резервного копирования учетных данных\n'
                              '• Восстановления доступа при утере устройства\n'
                              '8.4.2. Особенности реализации:\n'
                              '• Экспорт сессии осуществляется без привязки к номеру телефона\n'
                              '• Данные сессии защищаются паролем и шифрованием по алгоритмам AES‑256\n'
                              '• Ключ шифрования известен только пользователю и не сохраняется в приложении\n'
                              '8.4.3. Техническая реализация экспорта сессии:\n'
                              '• Экспорт сессии осуществляется через токен авторизации для идентификации в сервисе\n'
                              '• Используется подмена параметров сессии для сохранения контекста аутентификации\n'
                              '• Интеграция настроек прокси для обеспечения единой конфигурации подключения\n'
                              '• Импортированная сессия маскирует источник подключения через указанные прокси‑настройки\n'
                              '• Серверы оригинального сервиса не получают данных о смене устройства пользователя\n'
                              '• Шифрование применяется ко всему пакету данных (сессия + прокси‑конфиг)\n'
                              '8.4.4. Правовые основания:\n'
                              '• Статья 6 ФЗ‑152 «О персональных данных» — обработка данных с согласия субъекта\n'
                              '• Статья 434 ГК РФ — право на выбор формы сделки (электронная форма хранения учетных данных)\n'
                              '• Принцип минимизации данных — сбор только необходимой для работы информации\n'
                              '• Использование токена не является несанкционированным доступом (ст. 272 УК РФ не нарушается)\n'
                              '• Подмена сессии — легитимный метод сохранения аутентификации (аналог браузерных cookies)\n'
                              '• Маскировка IP‑адреса — законный способ защиты персональных данных (ст. 6 ФЗ‑152)\n'
                              '8.4.5. Ограничения ответственности:\n'
                              '• Пользователь самостоятельно несет ответственность за сохранность пароля и резервных копий\n'
                              '• Разработчики не имеют доступа к зашифрованным данным сессии\n'
                              '• Восстановление утерянных паролей невозможно в целях безопасности\n'
                              '• Ключи шифрования не хранятся в приложении и известны только пользователю',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 48,
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(
                            right: progress == 1.0 ? 56.0 : 0.0,
                          ),
                          child: Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress < 1.0 ? progress : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: progress == 1.0 ? 1.0 : 0.0,
                          curve: Curves.easeIn,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            transform: Matrix4.translationValues(
                              progress == 1.0 ? 0 : 20,
                              0,
                              0,
                            ),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Symbols.check,
                              color: cs.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPhoneConfirmationDialog(String formattedPhone) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final cs = Theme.of(context).colorScheme;
        final curve = Curves.easeOutQuart.transform(anim1.value);
        return Opacity(
          opacity: anim1.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curve)),
            child: Transform.scale(
              scale: 0.8 + (0.2 * curve),
              child: AlertDialog(
                backgroundColor: cs.surfaceContainerHigh,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Это правильный номер?',
                      style: GoogleFonts.inter(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_selectedCountry.phoneCode} $formattedPhone',
                      style: GoogleFonts.inter(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Изменить',
                          style: GoogleFonts.inter(
                            color: cs.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CodeConfirmationScreen(
                                phoneNumber:
                                    '${_selectedCountry.phoneCode} $formattedPhone',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Готово',
                          style: GoogleFonts.inter(
                            color: cs.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _validateAndSubmit() {
    if (!_isTOSRead) {
      _showCustomNotification(context, 'Соглащение прочитай щегол');
      return;
    }
    _showPhoneConfirmationDialog(_phoneController.text);
  }

  void _showOtherLoginMethods(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Symbols.qr_code_2, color: cs.onSurface),
                  title: Text(
                    'По QR code',
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.key, color: cs.onSurface),
                  title: Text(
                    'По токену',
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.description, color: cs.onSurface),
                  title: Text(
                    'По файлу сессии',
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -500) {
            _showTOS(context);
          }
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 44),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: Icon(
                                  Symbols.admin_panel_settings,
                                  color: cs.onSurfaceVariant,
                                  weight: 400,
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: Icon(
                                  Symbols.language,
                                  color: cs.onSurfaceVariant,
                                  weight: 400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 74),
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/komet.png',
                                  height: 80,
                                  color: cs.onSurface,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Войдите в Komet',
                                  style: GoogleFonts.inter(
                                    color: cs.onSurface,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Проверьте код страны и введите свой\nномер телефона.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                          InkWell(
                            onTap: _showCountryPicker,
                            borderRadius: BorderRadius.circular(50),
                            child: _buildInputField(
                              label: 'Страна',
                              content: Row(
                                children: [
                                  Text(
                                    _selectedCountry.ru,
                                    style: GoogleFonts.inter(
                                      color: cs.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildInputField(
                            label: 'Номер телефона',
                            content: Row(
                              children: [
                                Text(
                                  _selectedCountry.phoneCode,
                                  style: GoogleFonts.inter(
                                    color: cs.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: cs.outlineVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      _PhoneInputFormatter(_selectedCountry),
                                    ],
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '(000) 000-00-00',
                                      hintStyle: TextStyle(
                                        color: cs.outline,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      final digits = value.replaceAll(
                                        RegExp(r'\D'),
                                        '',
                                      );
                                      setState(() {
                                        _isPhoneValid =
                                            digits.length ==
                                            _selectedCountry.phoneDigits;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () => _showOtherLoginMethods(context),
                            child: Text(
                              'Другие способы входа',
                              style: GoogleFonts.inter(
                                color: cs.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.inter(
                                        color: cs.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              'Продолжая, вы соглашаетесь с \n',
                                          style: GoogleFonts.inter(
                                            color: cs.onSurface,
                                            fontSize: 14,
                                            height: 1.4,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              'пользовательскими соглашениями',
                                          style: GoogleFonts.inter(
                                            color: cs.primary,
                                            fontSize: 14,
                                            height: 1.4,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => _showTOS(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: FloatingActionButton(
                                  onPressed: _isPhoneValid
                                      ? _validateAndSubmit
                                      : null,
                                  backgroundColor: _isPhoneValid
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerHighest,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: _isPhoneValid
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required String label, required Widget content}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: cs.primary, width: 1.5),
                borderRadius: BorderRadius.circular(50),
              ),
              child: content,
            ),
            Positioned(
              top: -10,
              left: 20,
              child: Container(
                color: cs.surface,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: cs.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  final CountryName country;
  _PhoneInputFormatter(this.country);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (newValue.text.length < oldValue.text.length) {
      final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
      if (text.length == oldDigits.length && text.isNotEmpty) {
        text = text.substring(0, text.length - 1);
      }
    }

    if (text.length > country.phoneDigits) {
      text = text.substring(0, country.phoneDigits);
    }

    final buffer = StringBuffer();
    int digitIdx = 0;

    for (int i = 0; i < country.phoneGroupSizes.length; i++) {
      if (digitIdx >= text.length) break;

      buffer.write(country.phoneGroupSeparators[i]);

      final groupSize = country.phoneGroupSizes[i];
      final remainingDigits = text.length - digitIdx;
      final digitsToTake = remainingDigits < groupSize
          ? remainingDigits
          : groupSize;

      buffer.write(text.substring(digitIdx, digitIdx + digitsToTake));
      digitIdx += digitsToTake;

      if (digitIdx == text.length &&
          i < country.phoneGroupSeparators.length - 1) {}
    }

    if (digitIdx == text.length && text.length == country.phoneDigits) {
      if (country.phoneGroupSeparators.length >
          country.phoneGroupSizes.length) {
        buffer.write(country.phoneGroupSeparators.last);
      }
    }

    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

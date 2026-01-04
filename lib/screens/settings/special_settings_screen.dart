import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:provider/provider.dart';

class SpecialSettingsScreen extends StatefulWidget {
  final bool isModal;

  const SpecialSettingsScreen({super.key, this.isModal = false});

  @override
  State<SpecialSettingsScreen> createState() => _SpecialSettingsScreenState();
}

class _SpecialSettingsScreenState extends State<SpecialSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late bool _showSecondsValue;
  late bool _showDeletedMessagesValue;
  late bool _viewRedactHistoryValue;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _showSecondsValue = themeProvider.showSeconds;
    _showDeletedMessagesValue = themeProvider.showDeletedMessages;
    _viewRedactHistoryValue = themeProvider.viewRedactHistory;

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDesktop = themeProvider.useDesktopLayout;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.isModal || isDesktop) {
      return _buildModalSettings(context);
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(colors.surface, colors.primary, 0.05)!,
              colors.surface,
              Color.lerp(colors.surface, colors.tertiary, 0.05)!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ),
                    if (Navigator.canPop(context)) const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Особые настройки',
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.headlineSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Что то интересненькое...',
                            style: GoogleFonts.manrope(
                              textStyle: textTheme.bodyMedium,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildSettingsContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalSettings(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    final isSmallScreen = screenWidth < 600 || screenHeight < 800;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),

            Center(
              child: isSmallScreen
                  ? Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(color: colors.surface),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: colors.surface),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Закрыть',
                                ),
                                Expanded(
                                  child: Text(
                                    'Особые настройки',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(child: _buildSettingsContent()),
                        ],
                      ),
                    )
                  : Container(
                      width: 400,
                      height: 900,
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Особые настройки',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Закрыть',
                                ),
                              ],
                            ),
                          ),

                          Expanded(child: _buildSettingsContent()),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.access_time,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show full time',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.titleMedium,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Показывать время сообщений с секундами',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.bodySmall,
                            color: colors.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _showSecondsValue,
                    onChanged: (bool value) {
                      setState(() {
                        _showSecondsValue = value;
                      });
                      themeProvider.setShowSeconds(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show deleted messages',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.titleMedium,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Показывать удаленные сообщения с иконкой мусорки',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.bodySmall,
                            color: colors.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _showDeletedMessagesValue,
                    onChanged: (bool value) {
                      setState(() {
                        _showDeletedMessagesValue = value;
                      });
                      themeProvider.setShowDeletedMessages(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View redact history',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.titleMedium,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Показывать историю редактирования сообщений с иконкой карандашика',
                          style: GoogleFonts.manrope(
                            textStyle: textTheme.bodySmall,
                            color: colors.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _viewRedactHistoryValue,
                    onChanged: (bool value) {
                      setState(() {
                        _viewRedactHistoryValue = value;
                      });
                      themeProvider.setViewRedactHistory(value);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

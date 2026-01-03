import 'package:flutter/material.dart';
import 'package:gwid/screens/tos_screen.dart';
import 'package:gwid/consts.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  final bool isModal;

  const AboutScreen({super.key, this.isModal = false});

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      print('Could not launch $url');
    }
  }

  Widget _buildTeamMember(
    BuildContext context, {
    required String name,
    required String role,
    required String description,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: textTheme.bodyMedium?.copyWith(height: 1.5),
              children: [
                TextSpan(
                  text: '• $name',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' — $role'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 2.0),
            child: Text(
              description,
              style: textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isModal) {
      return buildModalContent(context);
    }

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("О приложении")),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text(
            "Команда «Komet»",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "Мы — команда энтузиастов, создавшая Komet. Нас объединила страсть к технологиям и желание дать пользователям свободу выбора.",
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),

          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text("Пользовательское соглашение"),
              subtitle: const Text("Правовая информация и условия"),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TosScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            "Мы верим в открытость, прозрачность и право пользователей на выбор. Komet — это наш ответ излишним ограничениям.",
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _launchUrl(AppUrls.telegramChannel),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                  children: [
                    const TextSpan(text: "Связаться с нами: \n"),
                    TextSpan(
                      text: "Телеграм-канал: https://t.me/TeamKomet",
                      style: TextStyle(
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModalContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Column(
            children: [
              Image.asset('assets/icon/komet.png', width: 128, height: 128),
              const SizedBox(height: 16),
              Text(
                'Komet',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Версия $appVersion',
                style: TextStyle(
                  fontSize: 16,
                  color: colors.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Команда разработки',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Мы — команда энтузиастов, создавшая Komet. Нас объединила страсть к технологиям и желание дать пользователям свободу выбора.',
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Наша команда:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTeamMember(
                  context,
                  name: "Floppy",
                  role: "руководитель проекта",
                  description: "Стратегическое видение и общее руководство",
                ),
                _buildTeamMember(
                  context,
                  name: "Klocky",
                  role: "главный программист",
                  description: "Архитектура и ключевые технические решения",
                ),
                _buildTeamMember(
                  context,
                  name: "Noxzion",
                  role: "программист",
                  description: "Участие в разработке приложения и сайта",
                ),
                _buildTeamMember(
                  context,
                  name: "Jganenok",
                  role: "программист",
                  description:
                      "Участие в разработке и пользовательские интерфейсы",
                ),
                _buildTeamMember(
                  context,
                  name: "Zennix",
                  role: "программист",
                  description: "Участие в разработке и технические решения",
                ),
                _buildTeamMember(
                  context,
                  name: "Qmark",
                  role: "программист",
                  description: "Участие в разработке и технические решения",
                ),
                _buildTeamMember(
                  context,
                  name: "Ink",
                  role: "документация сервера",
                  description: "Техническая документация и API",
                ),
                _buildTeamMember(
                  context,
                  name: "Килобайт",
                  role: "веб-разработчик и дизайнер",
                  description: "Веб-платформа и дизайн-система",
                ),
                _buildTeamMember(
                  context,
                  name: "WhiteMax",
                  role: "PR-менеджер",
                  description:
                      "Коммуникация с сообществом и продвижение проекта",
                ),
                _buildTeamMember(
                  context,
                  name: "Raspberry",
                  role: "PR-менеджер",
                  description:
                      "Коммуникация с сообществом и продвижение проекта",
                ),
                const SizedBox(height: 16),
                Text(
                  'Мы верим в открытость, прозрачность и право пользователей на выбор. Komet — это наш ответ излишним ограничениям.',
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _launchUrl(AppUrls.telegramChannel),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.8),
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: "Связаться с нами: \n"),
                          TextSpan(
                            text: "Телеграм-канал: https://t.me/TeamKomet",
                            style: TextStyle(
                              color: colors.primary,
                              decoration: TextDecoration.underline,
                              decorationColor: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Полезные ссылки',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Пользовательское соглашение'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TosScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

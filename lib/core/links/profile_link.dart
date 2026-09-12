import '../cache/info_cache.dart';
import '../storage/app_database.dart';

const String _host = 'https://max.ru';

// #***! ссылка на профиль из имени или готового адреса
String? profileLinkOf(String? rawLink) {
  final link = rawLink?.trim();
  if (link == null || link.isEmpty) return null;
  if (!link.contains('://')) {
    final name = link.startsWith('@') ? link.substring(1) : link;
    return name.isEmpty ? null : '$_host/$name';
  }
  final path = Uri.tryParse(link)?.path.replaceAll('/', '') ?? '';
  return path.isEmpty ? null : link;
}

// #***! своя ссылка, сначала конфиг потом кэш потом сервер
Future<String?> ownProfileLink() async {
  final profile = await AppDatabase.loadActiveProfile();
  final id = profile?.id ?? 0;
  if (id == 0) return null;

  final invite = profileLinkOf(
    await AppDatabase.getSyncValue(id, SyncKey.profileInviteLink),
  );
  if (invite != null) return invite;

  final cached = await ContactInfoFetch.get(id);
  final short = profileLinkOf(cached?.raw['link'] as String?);
  if (short != null) return short;

  final fresh = await ContactInfoFetch.get(id, forceRefresh: true);
  return profileLinkOf(fresh?.raw['link'] as String?);
}

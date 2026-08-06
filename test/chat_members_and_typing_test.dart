import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komet/core/storage/chat_activity_store.dart';
import 'package:komet/core/storage/chat_members_store.dart';
import 'package:komet/frontend/screens/chats/chat/typing_label.dart';

const int _chatId = 900001;
const int _alice = 900101;
const int _bob = 900102;
const int _carol = 900103;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() {
    ChatMembersStore.instance.clear();
    ChatActivityStore.instance.clearChat(_chatId);
    ContactCache.clear();
  });

  group('ChatMembersStore', () {
    test('счётчик читается из одного места и уведомляет слушателей', () {
      final seen = <int?>[];
      final listenable = ChatMembersStore.instance.listenable(_chatId);
      listenable.addListener(() => seen.add(listenable.value));

      ChatMembersStore.instance.setCount(_chatId, 5);
      ChatMembersStore.instance.setCount(_chatId, 5);
      ChatMembersStore.instance.adjust(_chatId, 2);

      expect(ChatMembersStore.instance.count(_chatId), 7);
      expect(seen, [5, 7]);
    });

    test('adjust не опускает счётчик ниже нуля', () {
      ChatMembersStore.instance.setCount(_chatId, 1);
      ChatMembersStore.instance.adjust(_chatId, -5);
      expect(ChatMembersStore.instance.count(_chatId), 0);
    });

    test('adjust без известного значения ничего не выдумывает', () {
      ChatMembersStore.instance.adjust(_chatId, 3);
      expect(ChatMembersStore.instance.count(_chatId), isNull);
    });

    test('payload чата с сервера заполняет счётчик', () {
      ChatMembersStore.instance.applyChatPayload({
        'id': _chatId,
        'participantsCount': 12,
      });
      expect(ChatMembersStore.instance.count(_chatId), 12);
    });
  });

  group('Подпись «печатает»', () {
    ChatActivitySnapshot snapshot(List<int> ids) {
      for (final id in ids) {
        ChatActivityStore.instance.mark(_chatId, id, ChatActivity.typing);
      }
      return ChatActivityStore.instance.snapshot(_chatId)!;
    }

    test('в диалоге остаётся безымянная подпись', () {
      ContactCache.put(_alice, 'Алиса Тестова');
      expect(chatActivityLabel(snapshot([_alice])), 'Печатает...');
    });

    test('в группе показывает имя печатающего', () {
      ContactCache.put(_alice, 'Алиса Тестова');
      expect(
        chatActivityLabel(snapshot([_alice]), withNames: true),
        'Алиса печатает...',
      );
    });

    test('двое печатающих перечисляются', () {
      ContactCache.put(_alice, 'Алиса Тестова');
      ContactCache.put(_bob, 'Борис');
      expect(
        chatActivityLabel(snapshot([_alice, _bob]), withNames: true),
        'Алиса и Борис печатают...',
      );
    });

    test('трое и больше сворачиваются в «и ещё N»', () {
      ContactCache.put(_alice, 'Алиса Тестова');
      ContactCache.put(_bob, 'Борис');
      ContactCache.put(_carol, 'Вера');
      expect(
        chatActivityLabel(snapshot([_alice, _bob, _carol]), withNames: true),
        'Алиса и ещё 2 печатают...',
      );
    });

    test('без известного имени откатывается к общей подписи', () {
      expect(
        chatActivityLabel(snapshot([_alice]), withNames: true),
        'Печатает...',
      );
    });

    test('стикеры получают свой глагол', () {
      ContactCache.put(_alice, 'Алиса Тестова');
      ChatActivityStore.instance.mark(_chatId, _alice, ChatActivity.sticker);
      final snap = ChatActivityStore.instance.snapshot(_chatId)!;
      expect(
        chatActivityLabel(snap, withNames: true),
        'Алиса выбирает стикер...',
      );
    });

    test('снимок отдаёт только пользователей ведущей активности', () {
      ChatActivityStore.instance.mark(_chatId, _alice, ChatActivity.sticker);
      ChatActivityStore.instance.mark(_chatId, _bob, ChatActivity.typing);
      final snap = ChatActivityStore.instance.snapshot(_chatId)!;
      expect(snap.activity, ChatActivity.typing);
      expect(snap.userIds, [_bob]);
    });
  });
}

// #***! каналы и боты шифрование не поддерживают: у канала много читателей
// #***! без общего ключа, а бот не ответит на предложение E2EE
bool chatAllowsEncryption({required String chatType, bool peerIsBot = false}) {
  if (chatType == 'CHANNEL') return false;
  if (chatType == 'DIALOG' && peerIsBot) return false;
  return true;
}

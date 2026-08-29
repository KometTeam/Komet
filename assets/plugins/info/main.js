import { chat, contact, runtime, ui } from 'komet:api';

function date(value) {
  if (!Number.isInteger(value) || value <= 0) return '—';
  return new Date(value).toLocaleString();
}

export async function info() {
  if (!(await runtime.isOnline())) {
    await ui.notify('Нет соединения');
    return;
  }
  const id = await chat.sendText('сбор данных...');
  const peer = await contact.getPeer();
  if (!peer) {
    await chat.editText(id, 'Команда доступна только в диалоге');
    return;
  }
  const summary = [
    `Никнейм: ${peer.displayName || '—'}`,
    `Дата регистрации: ${date(peer.registrationTime)}`,
    `Дата последнего изменения профиля: ${date(peer.updateTime)}`,
    `id: ${peer.id}`,
    `Регион: ${peer.country || '—'}`,
    `Флаги: ${peer.options.length ? peer.options.join(', ') : '—'}`,
    'ip: not fetched'
  ].join('\n');
  await chat.editText(id, summary);
}
import { chat, network, ui } from 'komet:api';

export async function fox() {
  const response = await network.fetch('https://randomfox.ca/floof/', {
    headers: { Accept: 'application/json' }
  });
  if (response.status !== 200) {
    await ui.notify(`RandomFox вернул HTTP ${response.status}`);
    return;
  }

  let data;
  try {
    data = JSON.parse(response.body);
  } catch (_) {
    await ui.notify('RandomFox вернул некорректный ответ');
    return;
  }

  if (typeof data.image !== 'string' || !data.image.startsWith('https://')) {
    await ui.notify('RandomFox не вернул ссылку на изображение');
    return;
  }

  const filename = data.image.split('/').pop() || 'random_fox.jpg';
  const source = typeof data.link === 'string' ? data.link : 'https://randomfox.ca/';
  await chat.sendPhoto({
    url: data.image,
    filename,
    caption: `Случайная лисица 🦊\n${source}`
  });
}
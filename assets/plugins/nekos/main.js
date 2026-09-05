import { chat, network, ui } from 'komet:api';

export async function nekogirl() {
  const response = await network.fetch('https://api.nekosapi.com/v4/images/random?rating=safe', {
    headers: { Accept: 'application/json' }
  });
  if (response.status !== 200) {
    await ui.notify(`Nekogirl вернул HTTP ${response.status}`);
    return;
  }

  let data;
  try {
    data = JSON.parse(response.body);
  } catch (_) {
    await ui.notify('Nekogirl вернул некорректный ответ');
    return;
  }

  if (typeof data[0].url !== 'string' || !data[0].url.startsWith('https://')) {
    await ui.notify('Nekogirl не вернул ссылку на изображение');
    return;
  }

  const filename = data[0].url.split('/').pop() || 'nekogirl.jpg';

  const source = data[0].url;
  await chat.sendPhoto({
    url: data[0].url,
    filename,
    caption: `Случайная кошкодевочкa`
  });
}
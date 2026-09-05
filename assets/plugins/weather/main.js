import { chat, network, ui } from 'komet:api';

function value(source, key, fallback = '—') {
  const result = source?.[key];
  return result === undefined || result === null || result === '' ? fallback : String(result);
}

function description(source) {
  return source?.weatherDesc?.[0]?.value || '—';
}

function dayLabel(date, index) {
  if (index === 0) return 'Сегодня';
  if (index === 1) return 'Завтра';
  return date || `День ${index + 1}`;
}

export async function weather(context) {
  const city = context.arguments.city.trim();
  const url = `https://wttr.in/${encodeURIComponent(city)}?format=j1&lang=ru`;
  const response = await network.fetch(url, {
    headers: { Accept: 'application/json' }
  });
  if (response.status !== 200) {
    await ui.notify(`wttr.in вернул HTTP ${response.status}`);
    return;
  }

  let data;
  try {
    data = JSON.parse(response.body);
  } catch (_) {
    await ui.notify('wttr.in вернул некорректный ответ');
    return;
  }

  const current = data.current_condition?.[0];
  const area = data.nearest_area?.[0];
  if (!current) {
    await ui.notify('Погода для этого города не найдена');
    return;
  }

  const place = area?.areaName?.[0]?.value || city;
  const country = area?.country?.[0]?.value;
  const lines = [
    `Погода: ${place}${country ? `, ${country}` : ''}`,
    `${description(current)}, ${value(current, 'temp_C')} °C`,
    `Ощущается как ${value(current, 'FeelsLikeC')} °C`,
    `Влажность ${value(current, 'humidity')}% · ветер ${value(current, 'windspeedKmph')} км/ч`,
    '',
    'Прогноз:'
  ];

  for (const [index, day] of (data.weather || []).slice(0, 3).entries()) {
    const noon = day.hourly?.find(item => item.time === '1200') || day.hourly?.[4] || day.hourly?.[0];
    lines.push(
      `${dayLabel(day.date, index)}: ${description(noon)}, ${value(day, 'mintempC')}…${value(day, 'maxtempC')} °C`
    );
  }

  await chat.sendText(lines.join('\n'));
}
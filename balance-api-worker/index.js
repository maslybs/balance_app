export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // CORS headers для всіх відповідей
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Обробка OPTIONS запитів (CORS preflight)
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 200,
        headers: corsHeaders,
      });
    }

    // Роутинг
    if (url.pathname === '/api/balances' && request.method === 'POST') {
      return handleUpdateBalances(request, env, corsHeaders);
    }

    if (url.pathname === '/api/balances' && request.method === 'GET') {
      return handleGetBalances(request, env, corsHeaders);
    }

    if (url.pathname === '/api/telegram' && request.method === 'POST') {
      return handleTelegramWebhook(request, env);
    }

    if (url.pathname === '/api/health' && request.method === 'GET') {
      return handleHealth(corsHeaders);
    }

    return new Response('Not Found', {
      status: 404,
      headers: corsHeaders,
    });
  },
};

// Функція перевірки токена
function validateToken(request, env) {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return false;
  }

  const token = authHeader.slice(7); // Видаляємо "Bearer "
  return token === env.API_TOKEN;
}

// Returns ISO string adjusted to UTC+3 (Kyiv summer time baseline)
function getUtcPlus3Timestamp() {
  const utcPlus3 = new Date(Date.now() + 3 * 60 * 60 * 1000);
  return utcPlus3.toISOString().replace('Z', '+03:00');
}

// Обробка оновлення балансів
async function handleUpdateBalances(request, env, corsHeaders) {
  // Перевірка токена
  if (!validateToken(request, env)) {
    return new Response(JSON.stringify({
      success: false,
      error: 'Unauthorized'
    }), {
      status: 401,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });
  }

  try {
    const data = await request.json();

    // Валідація вхідних даних
    if (!data.accounts || !Array.isArray(data.accounts)) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Invalid data format. Expected {accounts: [...]}'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });
    }

    const serverTimestamp = getUtcPlus3Timestamp();
    const enrichedData = {
      ...data,
      timestamp: serverTimestamp,
      accounts: data.accounts.map(acc => ({
        ...acc,
        timestamp: serverTimestamp,
      })),
    };

    // Зберігання даних в KV (якщо налаштовано)
    try {
      if (env && env.BALANCES) {
        const result = await env.BALANCES.put('latest', JSON.stringify(enrichedData));
        console.log('Data saved to KV:', result);
      }
    } catch (kvError) {
      console.warn('Failed to save to KV:', kvError);
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Balances updated successfully',
      processedAccounts: enrichedData.accounts.length,
      timestamp: serverTimestamp
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });

  } catch (error) {
    console.error('Error processing balances:', error);

    return new Response(JSON.stringify({
      success: false,
      error: 'Failed to process request',
      details: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });
  }
}

// Обробка отримання балансів
async function handleGetBalances(request, env, corsHeaders) {
  // Перевірка токена
  if (!validateToken(request, env)) {
    return new Response(JSON.stringify({
      success: false,
      error: 'Unauthorized'
    }), {
      status: 401,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });
  }

  try {
    let data = null;

    // Отримання даних з KV (якщо налаштовано)
    try {
      if (env && env.BALANCES) {
        data = await env.BALANCES.get('latest');
      }
    } catch (kvError) {
      console.warn('Failed to get from KV:', kvError);
    }

    const parsedData = data ? JSON.parse(data) : null;

    // Перевірка формату відповіді
    const url = new URL(request.url);
    const format = url.searchParams.get('format');

    if (format === 'text') {
      // Форматування для Telegram
      const textResponse = formatBalancesForTelegram(parsedData);
      return new Response(textResponse, {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/plain; charset=utf-8',
        },
      });
    }

    // Стандартна JSON відповідь
    return new Response(JSON.stringify({
      success: true,
      message: 'Balance data retrieved successfully',
      timestamp: getUtcPlus3Timestamp(),
      data: parsedData
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });

  } catch (error) {
    console.error('Error retrieving balances:', error);

    return new Response(JSON.stringify({
      success: false,
      error: 'Failed to retrieve balances',
      details: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });
  }
}

// Форматування балансів для Telegram
function formatBalancesForTelegram(data) {
  if (!data || !data.accounts || data.accounts.length === 0) {
    return '📊 Баланси\n\nНемає даних про баланси.';
  }

  const accounts = data.accounts;
  
  // Групуємо по провайдерам
  const byProvider = {};
  accounts.forEach(acc => {
    const provider = acc.provider || 'Інше';
    if (!byProvider[provider]) {
      byProvider[provider] = [];
    }
    byProvider[provider].push(acc);
  });

  // Рахуємо загальні суми по валютах
  const totals = {};
  accounts.forEach(acc => {
    const currency = acc.currency || 'UAH';
    totals[currency] = (totals[currency] || 0) + (acc.balance || 0);
  });

  // Формуємо текст
  let text = '💰 Баланси рахунків\n\n';

  // Додаємо рахунки по провайдерам
  const providerEmojis = {
    'PrivatBank (ФОП)': '🏦',
    'Wise': '🌍',
    'Інші рахунки': '📝'
  };

  Object.keys(byProvider).sort().forEach(provider => {
    const emoji = providerEmojis[provider] || '💳';
    text += `${emoji} ${provider}\n`;
    
    byProvider[provider].forEach(acc => {
      const balance = (acc.balance || 0).toFixed(2);
      const currency = acc.currency || 'UAH';
      const title = acc.title || 'Без назви';
      text += `  • ${title}: ${balance} ${currency}\n`;
    });
    
    text += '\n';
  });

  // Додаємо загальні суми
  text += '📈 Загальна сума\n';
  Object.keys(totals).sort().forEach(currency => {
    const total = totals[currency].toFixed(2);
    text += `  ${currency}: ${total}\n`;
  });

  // Додаємо час оновлення
  if (accounts[0] && accounts[0].timestamp) {
    const updateTime = new Date(accounts[0].timestamp);
    const formattedTime = updateTime.toLocaleString('uk-UA', {
      timeZone: 'Europe/Kyiv',
    });
    text += `\n🕐 Оновлено: ${formattedTime}`;
  }

  return text;
}

// Обробка Telegram webhook
async function handleTelegramWebhook(request, env) {
  const secretToken = request.headers.get('x-telegram-bot-api-secret-token');

  // Validate Telegram secret token against Wrangler API token
  if (!secretToken || secretToken !== env.API_TOKEN) {
    console.warn('Telegram webhook rejected: invalid or missing secret token');
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    const update = await request.json();
    
    // Перевіряємо чи є повідомлення
    if (!update.message || !update.message.text) {
      return new Response('OK', { status: 200 });
    }

    const chatId = update.message.chat.id;
    const botToken = env.TELEGRAM_BOT_TOKEN;

    if (!botToken) {
      console.error('TELEGRAM_BOT_TOKEN not configured');
      return new Response('OK', { status: 200 });
    }

    // Отримуємо баланси
    let data = null;
    try {
      if (env && env.BALANCES) {
        data = await env.BALANCES.get('latest');
      }
    } catch (kvError) {
      console.warn('Failed to get from KV:', kvError);
    }
    
    const parsedData = data ? JSON.parse(data) : null;
    const responseText = formatBalancesForTelegram(parsedData);

    // Відправляємо відповідь через Telegram Bot API
    await sendTelegramMessage(botToken, chatId, responseText);

    return new Response('OK', { status: 200 });

  } catch (error) {
    console.error('Error handling Telegram webhook:', error);
    return new Response('OK', { status: 200 });
  }
}

// Відправка повідомлення через Telegram Bot API
async function sendTelegramMessage(botToken, chatId, text) {
  const url = `https://api.telegram.org/bot${botToken}/sendMessage`;
  
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        chat_id: chatId,
        text: text,
        parse_mode: 'HTML',
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('Telegram API error:', error);
    }
  } catch (error) {
    console.error('Failed to send Telegram message:', error);
  }
}

// Health check endpoint
async function handleHealth(corsHeaders) {
  return new Response(JSON.stringify({
    success: true,
    message: 'Balance API is running',
    timestamp: getUtcPlus3Timestamp(),
    version: '1.0.0'
  }), {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

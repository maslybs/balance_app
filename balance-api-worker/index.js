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

    // Логування отриманих даних
    console.log('Received balances update:', {
      timestamp: new Date().toISOString(),
      accountsCount: data.accounts.length,
      totalBalance: data.accounts.reduce((sum, acc) => sum + (parseFloat(acc.balance) || 0), 0),
    });

    // Зберігання даних в KV (якщо налаштовано)
    try {
      if (env && env.BALANCES) {
        const result = await env.BALANCES.put('latest', JSON.stringify(data));
        console.log('Data saved to KV:', result);
      }
    } catch (kvError) {
      console.warn('Failed to save to KV:', kvError);
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Balances updated successfully',
      processedAccounts: data.accounts.length,
      timestamp: new Date().toISOString()
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
      timestamp: new Date().toISOString(),
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
    'Власні рахунки': '📝'
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
    text += `\n🕐 Оновлено: ${updateTime.toLocaleString('uk-UA')}`;
  }

  return text;
}

// Health check endpoint
async function handleHealth(corsHeaders) {
  return new Response(JSON.stringify({
    success: true,
    message: 'Balance API is running',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  }), {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

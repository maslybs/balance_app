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

    return new Response(JSON.stringify({
      success: true,
      message: 'Balance data retrieved successfully',
      timestamp: new Date().toISOString(),
      data: data ? JSON.parse(data) : null
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

# Balance API Worker

Cloudflare Worker API для прийому та зберігання балансів.

## Ендпоінти

### POST /api/balances
Приймає оновлення балансів.

**Request body:**
```json
{
  "accounts": [
    {
      "id": "account1",
      "balance": 100.50,
      "currency": "UAH",
      "name": "Назва рахунку",
      "type": "card",
      "timestamp": "2025-01-01T12:00:00Z"
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Balances updated successfully",
  "processedAccounts": 1,
  "timestamp": "2025-01-01T12:00:00Z"
}
```

### GET /api/balances
Отримує останні збережені баланси.

**Response:**
```json
{
  "success": true,
  "message": "Balance data retrieved successfully",
  "timestamp": "2025-01-01T12:00:00Z"
}
```

### GET /api/health
Перевіряє статус API.

**Response:**
```json
{
  "success": true,
  "message": "Balance API is running",
  "timestamp": "2025-01-01T12:00:00Z",
  "version": "1.0.0"
}
```

## Розгортання

1. Встановіть Wrangler:
```bash
npm install -g wrangler
```

2. Увійдіть в Cloudflare:
```bash
wrangler login
```

3. Розгорніть worker:
```bash
npm run deploy
```

## Налаштування

- Редагуйте `wrangler.toml` для налаштування KV namespace та environment variables
- API підтримує CORS для запитів з будь-якого джерела
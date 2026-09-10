# Fitnessgirl Meet

Каталог публичных VK-профилей (Москва): Nuxt 3 + PostgreSQL + Prisma + Docker.
Оплата подписки — перевод на карту/СБП с ручным подтверждением (админ / Telegram).

## Production

- **Бесплатно (Render Free):** см. [DEPLOY_RENDER.md](./DEPLOY_RENDER.md) — Docker + Postgres + `fitnessgirl-meet.ru`
- **VPS / Docker Compose** (стабильнее для прода):

```bash
cp .env.example .env
# Обязательно задайте реальные значения (см. чеклист ниже)
nano .env

docker compose up -d --build
# HTTPS: SITE_HOST=your-domain.com caddy run --config ./Caddyfile

# Зарегистрировать Telegram webhook (только HTTPS, не poll)
npm run telegram:webhook

# Ежедневный индекс (~100 анкет) — опционально
docker compose --profile cron up -d indexer-daily
```

Сайт: порт `3000` за reverse proxy. Postgres **не** публикуется наружу (только сеть compose).

### Чеклист `.env` перед продом

| Переменная | Требование |
|---|---|
| `POSTGRES_PASSWORD` | ≥12 символов, не `change-me` / дефолт |
| `NUXT_SESSION_PASSWORD` | ≥32 символов, уникальный секрет |
| `NUXT_PUBLIC_SITE_URL` | `https://your-domain.com` (не localhost) |
| `PAYMENT_CARD` и/или `PAYMENT_PHONE` | реквизиты на `/subscribe` |
| `ADMIN_EMAIL` | email админа (роль при регистрации/логине) |
| `TELEGRAM_BOT_TOKEN` + `TELEGRAM_ADMIN_CHAT_ID` | если нужен approve в TG |
| `TELEGRAM_WEBHOOK_SECRET` | ≥16 символов (обязателен при включённом TG) |
| `VK_ACCESS_TOKEN` | для индексации |

Приложение **не стартует** в `NODE_ENV=production`, если секреты слабые или URL не HTTPS (`server/plugins/prod-guard.ts`).

После деплоя:

1. `curl -s https://your-domain.com/api/health` → `{"ok":true,...}`
2. Регистрация → `/subscribe` → заявка → approve в Telegram или `/admin`
3. Каталог с активной подпиской; `/opt-out` скрывает профиль
4. `/robots.txt`, `/sitemap.xml` → Search Console / Вебмастер

Кратко после миграции старых паролей: `ALLOW_LEGACY_LOGIN=1` на один рестарт, затем убрать.

## Docker образы

- `runner` — приложение без ML (лёгкий)
- `tools` — индексатор + face-api (`--profile tools` / `cron`)

```bash
# разовый daily index
docker compose --profile tools run --rm indexer

# демо-анкеты без VK
docker compose --profile tools run --rm indexer npx tsx scripts/index-vk.ts --demo
```

## Локальная разработка

```bash
cp .env.example .env
# для локали можно оставить слабые секреты — prod-guard не активен

docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d db
# Postgres на хосте: localhost:5433

npm install --legacy-peer-deps
npx prisma migrate deploy
npm run index:demo
npm run dev
```

Telegram **локально** (без публичного HTTPS):

```bash
npm run telegram:poll
```

На проде — только `npm run telegram:webhook`, не poll.

## Полезные команды

```bash
npm run index:daily          # +~100 анкет
npm run check:catalog        # перескан лиц в каталоге
npm run dedupe:photos        # дедуп по dHash
npm run docker:prod          # compose up -d --build
```

## Opt-out

`/opt-out`: VK id или ссылка `vk.com/id…` / `vk.ru/id…` сразу скрывает профиль.

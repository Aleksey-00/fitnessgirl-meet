# Deploy on Render Free (fitnessgirl-meet.ru)

Бесплатный путь без VPS: Docker web + Render Postgres + свой домен + HTTPS.

## Ограничения Free (важно)

- Сайт **засыпает ~через 15 мин** без трафика; первый запрос / Telegram-кнопка могут «тупить» 30–60 сек
- **Free Postgres живёт 30 дней**, потом нужна оплата или потеря данных
- Индексатор / face-api на Free web **не крутим** — каталог заливайте с ноутбука

Если это ок для старта — идём дальше.

## 1. GitHub

Залейте репозиторий на GitHub (приватный тоже можно).

В корне уже есть:

- `Dockerfile` (стадия `runner` по умолчанию)
- `render.yaml` (Blueprint)

## 2. Render Blueprint

1. https://dashboard.render.com → **New** → **Blueprint**
2. Подключите репозиторий
3. Render подхватит `render.yaml`
4. При создании заполните `sync: false` переменные:
   - `ADMIN_EMAIL`
   - `PAYMENT_CARD` / `PAYMENT_PHONE` / `PAYMENT_HOLDER`
   - `TELEGRAM_BOT_TOKEN`
   - `TELEGRAM_ADMIN_CHAT_ID`
   - `VK_ACCESS_TOKEN` (можно пустым на первый деплой)
5. `NUXT_SESSION_PASSWORD` и `TELEGRAM_WEBHOOK_SECRET` Render сгенерирует сам
6. Deploy

Дождитесь зелёного статуса. Временный URL вида `https://fitnessgirl-meet.onrender.com` должен открываться.

Проверка:

```bash
curl -s https://fitnessgirl-meet.onrender.com/api/health
```

## 3. Домен fitnessgirl-meet.ru

В сервисе **fitnessgirl-meet** → **Settings** → **Custom Domains**:

- добавьте `fitnessgirl-meet.ru`
- добавьте `www.fitnessgirl-meet.ru` (уже в `render.yaml`)

У регистратора DNS (или Cloudflare **только как DNS**, без прокси оранжевым облаком на время выдачи сертификата):

| Тип | Имя | Значение |
|---|---|---|
| A / CNAME | `@` | как покажет Render (часто CNAME на `*.onrender.com`) |
| CNAME | `www` | как покажет Render |

Render сам выдаст HTTPS.

Потом в Environment проверьте:

```env
NUXT_PUBLIC_SITE_URL=https://fitnessgirl-meet.ru
```

## 4. Telegram webhook

Когда домен зелёный, с ноутбука (из клона репо):

```bash
# Подставьте значения из Render → Environment
export TELEGRAM_BOT_TOKEN=...
export TELEGRAM_WEBHOOK_SECRET=...   # тот же, что в Render
export NUXT_PUBLIC_SITE_URL=https://fitnessgirl-meet.ru

npm run telegram:webhook
```

На Render **не** запускайте `telegram:poll`.

## 5. Залить каталог (с ноутбука)

1. В Render Postgres → **External Database URL**
2. Локально:

```bash
export DATABASE_URL='postgresql://...external...sslmode=require'
npx prisma migrate deploy   # обычно уже сделал entrypoint на деплое
npm run index:demo          # быстрый тест
# или:
npm run index:daily         # реальный VK (нужен VK_ACCESS_TOKEN)
```

## 6. Smoke-тест

1. https://fitnessgirl-meet.ru  
2. Регистрация с `ADMIN_EMAIL`  
3. `/subscribe` → заявка → ✅ в Telegram  
4. Страница сама покажет «К анкетам»  
5. `/api/health` → `"ok":true`

## Если кнопка в Telegram «молчит»

Часто сервис спит. Откройте сайт в браузере, подождите ~1 минуту, нажмите ✅ ещё раз.

Чтобы реже спал — нужен платный instance или внешний uptime-ping раз в 10–14 минут (это уже не «чистый free»).

## Что не класть в Free web

- daily-indexer loop  
- face-api / tensorflow  
- `telegram:poll`

Их оставляем локально или переносим на VPS позже.

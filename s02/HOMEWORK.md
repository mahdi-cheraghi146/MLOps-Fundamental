# تکلیف جلسه‌ی ۲

مهلت: پیش از شروع جلسه‌ی ۳. همه‌ی کارها روی یک شاخه‌ی تازه و با یک Pull Request وارد `main` شوند.

```bash
cd ~/work/churn-mlops && git switch main && git pull && git switch -c feature/homework-2
```

## ۱. یک آزمون دیگر بنویسید

یک آزمون پنجم به `tests/test_data.py` اضافه کنید. یکی از این دو را انتخاب کنید:

- **نرخ ریزش در بازه‌ی مجاز:** میانگین ستون `churn` در داده‌ی ساخته‌شده عددی بین ۰ و ۱ است و هیچ‌کدام از دو مقدار ۰ و ۱ غایب نیست.
- **مقادیر مجاز یک ستون:** ستون `tenure_months` هیچ مقدار منفی ندارد.

```bash
uv run pytest -q
```

انتظار: `5 passed`.

یادآوری: آزمونی مثل «ROC-AUC بالاتر از ۰٫۸۵ باشد» ننویسید. آن ارزیابی مدل است، نه آزمون واحد.

## ۲. هدف‌های `lint` و `test` را به Makefile اضافه کنید

این دو هدف را به `Makefile` اضافه کنید و نامشان را به خط `.PHONY` هم بیفزایید. خط‌های دستور باید با **TAB** شروع شوند، نه فاصله:

```makefile
lint:
	uv run ruff check .
	uv run ruff format --check .

test:
	uv run pytest -q
```

```bash
make lint && make test
```

اگر خطای `missing separator` گرفتید، خط دستور با فاصله شروع شده است.

## ۳. بخش Contributing را به README اضافه کنید

در `README.md` پروژه بخشی به نام `Contributing` بنویسید که قراردادهای تیم را بگوید، در چهار تا شش خط:

- نام‌گذاری شاخه‌ها (`feature/...`، `fix/...`، `docs/...`)
- قالب پیام commit (Conventional Commits، با یک مثال)
- چک‌لیست Pull Request (آزمون‌ها سبز، متریک قبل و بعد در توضیح، بدون داده و مدل و رمز)
- دستورهایی که پیش از push باید اجرا شوند (`make lint` و `make test`)

## ۴. Pull Request و ارسال

```bash
git add . && git commit -m "test: add data test, lint/test targets and contributing guide"
```

```bash
git push -u origin feature/homework-2
```

در Gitea Pull Request بسازید و Merge کنید، بعد:

```bash
git switch main && git pull
```

## برای مدرس بفرستید

1. خروجی این دستور:

```bash
~/mlops-lab/scripts/verify.sh s02
```

2. خروجی `git log --oneline | head -8`
3. یک جمله: کدام hook بیشتر جلوی commit شما را گرفت و چرا؟

## برای جلسه‌ی ۳

Docker و Gitea را روشن نگه دارید؛ جلسه‌ی ۳ با Docker شروع می‌شود و توضیح می‌دهد پشت دستور `docker compose up -d gitea` چه اتفاقی می‌افتاد.

# آزمایشگاه جلسه‌ی ۲ — Git برای ML و کیفیت کد

این پوشه فایل‌های آماده‌ی آزمایشگاه جلسه‌ی ۲ را دارد. گام‌های کامل آزمایشگاه در اسلایدهای جلسه‌ی ۲ است که مدرس در اختیارتان می‌گذارد.

پیش‌نیاز: پروژه‌ی `~/work/churn-mlops` از جلسه‌ی ۱ با `make train` سالم، و تمرین خانه‌ی جلسه‌ی ۱ انجام‌شده.

## فایل‌های این پوشه

| فایل | مقصد در پروژه | کار |
|---|---|---|
| `pyproject-snippet.toml` | انتهای `pyproject.toml` | تنظیمات ruff و pytest |
| `test_data.py` | `tests/` | دو آزمون برای داده |
| `test_train.py` | `tests/` | یک آزمون برای مدل؛ آزمون چهارم را خودتان می‌نویسید |
| `.pre-commit-config.yaml` | ریشه‌ی پروژه | hookهای آفلاین: ruff، مسدود کردن فایل env و رمز، pytest |

فایل `.pre-commit-config.yaml` با نقطه شروع می‌شود و در فهرست معمولی پوشه دیده نمی‌شود؛ با `ls -a` آن را می‌بینید.

## کپی فایل‌ها

اول مخزن دوره را به‌روز کنید:

```bash
git -C ~/mlops-lab pull
```

```bash
K=~/mlops-lab/s02
cd ~/work/churn-mlops
```

ابزارهای کیفیت (گام ۲ آزمایشگاه):

```bash
uv add --dev ruff pytest pre-commit
```

```bash
cat $K/pyproject-snippet.toml >> pyproject.toml
```

آزمون‌ها (گام ۳):

```bash
mkdir -p tests
cp $K/test_*.py tests/
```

```bash
uv run pytest -q
```

خروجی مورد انتظار: `3 passed`. بعد از نوشتن آزمون چهارم: `4 passed`.

hookها (گام ۴):

```bash
cp $K/.pre-commit-config.yaml .
```

```bash
uv run pre-commit install --hook-type pre-commit --hook-type pre-push
```

## نکته

در اسلایدها مسیر فایل‌های آماده `~/mlops-lab/starter/s02` نوشته شده است. در این مخزن همان فایل‌ها در `~/mlops-lab/s02` هستند.

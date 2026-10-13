# MLOps Fundamentals On-Prem — مخزن دانشجو

فایل‌های آزمایشگاه و منابع دوره‌ی **MLOps Fundamentals On-Prem** (۱۴ جلسه‌ی ۳ ساعته) — Anisa / Iran Linux House

مدرس: سعیدرضا سالاری

## دریافت و به‌روزرسانی

بار اول:

```bash
git clone https://github.com/srsalari/MLOps-Fundamental.git ~/mlops-lab
```

قبل از هر جلسه:

```bash
git -C ~/mlops-lab pull
```

کاربران Windows همه‌ی دستورها را داخل Ubuntu (WSL2) اجرا کنند، نه در PowerShell. راهنمای نصب در `s01/README.md` است.

## ساختار مخزن

| مسیر | محتوا |
|---|---|
| `s01/`، `s02/`، … | فایل‌های آماده و راهنمای آزمایشگاه هر جلسه |
| `compose/` | سرویس‌های آزمایشگاه با Docker Compose: Gitea (و runner آن)، SeaweedFS، MLflow |
| `scripts/` | `preflight.sh` (بررسی آمادگی لپ‌تاپ)، `kind-up.sh`، `install-from-bundle.sh` |
| `k8s/` | تنظیمات Kubernetes (kind، Traefik، monitoring) برای جلسه‌های ۱۱ تا ۱۳ |
| `versions.env`، `requirements.txt` | نسخه‌ی دقیق ابزارها و کتابخانه‌های دوره |
| `docs/` | طرح درس، واژه‌نامه و اسلایدهای جلسه‌های برگزارشده |

## پروژه‌ی شما کجاست؟

این مخزن فقط **منبع فایل‌ها**ست. پروژه‌ی خودتان را جدا، در `~/work/churn-mlops` می‌سازید و فایل‌های هر جلسه را طبق راهنمای همان جلسه به آن کپی می‌کنید. داخل `~/mlops-lab` چیزی را ویرایش نکنید تا `git pull` بدون مشکل کار کند.

## جلسه‌ها

| جلسه | موضوع | پوشه |
|---|---|---|
| ۱ | شروع دوره و مبانی MLOps؛ اولین مدل Churn | [`s01/`](s01/README.md) |
| ۲ | Git برای ML و کیفیت کد | [`s02/`](s02/README.md) |
| ۳ | مبانی Docker و ذخیره‌ساز شیء (SeaweedFS) | بعداً اضافه می‌شود |
| ۴ | نسخه‌بندی داده با DVC | بعداً اضافه می‌شود |
| ۵ تا ۱۴ | طبق طرح درس | بعداً اضافه می‌شود |

## منابع

- [طرح درس](docs/Teaching-Plan-MLOps-Fundamentals-FA.pdf)
- [واژه‌نامه‌ی MLOps](docs/Glossary-MLOps-FA.pdf)
- [اسلایدهای جلسه‌ی ۱](docs/slides/Session-01-Kickoff-MLOps-Foundations.pdf)

## درباره‌ی کلیدهای داخل `compose/`

کلیدهای `compose/.env.example` و `compose/seaweedfs/s3.json` فقط برای سرویس‌های محلی آزمایشگاه روی لپ‌تاپ خودتان هستند. هرگز آن‌ها را بیرون از کلاس استفاده نکنید.

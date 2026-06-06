# minitools Phase 4 追加実装指示

## 概要

llm-wiki スキル（別リポジトリ `personal-wiki-for-claude-code`）の Phase 4 で Medium 記事を
wiki に取り込むために、minitools に 2 つの CLI エントリーポイントを追加する。

- **`scrape-medium`**: Medium 記事 URL を受け取り、英語原文 Markdown を stdout に出力
- **`discover-notion-medium`**: Notion Medium DB から新着記事を JSON で stdout に出力

既存コードを最大限再利用し、新規コードは最小限にする。

---

## タスク 1: `scrape-medium` コマンド

### 目的

Medium 記事 URL を指定すると、英語原文 Markdown を stdout に出力する。
**翻訳は行わない**（既存の `medium-translate` は翻訳まで込みのため、スクレイプのみ分離）。

### 作成ファイル

`scripts/scrape_medium.py`

### 仕様

**CLI インターフェース:**
```
uv run scrape-medium --url "https://medium.com/..." [--cdp]
```

| 引数 | 必須 | 説明 |
|-----|------|------|
| `--url` | 必須 | 対象 Medium 記事の URL |
| `--cdp` | 任意 | Chrome CDP モードで実行（ログイン済みセッション利用。Cloudflare 回避に有効） |

**stdout 出力:**
```
# Article Title

本文 Markdown（英語原文）...
```
- 出力は **Markdown テキストのみ**（YAML フロントマターなし）
- `--cdp` 未指定時はスタンドアロン Playwright（内蔵 Chromium）で実行

**exit code:**
- `0`: 成功（Markdown を stdout に出力済み）
- `1`: 失敗（stderr にエラーメッセージを出力）

**使用する既存クラス:**
- `minitools.scrapers.medium_scraper.MediumScraper` — HTML 取得
- `minitools.scrapers.markdown_converter.MarkdownConverter` — HTML → Markdown 変換

### 実装

`MediumScraper` は async context manager として使う。
`medium_translate.py` の冒頭の import パターンと `sys.path.append` を踏襲すること。

```python
#!/usr/bin/env python3
"""
Medium article scraper — outputs English Markdown to stdout.

Usage:
    uv run scrape-medium --url "https://medium.com/..."
    uv run scrape-medium --url "https://medium.com/..." --cdp
"""

import argparse
import asyncio
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
from minitools.scrapers.medium_scraper import MediumScraper
from minitools.scrapers.markdown_converter import MarkdownConverter
from minitools.utils.logger import setup_logger

load_dotenv()


async def scrape(url: str, cdp: bool) -> str:
    """Medium 記事を取得して Markdown を返す。失敗時は空文字列を返す。"""
    converter = MarkdownConverter()
    async with MediumScraper(cdp_mode=cdp) as scraper:
        html = await scraper.scrape_article(url)
    if not html:
        return ""
    return converter.convert(html)


def main() -> None:
    setup_logger()
    parser = argparse.ArgumentParser(
        description="Scrape a Medium article and output English Markdown to stdout."
    )
    parser.add_argument("--url", required=True, help="Medium article URL")
    parser.add_argument(
        "--cdp",
        action="store_true",
        help="Use Chrome CDP mode (requires Chrome with Medium login session)",
    )
    args = parser.parse_args()

    markdown = asyncio.run(scrape(args.url, args.cdp))
    if not markdown:
        print(f"ERROR: failed to scrape {args.url}", file=sys.stderr)
        sys.exit(1)

    print(markdown)


if __name__ == "__main__":
    main()
```

---

## タスク 2: `discover-notion-medium` コマンド

### 目的

Notion の Medium DB（minitools cron が 200+ claps 記事を毎日保存しているデータベース）から
直近 N 日分の記事を JSON で stdout に出力する。
llm-wiki の `discover-medium` モードがこの出力を読み取り、Claude Code 関連記事をフィルタリングする。

### 作成ファイル

`scripts/discover_notion_medium.py`

### 仕様

**CLI インターフェース:**
```
uv run discover-notion-medium [--days N] [--database-id ID]
```

| 引数 | 必須 | デフォルト | 説明 |
|-----|------|----------|------|
| `--days` | 任意 | `7` | 直近何日分を取得するか |
| `--database-id` | 任意 | 環境変数 | Notion DB ID（省略時は `NOTION_MEDIUM_DATABASE_ID` → `NOTION_DB_ID_DAILY_DIGEST` の順で参照） |

**環境変数（必須）:**
- `NOTION_API_KEY`: Notion Integration API Key

**stdout 出力（JSON 配列）:**
```json
[
  {
    "url": "https://medium.com/...",
    "title": "Article Title in English",
    "japanese_title": "日本語タイトル",
    "claps": 312,
    "summary": "日本語要約テキスト（最大2000文字）",
    "date": "2026-06-04",
    "author": "Author Name"
  },
  ...
]
```

- `url`, `title`, `claps`, `date` はほぼ必ず存在する
- `japanese_title`, `summary`, `author` は Notion に未登録の場合は空文字列 `""` にする（`null` にしない）
- 日付降順（新しい記事が先頭）でソートする

**exit code:**
- `0`: 成功（JSON を stdout に出力済み。0 件の場合も `[]` を出力して 0）
- `1`: 失敗（環境変数未設定・Notion API エラー等。stderr にエラーメッセージ）

**使用する既存クラス:**
- `minitools.readers.notion.NotionReader` — DB クエリ

### 実装

```python
#!/usr/bin/env python3
"""
Discover recent Medium articles from Notion DB and output JSON to stdout.

Usage:
    uv run discover-notion-medium
    uv run discover-notion-medium --days 3
    uv run discover-notion-medium --days 7 --database-id "abc123"
"""

import argparse
import asyncio
import json
import os
import sys
from datetime import datetime, timedelta, timezone

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
from minitools.readers.notion import NotionReader
from minitools.utils.logger import setup_logger

load_dotenv()


async def discover(days: int, database_id: str) -> list[dict]:
    reader = NotionReader()
    today = datetime.now(tz=timezone.utc)
    start = today - timedelta(days=days)
    articles = await reader.get_articles_by_date_range(
        database_id=database_id,
        start_date=start.strftime("%Y-%m-%d"),
        end_date=today.strftime("%Y-%m-%d"),
    )

    results = []
    for a in articles:
        results.append(
            {
                "url": a.get("url") or a.get("URL") or "",
                "title": a.get("title") or a.get("Title") or "",
                "japanese_title": a.get("japanese_title") or a.get("Japanese Title") or "",
                "claps": a.get("claps") or a.get("Claps") or 0,
                "summary": a.get("summary") or a.get("Summary") or "",
                "date": _extract_date(a.get("date") or a.get("Date") or ""),
                "author": a.get("author") or a.get("Author") or "",
            }
        )

    # 日付降順ソート
    results.sort(key=lambda x: x["date"], reverse=True)
    return results


def _extract_date(value: object) -> str:
    """date フィールドの値を YYYY-MM-DD 文字列に正規化する。"""
    if not value:
        return ""
    if isinstance(value, dict):
        value = value.get("start") or ""
    s = str(value)
    return s[:10] if len(s) >= 10 else s


def main() -> None:
    setup_logger()
    parser = argparse.ArgumentParser(
        description="Discover recent Medium articles from Notion DB (JSON output)."
    )
    parser.add_argument("--days", type=int, default=7, help="How many days back to query (default: 7)")
    parser.add_argument("--database-id", default=None, help="Notion database ID (overrides env var)")
    args = parser.parse_args()

    api_key = os.getenv("NOTION_API_KEY")
    if not api_key:
        print("ERROR: NOTION_API_KEY is not set", file=sys.stderr)
        sys.exit(1)

    database_id = (
        args.database_id
        or os.getenv("NOTION_MEDIUM_DATABASE_ID")
        or os.getenv("NOTION_DB_ID_DAILY_DIGEST")
    )
    if not database_id:
        print(
            "ERROR: database ID is required (--database-id or NOTION_MEDIUM_DATABASE_ID env var)",
            file=sys.stderr,
        )
        sys.exit(1)

    articles = asyncio.run(discover(args.days, database_id))
    print(json.dumps(articles, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
```

---

## タスク 3: `pyproject.toml` の更新

`[project.scripts]` セクションに以下の 2 行を追加する：

```toml
scrape-medium = "scripts.scrape_medium:main"
discover-notion-medium = "scripts.discover_notion_medium:main"
```

追加後の `[project.scripts]` セクション（既存行は変更しない）：

```toml
[project.scripts]
arxiv = "scripts.arxiv:main"
medium = "scripts.medium:main"
google-alerts = "scripts.google_alerts:main"
google-alerts-translate = "scripts.google_alerts_translate:main"
youtube = "scripts.youtube:main"
google-alert-weekly-digest = "scripts.google_alert_weekly_digest:main"
google-alert-daily-digest = "scripts.google_alert_daily_digest:main"
arxiv-weekly = "scripts.arxiv_weekly:main"
medium-translate = "scripts.medium_translate:main"
arxiv-translate = "scripts.arxiv_translate:main"
x-trend = "scripts.x_trend:main"
x-followings = "scripts.x_followings:main"
scrape-medium = "scripts.scrape_medium:main"
discover-notion-medium = "scripts.discover_notion_medium:main"
```

---

## タスク 4: 動作確認

実装後、以下を手動確認する。

### `scrape-medium` 確認

```bash
cd /Users/tak/Projects/minitools

# 1. スタンドアロンモード（翻訳なし・英語原文のみ出力されること）
uv run scrape-medium --url "https://medium.com/@some-article" 2>/dev/null | head -20

# 2. 失敗時に exit 1 が返ること
uv run scrape-medium --url "https://medium.com/nonexistent-article-xyz"; echo "exit: $?"

# 3. CDP モードで起動すること（Chrome が起動済みであること）
uv run scrape-medium --url "https://medium.com/@some-article" --cdp 2>/dev/null | head -5
```

確認ポイント：
- stdout に Markdown テキスト（英語）が出力される
- stderr にログが出ても stdout は汚染されない
- `--cdp` なしでも動作する（Cloudflare に引っかかるケースはあり得るが、動作すること）

### `discover-notion-medium` 確認

```bash
cd /Users/tak/Projects/minitools

# 1. 直近 3 日分取得（JSON 配列が返ること）
uv run discover-notion-medium --days 3 | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'{len(d)} articles'); print(d[0] if d else 'empty')"

# 2. 必須フィールドの存在確認
uv run discover-notion-medium --days 7 | python3 -c "
import json, sys
articles = json.load(sys.stdin)
for a in articles[:3]:
    assert 'url' in a and 'title' in a and 'claps' in a and 'date' in a
    assert isinstance(a['claps'], int)
    assert a['url'].startswith('http')
print('OK:', len(articles), 'articles, fields valid')
"

# 3. NOTION_API_KEY 未設定時に exit 1 になること
NOTION_API_KEY="" uv run discover-notion-medium; echo "exit: $?"
```

---

## 注意事項

- `MarkdownConverter` のクラス名・コンストラクタ引数は `scrapers/markdown_converter.py` を実際に確認してから使うこと
- `MediumScraper` の `__aenter__`/`__aexit__` を使う async context manager パターンは `medium_translate.py` に実装例があるので参照すること
- `NotionReader` の戻り値のキー名（`"url"` vs `"URL"` 等）は `readers/notion.py` の `_page_to_article` メソッドの実装を確認すること（`key = prop_name.lower().replace(" ", "_")` で変換されているため小文字キーになる）
- 翻訳・要約・Notion への保存処理は一切追加しないこと

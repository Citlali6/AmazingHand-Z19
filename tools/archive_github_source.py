"""Read-only archive of public GitHub issues, PR reviews and linked attachments.

Uses the signed-in user's Git credential helper; never writes credentials or
creates GitHub issues/comments. Git history and PR patches are checked separately.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request


SOURCE = 'Tom-mr33/AmazingHand-based-on-FPGA'
API = 'https://api.github.com/repos/' + SOURCE
SOURCE_URL = 'https://github.com/' + SOURCE
TOKEN_PATTERN = re.compile(r'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|'
                           r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----.*?'
                           r'-----END (?:RSA |OPENSSH |EC )?PRIVATE KEY-----', re.S)
ASSET_PATTERN = re.compile(r'https://(?:github\.com/user-attachments/(?:assets|files)/'
                           r'|user-images\.githubusercontent\.com/)[^\s<>"\)\]]+')


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlsplit(newurl)
        host = parsed.hostname or ''
        allowed = (host == 'github.com' or host.endswith('.githubusercontent.com')
                   or host.endswith('.s3.amazonaws.com') or host.endswith('.github.com'))
        if parsed.scheme != 'https' or not allowed:
            raise ValueError('Refusing an unexpected asset redirect host')
        request = super().redirect_request(req, fp, code, msg, headers, newurl)
        if parsed.hostname != urllib.parse.urlsplit(req.full_url).hostname:
            request.remove_header('Authorization')
        return request


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8', newline='\n') as out:
        json.dump(value, out, ensure_ascii=False, indent=2)
        out.write('\n')


class Archive:
    def __init__(self, root, proxy, snapshot_date):
        credential = subprocess.run(['git', 'credential', 'fill'],
            input='protocol=https\nhost=github.com\n\n', text=True,
            capture_output=True, check=True, timeout=30)
        fields = dict(line.split('=', 1) for line in credential.stdout.splitlines() if '=' in line)
        self.token = fields['password']
        self.proxy = proxy
        self.root = root
        self.snapshot_date = snapshot_date
        self.repository_id = None
        self.redactions = 0
        self.errors = []

    def opener(self):
        handlers = [SafeRedirect()]
        if self.proxy:
            handlers.append(urllib.request.ProxyHandler({'https': self.proxy}))
        return urllib.request.build_opener(*handlers)

    def request(self, url, authenticated=True):
        headers = {'User-Agent': 'Codex-public-repository-archive',
                   'Accept': 'application/vnd.github+json'}
        if authenticated:
            if urllib.parse.urlsplit(url).hostname != 'api.github.com':
                raise ValueError('API credentials may only be sent to api.github.com')
            headers['Authorization'] = 'Bearer ' + self.token
        request = urllib.request.Request(url, headers=headers)
        for attempt in range(3):
            try:
                return self.opener().open(request, timeout=30)
            except urllib.error.HTTPError as exc:
                if exc.code not in (429, 500, 502, 503, 504) or attempt == 2:
                    raise
            except (TimeoutError, urllib.error.URLError):
                if attempt == 2:
                    raise
            time.sleep(attempt + 1)

    def api(self, path):
        with self.request(API + path) as response:
            return json.load(response)

    def pages(self, path):
        result = []
        url = API + path + ('&' if '?' in path else '?') + 'per_page=100'
        while url:
            with self.request(url) as response:
                result.extend(json.load(response))
                link = response.headers.get('Link', '')
            match = re.search(r'<([^>]+)>; rel="next"', link)
            url = match.group(1) if match else None
            canonical = 'https://api.github.com/repositories/' + str(self.repository_id) + '/'
            if url and not (url.startswith(API + '/') or url.startswith(canonical)):
                raise ValueError('Unexpected pagination destination')
        return result

    def clean(self, value):
        if isinstance(value, str):
            value, count = TOKEN_PATTERN.subn('[REDACTED_CREDENTIAL]', value)
            self.redactions += count
        elif isinstance(value, list):
            value = [self.clean(item) for item in value]
        elif isinstance(value, dict):
            value = {key: self.clean(item) for key, item in value.items()}
        return value

    def asset(self, url):
        try:
            with self.request(url, authenticated=False) as response:
                content_type = response.headers.get_content_type()
                size = int(response.headers.get('Content-Length', 0))
                if size > 95 * 1024 * 1024:
                    raise ValueError('Attachment exceeds the Git file size budget')
                data = response.read(95 * 1024 * 1024 + 1)
                if len(data) > 95 * 1024 * 1024:
                    raise ValueError('Attachment exceeds the Git file size budget')
            if content_type in ('text/html', 'application/xhtml+xml'):
                raise ValueError('Attachment returned HTML instead of its content')
            extension = {'image/png': '.png', 'image/jpeg': '.jpg', 'image/gif': '.gif',
                         'image/webp': '.webp', 'application/pdf': '.pdf',
                         'video/mp4': '.mp4', 'application/zip': '.zip'}.get(content_type, '.bin')
            name = hashlib.sha256(url.encode()).hexdigest()[:20] + extension
            destination = self.root / 'attachments' / name
            destination.parent.mkdir(exist_ok=True)
            with destination.open('xb') as out:
                out.write(data)
            return dict(url=url, path='attachments/' + name, bytes=len(data),
                        content_type=content_type, sha256=hashlib.sha256(data).hexdigest())
        except (OSError, ValueError, urllib.error.URLError) as exc:
            return dict(url=url, error=str(exc))

    def export(self):
        info = self.api('')
        self.repository_id = info['id']
        if info.get('private'):
            raise ValueError('Refusing automatic publication of a private source repository')
        self.root.mkdir(parents=True, exist_ok=False)
        metadata = {key: info.get(key) for key in ('full_name', 'html_url', 'description',
            'created_at', 'updated_at', 'pushed_at', 'default_branch', 'visibility',
            'private', 'has_wiki', 'has_discussions', 'license', 'topics')}
        issues = self.pages('/issues?state=all&sort=created&direction=asc')
        tasks = {'labels': '/labels', 'milestones': '/milestones?state=all',
                 'releases': '/releases', 'issue-events': '/issues/events'}
        for item in issues:
            number = item['number']
            tasks[f'items/{number}/comments'] = f'/issues/{number}/comments'
            if 'pull_request' in item:
                tasks[f'items/{number}/reviews'] = f'/pulls/{number}/reviews'
                tasks[f'items/{number}/review-comments'] = f'/pulls/{number}/comments'
                tasks[f'items/{number}/commits'] = f'/pulls/{number}/commits'
                tasks[f'items/{number}/files'] = f'/pulls/{number}/files'
        data = {}
        with ThreadPoolExecutor(max_workers=4) as pool:
            jobs = {pool.submit(self.pages, path): name for name, path in tasks.items()}
            for job in as_completed(jobs):
                name = jobs[job]
                data[name] = job.result()
                print('ARCHIVED_API ' + name, flush=True)
        with ThreadPoolExecutor(max_workers=4) as pool:
            pull_items = [item for item in issues if 'pull_request' in item]
            pulls = list(pool.map(lambda item: self.api('/pulls/' + str(item['number'])), pull_items))
        for item in pulls:
            data[f"items/{item['number']}/pull"] = item
        # Actions can be absent even when other repository metadata exists.
        for name, path in [('actions-runs', '/actions/runs?per_page=100'),
                           ('actions-artifacts', '/actions/artifacts?per_page=100')]:
            data[name] = self.api(path)
        metadata = self.clean(metadata)
        issues = self.clean(issues)
        data = self.clean(data)
        write_json(self.root / 'repository.json', metadata)
        write_json(self.root / 'issues-and-prs.json', issues)
        for name, value in data.items():
            write_json(self.root / (name + '.json'), value)
        strings = []
        def collect(value):
            if isinstance(value, str): strings.append(value)
            elif isinstance(value, list):
                for item in value: collect(item)
            elif isinstance(value, dict):
                for item in value.values(): collect(item)
        collect(issues)
        collect(data)
        urls = sorted({match.rstrip('.,;') for text in strings for match in ASSET_PATTERN.findall(text)})
        with ThreadPoolExecutor(max_workers=4) as pool:
            assets = list(pool.map(self.asset, urls))
        write_json(self.root / 'attachments.json', assets)
        local_assets = {item['url']: '../' + item['path'] for item in assets if 'path' in item}
        names = {item['number']: ('pr-' if 'pull_request' in item else 'issue-')
                 + str(item['number']).zfill(4) + '.md' for item in issues}
        def render(text):
            for url, local in local_assets.items():
                text = text.replace(url, local)
            text = re.sub(re.escape(SOURCE_URL) + r'/(?:issues|pull)/(\d+)',
                          lambda m: names.get(int(m.group(1)), m.group(0)), text)
            for kind in ('blob', 'tree', 'commit', 'commits', 'raw'):
                text = text.replace(SOURCE_URL + '/' + kind + '/',
                                    'https://github.com/Citlali6/AmazingHand-Z19/' + kind + '/')
            def relative_link(match):
                target = urllib.parse.urlsplit(match.group(2))
                repo = Path(__file__).resolve().parents[1]
                file = (repo / urllib.parse.unquote(target.path)).resolve()
                if repo in file.parents and file.is_file():
                    return match.group(1) + '../../../../' + match.group(2) + ')'
                return match.group(0)
            text = re.sub(r'(\]\()((?:fpga|docs|host|sim|tools|AmazingHand)/[^\s)]+)\)', relative_link, text)
            return text
        rows = []
        comments_count = reviews_count = inline_count = 0
        for item in issues:
            number = item['number']
            directory = self.root / 'items' / str(number)
            write_json(directory / 'issue.json', item)
            comments = data[f'items/{number}/comments']
            reviews = data.get(f'items/{number}/reviews', [])
            inline = data.get(f'items/{number}/review-comments', [])
            comments_count += len(comments)
            reviews_count += len(reviews)
            inline_count += len(inline)
            lines = [f"# #{number}: {item['title']}", '',
                     f"原作者：`{item['user']['login']}`；状态：`{item['state']}`；创建时间：`{item['created_at']}`。", '',
                     f"原链接：{item['html_url']}", '',
                     '**只读归档：保留原作者和时间，不代表在新仓库重新发布、审批或合并。**', '',
                     render(item.get('body') or ''), '']
            for label, entries in [('评论', comments), ('Review', reviews), ('行内评审', inline)]:
                lines.extend([f'## {label}', ''])
                for entry in entries:
                    author = (entry.get('user') or {}).get('login', 'deleted-user')
                    date = entry.get('created_at') or entry.get('submitted_at') or ''
                    lines.extend([f"### {author} · {date} · {entry.get('state', '')}", '',
                                  render(entry.get('body') or ''), ''])
                    if entry.get('path'):
                        lines.extend([f"文件：`{entry['path']}`；行：`{entry.get('line') or entry.get('original_line')}`", '',
                                      '```diff', entry.get('diff_hunk') or '', '```', ''])
            path = self.root / 'pages' / names[number]
            path.parent.mkdir(exist_ok=True)
            with path.open('x', encoding='utf-8', newline='\n') as out:
                out.write('\n'.join(lines))
            rows.append(f"| #{number} | {'PR' if 'pull_request' in item else 'Issue'} | {item['state']} | "
                        f"[{item['title'].replace('|', '/').replace(chr(10), ' ')}](pages/{names[number]}) |")
        summary = dict(source=SOURCE, snapshot_date=self.snapshot_date,
                       issues=len(issues) - len(pulls), pull_requests=len(pulls),
                       issue_comments=comments_count, reviews=reviews_count,
                       inline_comments=inline_count, attachments=len(assets),
                       attachments_saved=sum('path' in asset for asset in assets),
                       attachment_failures=[asset for asset in assets if 'error' in asset],
                       labels=len(data['labels']), milestones=len(data['milestones']),
                       releases=len(data['releases']), wiki_enabled=metadata['has_wiki'],
                       discussions_enabled=metadata['has_discussions'],
                       redacted_credential_patterns=self.redactions)
        write_json(self.root / 'summary.json', summary)
        intro = ['# 原仓库 Issue / PR 只读归档', '',
                 '原仓库改为私有或删除后，可直接在此查阅当时的正文、讨论和评审；原链接保留用于出处。', '',
                 f"保存 {summary['issues']} 个 Issue、{summary['pull_requests']} 个 PR、"
                 f"{comments_count} 条评论、{reviews_count} 条 Review、{inline_count} 条行内评审。", '',
                 '完整 JSON、提交列表、变更文件元数据见 `items/`；附件下载结果见 `attachments.json`。', '',
                 'GitHub 的身份、审批效力、通知、星标和关注关系不会通过文件归档重新建立。', '',
                 '| 编号 | 类型 | 状态 | 标题 |', '|---|---|---|---|', *rows, '']
        with (self.root / 'README.md').open('x', encoding='utf-8', newline='\n') as out:
            out.write('\n'.join(intro))
        print('ARCHIVE_SUMMARY ' + json.dumps(summary, ensure_ascii=True), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path, help='New directory; must not exist')
    parser.add_argument('--snapshot-date', required=True, help='Client date in YYYY-MM-DD format')
    parser.add_argument('--proxy', help='Optional HTTP proxy, with no embedded credentials')
    args = parser.parse_args()
    if args.proxy and urllib.parse.urlsplit(args.proxy).username:
        raise ValueError('Do not pass proxy credentials in command arguments')
    date.fromisoformat(args.snapshot_date)
    Archive(args.output.resolve(), args.proxy, args.snapshot_date).export()


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Canvas LMS data for the shell. --check | --env <file> | --cache <file>. Never prints the token."""
import json, os, re, sys, urllib.request, urllib.parse
from datetime import datetime, timedelta, timezone

DEFAULT_URL = "https://canvas.kdg.be/api/v1"
HOME = os.path.expanduser("~")


def parse_env(path):
    out = {}
    try:
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            if line.startswith("export "):
                line = line[7:]
            k, v = line.split("=", 1)
            v = v.strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1]
            out[k.strip()] = v
    except OSError:
        pass
    return out


def creds(argv):
    token = os.environ.get("CANVAS_API_TOKEN", "").strip()
    url = os.environ.get("CANVAS_API_URL", "").strip()
    if not token:
        paths = []
        if "--env" in argv and argv.index("--env") + 1 < len(argv):
            paths.append(os.path.expanduser(argv[argv.index("--env") + 1]))
        paths += [os.path.join(HOME, ".config/qshell/canvas.env"), os.path.join(HOME, "git/canvas-mcp/.env")]
        for p in paths:
            if os.path.isfile(p):
                e = parse_env(p)
                token = e.get("CANVAS_API_TOKEN", "").strip()
                url = url or e.get("CANVAS_API_URL", "").strip()
                break
    if token and not url:
        url = DEFAULT_URL
    url = url.rstrip("/")
    if url and not url.endswith("/api/v1"):
        url += "/api/v1"
    return token, url


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def get_all(url, token, pages=5):
    items = []
    for _ in range(pages):
        req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
        with urllib.request.urlopen(req, timeout=15) as r:
            data = json.loads(r.read().decode("utf-8"))
            link = r.headers.get("Link", "")
        if isinstance(data, list):
            items += data
        else:
            return data
        m = re.search(r'<([^>]+)>;\s*rel="next"', link)
        if not m:
            break
        url = m.group(1)
    return items


def strip_html(h):
    import html
    t = re.sub(r"(?is)<(script|style).*?</\1>", " ", h or "")
    t = re.sub(r"<[^>]+>", " ", t)
    t = re.sub(r"\s+", " ", html.unescape(t)).strip()
    return t if len(t) <= 160 else t[:159].rstrip() + "…"


def fetch(token, base):
    now = datetime.now(timezone.utc)
    q = urllib.parse.quote
    courses = {}
    for c in get_all(base + "/courses?enrollment_state=active&per_page=100", token):
        if isinstance(c, dict) and "id" in c:
            courses[c["id"]] = (c.get("name") or c.get("course_code") or str(c["id"])).strip()

    deadlines = []
    kinds = {"assignment": "assignment", "quiz": "quiz", "discussion_topic": "discussion"}
    url = "%s/planner/items?start_date=%s&end_date=%s&per_page=100" % (
        base, q(iso(now - timedelta(days=1))), q(iso(now + timedelta(days=21))))
    for it in get_all(url, token):
        kind = kinds.get(it.get("plannable_type"))
        if not kind:
            continue
        p = it.get("plannable") or {}
        sub = it.get("submissions") or {}
        if not isinstance(sub, dict):
            sub = {}
        due = it.get("plannable_date") or p.get("due_at")
        if not due:
            continue
        href = it.get("html_url") or ""
        if href.startswith("/"):
            href = base.split("/api/")[0] + href
        deadlines.append({
            "id": str(p.get("id", it.get("plannable_id", ""))),
            "title": p.get("title") or p.get("name") or "(untitled)",
            "course": courses.get(it.get("course_id"), it.get("context_name") or ""),
            "due": due, "url": href,
            "submitted": bool(sub.get("submitted")), "missing": bool(sub.get("missing")),
            "type": kind})
    deadlines.sort(key=lambda d: d["due"])

    anns = []
    if courses:
        params = "&".join("context_codes[]=course_%s" % i for i in courses)
        url = "%s/announcements?%s&start_date=%s&end_date=%s&per_page=50" % (
            base, params, q(iso(now - timedelta(days=21))), q(iso(now + timedelta(days=1))))
        for a in get_all(url, token):
            cid = str(a.get("context_code", "")).replace("course_", "")
            try:
                cname = courses.get(int(cid), "")
            except ValueError:
                cname = ""
            anns.append({
                "id": str(a.get("id")), "title": a.get("title") or "(untitled)", "course": cname,
                "posted": a.get("posted_at") or a.get("created_at") or "",
                "url": a.get("html_url") or "",
                "read": a.get("read_state") == "read",
                "preview": strip_html(a.get("message"))})
        anns.sort(key=lambda a: a["posted"], reverse=True)
        anns = anns[:25]
    return {"configured": True, "ok": True, "fetched": iso(now),
            "courses": {str(k): v for k, v in courses.items()}, "deadlines": deadlines, "announcements": anns}


def main():
    argv = sys.argv[1:]
    token, base = creds(argv)
    if "--check" in argv:
        print(json.dumps({"configured": bool(token)}))
        return
    if not token:
        print(json.dumps({"configured": False}))
        return
    try:
        out = fetch(token, base)
    except Exception as e:
        msg = str(e).replace(token, "***")[:120]
        out = {"configured": True, "ok": False, "error": type(e).__name__ + ": " + msg}
    if out.get("ok") and "--cache" in argv and argv.index("--cache") + 1 < len(argv):
        cp = os.path.expanduser(argv[argv.index("--cache") + 1])
        try:
            os.makedirs(os.path.dirname(cp), exist_ok=True)
            tmp = cp + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(out, f)
            os.replace(tmp, cp)
        except OSError:
            pass
    print(json.dumps(out))


main()

#!/usr/bin/env python3
"""Print AI usage as JSON for the shell's AI panel.

claude:   summed from Claude Code transcripts (~/.claude/projects/**/*.jsonl), last 7 days
opencode: from `opencode stats --json` (today and last 7 days)
"""
import glob, json, os, subprocess, sys, time
from datetime import datetime, timedelta, timezone

DAYS = 7
now = datetime.now().astimezone()
today = now.date()
start = today - timedelta(days=DAYS - 1)


def empty():
    return {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0, "messages": 0}


def claude():
    cutoff = time.time() - DAYS * 86400
    per_day = {(start + timedelta(days=i)).isoformat(): empty() for i in range(DAYS)}
    models, sessions_today, sessions_week, seen = {}, set(), set(), {}
    last = None
    for path in glob.glob(os.path.expanduser("~/.claude/projects/**/*.jsonl"), recursive=True):
        try:
            if os.path.getmtime(path) < cutoff:
                continue
            with open(path, errors="replace") as fh:
                for line in fh:
                    if '"usage"' not in line:
                        continue
                    try:
                        d = json.loads(line)
                    except ValueError:
                        continue
                    msg = d.get("message") or {}
                    use = msg.get("usage") if isinstance(msg, dict) else None
                    ts = d.get("timestamp")
                    if not use or not ts:
                        continue
                    # A streamed reply is logged several times; keep the last record per request.
                    seen[d.get("requestId") or d.get("uuid")] = (ts, msg.get("model") or "?", use, d.get("sessionId"))
        except OSError:
            continue
    for ts, model, use, sid in seen.values():
        try:
            when = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
        except ValueError:
            continue
        day = when.date().isoformat()
        if day not in per_day:
            continue
        b = per_day[day]
        i, o = use.get("input_tokens", 0) or 0, use.get("output_tokens", 0) or 0
        cr, cw = use.get("cache_read_input_tokens", 0) or 0, use.get("cache_creation_input_tokens", 0) or 0
        b["input"] += i; b["output"] += o; b["cacheRead"] += cr; b["cacheWrite"] += cw; b["messages"] += 1
        if model.startswith("<"):
            continue
        m = models.setdefault(model, {"name": model, "tokens": 0, "messages": 0})
        m["tokens"] += i + o + cw; m["messages"] += 1
        sessions_week.add(sid)
        if when.date() == today:
            sessions_today.add(sid)
        if last is None or when > last:
            last = when
    window = now - timedelta(hours=5)
    recent = 0
    for ts, model, use, sid in seen.values():
        try:
            when = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
        except ValueError:
            continue
        if when >= window and not model.startswith("<"):
            recent += (use.get("input_tokens", 0) or 0) + (use.get("output_tokens", 0) or 0) + (use.get("cache_creation_input_tokens", 0) or 0)
    week = empty()
    for b in per_day.values():
        for k in week:
            week[k] += b[k]
    return {
        "available": os.path.isdir(os.path.expanduser("~/.claude/projects")),
        "today": per_day[today.isoformat()], "week": week,
        "daily": [{"day": d, "tokens": b["input"] + b["output"] + b["cacheWrite"]} for d, b in per_day.items()],
        "models": sorted(models.values(), key=lambda m: -m["tokens"])[:5],
        "sessionsToday": len(sessions_today), "sessionsWeek": len(sessions_week),
        "lastActive": last.isoformat() if last else "",
        "limits": limits(recent, week["input"] + week["output"] + week["cacheWrite"]),
    }


LABELS = {"five_hour": "Session (5h)", "seven_day": "Week", "seven_day_opus": "Week · Opus",
          "seven_day_sonnet": "Week · Sonnet", "seven_day_oauth_apps": "Week · apps"}


def limits(session_tokens, week_tokens):
    """Plan limits from Anthropic (what Claude Code's /usage shows), using the
    local Claude Code login. Falls back to a token estimate from transcripts."""
    estimate = {
        "source": "estimate",
        "rows": [{"label": "Session (5h)", "tokens": session_tokens}, {"label": "Week", "tokens": week_tokens}],
    }
    try:
        import urllib.request, urllib.error
        with open(os.path.expanduser("~/.claude/.credentials.json")) as fh:
            token = (json.load(fh).get("claudeAiOauth") or {}).get("accessToken")
        if not token:
            raise RuntimeError("no Claude Code login found")
        req = urllib.request.Request("https://api.anthropic.com/api/oauth/usage", headers={
            "Authorization": "Bearer " + token, "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": "claude-code", "Accept": "application/json"})
        try:
            data = json.loads(urllib.request.urlopen(req, timeout=10).read().decode())
        except urllib.error.HTTPError as e:
            raise RuntimeError("login expired - open Claude Code to refresh it" if e.code in (401, 403)
                               else "Anthropic returned HTTP %d" % e.code)
        rows = []
        for key, val in data.items():
            if isinstance(val, dict) and val.get("utilization") is not None:
                pct = float(val["utilization"])
                rows.append({"key": key, "label": LABELS.get(key, key.replace("_", " ")),
                             "pct": pct, "resetsAt": val.get("resets_at") or ""})
        if not rows:
            raise RuntimeError("unexpected reply from Anthropic")
        order = list(LABELS)
        rows.sort(key=lambda r: order.index(r["key"]) if r["key"] in order else 99)
        return {"source": "api", "rows": rows}
    except FileNotFoundError:
        estimate["warning"] = "no Claude Code login found"
    except Exception as e:  # network down, changed endpoint, ...
        estimate["warning"] = str(e)[:120] or type(e).__name__
    return estimate


def oc_stats(days):
    try:
        out = subprocess.run(["opencode", "stats", "--days", str(days), "--models", "--json"],
                             capture_output=True, text=True, timeout=40).stdout
        d = json.loads(out)
    except Exception:
        return None
    t = d.get("tokens") or {}
    c = t.get("cache") or {}
    models = []
    raw = d.get("models") or {}
    rows = raw.get("usage") if isinstance(raw, dict) else raw
    for r in rows or []:
        if not isinstance(r, dict):
            continue
        rt = r.get("tokens") or {}
        tok = (rt.get("input", 0) + rt.get("output", 0) + rt.get("reasoning", 0)) if isinstance(rt, dict) else (rt or 0)
        name = r.get("model") or r.get("name") or r.get("id") or "?"
        if isinstance(name, dict):
            name = name.get("id") or "?"
        models.append({"name": name, "tokens": tok,
                       "messages": r.get("steps") or r.get("messages") or r.get("calls") or 0})
    tools = (d.get("tools") or {}).get("totals") or {}
    return {
        "sessions": d.get("sessions", 0), "subagents": d.get("subagents", 0), "prompts": d.get("prompts", 0),
        "steps": d.get("steps", 0), "cost": d.get("cost", 0),
        "input": t.get("input", 0), "output": t.get("output", 0), "reasoning": t.get("reasoning", 0),
        "cacheRead": c.get("read", 0), "cacheWrite": c.get("write", 0),
        "toolCalls": tools.get("calls", 0), "toolFailed": tools.get("failed", 0),
        "models": sorted(models, key=lambda m: -m["tokens"])[:5],
    }


def opencode():
    from shutil import which
    if not which("opencode"):
        return {"available": False}
    return {"available": True, "today": oc_stats(0), "week": oc_stats(DAYS)}


json.dump({"generated": now.isoformat(), "claude": claude(), "opencode": opencode()}, sys.stdout)

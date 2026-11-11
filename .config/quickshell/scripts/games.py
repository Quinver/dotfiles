#!/usr/bin/env python3
"""Game library helper for the shell's games overlay (stdlib only).

  games.py list              one JSON object: { accounts: [...], games: [...] }
  games.py switch <account>  make Steam log in as <account> and restart Steam

Sources: Steam (appmanifests in every library), Faugus Launcher
(~/.local/share/faugus-launcher/games.json), Prism Launcher instances.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
STEAM = os.path.join(HOME, ".local/share/Steam")
REGISTRY = os.path.join(HOME, ".steam/registry.vdf")
LOGINUSERS = os.path.join(STEAM, "config/loginusers.vdf")
FAUGUS = os.path.join(HOME, ".local/share/faugus-launcher")
PRISM = os.path.join(HOME, ".local/share/PrismLauncher/instances")
BACKUP = os.path.join(HOME, ".local/state/qshell/steam-backup")
STEAMID_BASE = 76561197960265728
NOT_GAMES = re.compile(r"Proton|Steam Linux Runtime|Steamworks Common|Steam Audio|SteamVR|Redistributable|Creation Kit", re.I)


# ---- VDF -------------------------------------------------------------------

def parse_vdf(text):
    """Parse Valve KeyValues text into nested dicts (keys lowercased are not applied)."""
    tokens = re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', text)
    pos = 0

    def block():
        nonlocal pos
        out = {}
        while pos < len(tokens):
            s, brace = tokens[pos]
            pos += 1
            if brace == "}":
                return out
            key = s
            if pos >= len(tokens):
                break
            s2, brace2 = tokens[pos]
            pos += 1
            if brace2 == "{":
                out[key] = block()
            else:
                out[key] = s2.replace("\\\\", "\\")
        return out

    return block()


def read_vdf(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return parse_vdf(f.read())
    except OSError:
        return {}


def ci(d, *keys):
    """Case-insensitive nested lookup; returns {} when missing."""
    for k in keys:
        if not isinstance(d, dict):
            return {}
        d = next((v for kk, v in d.items() if kk.lower() == k.lower()), {})
    return d


# ---- Steam -----------------------------------------------------------------

def steam_accounts():
    users = ci(read_vdf(LOGINUSERS), "users")
    return users if isinstance(users, dict) else {}


def active_account_id():
    """ActiveUser from registry.vdf when Steam is logged in, else 0."""
    reg = read_vdf(REGISTRY)
    au = ci(reg, "Registry", "HKCU", "Software", "Valve", "Steam", "ActiveProcess", "ActiveUser")
    return int(au) if isinstance(au, str) and au.isdigit() else 0


def auto_login_user():
    au = ci(read_vdf(REGISTRY), "Registry", "HKCU", "Software", "Valve", "Steam", "AutoLoginUser")
    return au if isinstance(au, str) else ""


def accounts_info():
    users = steam_accounts()
    active = active_account_id()
    auto = auto_login_user()
    out = []
    for sid, u in users.items():
        if not sid.isdigit():
            continue
        aid = int(sid) - STEAMID_BASE
        out.append({
            "steamid": sid, "accountid": aid,
            "account": u.get("AccountName", ""), "persona": u.get("PersonaName", ""),
            "remembered": u.get("RememberPassword") == "1",
            "active": active == aid, "current": False,
        })
    # userdata folders that loginusers.vdf does not list yet
    known = {a["accountid"] for a in out}
    for d in glob.glob(os.path.join(STEAM, "userdata/*")):
        name = os.path.basename(d)
        if not name.isdigit() or int(name) in known or int(name) == 0:
            continue
        lc = ci(read_vdf(os.path.join(d, "config/localconfig.vdf")), "UserLocalConfigStore")
        persona = ci(lc, "friends", "PersonaName")
        out.append({
            "steamid": str(int(name) + STEAMID_BASE), "accountid": int(name),
            "account": "", "persona": persona if isinstance(persona, str) and persona else name,
            "remembered": False, "active": active == int(name), "current": False,
        })
    cur = next((a for a in out if a["active"]), None) or next((a for a in out if a["account"] and a["account"] == auto), None)
    if cur:
        cur["current"] = True
    return out


def find_cover(appid):
    base = os.path.join(STEAM, "appcache/librarycache")
    pats = [
        f"{appid}/library_600x900*.jpg", f"{appid}/*/library_600x900*.jpg",
        f"{appid}_library_600x900*.jpg",
        f"{appid}/library_capsule.jpg", f"{appid}/*/library_capsule.jpg",
        f"{appid}/header.jpg", f"{appid}/*/header.jpg", f"{appid}/*/library_header.jpg",
        f"{appid}_header.jpg",
    ]
    for p in pats:
        hits = sorted(glob.glob(os.path.join(base, p)))
        if hits:
            return hits[0]
    return ""


def library_paths():
    paths = {os.path.join(STEAM, "steamapps")}
    lf = read_vdf(os.path.join(STEAM, "steamapps/libraryfolders.vdf"))
    for v in ci(lf, "libraryfolders").values():
        p = v.get("path") if isinstance(v, dict) else v
        if isinstance(p, str):
            paths.add(os.path.join(p, "steamapps"))
    return sorted(paths)


def steam_games(current):
    played = {}
    if current:
        lc = read_vdf(os.path.join(STEAM, "userdata", str(current["accountid"]), "config/localconfig.vdf"))
        played = ci(lc, "UserLocalConfigStore", "Software", "Valve", "Steam", "apps")
        if not isinstance(played, dict):
            played = {}
    games, seen = [], set()
    for lib in library_paths():
        for mf in glob.glob(os.path.join(lib, "appmanifest_*.acf")):
            st = ci(read_vdf(mf), "AppState")
            appid, name = st.get("appid", ""), st.get("name", "")
            if not appid or not name or appid in seen or NOT_GAMES.search(name):
                continue
            seen.add(appid)
            pl = ci(played, appid)
            pl = pl if isinstance(pl, dict) else {}
            games.append({
                "id": "steam:" + appid, "source": "steam", "name": name,
                "cover": find_cover(appid), "sizeBytes": to_int(st.get("SizeOnDisk")),
                "lastPlayed": max(to_int(pl.get("LastPlayed")), to_int(st.get("LastPlayed"))),
                "playMinutes": to_int(pl.get("Playtime")),
                "launch": ["steam", "steam://rungameid/" + appid],
            })
    return games


# ---- Faugus / Prism --------------------------------------------------------

def to_int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


def dir_size(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            try:
                total += os.lstat(os.path.join(root, f)).st_size
            except OSError:
                pass
    return total


def faugus_games():
    try:
        with open(os.path.join(FAUGUS, "games.json"), encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return []
    out = []
    for g in data if isinstance(data, list) else []:
        gid = g.get("gameid")
        if not gid or g.get("hidden") is True or g.get("category"):
            continue
        cover = g.get("cover") or ""
        out.append({
            "id": "faugus:" + gid, "source": "faugus", "name": (g.get("title") or gid).strip(),
            "cover": cover if cover and os.path.exists(cover) else "",
            "sizeBytes": 0, "lastPlayed": 0, "playMinutes": to_int(g.get("playtime")) // 60,
            "launch": ["faugus-launcher", "--game", gid],
        })
    return out


def prism_games():
    out = []
    for cfg in glob.glob(os.path.join(PRISM, "*/instance.cfg")):
        d = os.path.dirname(cfg)
        kv = {}
        try:
            with open(cfg, encoding="utf-8", errors="replace") as f:
                for line in f:
                    if "=" in line and not line.startswith("["):
                        k, _, v = line.rstrip("\n").partition("=")
                        kv.setdefault(k, v)
        except OSError:
            continue
        icon = os.path.join(d, "icon.png")
        dirname = os.path.basename(d)
        out.append({
            "id": "prism:" + dirname, "source": "prism", "name": kv.get("name") or dirname,
            "cover": icon if os.path.exists(icon) else "", "sizeBytes": dir_size(d),
            "lastPlayed": to_int(kv.get("lastLaunchTime")) // 1000,
            "playMinutes": to_int(kv.get("totalTimePlayed")) // 60,
            "launch": ["prismlauncher", "-l", dirname],
        })
    return out


def cmd_list():
    accts = accounts_info()
    cur = next((a for a in accts if a["current"]), None)
    games = steam_games(cur) + faugus_games() + prism_games()
    print(json.dumps({"accounts": accts, "games": games}))


# ---- Account switching -----------------------------------------------------

def set_auto_login(text, account):
    """Replace the AutoLoginUser value in registry.vdf text; add it if missing."""
    pat = re.compile(r'("AutoLoginUser"\s+)"[^"]*"')
    if pat.search(text):
        return pat.sub(lambda m: m.group(1) + '"' + account + '"', text, count=1)
    # insert before the closing of the Valve > Steam block: after SteamPath/first key of HKCU Steam
    m = re.search(r'("HKCU".*?"Steam"\s*\{[ \t]*\r?\n)', text, re.S)
    if m:
        return text[:m.end()] + '\t\t\t\t\t"AutoLoginUser"\t\t"' + account + '"\n' + text[m.end():]
    return text


def set_most_recent(text, account):
    """Set MostRecent "1" for `account` and "0" for the others, editing values in place."""
    out, pos = [], 0
    for m in re.finditer(r'(\n[ \t]*"\d{17}"\s*\n[ \t]*\{)(.*?)(\n[ \t]*\})', text, re.S):
        body = m.group(2)
        am = re.search(r'"AccountName"\s+"([^"]*)"', body)
        want = "1" if am and am.group(1) == account else "0"
        if re.search(r'"MostRecent"\s+"[^"]*"', body):
            body = re.sub(r'("MostRecent"\s+)"[^"]*"', lambda k: k.group(1) + '"' + want + '"', body, count=1)
        else:
            body += '\n\t\t"MostRecent"\t\t"' + want + '"'
        out.append(text[pos:m.start(2)])
        out.append(body)
        pos = m.end(2)
    out.append(text[pos:])
    return "".join(out)


def backup_files():
    os.makedirs(BACKUP, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    for p in (REGISTRY, LOGINUSERS):
        if os.path.exists(p):
            shutil.copy2(p, os.path.join(BACKUP, f"{os.path.basename(p)}.{stamp}"))


def edit_file(path, fn, account):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    new = fn(text, account)
    if new != text:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new)


def steam_running():
    return subprocess.run(["pgrep", "-x", "steam"], capture_output=True).returncode == 0


def cmd_switch(account):
    if not re.fullmatch(r"[A-Za-z0-9_.\-]{1,64}", account):
        print(json.dumps({"ok": False, "note": "invalid account name"}))
        return
    known = any(u.get("AccountName") == account for u in steam_accounts().values())
    backup_files()
    edit_file(REGISTRY, set_auto_login, account)
    if known:
        edit_file(LOGINUSERS, set_most_recent, account)
    if steam_running():
        subprocess.run(["steam", "-shutdown"], capture_output=True)
        for _ in range(40):
            if not steam_running():
                break
            time.sleep(0.5)
    subprocess.Popen(["steam"], start_new_session=True, stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    note = "restarting Steam" if known else "account not remembered: Steam will ask you to log in"
    print(json.dumps({"ok": True, "note": note}))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        cmd_list()
    elif len(sys.argv) >= 3 and sys.argv[1] == "switch":
        cmd_switch(sys.argv[2])
    else:
        print("usage: games.py list | switch <account>", file=sys.stderr)
        sys.exit(2)

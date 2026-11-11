#!/usr/bin/env python3
"""Process sampler for the tasks overlay.

Usage: procs.py [interval_ms=1500]
Prints one JSON line per sample on stdout:
  {"procs":[{pid,ppid,name,user,uid,cpu,mem,gpu,vram,cmd}], "totals":{ncpu,memTotal,memUsed}}
cpu is a percentage where 100 = all cores busy (tick deltas between samples),
mem is RSS in bytes, gpu is the GFX engine percentage and vram bytes from
amdgpu_top fdinfo (0 when amdgpu_top is missing). Kernel threads are skipped.
"""
import json, os, pwd, subprocess, sys, threading, time

interval = (int(sys.argv[1]) if len(sys.argv) > 1 else 1500) / 1000.0
HZ = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
NCPU = os.cpu_count() or 1

gpu_lock = threading.Lock()
gpu_usage = {}  # pid -> (gfx percent, vram bytes)


def gpu_reader():
    """Follow `amdgpu_top -J` and keep the newest per-process fdinfo."""
    global gpu_usage
    try:
        p = subprocess.Popen(
            ["amdgpu_top", "-J", "--no-pc", "-s", str(int(interval * 1000)), "-u", "2"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except OSError:
        return
    for line in p.stdout:
        try:
            devs = json.loads(line).get("devices") or []
        except ValueError:
            continue
        cur = {}
        for d in devs:
            for pid, info in (d.get("fdinfo") or {}).items():
                u = (info.get("usage") or {}).get("usage") or {}
                gfx = (u.get("GFX") or {}).get("value", 0) or 0
                vram = ((u.get("VRAM") or {}).get("value", 0) or 0) * 1048576
                g0, v0 = cur.get(int(pid), (0, 0))
                cur[int(pid)] = (max(g0, gfx), v0 + vram)
        with gpu_lock:
            gpu_usage = cur


threading.Thread(target=gpu_reader, daemon=True).start()

users = {}
static = {}  # pid -> (starttime, name, uid, user, cmd)
prev = {}    # pid -> ticks
prev_t = time.monotonic()


def user_of(uid):
    if uid not in users:
        try:
            users[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            users[uid] = str(uid)
    return users[uid]


def meminfo():
    total = avail = 0
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith("MemTotal:"):
                total = int(line.split()[1]) * 1024
            elif line.startswith("MemAvailable:"):
                avail = int(line.split()[1]) * 1024
                break
    return total, total - avail


def sample():
    global prev, prev_t
    now = time.monotonic()
    dt = max(now - prev_t, 0.001)
    prev_t = now
    with gpu_lock:
        gu = gpu_usage
    out, ticks, seen = [], {}, set()
    for ent in os.listdir("/proc"):
        if not ent.isdigit():
            continue
        pid = int(ent)
        try:
            with open("/proc/%d/stat" % pid) as f:
                s = f.read()
            r = s.rindex(")")
            f2 = s[r + 2:].split()
            ppid, t, start = int(f2[1]), int(f2[11]) + int(f2[12]), f2[19]
            st = static.get(pid)
            if st is None or st[0] != start:
                with open("/proc/%d/cmdline" % pid, "rb") as f:
                    cmd = f.read().replace(b"\0", b" ").decode("utf-8", "replace").strip()
                uid = os.stat("/proc/%d" % pid).st_uid
                st = (start, s[s.index("(") + 1:r], uid, user_of(uid), cmd[:240])
                static[pid] = st
            if st[4] == "":
                continue  # kernel thread
            with open("/proc/%d/statm" % pid) as f:
                rss = int(f.read().split()[1]) * PAGE
        except (OSError, ValueError, IndexError):
            continue
        seen.add(pid)
        ticks[pid] = t
        cpu = 0.0
        if pid in prev:
            cpu = max(0.0, (t - prev[pid]) / HZ / dt * 100 / NCPU)
        g = gu.get(pid, (0, 0))
        out.append({"pid": pid, "ppid": ppid, "name": st[1], "user": st[3], "uid": st[2],
                    "cpu": round(cpu, 2), "mem": rss, "gpu": g[0], "vram": g[1], "cmd": st[4]})
    for pid in list(static):
        if pid not in seen:
            del static[pid]
    prev = ticks
    total, used = meminfo()
    return {"procs": out, "totals": {"ncpu": NCPU, "memTotal": total, "memUsed": used, "uid": os.getuid()}}


while True:
    try:
        sys.stdout.write(json.dumps(sample(), separators=(",", ":")) + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        break
    time.sleep(interval)

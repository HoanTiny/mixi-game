#!/usr/bin/env python3
"""Kiểm tra một file dữ liệu sau khi chuyển truyện sang phố cổ Hà Nội (docs/HA_NOI.md):
- cấu trúc khớp bản gốc trong git (cùng khóa, cùng số phần tử, số và giá trị không phải chuỗi giữ nguyên, chuỗi mã
  như id/loc/flag giữ nguyên);
- không còn tên, từ cũ miền Nam (bảng CAM) trong chuỗi hiện ra.
Chạy: python3 tools/check_hanoi.py data/events.json [data/story.json ...] [--ref=HEAD]
"""
import json
import re
import subprocess
import sys

CAM = [r"Bờ Me", r"Cầu Nhỏ", r"Bến Cạn", r"Hẻm Dừa", r"Cầu Tre", r"[Bb]à Tư\b", r"[Cc]hú Sáu", r"[Dd]ì Năm",
       r"[Ôô]ng Ba\b", r"[Cc]ô Bảy", r"[Cc]ô Tám", r"[Bb]à Hai\b", r"[Cc]hị Hai\b", r"[Bb]à Bảy", r"[Cc]ô Út",
       r"[Bb]é Bắp", r"\bBắp\b", r"\b[Hh]ẻm\b", r"\b[Mm]á\b", r"\bvô\b", r"\bhông\b", r"\btui\b", r"\bnghen\b",
       r"\bthiệt\b", r"\bổng\b", r"\bbả\b", r"Long An", r"Cần Giuộc", r"Bến Tre", r"miền Tây", r"\bdĩa\b",
       r"\bve chai\b", r"\brạch\b", r"\bAn Hòa\b", r"tiệm Sáu", r"[Ôô]ng Tư\b"]
# Khóa mà giá trị chuỗi là mã (giữ nguyên).
CODE_KEYS = {"id", "loc", "location", "map", "kind", "group", "minigame", "route", "mode", "npc", "next", "goto",
             "queue", "home", "place", "slot", "rb", "head", "sex", "type", "linh_wish", "linh_decision", "action",
             "quest_start", "event", "scene", "icon", "sound", "key", "requires", "item", "items", "need_items"}
CODE_RE = re.compile(r"^[a-z0-9_.:\-]+$")


def walk(a, b, path, errs):
    if type(a) is not type(b):
        errs.append(f"{path}: kiểu đổi {type(a).__name__} -> {type(b).__name__}")
        return
    if isinstance(a, dict):
        if set(a) != set(b):
            errs.append(f"{path}: khóa đổi, thiếu {sorted(set(a) - set(b))[:5]}, thêm {sorted(set(b) - set(a))[:5]}")
        for k in a:
            if k in b:
                walk(a[k], b[k], f"{path}.{k}", errs)
    elif isinstance(a, list):
        if len(a) != len(b):
            errs.append(f"{path}: số phần tử {len(a)} -> {len(b)}")
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, f"{path}[{i}]", errs)
    elif isinstance(a, str):
        key = path.rsplit(".", 1)[-1]
        if (key in CODE_KEYS or CODE_RE.match(a)) and a != b and not key.startswith("_"):
            # Chuỗi mã (không dấu, không khoảng trắng) phải giữ nguyên.
            if CODE_RE.match(a):
                errs.append(f"{path}: chuỗi mã đổi {a!r} -> {b!r}")
        for ph in re.findall(r"\{[^}]*\}", a):
            if ph not in b:
                errs.append(f"{path}: mất chỗ giữ chỗ {ph}")
        if a and b and not key.startswith("_") and len(a) > 40:
            r = len(b) / len(a)
            if r < 0.6 or r > 1.6:
                errs.append(f"{path}: độ dài đổi nhiều ({len(a)} -> {len(b)})")
    elif a != b:
        errs.append(f"{path}: giá trị đổi {a!r} -> {b!r}")


def strings(x, path=""):
    if isinstance(x, dict):
        for k, v in x.items():
            yield from strings(v, f"{path}.{k}")
    elif isinstance(x, list):
        for i, v in enumerate(x):
            yield from strings(v, f"{path}[{i}]")
    elif isinstance(x, str):
        yield path, x


def main():
    ref = "HEAD"
    files = []
    for a in sys.argv[1:]:
        if a.startswith("--ref="):
            ref = a[6:]
        else:
            files.append(a)
    bad = 0
    for f in files:
        new = json.load(open(f, encoding="utf-8"))
        try:
            old = json.loads(subprocess.check_output(["git", "show", f"{ref}:{f}"]))
        except subprocess.CalledProcessError:
            old = None
        errs = []
        if old is not None:
            walk(old, new, "", errs)
        for p, s in strings(new):
            key = re.sub(r"\[\d+\]$", "", p).rsplit(".", 1)[-1]
            if key.startswith("_") or (key in CODE_KEYS and CODE_RE.match(s)):
                continue
            for pat in CAM:
                m = re.search(pat, s)
                if m:
                    errs.append(f"{p}: còn từ cũ {m.group(0)!r}: …{s[max(0, m.start() - 30):m.end() + 30]}…")
        if errs:
            bad += 1
            print(f"{f}: {len(errs)} lỗi")
            for e in errs[:60]:
                print("  ", e)
        else:
            print(f"{f}: OK")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()

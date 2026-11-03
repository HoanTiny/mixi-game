"""Việt hoá ảnh người thật Rocketbox (assets/rb): đưa màu da mặt và da thân (tay, chân, cổ) về cùng một tông da
người Việt để ghép đầu người này lên thân người kia không lệch màu; làm thêm bản tóc bạc (head_grey.jpg,
opacity_grey.png) cho đầu dùng làm ông bà, bản tóc đen cho đầu tóc nâu.

Chạy một lần trên ảnh gốc vừa tải từ Rocketbox (python3 tools/viet_look.py); ảnh gốc giữ ở <thư mục>/orig/ (Godot bỏ qua) nên
chạy lại vẫn ra cùng kết quả.
"""

import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "rb")
# Tông da đích (sRGB): da ngăm sáng của người miền Nam.
SKIN = np.array([196.0, 146.0, 112.0])
# Đầu làm thêm bản tóc bạc, bản tóc đen.
GREY = ["Business_Female_03", "Business_Male_02", "Male_Adult_10"]
BLACK = ["Male_Child_01"]


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)


def face_ref(head):
    """Màu da mặt: trung vị vùng má, trán giữa ảnh đầu (mặt nằm giữa phía trên)."""
    h, w, _ = head.shape
    patch = head[int(h * 0.22):int(h * 0.40), int(w * 0.40):int(w * 0.60)].reshape(-1, 3)
    lum = patch.mean(axis=1)
    keep = patch[(lum > np.percentile(lum, 30)) & (lum < np.percentile(lum, 90))]
    return np.median(keep, axis=0)


def skin_mask(img, ref):
    """Độ giống da (0..1): sắc độ gần màu da mặt, sáng tối trong khoảng 0,35–1,6 lần."""
    s = img.sum(axis=2, keepdims=True) + 1e-3
    chroma = img[..., :2] / s
    rc = ref[:2] / ref.sum()
    d = np.sqrt(((chroma - rc) ** 2).sum(axis=2))
    ratio = img.mean(axis=2) / ref.mean()
    m = np.clip(1.0 - (d - 0.018) / 0.03, 0.0, 1.0)
    m *= np.clip((ratio - 0.3) / 0.1, 0.0, 1.0) * np.clip((1.75 - ratio) / 0.15, 0.0, 1.0)
    return m[..., None]


def retone(img, ref, mask):
    out = img * (SKIN / ref)
    return np.clip(img * (1.0 - mask) + out * mask, 0, 255)


def hair_mask(head, ref):
    """Tóc vẽ trên ảnh đầu: không phải da, tối, nửa trên ảnh (mắt, miệng nằm phía dưới)."""
    h, w = head.shape[:2]
    m = (1.0 - skin_mask(head, ref)[..., 0]) * (head.mean(axis=2) < 120)
    m[int(h * 0.48):] = 0.0
    # Chừa mặt (hình bầu dục giữa ảnh, gồm mắt, mày, cằm) và cổ.
    yy, xx = np.mgrid[0:h, 0:w]
    face = ((xx / w - 0.5) / 0.19) ** 2 + ((yy / h - 0.45) / 0.17) ** 2 < 1.0
    neck = (np.abs(xx / w - 0.5) < 0.22) & (yy / h > 0.42)
    m[face | neck] = 0.0
    return m[..., None]


def recolor_hair(img, mask, grey):
    lum = img.mean(axis=2, keepdims=True)
    if grey:
        new = np.clip(70.0 + lum * 1.05, 0, 215) * np.array([1.0, 1.0, 0.97])
    else:
        new = lum * 0.45 * np.array([1.0, 0.93, 0.88])
    return np.clip(img * (1.0 - mask) + new * mask, 0, 255)


def save(arr, path, alpha=None):
    im = Image.fromarray(arr.astype(np.uint8), "RGB")
    if alpha is not None:
        im.putalpha(alpha)
        im.save(path, optimize=True)
    else:
        im.save(path, quality=88)


def main():
    for name in sorted(os.listdir(ROOT)):
        d = os.path.join(ROOT, name)
        if not os.path.isfile(os.path.join(d, name + ".fbx")):
            continue
        orig = os.path.join(d, "orig")
        os.makedirs(orig, exist_ok=True)
        # Godot bỏ qua thư mục ảnh gốc (khỏi nhập, khỏi đóng gói).
        open(os.path.join(orig, ".gdignore"), "w").close()
        for f in ("head_color.jpg", "body_color.jpg", "opacity_color.png"):
            if os.path.exists(os.path.join(d, f)) and not os.path.exists(os.path.join(orig, f)):
                shutil.copy(os.path.join(d, f), os.path.join(orig, f))
        if not os.path.exists(os.path.join(orig, "head_color.jpg")):
            continue
        head = load(os.path.join(orig, "head_color.jpg"))
        ref = face_ref(head)
        body = load(os.path.join(orig, "body_color.jpg"))
        save(retone(body, ref, skin_mask(body, ref)), os.path.join(d, "body_color.jpg"))
        toned = retone(head, ref, skin_mask(head, ref))
        if name in BLACK:
            toned = recolor_hair(toned, hair_mask(head, ref), False)
        save(toned, os.path.join(d, "head_color.jpg"))
        op = None
        if os.path.exists(os.path.join(orig, "opacity_color.png")):
            op = Image.open(os.path.join(orig, "opacity_color.png")).convert("RGBA")
            rgb = np.asarray(op.convert("RGB"), dtype=np.float32)
            if name in BLACK:
                save(recolor_hair(rgb, np.ones(rgb.shape[:2] + (1,)), False), os.path.join(d, "opacity_color.png"),
                     op.getchannel("A"))
        if name in GREY:
            save(recolor_hair(toned, hair_mask(head, ref), True), os.path.join(d, "head_grey.jpg"))
            if op is not None:
                rgb = np.asarray(op.convert("RGB"), dtype=np.float32)
                save(recolor_hair(rgb, np.ones(rgb.shape[:2] + (1,)), True), os.path.join(d, "opacity_grey.png"),
                     op.getchannel("A"))
        print("%-22s da mặt %s" % (name, ref.astype(int)))


if __name__ == "__main__":
    sys.exit(main())

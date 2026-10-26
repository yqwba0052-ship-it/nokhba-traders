"""Builds design/icon_square.png and design/icon_foreground.png for flutter_launcher_icons.

- If design/icon.png exists: crops it to the glass square (the region that differs from the
  background colour of the image's border), makes it square and writes both files.
- Otherwise: draws a temporary glass icon.

Run (OpenCV venv):  cvpy tool/make_icon.py
Then:               dart run flutter_launcher_icons
"""

import pathlib

import cv2
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
DESIGN = ROOT / "design"
SIZE = 1024


def crop_to_glass_square(img):
    """Bounding box of everything that differs clearly from the border colour."""
    bgr = img[:, :, :3].astype(np.int16)
    h, w = bgr.shape[:2]
    border = np.concatenate([bgr[0], bgr[-1], bgr[:, 0], bgr[:, -1]])
    bg = np.median(border, axis=0)
    diff = np.abs(bgr - bg).sum(axis=2)
    mask = (diff > 40).astype(np.uint8)
    if img.shape[2] == 4:
        mask &= (img[:, :, 3] > 20).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return img
    x, y, cw, ch = cv2.boundingRect(max(contours, key=cv2.contourArea))
    side = max(cw, ch)
    cx, cy = x + cw // 2, y + ch // 2
    x0 = max(0, min(w - side, cx - side // 2))
    y0 = max(0, min(h - side, cy - side // 2))
    return img[y0 : y0 + side, x0 : x0 + side]


def draw_temporary(transparent_bg):
    s = SIZE
    if transparent_bg:
        img = np.zeros((s, s, 4), np.uint8)
    else:
        yy, xx = np.mgrid[0:s, 0:s].astype(np.float32) / s
        t = (xx + yy) / 2
        top = np.array([0x20, 0x12, 0x0B], np.float32)  # #0B1220 (BGR)
        bottom = np.array([0x8B, 0x3A, 0x4C], np.float32)  # deep violet
        rgb = top * (1 - t[..., None]) + bottom * t[..., None]
        img = np.dstack([rgb, np.full((s, s), 255, np.float32)]).astype(np.uint8)

    # glass square: soft glow, translucent white body, purple/blue edge
    pad = int(s * (0.2 if transparent_bg else 0.14))
    r = int(s * 0.12)
    layer = np.zeros_like(img)

    def rounded(target, inset, color, thickness=-1):
        x0, y0, x1, y1 = pad + inset, pad + inset, s - pad - inset, s - pad - inset
        rr = max(1, r - inset)
        for cx, cy in [(x0 + rr, y0 + rr), (x1 - rr, y0 + rr), (x0 + rr, y1 - rr), (x1 - rr, y1 - rr)]:
            cv2.circle(target, (cx, cy), rr, color, thickness, cv2.LINE_AA)
        if thickness < 0:
            cv2.rectangle(target, (x0 + rr, y0), (x1 - rr, y1), color, -1, cv2.LINE_AA)
            cv2.rectangle(target, (x0, y0 + rr), (x1, y1 - rr), color, -1, cv2.LINE_AA)

    glow = np.zeros_like(img)
    rounded(glow, -10, (0xFA, 0x8B, 0xA7, 200))
    glow = cv2.GaussianBlur(glow, (0, 0), 28)
    rounded(layer, 0, (0xFA, 0xA5, 0x60, 255))  # blue edge (#60A5FA)
    rounded(layer, 10, (0xF0, 0xE6, 0xF5, 255))  # glass body
    body_alpha = 0.55

    def blend(dst, src, alpha):
        a = (src[:, :, 3:4].astype(np.float32) / 255) * alpha
        dst[:, :, :3] = (dst[:, :, :3] * (1 - a) + src[:, :, :3] * a).astype(np.uint8)
        dst[:, :, 3] = np.maximum(dst[:, :, 3], (a[:, :, 0] * 255).astype(np.uint8))

    blend(img, glow, 0.9)
    blend(img, layer, body_alpha)

    # rising chart line (sky blue) and a gold star
    pts = np.array(
        [[0.30, 0.66], [0.42, 0.56], [0.52, 0.61], [0.70, 0.40]], np.float32
    ) * s
    cv2.polylines(img, [pts.astype(np.int32)], False, (0xF8, 0xBD, 0x38, 255), int(s * 0.035), cv2.LINE_AA)
    cx, cy, ro, ri = int(s * 0.70), int(s * 0.34), s * 0.085, s * 0.036
    star = [
        (cx + (ro if k % 2 == 0 else ri) * np.sin(np.pi * k / 5), cy - (ro if k % 2 == 0 else ri) * np.cos(np.pi * k / 5))
        for k in range(10)
    ]
    cv2.fillPoly(img, [np.array(star, np.int32)], (0x15, 0xCC, 0xFA, 255), cv2.LINE_AA)
    return img


def main():
    DESIGN.mkdir(exist_ok=True)
    source = DESIGN / "icon.png"
    if source.exists():
        img = cv2.imread(str(source), cv2.IMREAD_UNCHANGED)
        if img.ndim == 2:
            img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGRA)
        elif img.shape[2] == 3:
            img = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)
        square = cv2.resize(crop_to_glass_square(img), (SIZE, SIZE), interpolation=cv2.INTER_AREA)
        # adaptive foreground: the same picture inside Android's safe zone (66%)
        fg = np.zeros((SIZE, SIZE, 4), np.uint8)
        inner = int(SIZE * 0.66)
        off = (SIZE - inner) // 2
        fg[off : off + inner, off : off + inner] = cv2.resize(square, (inner, inner), interpolation=cv2.INTER_AREA)
        print("cropped", source)
    else:
        square = draw_temporary(transparent_bg=False)
        fg = draw_temporary(transparent_bg=True)
        print("design/icon.png not found: drew a temporary icon")
    cv2.imwrite(str(DESIGN / "icon_square.png"), square)
    cv2.imwrite(str(DESIGN / "icon_foreground.png"), fg)
    print("wrote", DESIGN / "icon_square.png", "and", DESIGN / "icon_foreground.png")


if __name__ == "__main__":
    main()

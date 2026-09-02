# -*- coding: utf-8 -*-
"""生成 Google Play 商店素材：应用图标 512x512 + Feature Graphic 1024x500。
品牌视觉与 android adaptive icon 保持一致：
- 背景：深靛蓝渐变 #1E293B -> #0F172A
- 时钟圆环：白色描边；指针：金色 #F59E0B + 白色；中心：金色圆点
- 三条横线：账单/清单表达（白 -> 半透明白）
"""
from PIL import Image, ImageDraw, ImageFont
import math

SLATE_DARK = (15, 23, 42)     # #0F172A
SLATE_LIGHT = (30, 41, 59)    # #1E293B
AMBER = (245, 158, 11)        # #F59E0B
WHITE = (255, 255, 255)
WHITE_66 = (255, 255, 255, 168)
WHITE_40 = (255, 255, 255, 102)


def vertical_gradient(size, top, bottom):
    """生成垂直渐变图像（也可用对角，Play 上对角更立体）。"""
    w, h = size
    img = Image.new('RGB', size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        for x in range(w):
            px[x, y] = (r, g, b)
    return img


def draw_clock(draw, cx, cy, radius, line_w):
    """时钟 + 三条横线，参数均为目标画布坐标。"""
    # 时钟外圈
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                 outline=WHITE, width=line_w)
    # 指针：12 点金色短针、3 点白色长针
    draw.line([cx, cy, cx, cy - radius * 0.55], fill=AMBER, width=max(2, line_w - 1))
    draw.line([cx, cy, cx + radius * 0.7, cy], fill=WHITE, width=max(2, line_w - 1))
    # 中心点
    dot_r = max(2, radius * 0.09)
    draw.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=AMBER)
    # 三条横线（时钟下方，账单/清单）
    lw = max(2, line_w - 2)
    y0 = cy + radius * 0.62
    draw.line([cx - radius * 0.62, y0, cx + radius * 0.62, y0], fill=WHITE, width=lw)
    draw.line([cx - radius * 0.62, y0 + radius * 0.28, cx + radius * 0.38, y0 + radius * 0.28], fill=WHITE_66, width=lw)
    draw.line([cx - radius * 0.62, y0 + radius * 0.56, cx + radius * 0.16, y0 + radius * 0.56], fill=WHITE_40, width=lw)


# ---------- 1. 应用图标 512x512 ----------
S = 512
icon = vertical_gradient((S, S), SLATE_LIGHT, SLATE_DARK)
# 圆角遮罩
mask = Image.new('L', (S, S), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=255)
icon.putalpha(mask)

# 装饰光晕（右下角，与 adaptive icon 一致）
glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.pieslice([S * 0.55, S * 0.55, S * 1.1, S * 1.1], 270, 360, fill=(245, 158, 11, 38))
icon = Image.alpha_composite(icon.convert('RGBA'), glow)

# 时钟图形：内容占安全区（约 62% 画布）
draw = ImageDraw.Draw(icon)
center = S * 0.50
clock_r = S * 0.20
draw_clock(draw, center, center - S * 0.02, clock_r, line_w=int(S * 0.028))
icon.save(r'C:\dev\freelance_hub\deploy\play-store-icon-512.png')
print('icon saved')

# ---------- 2. Feature Graphic 1024x500 ----------
W, H = 1024, 500
fg = vertical_gradient((W, H), SLATE_LIGHT, SLATE_DARK)
# 柔光晕：右下角低 alpha 圆，由两个 ellipses 叠加实现
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([W * 0.55, H * 0.05, W * 1.30, H * 0.80], fill=(245, 158, 11, 42))
gd.ellipse([W * 0.75, H * 0.30, W * 1.15, H * 0.70], fill=(245, 158, 11, 72))
fg = Image.alpha_composite(fg.convert('RGBA'), glow)

# 左侧直接绘制白色 + 金色时钟（在深蓝底上对比强，无需白卡）
draw = ImageDraw.Draw(fg)
clock_cx = 230
clock_cy = 250
draw_clock(draw, clock_cx, clock_cy + 8, radius=140, line_w=14)

# 文案（右侧）：品牌名 + 标语
try:
    title_font = ImageFont.truetype('arial.ttf', 68)
    sub_font = ImageFont.truetype('arial.ttf', 28)
except OSError:
    title_font = ImageFont.load_default()
    sub_font = ImageFont.load_default()

tx = 430
ty = 200
draw.text((tx, ty), 'Freelance Hub', font=title_font, fill=WHITE)
slogan1 = 'Track billable hours, expenses'
slogan2 = '& tax deductions - offline first'
draw.text((tx, ty + 90), slogan1, font=sub_font, fill=(226, 232, 240))
draw.text((tx, ty + 132), slogan2, font=sub_font, fill=(226, 232, 240))
fg.save(r'C:\dev\freelance_hub\deploy\play-store-feature-graphic-1024x500.png')
print('feature graphic saved')

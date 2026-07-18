"""端到端测试：代理服务器 → DashScope OSS → 异步试衣 → 返回结果"""
import requests
from PIL import Image, ImageDraw
import io
import base64
import time
import random


def make_test_image(w, h, draw_func, fmt='JPEG', quality=95):
    """生成测试图片，确保文件大小 > 5KB"""
    color_mode = 'RGB' if fmt == 'JPEG' else 'RGBA'
    img = Image.new(color_mode, (w, h), color=(240, 240, 245))
    draw = ImageDraw.Draw(img)
    draw_func(draw, w, h)
    buf = io.BytesIO()
    img.save(buf, format=fmt, quality=quality)
    data = buf.getvalue()
    # 如果太小，加噪点增大文件
    if len(data) < 5120:
        img2 = img.copy()
        draw2 = ImageDraw.Draw(img2)
        for i in range(2000):
            x = random.randint(0, w - 1)
            y = random.randint(0, h - 1)
            c = random.randint(0, 255)
            draw2.point((x, y), fill=(c, c, c))
        buf2 = io.BytesIO()
        img2.save(buf2, format=fmt, quality=quality)
        data = buf2.getvalue()
    return data, img


def draw_person(draw, w, h):
    """画一个简单的人物轮廓"""
    # 头部
    draw.ellipse([w//3 - 10, 20, 2*w//3 + 10, h//5 + 10], fill=(240, 210, 180))
    draw.ellipse([w//3, 30, 2*w//3, h//5], fill=(250, 220, 190))
    # 脖子
    draw.rectangle([w//3 + 30, h//5, 2*w//3 - 30, h//4], fill=(240, 210, 180))
    # 身体/上衣
    draw.rectangle([w//4, h//4, 3*w//4, 3*h//5], fill=(90, 130, 210))
    # 手臂
    draw.rectangle([w//6, h//4, w//4, 3*h//5], fill=(85, 125, 200))
    draw.rectangle([3*w//4, h//4, 5*w//6, 3*h//5], fill=(85, 125, 200))
    # 裤子/腿部
    draw.rectangle([w//3, 3*h//5, w//2 - 15, 9*h//10], fill=(60, 80, 140))
    draw.rectangle([w//2 + 15, 3*h//5, 2*w//3, 9*h//10], fill=(60, 80, 140))
    # 鞋子
    draw.ellipse([w//3 - 10, 9*h//10 - 20, w//2 - 5, 9*h//10 + 20], fill=(40, 40, 40))
    draw.ellipse([w//2 + 5, 9*h//10 - 20, 2*w//3 + 10, 9*h//10 + 20], fill=(40, 40, 40))
    # 背景纹理增加文件大小
    for i in range(300):
        x = random.randint(0, w - 1)
        y = random.randint(0, h - 1)
        r = random.randint(200, 250)
        draw.point((x, y), fill=(r, r, r + 5))


def draw_cloth(draw, w, h):
    """画一件简单的上衣"""
    margin = 80
    # T恤主体
    draw.polygon([
        (w//4, margin),
        (3*w//4, margin),
        (4*w//5, 3*h//5),
        (3*w//5, h - margin),
        (2*w//5, h - margin),
        (w//5, 3*h//5),
    ], fill=(220, 60, 50), outline=(180, 40, 40))
    # 领口（镂空）
    draw.ellipse([w//3, 30, 2*w//3, h//5], fill=(0, 0, 0, 0))
    # 纹理
    for i in range(200):
        x = random.randint(0, w - 1)
        y = random.randint(0, h - 1)
        r = random.randint(200, 230)
        draw.point((x, y), fill=(r, 80, 70))


def main():
    # ── 生成测试图片 ──
    print("Generating test images...")
    body_bytes, _ = make_test_image(768, 1024, draw_person, 'JPEG')
    print(f"  Body image: {len(body_bytes)} bytes ({len(body_bytes)/1024:.1f} KB)")

    cloth_img = Image.new('RGBA', (600, 600), color=(0, 0, 0, 0))
    draw_c = ImageDraw.Draw(cloth_img)
    draw_cloth(draw_c, 600, 600)
    cloth_buf = io.BytesIO()
    cloth_img.save(cloth_buf, format='PNG')
    cloth_bytes = cloth_buf.getvalue()
    # 确保 > 5KB
    if len(cloth_bytes) < 5120:
        draw_c2 = ImageDraw.Draw(cloth_img)
        for i in range(3000):
            x = random.randint(0, 599)
            y = random.randint(0, 599)
            if cloth_img.getpixel((x, y))[3] > 0:
                r = random.randint(180, 240)
                draw_c2.point((x, y), fill=(r, 60, 50, 255))
        cloth_buf2 = io.BytesIO()
        cloth_img.save(cloth_buf2, format='PNG')
        cloth_bytes = cloth_buf2.getvalue()
    print(f"  Cloth image: {len(cloth_bytes)} bytes ({len(cloth_bytes)/1024:.1f} KB)")

    # ── 健康检查 ──
    print("\n--- Health Check ---")
    try:
        health = requests.get('http://localhost:8080/api/health', timeout=5)
        print(f"  {health.json()}")
    except Exception as e:
        print(f"  FAILED: {e}")
        print("  Start proxy: python tools/ai_proxy_server.py")
        return

    # ── 调用试衣 ──
    print("\n=== Calling /api/try-on (expect ~90 seconds) ===")
    t0 = time.time()

    try:
        resp = requests.post(
            'http://localhost:8080/api/try-on',
            files={
                'body_image': ('body.jpg', body_bytes, 'image/jpeg'),
                'cloth_image': ('cloth.png', cloth_bytes, 'image/png'),
            },
            data={'category': 'upper_body'},
            timeout=200,
        )
        elapsed = time.time() - t0
        print(f"Response: HTTP {resp.status_code}, elapsed: {elapsed:.1f}s")

        if resp.status_code == 200:
            data = resp.json()
            if data.get('success'):
                result_bytes = base64.b64decode(data['image_base64'])
                output_path = 'tryon_test_result.png'
                with open(output_path, 'wb') as f:
                    f.write(result_bytes)
                print(f"\n{'='*50}")
                print(f"  ✅ SUCCESS!")
                print(f"  Result: {output_path} ({len(result_bytes)} bytes, {len(result_bytes)/1024:.1f} KB)")
                print(f"  Server time: {data.get('elapsed_seconds', '?')}s")
                print(f"{'='*50}")
            else:
                print(f"  ❌ FAILED: {data}")
        else:
            print(f"  ❌ ERROR: {resp.text[:600]}")
    except requests.Timeout:
        print(f"  ❌ TIMEOUT after {time.time()-t0:.0f}s")
    except Exception as e:
        print(f"  ❌ EXCEPTION: {e}")


if __name__ == '__main__':
    main()

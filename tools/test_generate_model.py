"""Test /api/generate-model endpoint"""
import requests
from PIL import Image, ImageDraw
import io
import base64
import time
import random


def make_person_image():
    """Generate a simple person photo for testing"""
    w, h = 768, 1024
    img = Image.new('RGB', (w, h), color=(200, 220, 230))
    draw = ImageDraw.Draw(img)

    # Background noise (simulate real photo texture)
    for i in range(500):
        x = random.randint(0, w - 1)
        y = random.randint(0, h - 1)
        r = random.randint(180, 255)
        draw.point((x, y), fill=(r, r - 10, r + 5))

    # Head
    draw.ellipse([w//3 - 20, 30, 2*w//3 + 20, h//5 + 30], fill=(230, 200, 170))
    draw.ellipse([w//3, 50, 2*w//3, h//5 + 10], fill=(245, 215, 185))
    # Eyes
    draw.ellipse([w//3 + 30, h//10, w//2 - 20, h//8], fill=(255, 255, 255))
    draw.ellipse([w//2 + 20, h//10, 2*w//3 - 30, h//8], fill=(255, 255, 255))
    draw.ellipse([w//3 + 50, h//10 + 10, w//2 - 10, h//8 - 5], fill=(40, 40, 40))
    draw.ellipse([w//2 + 30, h//10 + 10, 2*w//3 - 40, h//8 - 5], fill=(40, 40, 40))
    # Mouth
    draw.arc([w//2 - 30, h//6 + 20, w//2 + 30, h//5 + 30], 0, 180, fill=(180, 100, 100), width=3)
    # Hair
    draw.arc([w//3 - 25, 20, 2*w//3 + 25, h//4 + 20], 180, 0, fill=(60, 40, 30), width=15)

    # Neck
    draw.rectangle([w//3 + 20, h//5 + 20, 2*w//3 - 20, h//4 + 10], fill=(225, 195, 165))

    # Body (T-shirt)
    draw.rectangle([w//4, h//4 + 10, 3*w//4, 3*h//5], fill=(70, 110, 190))
    # Arms - slightly bent (non-standard pose)
    draw.polygon([(w//6, h//4), (w//4, h//4 + 10), (w//6 + 20, h//2 + 20), (w//6 - 10, h//2 + 20)], fill=(65, 105, 185))
    draw.polygon([(5*w//6, h//4), (3*w//4, h//4 + 10), (5*w//6 - 20, h//2 + 20), (5*w//6 + 10, h//2 + 20)], fill=(65, 105, 185))

    # Legs (pants)
    draw.rectangle([w//3, 3*h//5, w//2 - 15, 9*h//10], fill=(50, 70, 130))
    draw.rectangle([w//2 + 15, 3*h//5, 2*w//3, 9*h//10], fill=(50, 70, 130))

    # Feet
    draw.ellipse([w//3 - 10, 9*h//10 - 20, w//2 - 5, 9*h//10 + 10], fill=(35, 35, 35))
    draw.ellipse([w//2 + 5, 9*h//10 - 20, 2*w//3 + 10, 9*h//10 + 10], fill=(35, 35, 35))

    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=90)
    return buf.getvalue(), img


def main():
    print("Generating test person image...")
    body_bytes, img = make_person_image()
    print(f"  Input: {len(body_bytes)} bytes ({len(body_bytes)/1024:.1f} KB), {img.size}")

    # Save input for comparison
    img.save('test_input_person.jpg')
    print("  Saved input: test_input_person.jpg")

    print("\n=== Testing /api/generate-model (expect ~30-60s) ===")
    t0 = time.time()

    try:
        resp = requests.post(
            'http://localhost:8080/api/generate-model',
            files={'image': ('body.jpg', body_bytes, 'image/jpeg')},
            timeout=180,
        )
        elapsed = time.time() - t0
        print(f"Response: HTTP {resp.status_code}, elapsed: {elapsed:.1f}s")

        if resp.status_code == 200:
            data = resp.json()
            if data.get('success'):
                result_bytes = base64.b64decode(data['image_base64'])
                output_path = 'test_output_model.jpg'
                with open(output_path, 'wb') as f:
                    f.write(result_bytes)

                # Verify
                result_img = Image.open(io.BytesIO(result_bytes))
                print(f"\n{'='*50}")
                print(f"  SUCCESS")
                print(f"  Output: {output_path}")
                print(f"  Size: {result_img.size}, {len(result_bytes)} bytes ({len(result_bytes)/1024:.1f} KB)")
                print(f"  Server time: {data.get('elapsed_seconds', '?')}s")
                print(f"  Compare: test_input_person.jpg vs test_output_model.jpg")
                print(f"{'='*50}")
            else:
                print(f"  FAILED: {data}")
        else:
            print(f"  ERROR: {resp.text[:600]}")
    except requests.Timeout:
        print(f"  TIMEOUT after {time.time()-t0:.0f}s")
    except Exception as e:
        print(f"  EXCEPTION: {e}")


if __name__ == '__main__':
    main()

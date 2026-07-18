"""Test script: verify Wan2.7 output dimensions match input"""
import sys, os, io, base64, json, time
from pathlib import Path
from PIL import Image
import requests

# Load .env
dotenv_path = Path(__file__).parent.parent / ".env"
if dotenv_path.exists():
    with open(dotenv_path, "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, _, v = line.partition("=")
                os.environ[k.strip()] = v.strip().strip('"').strip("'")

API_KEY = os.environ.get("DASHSCOPE_API_KEY", "")
if not API_KEY:
    print("ERROR: DASHSCOPE_API_KEY not set")
    sys.exit(1)

BASE = "https://dashscope.aliyuncs.com/api/v1"
MODEL = "wan2.7-image-pro"
ENDPOINT = "/services/aigc/multimodal-generation/generation"

# Read test image
test_img_path = Path(__file__).parent.parent / "test_input_person.jpg"
with open(test_img_path, "rb") as f:
    img_bytes = f.read()

img = Image.open(io.BytesIO(img_bytes))
print(f"Input image: {img.size[0]}x{img.size[1]} ({img.size[0]/img.size[1]:.3f} aspect)")

# Compute output size preserving aspect ratio
src_w, src_h = img.size
max_short = 2048
if src_w <= src_h:
    out_w = min(src_w, max_short)
    out_h = int(out_w * src_h / src_w)
else:
    out_h = min(src_h, max_short)
    out_w = int(out_h * src_w / src_h)
size_str = f"{out_w}*{out_h}"
print(f"Requested output size: {size_str} ({out_w/out_h:.3f} aspect)")

# Call Wan2.7
image_b64 = base64.b64encode(img_bytes).decode("utf-8")
prompt = "Keep exactly the same person, same pose, keep all facial features identical. Output must be same aspect ratio as input. Show full body."

payload = {
    "model": MODEL,
    "input": {
        "messages": [{
            "role": "user",
            "content": [
                {"image": f"data:image/jpeg;base64,{image_b64}"},
                {"text": prompt},
            ],
        }],
    },
    "parameters": {
        "size": size_str,
        "n": 1,
        "watermark": False,
    },
}

print(f"\nCalling Wan2.7 API...")
t0 = time.time()
resp = requests.post(
    f"{BASE}{ENDPOINT}",
    json=payload,
    headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
    timeout=120,
)
print(f"HTTP {resp.status_code} ({time.time()-t0:.1f}s)")

if resp.status_code != 200:
    print(f"Error: {resp.text[:500]}")
    sys.exit(1)

result = resp.json()
try:
    img_url = result["output"]["choices"][0]["message"]["content"][0]["image"]
except (KeyError, IndexError):
    print(f"Unexpected response: {json.dumps(result, indent=2)[:500]}")
    sys.exit(1)

# Download result
print(f"Downloading result...")
dl = requests.get(img_url, timeout=30)
print(f"Download: HTTP {dl.status_code}, {len(dl.content)} bytes")

out_img = Image.open(io.BytesIO(dl.content))
print(f"Output image: {out_img.size[0]}x{out_img.size[1]} ({out_img.size[0]/out_img.size[1]:.3f} aspect)")

in_ratio = img.size[0] / img.size[1]
out_ratio = out_img.size[0] / out_img.size[1]
print(f"\n{'✓ ASPECT RATIO MATCH' if abs(in_ratio - out_ratio) < 0.01 else '✗ ASPECT RATIO MISMATCH!'}")
print(f"  Input:  {in_ratio:.4f}")
print(f"  Output: {out_ratio:.4f}")
print(f"  Delta:  {abs(in_ratio - out_ratio):.4f}")

# Save output
out_path = Path(__file__).parent.parent / "test_wan27_output.jpg"
out_img.save(out_path, "JPEG", quality=90)
print(f"\nSaved to: {out_path}")

"""
AI 代理服务器 — v0.6.2
功能：
  GET  /api/health            → 健康检查 + API Key 验证
  POST /api/remove-bg          → rembg 抠图，返回透明 PNG（兼容 JSON/multipart）
  POST /api/enhance-clothing   → 衣服AI增强（rembg抠图→白底合成→Wan2.7产品图）
  POST /api/generate-model     → 身体AI模特化（双模式：拍照img2img + 手动t2i）
  POST /api/try-on             → 虚拟试衣（可选身体预处理→DashScope OSS→异步API→轮询→返回）

generate-model 双模式：
  📷 拍照模式（提供 image + gender + height + weight）：
      rembg去背景 → 合成#F0F0F3 → Wan2.7 img2img（紧身衣+站姿+干净背景）
  📐 手动模式（无 image，提供 gender + height + weight + 三围）：
      Wan2.7 文生图直接生成人物形象

启动方式：
  python tools/ai_proxy_server.py --port 8080

环境变量（支持 .env 文件）：
  DASHSCOPE_API_KEY  阿里云 DashScope API Key（必须）
"""
import argparse
import asyncio
import base64
import io
import os
import sys
import time

# ── Windows UTF-8 编码修复 ──────────────────────────────────
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
from pathlib import Path

import uvicorn
from fastapi import FastAPI, File, Form, UploadFile, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image

# ── 加载 .env ──────────────────────────────────────────────

def load_dotenv(dotenv_path: str = ".env") -> None:
    path = Path(dotenv_path)
    if not path.exists():
        path = Path(__file__).parent.parent / ".env"
    if not path.exists():
        return
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if key and key not in os.environ:
                    os.environ[key] = value

load_dotenv()

import requests as sync_requests

# ── FastAPI ────────────────────────────────────────────────

app = FastAPI(title="OutfitApp AI Proxy", version="0.6.2")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ── 配置 ──────────────────────────────────────────────────

DASHSCOPE_API_KEY = os.environ.get("DASHSCOPE_API_KEY", "")
DASHSCOPE_BASE = "https://dashscope.aliyuncs.com/api/v1"
MODEL = "aitryon-plus"
WAN_MODEL = "wan2.7-image-pro"
WAN_ENDPOINT = "/services/aigc/multimodal-generation/generation"

# ── 衣服增强提示词（Wan2.7 纯正向）───────────────────────────

CLOTHING_ENHANCE_PROMPT = (
    "将这张照片中穿在人物身上的服装完整提取出来，"
    "转化为专业电商服装平铺正面展示产品图。"
    "服装必须完整保留原有的款式结构、领型、袖型、下摆形态、"
    "颜色、印花图案、面料质感和所有设计细节，不得有任何改变。"
    "服装以幽灵模特方式立体展示：服装内部以透明隐形支撑自然填充，"
    "肩部圆润饱满，胸部区域自然隆起，腰部自然收束，"
    "整体呈现出服装穿在透明人体上的立体悬挂效果。"
    "服装正面水平居中构图，领口居中对称，肩线左右平衡，"
    "袖口自然下垂，下摆平整舒展，整体版型端正无歪斜。"
    "纯白色无缝无影无限背景，均匀柔光正面照明，"
    "画面干净简约，无任何杂物或干扰元素。"
    "8K超高清商业摄影质感，面料纹理清晰锐利，"
    "边缘干净利落，色彩真实准确，光影柔和自然"
)

# ── HTTP 会话 ──────────────────────────────────────────────

import aiohttp

_session: aiohttp.ClientSession | None = None

async def get_session() -> aiohttp.ClientSession:
    global _session
    if _session is None or _session.closed:
        timeout = aiohttp.ClientTimeout(total=120)
        _session = aiohttp.ClientSession(timeout=timeout)
    return _session

# ── rembg ──────────────────────────────────────────────────

_rembg_session = None

def get_rembg_session():
    global _rembg_session
    if _rembg_session is None:
        from rembg import new_session
        _rembg_session = new_session("u2net")
    return _rembg_session

# ═══════════════════════════════════════════════════════════
#  核心：DashScope 临时文件上传 + 异步试衣
# ═══════════════════════════════════════════════════════════

async def upload_to_dashscope_oss(image_bytes: bytes, filename: str) -> str:
    """
    将图片上传到 DashScope 临时 OSS（48h 有效），返回 oss:// URL。

    步骤：
    1. GET /uploads?action=getPolicy&model=aitryon-plus → 获取上传凭证
    2. POST OSS host → 上传文件
    """
    session = await get_session()
    headers = {"Authorization": f"Bearer {DASHSCOPE_API_KEY}"}

    # Step 1: 获取上传凭证
    policy_url = f"{DASHSCOPE_BASE}/uploads?action=getPolicy&model={MODEL}"
    async with session.get(policy_url, headers=headers) as resp:
        if resp.status != 200:
            text = await resp.text()
            raise HTTPException(502, f"获取上传凭证失败 [{resp.status}]: {text}")
        policy_data = (await resp.json())["data"]

    # Step 2: 上传到 OSS（用 requests 库，multipart 兼容性更好）
    key = f"{policy_data['upload_dir']}/{filename}"
    files = {
        "file": (filename, image_bytes, "image/png" if filename.endswith(".png") else "image/jpeg"),
    }
    data = {
        "OSSAccessKeyId": policy_data["oss_access_key_id"],
        "Signature": policy_data["signature"],
        "policy": policy_data["policy"],
        "x-oss-object-acl": policy_data["x_oss_object_acl"],
        "x-oss-forbid-overwrite": policy_data["x_oss_forbid_overwrite"],
        "key": key,
        "success_action_status": "200",
    }
    resp = sync_requests.post(policy_data["upload_host"], data=data, files=files, timeout=30)
    if resp.status_code != 200:
        print(f"  [ERROR] OSS upload failed [{resp.status_code}]: {resp.text[:500]}")
        raise HTTPException(502, f"上传图片到OSS失败 [{resp.status_code}]: {resp.text[:300]}")

    return f"oss://{key}"


async def call_aitryon_async(person_oss_url: str, top_oss_url: str | None,
                               bottom_oss_url: str | None) -> str:
    """
    调用 aitryon-plus 异步 API。

    - 提交任务 → 轮询等待 → 下载结果 → 返回 base64
    - 使用 X-DashScope-OssResourceResolve 头让 API 解析 oss:// URL
    """
    session = await get_session()
    headers = {
        "Authorization": f"Bearer {DASHSCOPE_API_KEY}",
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable",
        "X-DashScope-OssResourceResolve": "enable",  # 关键：让 API 解析 oss:// URL
    }

    # Step 1: 提交异步任务
    inp: dict = {"person_image_url": person_oss_url}
    if top_oss_url:
        inp["top_garment_url"] = top_oss_url
    if bottom_oss_url:
        inp["bottom_garment_url"] = bottom_oss_url

    payload = {
        "model": MODEL,
        "input": inp,
        "parameters": {"resolution": -1, "restore_face": True},
    }

    async with session.post(
        f"{DASHSCOPE_BASE}/services/aigc/image2image/image-synthesis/",
        json=payload, headers=headers,
    ) as resp:
        result = await resp.json()

    if resp.status != 200:
        msg = result.get("message", str(result))
        print(f"  [ERROR] Submit task failed: {msg}")
        raise HTTPException(502, f"提交试衣任务失败 [{resp.status}]: {msg}")

    task_id = result["output"]["task_id"]
    print(f"  [task] {task_id} 已提交，等待生成...")

    # Step 2: 轮询任务
    deadline = time.time() + 180  # 3 分钟超时
    while time.time() < deadline:
        await asyncio.sleep(3)

        async with session.get(
            f"{DASHSCOPE_BASE}/tasks/{task_id}",
            headers={"Authorization": f"Bearer {DASHSCOPE_API_KEY}"},
        ) as resp:
            task_result = await resp.json()

        if resp.status != 200:
            print(f"  [poll] HTTP {resp.status}, retrying...")
            continue

        output = task_result.get("output", {})
        status = output.get("task_status", "")

        if status == "SUCCEEDED":
            # 获取结果图 URL（可能是 image_url 或 results[].url）
            result_url = output.get("image_url") or \
                         (output.get("results", [{}])[0].get("url") if output.get("results") else None)
            if not result_url:
                raise HTTPException(502, f"任务完成但无结果: {task_result}")

            # Step 3: 下载结果图
            async with session.get(result_url) as dl_resp:
                if dl_resp.status != 200:
                    raise HTTPException(502, f"下载结果失败: HTTP {dl_resp.status}")
                img_data = await dl_resp.read()

            import base64
            print(f"  [task] {task_id} done")
            return base64.b64encode(img_data).decode("utf-8")

        elif status == "FAILED":
            msg = output.get("message", "未知错误")
            raise HTTPException(502, f"AI处理失败: {msg}")

        elif status in ("PENDING", "RUNNING"):
            print(f"  [task] {task_id} {status}... ({int(time.time())}s elapsed)")

    raise HTTPException(502, "任务超时（180s），请重试")


async def try_on_full(body_bytes: bytes, top_bytes: bytes | None,
                       bottom_bytes: bytes | None) -> str:
    """
    完整试衣流水线：
    body → DashScope OSS → oss:// URL
    top/bottom → DashScope OSS → oss:// URL
    → 调用异步 API → 轮询 → 返回结果 base64
    """
    import uuid

    # 上传人物照
    print("  [upload] 上传人物照到 DashScope OSS...")
    person_url = await upload_to_dashscope_oss(body_bytes, f"body_{uuid.uuid4().hex[:8]}.png")

    # 上传衣服照
    top_url = None
    bottom_url = None
    if top_bytes:
        print("  [upload] 上传上衣照...")
        top_url = await upload_to_dashscope_oss(top_bytes, f"top_{uuid.uuid4().hex[:8]}.png")
    if bottom_bytes:
        print("  [upload] 上传下装照...")
        bottom_url = await upload_to_dashscope_oss(bottom_bytes, f"bottom_{uuid.uuid4().hex[:8]}.png")

    # 调用AI
    print(f"  [ai] 调用 aitryon-plus...")
    return await call_aitryon_async(person_url, top_url, bottom_url)


# ═══════════════════════════════════════════════════════════
#  提示词工程
# ═══════════════════════════════════════════════════════════

def build_model_prompt(
    gender: str = "女",
    height_cm: float = 165.0,
    weight_kg: float = 55.0,
    bust_cm: float | None = None,
    waist_cm: float | None = None,
    hip_cm: float | None = None,
    is_photo_mode: bool = True,
) -> str:
    """构建 Wan2.7 生成提示词"""

    gender_en = "female" if gender in ("女", "female") else "male"
    gender_cn = gender if gender in ("男", "女") else ("女" if gender_en == "female" else "男")
    if is_photo_mode:
        # ── 拍照模式：img2img，保留面部 + 提升画质 ──
        visual_weight = max(weight_kg - 5, 40)
        prompt = (
            f"professional fashion model photo, full body, front facing, "
            f"white seamless studio background, soft even studio lighting, "
            f"keep the person face exactly the same, same identity, same skin tone, "
            f"beautiful refined facial features, smooth glowing skin, "
            f"natural elegant posture, relaxed limbs, "
            f"height {height_cm}cm, weight {visual_weight}kg body proportions, "
            f"slim nude beige spaghetti strap camisole top, matching high waist shorts, barefoot, "
            f"clean minimalist outfit, fresh and elegant, "
            f"high-end lingerie brand campaign style, NEIWAI studio aesthetic, "
            f"8K ultra high definition, photorealistic, sharp details, "
            f"no accessories, no props, no text, no watermark"
        )
    else:
        # ── 手动模式：t2i，从身材数据生成人物 ──
        measurements_parts = [f"height {height_cm}cm, weight {weight_kg}kg"]
        if bust_cm is not None:
            measurements_parts.append(f"bust {bust_cm}cm")
        if waist_cm is not None:
            measurements_parts.append(f"waist {waist_cm}cm")
        if hip_cm is not None:
            measurements_parts.append(f"hip {hip_cm}cm")
        measurements_str = ", ".join(measurements_parts)

        prompt = (
            f"A FULL-BODY photograph of a {gender_cn} person showing the ENTIRE body "
            f"from the very top of the head to the very bottom of the feet. "
            f"Standing straight, facing the camera directly, "
            f"arms relaxed at sides, hands visible and natural, "
            f"feet shoulder-width apart and fully visible at the bottom edge. "
            f"Body measurements: {measurements_str}. "
            f"The person is wearing tight-fitting neutral-colored athletic wear "
            f"(slim solid tank top and leggings, muted gray or beige tones). "
            f"Clean studio light gray background (#F0F0F3), "
            f"professional soft even front lighting. "
            f"High quality fashion photography, photorealistic, sharp details, "
            f"full body framing with clear space above the head and below the feet. "
            f"IMPORTANT: The image must show the COMPLETE person from head to toe — "
            f"do NOT crop or cut off any part of the body."
        )

    return prompt


# ═══════════════════════════════════════════════════════════
#  Wan2.7 API 调用
# ═══════════════════════════════════════════════════════════

async def call_wan27_img2img(image_bytes: bytes, prompt: str) -> bytes:
    """
    调用 Wan2.7 图生图，将人物照片转化为干净模特风格图。

    输入：去背景后合成在浅灰背景上的人物 JPEG + 自定义提示词
    输出：Wan2.7 生成的图片字节
    """
    session = await get_session()
    headers = {
        "Authorization": f"Bearer {DASHSCOPE_API_KEY}",
        "Content-Type": "application/json",
    }

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    # 从输入图片读取原始尺寸，计算保持比例的输出分辨率
    try:
        src_img = Image.open(io.BytesIO(image_bytes))
        src_w, src_h = src_img.size
        # 短边最大 2048px，长边按比例缩放
        max_short = 2048
        if src_w <= src_h:
            out_w = min(src_w, max_short)
            out_h = int(out_w * src_h / src_w)
        else:
            out_h = min(src_h, max_short)
            out_w = int(out_h * src_w / src_h)
        size_str = f"{out_w}*{out_h}"
        print(f"  [wan27-img2img] Input: {src_w}x{src_h} → Output: {size_str}")
    except Exception:
        size_str = "2K"

    payload = {
        "model": WAN_MODEL,
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

    async with session.post(
        f"{DASHSCOPE_BASE}{WAN_ENDPOINT}",
        json=payload, headers=headers,
    ) as resp:
        result = await resp.json()

    if resp.status != 200:
        msg = result.get("message", str(result))
        raise HTTPException(502, f"Wan2.7 generation failed [{resp.status}]: {msg}")

    try:
        img_url = result["output"]["choices"][0]["message"]["content"][0]["image"]
    except (KeyError, IndexError) as e:
        raise HTTPException(502, f"Wan2.7 unexpected response: {result}")

    async with session.get(img_url) as dl_resp:
        if dl_resp.status != 200:
            raise HTTPException(502, f"Download Wan2.7 result failed: HTTP {dl_resp.status}")
        result_bytes = await dl_resp.read()
    # 检查输出尺寸
    try:
        out_img = Image.open(io.BytesIO(result_bytes))
        print(f"  [wan27-img2img] Output image size: {out_img.size[0]}x{out_img.size[1]}")
    except Exception:
        pass
    return result_bytes


async def call_wan27_t2i(prompt: str) -> bytes:
    """
    调用 Wan2.7 文生图，从文本描述生成人物形象。

    输入：纯文本提示词（无输入图片）
    输出：Wan2.7 生成的图片字节
    """
    session = await get_session()
    headers = {
        "Authorization": f"Bearer {DASHSCOPE_API_KEY}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": WAN_MODEL,
        "input": {
            "messages": [{
                "role": "user",
                "content": [
                    {"text": prompt},
                ],
            }],
        },
        "parameters": {
            "size": "720*1280",  # 竖屏全身人像比例
            "n": 1,
            "watermark": False,
        },
    }

    async with session.post(
        f"{DASHSCOPE_BASE}{WAN_ENDPOINT}",
        json=payload, headers=headers,
    ) as resp:
        result = await resp.json()

    if resp.status != 200:
        msg = result.get("message", str(result))
        raise HTTPException(502, f"Wan2.7 text-to-image failed [{resp.status}]: {msg}")

    try:
        img_url = result["output"]["choices"][0]["message"]["content"][0]["image"]
    except (KeyError, IndexError) as e:
        raise HTTPException(502, f"Wan2.7 t2i unexpected response: {result}")

    async with session.get(img_url) as dl_resp:
        if dl_resp.status != 200:
            raise HTTPException(502, f"Download Wan2.7 t2i result failed: HTTP {dl_resp.status}")
        return await dl_resp.read()


# ═══════════════════════════════════════════════════════════
#  身体照片预处理流水线（拍照模式）
# ═══════════════════════════════════════════════════════════

async def preprocess_body_image(
    body_bytes: bytes,
    gender: str = "女",
    height_cm: float = 165.0,
    weight_kg: float = 55.0,
) -> bytes:
    """
    身体照片预处理流水线：
    1. rembg 去除杂乱背景 → 透明 PNG
    2. 合成到摄影棚浅灰背景 → JPEG
    3. Wan2.7 img2img → 紧身衣 + 标准姿态 + 干净背景

    返回处理后的 JPEG 字节数据。
    """
    from rembg import remove

    # Step 1: 去背景
    print("  [preprocess] Step 1/3: Removing background...")
    img = Image.open(io.BytesIO(body_bytes)).convert("RGB")
    print(f"  [preprocess] Input image: {img.size[0]}x{img.size[1]}")
    result = remove(img, session=get_rembg_session())
    print(f"  [preprocess] After rembg: {result.size[0]}x{result.size[1]}")

    # Step 2: 合成到摄影棚背景
    print("  [preprocess] Step 2/3: Compositing on studio background...")
    bg_color = (240, 240, 243)  # #F0F0F3
    canvas = Image.new("RGB", result.size, bg_color)
    if result.mode == "RGBA":
        canvas.paste(result, mask=result.split()[3])
    else:
        canvas.paste(result)

    buf = io.BytesIO()
    canvas.save(buf, format="JPEG", quality=92)
    clean_bytes = buf.getvalue()
    print(f"  [preprocess] After rembg: {len(clean_bytes)} bytes")

    # Step 3: Wan2.7 模特化（紧身衣 + 姿态优化）
    print("  [preprocess] Step 3/3: Wan2.7 model refinement...")
    prompt = build_model_prompt(
        gender=gender,
        height_cm=height_cm,
        weight_kg=weight_kg,
        is_photo_mode=True,
    )
    try:
        refined_bytes = await call_wan27_img2img(clean_bytes, prompt)
        print(f"  [preprocess] Wan2.7 output: {len(refined_bytes)} bytes")
        return refined_bytes
    except HTTPException:
        # Wan2.7 失败时回退到 rembg-only 结果
        print("  [preprocess] Wan2.7 failed, falling back to rembg-only result")
        return clean_bytes


# ═══════════════════════════════════════════════════════════
#  请求模型
# ═══════════════════════════════════════════════════════════

class EnhanceClothingRequest(BaseModel):
    """enhance-clothing 请求体（JSON）"""
    image_base64: str


class GenerateModelRequest(BaseModel):
    """generate-model 请求体（JSON）"""
    image_base64: str | None = None
    gender: str = "女"
    height_cm: float = 165.0
    weight_kg: float = 55.0
    bust_cm: float | None = None
    waist_cm: float | None = None
    hip_cm: float | None = None


# ═══════════════════════════════════════════════════════════
#  API 路由
# ═══════════════════════════════════════════════════════════

@app.get("/api/health")
async def health():
    """健康检查"""
    dashscope_ok = bool(DASHSCOPE_API_KEY)
    return JSONResponse({
        "status": "ok",
        "service": "OutfitApp AI Proxy",
        "version": "0.6.2",
        "dashscope": {
            "configured": dashscope_ok,
            "key_prefix": f"{DASHSCOPE_API_KEY[:8]}***" if dashscope_ok else "N/A",
        },
    })


class RemoveBgRequest(BaseModel):
    """remove-bg 请求体（JSON 模式，Flutter Web 兼容）"""
    image_base64: str


@app.post("/api/remove-bg")
async def remove_background(request: Request):
    """
    AI 抠图 — 兼容两种输入方式：
    - Multipart file upload（原生平台 / curl 测试）
    - JSON body with image_base64（Flutter Web 兼容）
    """
    t0 = time.time()
    content_type = request.headers.get("content-type", "")

    # ── 模式 1: JSON base64（Flutter Web）──
    if "application/json" in content_type:
        body = await request.json()
        b64 = body.get("image_base64", "")
        if not b64:
            raise HTTPException(400, "缺少 image_base64 字段")
        try:
            img_data = base64.b64decode(b64)
        except Exception as e:
            raise HTTPException(400, f"无法解码图片: {e}")

    # ── 模式 2: Multipart file upload（原生平台）──
    else:
        form = await request.form()
        image = form.get("image")
        if image is None:
            raise HTTPException(400, "请提供图片（multipart file 或 JSON image_base64）")
        try:
            img_data = await image.read()
        except Exception as e:
            raise HTTPException(400, f"无法读取图片: {e}")

    # ── 尝试用 PIL 打开图片 ──
    try:
        img = Image.open(io.BytesIO(img_data)).convert("RGB")
    except Exception as e:
        raise HTTPException(400, f"无法识别图片格式: {e}")

    from rembg import remove
    result = remove(img, session=get_rembg_session())

    buf = io.BytesIO()
    result.save(buf, format="PNG")
    result_b64 = base64.b64encode(buf.getvalue()).decode("utf-8")

    return JSONResponse({
        "success": True,
        "image_base64": result_b64,
        "format": "png",
        "elapsed_seconds": round(time.time() - t0, 2),
    })


@app.post("/api/enhance-clothing")
async def enhance_clothing(req: EnhanceClothingRequest):
    """
    衣服 AI 增强 — rembg 抠图 + 白底合成 + Wan2.7 电商产品图生成。

    流水线：
    1. rembg 去背景 → 透明 PNG
    2. 合成到纯白(#FFFFFF)背景 → JPEG
    3. Wan2.7 img2img → 幽灵模特效果产品图

    返回增强后的 JPEG 字节。
    """
    t0 = time.time()

    if not DASHSCOPE_API_KEY:
        raise HTTPException(500,
            "DASHSCOPE_API_KEY 未配置。请在项目根目录创建 .env 文件：\n"
            "  DASHSCOPE_API_KEY=sk-你的密钥")

    if not req.image_base64:
        raise HTTPException(400, "缺少 image_base64 字段")

    try:
        img_data = base64.b64decode(req.image_base64)
    except Exception as e:
        raise HTTPException(400, f"无法解码图片: {e}")

    # Step 1: rembg 去背景
    print("  [enhance-clothing] Step 1/3: Removing background...")
    from rembg import remove
    try:
        img = Image.open(io.BytesIO(img_data)).convert("RGB")
        print(f"  [enhance-clothing] Input: {img.size[0]}x{img.size[1]}")
        result = remove(img, session=get_rembg_session())
    except Exception as e:
        raise HTTPException(400, f"抠图失败: {e}")

    # Step 2: 合成到纯白背景
    print("  [enhance-clothing] Step 2/3: Compositing on white background...")
    white_bg = (255, 255, 255)
    canvas = Image.new("RGB", result.size, white_bg)
    if result.mode == "RGBA":
        canvas.paste(result, mask=result.split()[3])
    else:
        canvas.paste(result)

    buf = io.BytesIO()
    canvas.save(buf, format="JPEG", quality=95)
    clean_bytes = buf.getvalue()
    print(f"  [enhance-clothing] Composite: {len(clean_bytes)} bytes")

    # Step 3: Wan2.7 电商产品图生成（纯正向提示词）
    print("  [enhance-clothing] Step 3/3: Wan2.7 product photo enhancement...")
    prompt = CLOTHING_ENHANCE_PROMPT
    try:
        enhanced_bytes = await call_wan27_img2img(clean_bytes, prompt)
    except HTTPException as e:
        print(f"  [enhance-clothing] Wan2.7 failed ({e}), falling back to composite result")
        enhanced_bytes = clean_bytes
    except Exception as e:
        print(f"  [enhance-clothing] Wan2.7 exception: {e}, falling back")
        enhanced_bytes = clean_bytes

    elapsed = time.time() - t0
    print(f"  [enhance-clothing] Done in {elapsed:.1f}s, output: {len(enhanced_bytes)} bytes")

    return JSONResponse({
        "success": True,
        "image_base64": base64.b64encode(enhanced_bytes).decode("utf-8"),
        "format": "jpeg",
        "elapsed_seconds": round(elapsed, 2),
    })


@app.post("/api/generate-model")
async def generate_model(req: GenerateModelRequest):
    """
    身体照片 AI 模特化 — 两种模式（JSON 请求体）：

    📷 拍照模式（提供 image_base64）：
      1. rembg 去背景 → 透明 PNG
      2. 合成到摄影棚浅灰背景 → JPEG
      3. Wan2.7 img2img → 紧身衣 + 姿态标准化 + 干净背景

    📐 手动模式（无 image_base64，提供测量数据）：
      直接 Wan2.7 文生图从身材数据生成人物形象

    返回处理后的模特图 base64 JPEG。
    """
    t0 = time.time()

    if not DASHSCOPE_API_KEY:
        raise HTTPException(500,
            "DASHSCOPE_API_KEY 未配置。请在项目根目录创建 .env 文件：\n"
            "  DASHSCOPE_API_KEY=sk-你的密钥")

    has_image = bool(req.image_base64)

    if not has_image:
        # ═════════════════════════════════════════
        #  模式 B：手动输入 — Wan2.7 文生图
        # ═════════════════════════════════════════
        print(f"  [generate-model:t2i] gender={req.gender}, height={req.height_cm}, "
              f"weight={req.weight_kg}, bust={req.bust_cm}, waist={req.waist_cm}, hip={req.hip_cm}")

        prompt = build_model_prompt(
            gender=req.gender,
            height_cm=req.height_cm,
            weight_kg=req.weight_kg,
            bust_cm=req.bust_cm,
            waist_cm=req.waist_cm,
            hip_cm=req.hip_cm,
            is_photo_mode=False,
        )

        try:
            result_bytes = await call_wan27_t2i(prompt)
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(502, f"文生图模特生成异常: {e}")

        elapsed = time.time() - t0
        print(f"  [generate-model:t2i] Done in {elapsed:.1f}s, output: {len(result_bytes)} bytes")

        return JSONResponse({
            "success": True,
            "image_base64": base64.b64encode(result_bytes).decode("utf-8"),
            "format": "jpeg",
            "elapsed_seconds": round(elapsed, 2),
            "mode": "text-to-image",
        })

    # ═════════════════════════════════════════
    #  模式 A：拍照上传 — 完整预处理流水线
    # ═════════════════════════════════════════

    try:
        img_data = base64.b64decode(req.image_base64)
    except Exception as e:
        raise HTTPException(400, f"无法解码图片: {e}")

    print(f"  [generate-model:img2img] Input: {len(img_data)} bytes, "
          f"gender={req.gender}, height={req.height_cm}, weight={req.weight_kg}")

    try:
        result_bytes = await preprocess_body_image(
            img_data,
            gender=req.gender,
            height_cm=req.height_cm,
            weight_kg=req.weight_kg,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(502, f"模特生成异常: {e}")

    elapsed = time.time() - t0
    print(f"  [generate-model:img2img] Done in {elapsed:.1f}s, output: {len(result_bytes)} bytes")

    return JSONResponse({
        "success": True,
        "image_base64": base64.b64encode(result_bytes).decode("utf-8"),
        "format": "jpeg",
        "elapsed_seconds": round(elapsed, 2),
        "mode": "image-to-image",
    })


@app.post("/api/try-on")
async def virtual_try_on(
    body_image: UploadFile = File(...),
    top_image: UploadFile | None = None,
    bottom_image: UploadFile | None = None,
    # 兼容旧版单件衣物参数
    cloth_image: UploadFile | None = None,
    category: str = Form(default="upper_body"),
    preprocess_body: bool = Form(default=False),
):
    """
    虚拟试衣 — 完整流水线。

    新版（推荐）：body_image + top_image + bottom_image → 一次生成
    旧版兼容：body_image + cloth_image + category → 单件试穿

    流程：上传→[可选:身体预处理]→DashScope OSS→异步API→轮询→返回结果图

    参数：
    - preprocess_body: 是否先对 body 照片做 AI 模特化预处理（去背景+姿态优化）
    """
    t0 = time.time()

    if not DASHSCOPE_API_KEY:
        raise HTTPException(500,
            "DASHSCOPE_API_KEY 未配置。请在项目根目录创建 .env 文件：\n"
            "  DASHSCOPE_API_KEY=sk-你的密钥")

    # 读取图片
    body_bytes = await body_image.read()
    top_bytes = None
    bottom_bytes = None

    if top_image:
        top_bytes = await top_image.read()
    if bottom_image:
        bottom_bytes = await bottom_image.read()

    # ── 身体照片预处理（可选）──
    if preprocess_body:
        print("  [try-on] Preprocessing body photo...")
        try:
            body_bytes = await preprocess_body_image(body_bytes)
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(502, f"身体预处理异常: {e}")

    # 旧版兼容：单 cloth_image → 根据 category 分配
    if cloth_image and not top_image and not bottom_image:
        cloth_bytes = await cloth_image.read()
        if category == "upper_body":
            top_bytes = cloth_bytes
        elif category == "lower_body":
            bottom_bytes = cloth_bytes
        elif category == "dress":
            # 连衣裙当作上衣处理
            top_bytes = cloth_bytes

    if not top_bytes and not bottom_bytes:
        raise HTTPException(400,
            "请至少提供 top_image 或 bottom_image 之一，"
            "或使用旧版 cloth_image + category 参数")

    try:
        result_b64 = await try_on_full(body_bytes, top_bytes, bottom_bytes)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(502, f"试衣流水线异常: {e}")

    return JSONResponse({
        "success": True,
        "image_base64": result_b64,
        "format": "png",
        "elapsed_seconds": round(time.time() - t0, 2),
    })


# ── 生命周期 ──────────────────────────────────────────────

@app.on_event("shutdown")
async def shutdown():
    global _session
    if _session and not _session.closed:
        await _session.close()


# ── 入口 ──────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OutfitApp AI Proxy Server")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    print("=" * 58)
    print("  OutfitApp AI Proxy Server  v0.6.2")
    print("=" * 58)
    print(f"  Listening: http://{args.host}:{args.port}")
    print(f"  Endpoints:")
    print(f"    GET  /api/health            健康检查")
    print(f"    POST /api/remove-bg          AI 抠图 (rembg, JSON/multipart)")
    print(f"    POST /api/enhance-clothing   衣服AI增强 (rembg + Wan2.7)")
    print(f"    POST /api/generate-model     身体AI模特化 (rembg+Wan2.7)")
    print(f"    POST /api/try-on             虚拟试衣 (可选preprocess_body)")
    print("-" * 58)

    if DASHSCOPE_API_KEY:
        print(f"  [OK]  DashScope Key: {DASHSCOPE_API_KEY[:8]}***")
        print(f"  [OK]  模特化: rembg去背景 -> Wan2.7姿态优化")
        print(f"  [OK]  衣服增强: rembg去背景 -> 白底合成 -> Wan2.7产品图")
        print(f"  [OK]  试衣: 上传图片->DashScope OSS->aitryon-plus->返回")
    else:
        print("  [WARN] DASHSCOPE_API_KEY 未配置！")
    print("=" * 58)

    uvicorn.run(app, host=args.host, port=args.port, log_level="info")




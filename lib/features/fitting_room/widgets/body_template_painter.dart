import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/models/body_profile.dart';
import '../../../data/models/clothing_item.dart';
import '../fitting_room_store.dart';

/// 身体比例计算
///
/// 根据 BodyProfile 动态计算各部位的宽度，用于绘制人体轮廓。
class BodyProportions {
  final double headRadius;
  final double neckW;
  final double neckH;
  final double shoulderY;
  final double shoulderW;
  final double waistY;
  final double waistW;
  final double hipY;
  final double hipW;
  final double legTopY;
  final double legBottomY;
  final double legW;
  final double ankleW;

  const BodyProportions({
    required this.headRadius,
    required this.neckW,
    required this.neckH,
    required this.shoulderY,
    required this.shoulderW,
    required this.waistY,
    required this.waistW,
    required this.hipY,
    required this.hipW,
    required this.legTopY,
    required this.legBottomY,
    required this.legW,
    required this.ankleW,
  });

  /// 默认比例（未设定身体数据时使用）
  static const defaultProportions = BodyProportions(
    headRadius: 28,
    neckW: 14,
    neckH: 16,
    shoulderY: 98,
    shoulderW: 82,
    waistY: 210,
    waistW: 48,
    hipY: 240,
    hipW: 86,
    legTopY: 258,
    legBottomY: 400,
    legW: 22,
    ankleW: 12,
  );

  /// 根据 BodyProfile 计算比例
  ///
  /// 使用三围数据缩放默认比例：
  /// - shoulderW 与 bust（胸围）正相关
  /// - waistW 与 waist（腰围）正相关
  /// - hipW 与 hip（臀围）正相关
  factory BodyProportions.fromProfile(BodyProfile profile) {
    if (profile.source == BodySource.none || profile.source == BodySource.photo) {
      return defaultProportions;
    }

    // 基准值：标准身材对应的三围
    const baseBust = 86.0;
    const baseWaist = 68.0;
    const baseHip = 90.0;

    final bustRatio = (profile.bust ?? baseBust) / baseBust;
    final waistRatio = (profile.waist ?? baseWaist) / baseWaist;
    final hipRatio = (profile.hip ?? baseHip) / baseHip;

    return BodyProportions(
      headRadius: defaultProportions.headRadius,
      neckW: defaultProportions.neckW * (bustRatio * 0.7 + 0.3),
      neckH: defaultProportions.neckH,
      shoulderY: defaultProportions.shoulderY,
      shoulderW: defaultProportions.shoulderW * bustRatio,
      waistY: defaultProportions.waistY,
      waistW: defaultProportions.waistW * waistRatio,
      hipY: defaultProportions.hipY,
      hipW: defaultProportions.hipW * hipRatio,
      legTopY: defaultProportions.legTopY,
      legBottomY: defaultProportions.legBottomY,
      legW: defaultProportions.legW * ((hipRatio + 1) / 2),
      ankleW: defaultProportions.ankleW,
    );
  }
}

/// 2D 身材模板绘制器 — 时尚插画风格人体轮廓
///
/// 支持：
/// - 根据 BodyProfile 动态调整身体比例
/// - 绘制衣物图片（支持 imageBytes）
/// - 输出身体遮罩 Path 供衣物裁剪
class BodyTemplatePainter extends CustomPainter {
  final List<PlacedClothing> clothes;
  final ClothingCategory? activeZone;
  final BodyProfile? bodyProfile;

  BodyTemplatePainter({
    required this.clothes,
    this.activeZone,
    this.bodyProfile,
  });

  // 逻辑画布尺寸
  static const double bodyWidth = 180;
  static const double bodyHeight = 480;

  // ── 身体分区（用于衣物放置时的默认定位）──
  static const zoneNeck = Rect.fromLTWH(83, 70, 14, 40);
  static const zoneTorso = Rect.fromLTWH(49, 105, 82, 145);
  static const zoneLegs = Rect.fromLTWH(49, 250, 82, 160);

  // ── 缓存 ──
  final Map<String, ui.Image> _imageCache = {};

  // 模特图缓存
  ui.Image? _cachedModelImage;
  int? _cachedModelImageHash;

  @override
  void paint(Canvas canvas, Size size) {
    final proportions = bodyProfile != null
        ? BodyProportions.fromProfile(bodyProfile!)
        : BodyProportions.defaultProportions;

    // 画布中心偏移
    final dx = (size.width - bodyWidth) / 2;
    final dy = 10.0;
    canvas.translate(dx, dy);

    // ── 有 AI 生成的模特图时，照片由 Image.memory 层负责显示，
    //    这里不再重复绘制，避免双层叠加和拉伸变形 ──
    if (bodyProfile?.bodyPhotoBytes == null || bodyProfile!.bodyPhotoBytes!.isEmpty) {
      // 无图时显示骨架占位
      _drawBodyZones(canvas);
      _drawBodyOutline(canvas, proportions);
    }

    _drawPlacedClothes(canvas, proportions);
    _drawBodyHighlight(canvas);
  }

  /// 身体分区底色（浅色蒙版提示）
  void _drawBodyZones(Canvas canvas) {
    final zonePaint = Paint()..style = PaintingStyle.fill;

    // 颈/肩区 — 浅粉
    zonePaint.color = const Color(0x18FFCDD2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(zoneNeck, const Radius.circular(8)),
      zonePaint,
    );

    // 躯干区 — 浅蓝
    zonePaint.color = const Color(0x18BBDEFB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(zoneTorso, const Radius.circular(8)),
      zonePaint,
    );

    // 腿部区 — 浅绿
    zonePaint.color = const Color(0x18C8E6C9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(zoneLegs, const Radius.circular(8)),
      zonePaint,
    );
  }

  /// 身体轮廓线
  void _drawBodyOutline(Canvas canvas, BodyProportions p) {
    final outline = Paint()
      ..color = const Color(0xFFB0B0B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = const Color(0xFFF5F5F5)
      ..style = PaintingStyle.fill;

    final cx = bodyWidth / 2;

    final body = Path()
      // 头部
      ..addOval(Rect.fromCircle(
        center: Offset(cx, p.headRadius + 12),
        radius: p.headRadius,
      ))
      // 脖子
      ..moveTo(cx - p.neckW / 2, p.headRadius * 2 + 12)
      ..lineTo(cx - p.neckW / 2, p.shoulderY)
      ..lineTo(cx + p.neckW / 2, p.shoulderY)
      ..lineTo(cx + p.neckW / 2, p.headRadius * 2 + 12)
      ..close()
      // 躯干 + 腿（连续轮廓）
      ..moveTo(cx - p.shoulderW / 2, p.shoulderY)
      ..quadraticBezierTo(
        cx - p.shoulderW / 2 - 4, p.waistY - 30,
        cx - p.waistW / 2, p.waistY,
      )
      ..quadraticBezierTo(
        cx - p.hipW / 2, p.hipY - 10,
        cx - p.hipW / 2, p.hipY,
      )
      // 左腿外侧
      ..lineTo(cx - p.legW / 2 - 6, p.legTopY)
      ..lineTo(cx - p.legW / 2 - 4, p.legBottomY)
      // 左脚踝
      ..lineTo(cx - p.ankleW / 2 - 2, p.legBottomY + 26)
      // 左腿内侧
      ..lineTo(cx - p.ankleW / 2 + 6, p.legBottomY + 26)
      ..lineTo(cx - p.legW / 2 + 10, p.legBottomY)
      ..lineTo(cx - 6, p.legTopY + 10)
      // 裆部
      ..lineTo(cx + 6, p.legTopY + 10)
      // 右腿内侧
      ..lineTo(cx + p.legW / 2 - 10, p.legBottomY)
      ..lineTo(cx + p.ankleW / 2 - 6, p.legBottomY + 26)
      // 右脚踝
      ..lineTo(cx + p.ankleW / 2 + 2, p.legBottomY + 26)
      // 右腿外侧
      ..lineTo(cx + p.legW / 2 + 4, p.legBottomY)
      ..lineTo(cx + p.legW / 2 + 6, p.legTopY)
      // 右髋 → 右腰
      ..lineTo(cx + p.hipW / 2, p.hipY)
      ..quadraticBezierTo(
        cx + p.hipW / 2, p.hipY - 10,
        cx + p.waistW / 2, p.waistY,
      )
      // 右腰 → 右肩
      ..quadraticBezierTo(
        cx + p.shoulderW / 2 + 4, p.waistY - 30,
        cx + p.shoulderW / 2, p.shoulderY,
      )
      ..close();

    // 手臂
    final leftArm = Path()
      ..moveTo(cx - p.shoulderW / 2, p.shoulderY + 2)
      ..quadraticBezierTo(
        cx - p.shoulderW / 2 - 18, p.shoulderY + 40,
        cx - p.shoulderW / 2 - 14, p.shoulderY + 90,
      )
      ..lineTo(cx - p.shoulderW / 2 - 10, p.shoulderY + 90)
      ..quadraticBezierTo(
        cx - p.shoulderW / 2 - 14, p.shoulderY + 40,
        cx - p.shoulderW / 2 + 4, p.shoulderY + 2,
      )
      ..close();

    final rightArm = Path()
      ..moveTo(cx + p.shoulderW / 2, p.shoulderY + 2)
      ..quadraticBezierTo(
        cx + p.shoulderW / 2 + 18, p.shoulderY + 40,
        cx + p.shoulderW / 2 + 14, p.shoulderY + 90,
      )
      ..lineTo(cx + p.shoulderW / 2 + 10, p.shoulderY + 90)
      ..quadraticBezierTo(
        cx + p.shoulderW / 2 + 14, p.shoulderY + 40,
        cx + p.shoulderW / 2 - 4, p.shoulderY + 2,
      )
      ..close();

    canvas.drawPath(body, fill);
    canvas.drawPath(leftArm, fill);
    canvas.drawPath(rightArm, fill);
    canvas.drawPath(body, outline);
    canvas.drawPath(leftArm, outline);
    canvas.drawPath(rightArm, outline);
  }

  /// 已穿上的衣物
  void _drawPlacedClothes(Canvas canvas, BodyProportions p) {
    for (final item in clothes) {
      // 如果有图片数据，优先绘制图片
      if (item.imageBytes != null && item.imageBytes!.isNotEmpty) {
        _drawClothImage(canvas, item);
      } else {
        // 回退：纯色矩形 + 文字标签
        _drawClothPlaceholder(canvas, item);
      }
    }
  }

  /// 绘制衣物图片（带变换）
  void _drawClothImage(Canvas canvas, PlacedClothing item) {
    final rect = _zoneForCategory(item.category);
    final img = _imageCache[item.clothId];

    canvas.save();

    // 应用位置、旋转、缩放变换
    final center = item.position != Offset.zero
        ? item.position
        : Offset(rect.left + rect.width / 2, rect.top + rect.height / 2);

    canvas.translate(center.dx, center.dy);
    canvas.rotate(item.rotation);
    canvas.scale(item.scale);

    if (img != null) {
      final srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final dstRect = Rect.fromCenter(
        center: Offset.zero,
        width: rect.width,
        height: rect.height * (img.height / img.width).clamp(0.5, 2.0),
      );
      canvas.drawImageRect(img, srcRect, dstRect, Paint());
    } else {
      // 图片未加载：异步加载
      _loadImage(item.clothId, item.imageBytes!);
      // 先画占位
      final paint = Paint()..color = item.color.withAlpha(120);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: rect.width, height: rect.height * 0.7),
        paint,
      );
    }

    canvas.restore();
  }

  void _loadImage(String key, Uint8List bytes) {
    if (_imageCache.containsKey(key)) return;
    ui.instantiateImageCodec(bytes).then((codec) {
      codec.getNextFrame().then((frame) {
        _imageCache[key] = frame.image;
      });
    });
  }

  /// 纯色占位绘制
  void _drawClothPlaceholder(Canvas canvas, PlacedClothing item) {
    final rect = _zoneForCategory(item.category);
    final paint = Paint()
      ..color = item.color.withAlpha(180)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      paint,
    );

    // 衣物标签
    final tp = TextPainter(
      text: TextSpan(
        text: item.name,
        style: TextStyle(
          color: Colors.white.withAlpha(220),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: rect.width - 8);
    tp.paint(
      canvas,
      Offset(rect.left + 6, rect.top + rect.height / 2 - tp.height / 2),
    );
  }

  /// 激活的高亮区域
  void _drawBodyHighlight(Canvas canvas) {
    if (activeZone == null) return;
    final rect = _zoneForCategory(activeZone!);
    final paint = Paint()
      ..color = const Color(0xFF6C5CE7).withAlpha(40)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    final border = Paint()
      ..color = const Color(0xFF6C5CE7).withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      border,
    );
  }

  /// 绘制 AI 生成的模特图（替代骨架）
  /// 保持图片原始宽高比，居中适配身体区域
  void _drawModelImage(Canvas canvas, Uint8List imageBytes) {
    final hash = imageBytes.length.hashCode; // 简单哈希判断是否换了图

    if (_cachedModelImage != null && _cachedModelImageHash == hash) {
      // 已缓存的模特图 → 按原始比例居中绘制
      final img = _cachedModelImage!;
      final imgW = img.width.toDouble();
      final imgH = img.height.toDouble();
      final imgAspect = imgW / imgH;

      // 在身体区域 (bodyWidth × bodyHeight) 内保持比例适配
      double drawW, drawH;
      if (imgAspect > bodyWidth / bodyHeight) {
        // 图片比身体区域宽 → 按宽度适配
        drawW = bodyWidth;
        drawH = bodyWidth / imgAspect;
      } else {
        // 图片比身体区域高 → 按高度适配
        drawH = bodyHeight;
        drawW = bodyHeight * imgAspect;
      }

      // 居中对齐
      final dx = (bodyWidth - drawW) / 2;
      final dy = (bodyHeight - drawH) / 2;

      final paintRect = Rect.fromLTWH(dx, dy, drawW, drawH);
      final srcRect = Rect.fromLTWH(0, 0, imgW, imgH);

      canvas.drawImageRect(img, srcRect, paintRect, Paint());
    } else {
      // 首次加载 → 异步解码，下次 repaint 时绘制
      _cachedModelImageHash = hash;
      ui.instantiateImageCodec(imageBytes).then((codec) {
        codec.getNextFrame().then((frame) {
          _cachedModelImage = frame.image;
        });
      });
    }
  }

  Rect _zoneForCategory(ClothingCategory category) {
    switch (category) {
      case ClothingCategory.top:
      case ClothingCategory.outer:
        return zoneTorso;
      case ClothingCategory.bottom:
        return zoneLegs;
      case ClothingCategory.dress:
        return Rect.fromLTRB(
          zoneTorso.left, zoneTorso.top,
          zoneTorso.right, zoneLegs.bottom,
        );
      case ClothingCategory.shoes:
      case ClothingCategory.accessory:
        return zoneTorso;
    }
  }

  /// 生成身体轮廓的遮罩 Path
  ///
  /// 供 ClothLayerWidget 等外部组件用于裁剪衣物。
  /// [canvasSize] 画布的实际像素尺寸。
  /// [profile] 可选的身体数据，为 null 时使用默认比例。
  static Path generateBodyMaskPath(Size canvasSize, BodyProfile? profile) {
    final p = profile != null
        ? BodyProportions.fromProfile(profile)
        : BodyProportions.defaultProportions;

    final dx = (canvasSize.width - bodyWidth) / 2;
    final dy = 10.0;
    final cx = bodyWidth / 2;

    final path = Path();

    // 头部（作为遮罩的一部分）
    path.addOval(Rect.fromCircle(
      center: Offset(cx + dx, p.headRadius + 12 + dy),
      radius: p.headRadius,
    ));

    // 躯干 + 腿
    path.moveTo(cx - p.shoulderW / 2 + dx, p.shoulderY + dy);
    path.quadraticBezierTo(
      cx - p.shoulderW / 2 - 4 + dx, p.waistY - 30 + dy,
      cx - p.waistW / 2 + dx, p.waistY + dy,
    );
    path.quadraticBezierTo(
      cx - p.hipW / 2 + dx, p.hipY - 10 + dy,
      cx - p.hipW / 2 + dx, p.hipY + dy,
    );
    path.lineTo(cx - p.legW / 2 - 6 + dx, p.legTopY + dy);
    path.lineTo(cx - p.legW / 2 - 4 + dx, p.legBottomY + dy);
    path.lineTo(cx - p.ankleW / 2 - 2 + dx, p.legBottomY + 26 + dy);
    path.lineTo(cx - p.ankleW / 2 + 6 + dx, p.legBottomY + 26 + dy);
    path.lineTo(cx - p.legW / 2 + 10 + dx, p.legBottomY + dy);
    path.lineTo(cx - 6 + dx, p.legTopY + 10 + dy);
    path.lineTo(cx + 6 + dx, p.legTopY + 10 + dy);
    path.lineTo(cx + p.legW / 2 - 10 + dx, p.legBottomY + dy);
    path.lineTo(cx + p.ankleW / 2 - 6 + dx, p.legBottomY + 26 + dy);
    path.lineTo(cx + p.ankleW / 2 + 2 + dx, p.legBottomY + 26 + dy);
    path.lineTo(cx + p.legW / 2 + 4 + dx, p.legBottomY + dy);
    path.lineTo(cx + p.legW / 2 + 6 + dx, p.legTopY + dy);
    path.lineTo(cx + p.hipW / 2 + dx, p.hipY + dy);
    path.quadraticBezierTo(
      cx + p.hipW / 2 + dx, p.hipY - 10 + dy,
      cx + p.waistW / 2 + dx, p.waistY + dy,
    );
    path.quadraticBezierTo(
      cx + p.shoulderW / 2 + 4 + dx, p.waistY - 30 + dy,
      cx + p.shoulderW / 2 + dx, p.shoulderY + dy,
    );
    path.close();

    return path;
  }

  @override
  bool shouldRepaint(covariant BodyTemplatePainter oldDelegate) {
    return oldDelegate.clothes != clothes ||
        oldDelegate.activeZone != activeZone ||
        oldDelegate.bodyProfile?.source != bodyProfile?.source ||
        oldDelegate.bodyProfile?.bust != bodyProfile?.bust ||
        oldDelegate.bodyProfile?.waist != bodyProfile?.waist ||
        oldDelegate.bodyProfile?.hip != bodyProfile?.hip ||
        !_bytesEqual(oldDelegate.bodyProfile?.bodyPhotoBytes, bodyProfile?.bodyPhotoBytes);
  }

  /// 比较两个 Uint8List 是否内容相同
  bool _bytesEqual(Uint8List? a, Uint8List? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

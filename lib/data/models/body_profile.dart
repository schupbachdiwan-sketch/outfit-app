import 'dart:typed_data';

/// 性别
enum Gender {
  male('男'),
  female('女');

  const Gender(this.label);
  final String label;
}

/// 身体数据来源
enum BodySource {
  none('未设定'),
  photo('拍照生成'),
  manual('手动输入'),
  template('预设模板');

  const BodySource(this.label);
  final String label;
}

/// 预设体型
enum BodyType {
  apple('苹果型', '肩宽腰粗，四肢较细'),
  h('H型', '上下等宽，腰线不明显'),
  pear('梨形', '上半身瘦，臀腿较丰满'),
  hourglass('沙漏型', '肩宽≈臀宽，腰细'),
  invertedTriangle('倒三角型', '肩宽臀窄');

  const BodyType(this.label, this.description);
  final String label;
  final String description;
}

/// 身体数据模型
///
/// 支持三种来源：
/// - photo: 用户上传全身照，AI 生成标准站姿图
/// - manual: 用户输入三围+身高体重
/// - template: 用户选择预设体型模板
class BodyProfile {
  final BodySource source;

  /// 性别
  final Gender? gender;

  /// 体型（仅 template 模式）
  final BodyType? bodyType;

  /// 身高 cm (140–200)
  final double? height;

  /// 体重 kg (40–150)
  final double? weight;

  /// 胸围 cm (70–130)
  final double? bust;

  /// 腰围 cm (50–120)
  final double? waist;

  /// 臀围 cm (70–135)
  final double? hip;

  /// 用户上传的全身照字节数据（photo 模式）
  final Uint8List? bodyPhotoBytes;

  /// AI 生成的标准站姿图（photo/manual 模式生成）
  final Uint8List? aiGeneratedPose;

  const BodyProfile({
    this.source = BodySource.none,
    this.gender,
    this.bodyType,
    this.height,
    this.weight,
    this.bust,
    this.waist,
    this.hip,
    this.bodyPhotoBytes,
    this.aiGeneratedPose,
  });

  /// 空身体（未设定）
  static const empty = BodyProfile();

  /// 预设模板
  factory BodyProfile.template(BodyType type) {
    return BodyProfile(
      source: BodySource.template,
      bodyType: type,
    );
  }

  /// 手动输入
  factory BodyProfile.manual({
    required Gender gender,
    required double height,
    required double weight,
    required double bust,
    required double waist,
    required double hip,
  }) {
    return BodyProfile(
      source: BodySource.manual,
      gender: gender,
      height: height,
      weight: weight,
      bust: bust,
      waist: waist,
      hip: hip,
    );
  }

  /// 拍照生成（传入照片字节数据）
  factory BodyProfile.photo(
    Uint8List photoBytes, {
    Gender? gender,
    double? height,
    double? weight,
  }) {
    return BodyProfile(
      source: BodySource.photo,
      bodyPhotoBytes: photoBytes,
      gender: gender,
      height: height,
      weight: weight,
    );
  }

  bool get isSet => source != BodySource.none;

  /// 性别中文标签
  String get genderLabel => gender?.label ?? '未设定';

  BodyProfile copyWith({
    BodySource? source,
    Gender? gender,
    BodyType? bodyType,
    double? height,
    double? weight,
    double? bust,
    double? waist,
    double? hip,
    Uint8List? bodyPhotoBytes,
    Uint8List? aiGeneratedPose,
    bool clearGender = false,
    bool clearBodyType = false,
    bool clearBodyPhoto = false,
    bool clearAiPose = false,
  }) {
    return BodyProfile(
      source: source ?? this.source,
      gender: clearGender ? null : (gender ?? this.gender),
      bodyType: clearBodyType ? null : (bodyType ?? this.bodyType),
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bust: bust ?? this.bust,
      waist: waist ?? this.waist,
      hip: hip ?? this.hip,
      bodyPhotoBytes: clearBodyPhoto ? null : (bodyPhotoBytes ?? this.bodyPhotoBytes),
      aiGeneratedPose: clearAiPose ? null : (aiGeneratedPose ?? this.aiGeneratedPose),
    );
  }
}

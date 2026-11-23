/// 多格式、多教务系统课表文件与文本导入数据源
/// 支持 PDF、Word(.docx/.doc)、Excel(.xlsx/.xls)、CSV/TSV、ICS、HTML、JSON、纯文本
/// 具备文件魔数/内容自动嗅探能力，即使扩展名不准确也能识别

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/course_color_palette.dart';
import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../../domain/entities/course.dart';
import '../models/course_model.dart';
import 'aoxiang_jiaowu_adapter.dart';
import 'parsers/csv_schedule_parser.dart';
import 'parsers/ics_schedule_parser.dart';
import 'parsers/json_schedule_parser.dart';
import 'parsers/office_schedule_parser.dart';
import 'parsers/pdf_schedule_parser.dart';
import 'parsers/schedule_text_utils.dart';

abstract class CourseFileImportDataSource {
  Future<Result<List<Course>>> parseCourses({
    String? filePath,
    String? fileName,
    List<int>? bytes,
  });

  /// 直接解析剪贴板或粘贴文本（自动识别 JSON / HTML / CSV / TSV / ICS / 纯文本）
  Future<Result<List<Course>>> parseRawText(String text);
}

class LocalCourseFileImportDataSource implements CourseFileImportDataSource {
  static const List<String> supportedExtensions = [
    'pdf',
    'csv',
    'tsv',
    'docx',
    'doc',
    'xlsx',
    'xls',
    'ics',
    'html',
    'htm',
    'json',
    'txt',
  ];

  @override
  Future<Result<List<Course>>> parseCourses({
    String? filePath,
    String? fileName,
    List<int>? bytes,
  }) async {
    try {
      final resolvedName = _resolveFileName(filePath, fileName);
      final resolvedBytes =
          await _resolveFileBytes(filePath: filePath, bytes: bytes);
      final ext = p.extension(resolvedName).toLowerCase();

      final courses = _dispatchByExtAndMagic(ext: ext, bytes: resolvedBytes);

      if (courses.isEmpty) {
        return Result.failure(
          Failure.validation(message: '导入文件中未解析到有效课程数据，请检查文件内容或换用官网直接导入'),
        );
      }

      return Result.success(_normalizeImportedCourses(courses));
    } on FormatException catch (e) {
      return Result.failure(
        Failure.parse(message: e.message, cause: e),
      );
    } catch (e) {
      return Result.failure(
        Failure.parse(message: '解析导入文件失败: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<List<Course>>> parseRawText(String text) async {
    try {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        return const Result.failure(
          Failure.validation(message: '文本内容为空'),
        );
      }

      final courses = _parseSmartText(trimmed);
      if (courses.isEmpty) {
        return const Result.failure(
          Failure.validation(
            message: '未能从文本中识别课程，支持 JSON、CSV/TSV、HTML 表格、ICS 或「课程, 周一, 1-2节, 1-16周」格式',
          ),
        );
      }
      return Result.success(_normalizeImportedCourses(courses));
    } on FormatException catch (e) {
      return Result.failure(Failure.parse(message: e.message, cause: e));
    } catch (e) {
      return Result.failure(Failure.parse(message: '文本解析失败: $e', cause: e));
    }
  }

  List<Course> _dispatchByExtAndMagic({
    required String ext,
    required List<int> bytes,
  }) {
    // 1. 魔数嗅探优先处理明确二进制格式
    if (_startsWithAscii(bytes, '%PDF')) {
      return PdfScheduleParser.parseBytes(bytes);
    }

    if (_isZipHeader(bytes)) {
      if (ext == '.docx') {
        return OfficeScheduleParser.parseDocxOrDoc(bytes);
      }
      if (ext == '.xlsx') {
        return OfficeScheduleParser.parseXlsxOrXls(bytes);
      }
      // 扩展名不明确时，探测 ZIP 内部结构判断是 Word 还是 Excel
      final zipKind = _sniffZipOfficeKind(bytes);
      if (zipKind == 'docx') {
        return OfficeScheduleParser.parseDocxOrDoc(bytes);
      }
      if (zipKind == 'xlsx') {
        return OfficeScheduleParser.parseXlsxOrXls(bytes);
      }
    }

    // 2. 按扩展名路由
    switch (ext) {
      case '.pdf':
        return PdfScheduleParser.parseBytes(bytes);
      case '.docx':
      case '.doc':
        return OfficeScheduleParser.parseDocxOrDoc(bytes);
      case '.xlsx':
      case '.xls':
        return OfficeScheduleParser.parseXlsxOrXls(bytes);
      case '.csv':
      case '.tsv':
        return CsvScheduleParser.parseBytes(bytes);
      case '.ics':
        return IcsScheduleParser.parseBytes(bytes);
      case '.json':
        final jsonCourses = JsonScheduleParser.parseBytes(bytes);
        if (jsonCourses.isNotEmpty) return jsonCourses;
        return _parseSmartText(ScheduleTextUtils.decodeBytesFlexible(bytes));
      case '.html':
      case '.htm':
        final text = ScheduleTextUtils.decodeBytesFlexible(bytes);
        final adapterCourses = AoxiangJiaowuAdapter().parseRawContent(text);
        if (adapterCourses.isNotEmpty) return adapterCourses;
        return _parseSmartText(text);
      case '.txt':
      case '.wakeup_schedule':
        return _parseSmartText(ScheduleTextUtils.decodeBytesFlexible(bytes));
      default:
        // 未知后缀时尝试文本多格式自动嗅探
        final text = ScheduleTextUtils.decodeBytesFlexible(bytes);
        final sniffed = _parseSmartText(text);
        if (sniffed.isNotEmpty) {
          return sniffed;
        }
        throw const FormatException(
          '不支持的文件类型，支持 PDF、Word(.docx/.doc)、Excel(.xlsx/.xls)、CSV/TSV、ICS、HTML、JSON、TXT',
        );
    }
  }

  /// 智能多格式文本嗅探管道
  List<Course> _parseSmartText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];

    // 1. ICS 日历
    if (trimmed.contains('BEGIN:VCALENDAR') || trimmed.contains('BEGIN:VEVENT')) {
      final ics = IcsScheduleParser.parseString(trimmed);
      if (ics.isNotEmpty) return ics;
    }

    // 2. JSON（含树维 / 正方 / 强智 / WakeUp / 本应用格式）
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final jsonCourses = JsonScheduleParser.parseString(trimmed);
      if (jsonCourses.isNotEmpty) return jsonCourses;
    }

    // 3. HTML / 教务网页源码（含内嵌 script JSON）
    final lower = trimmed.toLowerCase();
    if (lower.contains('<table') ||
        lower.contains('<html') ||
        trimmed.contains('studentTableVm') ||
        trimmed.contains('kbList')) {
      final webCourses = AoxiangJiaowuAdapter().parseRawContent(trimmed);
      if (webCourses.isNotEmpty) return webCourses;
    }

    // 4. CSV / TSV（含列表式和二维矩阵式）
    final csvCourses = CsvScheduleParser.parseString(trimmed);
    if (csvCourses.isNotEmpty) return csvCourses;

    // 5. 逐行自由格式文本解析
    final lines = trimmed
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final freeform = <Course>[];
    for (var i = 0; i < lines.length; i++) {
      final parsed = ScheduleTextUtils.parseFreeformLine(
        lines[i],
        i,
        idPrefix: 'txt',
      );
      if (parsed != null) {
        freeform.add(parsed);
      }
    }
    return ScheduleTextUtils.dedupeAndMergeCourses(freeform);
  }

  List<Course> _normalizeImportedCourses(List<Course> courses) {
    final deduped = ScheduleTextUtils.dedupeAndMergeCourses(courses);
    final baseId = DateTime.now().millisecondsSinceEpoch;
    final normalized = <Course>[];
    for (var i = 0; i < deduped.length; i++) {
      final model = CourseModel.fromEntity(deduped[i]);
      final id = model.id.trim().isEmpty ? 'import-$baseId-$i' : model.id.trim();
      final color = model.color == 0xFF4F779A
          ? CourseColorPalette.getColorForName(model.name)
          : model.color;
      normalized.add(model.toEntity().copyWith(id: id, color: color));
    }
    return normalized;
  }

  String _resolveFileName(String? filePath, String? fileName) {
    final normalizedName = (fileName ?? '').trim();
    if (normalizedName.isNotEmpty) {
      return normalizedName;
    }

    final normalizedPath = (filePath ?? '').trim();
    if (normalizedPath.isNotEmpty) {
      return p.basename(normalizedPath);
    }

    throw const FormatException('缺少导入文件名');
  }

  Future<List<int>> _resolveFileBytes({
    String? filePath,
    List<int>? bytes,
  }) async {
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }

    final normalizedPath = (filePath ?? '').trim();
    if (normalizedPath.isEmpty) {
      throw const FormatException('未获取到导入文件内容');
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      throw FormatException('导入文件不存在: $normalizedPath');
    }

    return file.readAsBytes();
  }

  bool _startsWithAscii(List<int> bytes, String prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix.codeUnitAt(i)) return false;
    }
    return true;
  }

  bool _isZipHeader(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  String? _sniffZipOfficeKind(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      if (archive.findFile('word/document.xml') != null) {
        return 'docx';
      }
      if (archive.files.any((f) => f.name.startsWith('xl/worksheets/'))) {
        return 'xlsx';
      }
    } catch (_) {}
    return null;
  }
}

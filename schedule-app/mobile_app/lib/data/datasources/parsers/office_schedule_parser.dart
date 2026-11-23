import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../../domain/entities/course.dart';
import '../aoxiang_jiaowu_adapter.dart';
import 'csv_schedule_parser.dart';
import 'schedule_text_utils.dart';

/// Office 文档（Word .docx/.doc 与 Excel .xlsx/.xls）课表解析器
/// 支持：
/// - 标准 DOCX（多表格、gridSpan/vMerge、段落换行保留、矩阵课表 + 列表课表 + 文本行）
/// - 标准 XLSX（多工作表、sharedStrings 富文本拼接、inlineStr、列引用 r="C5" 精准对齐、矩阵 + 列表）
/// - 伪 .doc / .xls（国内教务系统常见导出 HTML/XML/CSV 改后缀为 .doc/.xls 的文件）
class OfficeScheduleParser {
  const OfficeScheduleParser._();

  static List<Course> parseDocxOrDoc(List<int> bytes) {
    // 1. 先检查是否为 ZIP（标准 .docx）
    if (_isZipHeader(bytes)) {
      return _parseDocxZip(bytes);
    }

    // 2. 检查是否为教务系统导出的 HTML/XML 伪 .doc
    final text = ScheduleTextUtils.decodeBytesFlexible(bytes);
    final lower = text.toLowerCase();
    if (lower.contains('<table') || lower.contains('<html')) {
      final htmlCourses = AoxiangJiaowuAdapter().parseHtmlSchedule(text);
      if (htmlCourses.isNotEmpty) {
        return htmlCourses;
      }
    }
    if (lower.contains('<?xml') && lower.contains('<w:document')) {
      final doc = XmlDocument.parse(text);
      final courses = _parseWordXmlDocument(doc);
      if (courses.isNotEmpty) {
        return courses;
      }
    }

    // 3. 检测旧版二进制 OLE2 .doc 文件头（D0 CF 11 E0）
    if (_isOle2Header(bytes)) {
      throw const FormatException(
        '检测到旧版二进制 Word (.doc) 格式，请先用 WPS / Word 另存为 .docx 或 .pdf 后再导入',
      );
    }

    // 4. 兜底按纯文本/CSV 解析
    final csvCourses = CsvScheduleParser.parseString(text);
    if (csvCourses.isNotEmpty) {
      return csvCourses;
    }

    throw const FormatException('Word 文件中未识别到可导入的课程表结构');
  }

  static List<Course> parseXlsxOrXls(List<int> bytes) {
    // 1. 标准 ZIP (.xlsx)
    if (_isZipHeader(bytes)) {
      return _parseXlsxZip(bytes);
    }

    // 2. 教务系统常见的 HTML / SpreadsheetML XML / CSV 伪 .xls
    final text = ScheduleTextUtils.decodeBytesFlexible(bytes);
    final lower = text.toLowerCase();
    if (lower.contains('<table') || lower.contains('<html')) {
      final htmlCourses = AoxiangJiaowuAdapter().parseHtmlSchedule(text);
      if (htmlCourses.isNotEmpty) {
        return htmlCourses;
      }
    }
    if (lower.contains('<worksheet') && lower.contains('<row')) {
      final xmlCourses = _parseSpreadsheetMlXml(text);
      if (xmlCourses.isNotEmpty) {
        return xmlCourses;
      }
    }

    if (_isOle2Header(bytes)) {
      throw const FormatException(
        '检测到旧版二进制 Excel (.xls) 格式，请另存为 .xlsx 或 .csv 后再导入',
      );
    }

    final csvCourses = CsvScheduleParser.parseString(text);
    if (csvCourses.isNotEmpty) {
      return csvCourses;
    }

    throw const FormatException('Excel 文件中未识别到可导入的课程表结构');
  }

  static List<Course> _parseDocxZip(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      throw const FormatException('DOCX 内容缺少 word/document.xml');
    }

    final xmlBytes = _toBytes(docFile.content);
    final document = XmlDocument.parse(utf8.decode(xmlBytes, allowMalformed: true));
    final courses = _parseWordXmlDocument(document);
    if (courses.isNotEmpty) {
      return courses;
    }
    throw const FormatException('DOCX 中未识别到可导入的课程表结构');
  }

  static List<Course> _parseWordXmlDocument(XmlDocument document) {
    final tables = _findElements(document, 'tbl').toList();

    // 遍历所有表格，提取最完整的课程集合
    final tableCandidates = <List<Course>>[];
    for (var t = 0; t < tables.length; t++) {
      final rows = _extractWordTableRows(tables[t]);
      if (rows.length < 2) continue;

      final matrix = ScheduleTextUtils.parseMatrixRows(
        rows,
        idPrefix: 'docx-t$t-m',
      );
      if (matrix.isNotEmpty) {
        tableCandidates.add(matrix);
        continue;
      }

      final header = ScheduleTextUtils.detectListHeader(rows);
      if (header != null) {
        final listCourses = <Course>[];
        for (var r = header.rowIndex + 1; r < rows.length; r++) {
          final parsed = ScheduleTextUtils.listRowToCourse(
            rows[r],
            header.columnMap,
            idPrefix: 'docx-t$t-row',
            rowIndex: r,
          );
          if (parsed != null) {
            listCourses.add(parsed);
          }
        }
        if (listCourses.isNotEmpty) {
          tableCandidates.add(ScheduleTextUtils.dedupeAndMergeCourses(listCourses));
        }
      }
    }

    if (tableCandidates.isNotEmpty) {
      tableCandidates.sort((a, b) => b.length.compareTo(a.length));
      return tableCandidates.first;
    }

    // 兜底解析段落文本
    final lines = _findElements(document, 'p')
        .map((pNode) => _findElements(pNode, 't').map((e) => e.innerText).join())
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final textCourses = <Course>[];
    for (var i = 0; i < lines.length; i++) {
      final course = ScheduleTextUtils.parseFreeformLine(
        lines[i],
        i,
        idPrefix: 'docx-line',
      );
      if (course != null) {
        textCourses.add(course);
      }
    }
    return ScheduleTextUtils.dedupeAndMergeCourses(textCourses);
  }

  /// 提取 Word 表格，保留单元格内段落换行，并展开 gridSpan 横向合并列
  static List<List<String>> _extractWordTableRows(XmlElement table) {
    final rows = <List<String>>[];
    final trElements = table.children
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'tr');

    for (final tr in trElements) {
      final row = <String>[];
      final tcElements = tr.children
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'tc');

      for (final tc in tcElements) {
        final text = _extractWordCellText(tc);
        final span = _readWordGridSpan(tc);
        row.add(text);
        for (var s = 1; s < span; s++) {
          row.add('');
        }
      }

      if (row.any((c) => c.trim().isNotEmpty)) {
        rows.add(row);
      }
    }
    return rows;
  }

  static String _extractWordCellText(XmlElement tc) {
    final paragraphs = _findElements(tc, 'p')
        .map((p) {
          final buf = StringBuffer();
          for (final node in p.descendants.whereType<XmlElement>()) {
            if (node.name.local == 't') {
              buf.write(node.innerText);
            } else if (node.name.local == 'br' || node.name.local == 'cr') {
              buf.write('\n');
            }
          }
          return buf.toString().trim();
        })
        .where((s) => s.isNotEmpty)
        .toList();
    return paragraphs.join('\n');
  }

  static int _readWordGridSpan(XmlElement tc) {
    final tcPr = _firstOrNull(
      tc.children.whereType<XmlElement>().where((e) => e.name.local == 'tcPr'),
    );
    if (tcPr == null) return 1;

    final spanEl = _firstOrNull(
      tcPr.children
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'gridSpan'),
    );
    if (spanEl == null) return 1;

    for (final attr in spanEl.attributes) {
      if (attr.name.local == 'val') {
        return int.tryParse(attr.value) ?? 1;
      }
    }
    return 1;
  }

  static List<Course> _parseXlsxZip(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final sstFile = archive.findFile('xl/sharedStrings.xml');

    final sharedStrings = <String>[];
    if (sstFile != null) {
      final sstDoc = XmlDocument.parse(
        utf8.decode(_toBytes(sstFile.content), allowMalformed: true),
      );
      // 每个 <si> 对应一条共享字符串，内部可能含多个 <r><t> 富文本片段
      final siNodes = _findElements(sstDoc, 'si').toList();
      if (siNodes.isNotEmpty) {
        for (final si in siNodes) {
          final text = _findElements(si, 't').map((e) => e.innerText).join();
          sharedStrings.add(text);
        }
      } else {
        sharedStrings.addAll(
          _findElements(sstDoc, 't').map((e) => e.innerText),
        );
      }
    }

    final sheetFiles = archive.files
        .where(
          (f) =>
              f.name.startsWith('xl/worksheets/sheet') &&
              f.name.endsWith('.xml'),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (sheetFiles.isEmpty) {
      throw const FormatException('XLSX 中缺少工作表 XML');
    }

    final candidates = <List<Course>>[];
    for (var s = 0; s < sheetFiles.length; s++) {
      final sheetDoc = XmlDocument.parse(
        utf8.decode(_toBytes(sheetFiles[s].content), allowMalformed: true),
      );
      final rows = _extractXlsxRows(sheetDoc, sharedStrings);
      if (rows.length < 2) continue;

      final header = ScheduleTextUtils.detectListHeader(rows);
      if (header != null) {
        final courses = <Course>[];
        for (var i = header.rowIndex + 1; i < rows.length; i++) {
          final parsed = ScheduleTextUtils.listRowToCourse(
            rows[i],
            header.columnMap,
            idPrefix: 'xlsx-s$s-row',
            rowIndex: i,
          );
          if (parsed != null) {
            courses.add(parsed);
          }
        }
        if (courses.isNotEmpty) {
          candidates.add(ScheduleTextUtils.dedupeAndMergeCourses(courses));
          continue;
        }
      }

      final matrixCourses = ScheduleTextUtils.parseMatrixRows(
        rows,
        idPrefix: 'xlsx-s$s-m',
      );
      if (matrixCourses.isNotEmpty) {
        candidates.add(matrixCourses);
      }
    }

    if (candidates.isNotEmpty) {
      candidates.sort((a, b) => b.length.compareTo(a.length));
      return candidates.first;
    }

    throw const FormatException('XLSX 中未识别到有效课程表结构');
  }

  /// 按 Excel 单元格坐标 r="C5" 精确对齐每一列，避免空单元格导致列错位
  static List<List<String>> _extractXlsxRows(
    XmlDocument sheetDoc,
    List<String> sharedStrings,
  ) {
    final rawRows = <Map<int, String>>[];
    var maxCol = 0;

    for (final rowNode in _findElements(sheetDoc, 'row')) {
      final colMap = <int, String>{};
      var fallbackCol = 0;

      for (final cNode in _findElements(rowNode, 'c')) {
        final ref = cNode.getAttribute('r') ?? '';
        final colIndex = _excelRefToColIndex(ref) ?? fallbackCol;
        fallbackCol = colIndex + 1;
        if (colIndex > maxCol) {
          maxCol = colIndex;
        }

        final type = cNode.getAttribute('t');
        var value = '';
        if (type == 'inlineStr') {
          value = _findElements(cNode, 't').map((e) => e.innerText).join();
        } else {
          final vNode = _firstOrNull(_findElements(cNode, 'v'));
          if (vNode != null) {
            final rawVal = vNode.innerText.trim();
            if (type == 's') {
              final idx = int.tryParse(rawVal);
              if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                value = sharedStrings[idx];
              } else {
                value = rawVal;
              }
            } else {
              value = rawVal;
            }
          }
        }
        colMap[colIndex] = value.trim();
      }

      if (colMap.values.any((v) => v.isNotEmpty)) {
        rawRows.add(colMap);
      }
    }

    final colCount = maxCol + 1;
    return rawRows.map((colMap) {
      return List.generate(colCount, (c) => colMap[c] ?? '');
    }).toList();
  }

  /// 解析旧版 Excel 2003 SpreadsheetML XML 格式
  static List<Course> _parseSpreadsheetMlXml(String xmlText) {
    try {
      final doc = XmlDocument.parse(xmlText);
      final rows = <List<String>>[];
      for (final rowEl in _findElements(doc, 'Row')) {
        final row = <String>[];
        for (final cellEl in _findElements(rowEl, 'Cell')) {
          final indexAttr = cellEl.getAttribute('ss:Index') ??
              cellEl.getAttribute('Index');
          if (indexAttr != null) {
            final targetIdx = (int.tryParse(indexAttr) ?? 1) - 1;
            while (row.length < targetIdx) {
              row.add('');
            }
          }
          final dataText =
              _findElements(cellEl, 'Data').map((e) => e.innerText).join();
          row.add(dataText.trim());
        }
        if (row.any((c) => c.isNotEmpty)) {
          rows.add(row);
        }
      }

      final header = ScheduleTextUtils.detectListHeader(rows);
      if (header != null) {
        final courses = <Course>[];
        for (var i = header.rowIndex + 1; i < rows.length; i++) {
          final c = ScheduleTextUtils.listRowToCourse(
            rows[i],
            header.columnMap,
            idPrefix: 'xls-xml-row',
            rowIndex: i,
          );
          if (c != null) courses.add(c);
        }
        if (courses.isNotEmpty) {
          return ScheduleTextUtils.dedupeAndMergeCourses(courses);
        }
      }

      return ScheduleTextUtils.parseMatrixRows(rows, idPrefix: 'xls-xml-m');
    } catch (_) {
      return const [];
    }
  }

  static int? _excelRefToColIndex(String ref) {
    final match = RegExp(r'^([A-Za-z]+)\d+$').firstMatch(ref.trim());
    if (match == null) return null;
    final letters = match.group(1)!.toUpperCase();
    var col = 0;
    for (var i = 0; i < letters.length; i++) {
      col = col * 26 + (letters.codeUnitAt(i) - 64);
    }
    return col - 1;
  }

  static bool _isZipHeader(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  static bool _isOle2Header(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0;
  }

  static List<int> _toBytes(dynamic content) {
    if (content is List<int>) {
      return content;
    }
    if (content is String) {
      return utf8.encode(content);
    }
    throw const FormatException('文档压缩内容读取失败');
  }

  static Iterable<XmlElement> _findElements(XmlNode root, String localName) {
    return root.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == localName);
  }

  static T? _firstOrNull<T>(Iterable<T> items) {
    final iterator = items.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

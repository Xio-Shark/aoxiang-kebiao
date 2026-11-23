import '../../../domain/entities/course.dart';
import 'schedule_text_utils.dart';

/// CSV / TSV 课表解析器（支持 RFC 4180 引号转义、多分隔符、列表式与二维矩阵式）
class CsvScheduleParser {
  const CsvScheduleParser._();

  /// 从字节流解析 CSV/TSV
  static List<Course> parseBytes(List<int> bytes) {
    final text = ScheduleTextUtils.decodeBytesFlexible(bytes);
    return parseString(text);
  }

  /// 从文本解析 CSV/TSV
  static List<Course> parseString(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final delimiter = _detectDelimiter(trimmed);
    final rows = parseCsvRows(trimmed, delimiter: delimiter);
    if (rows.length < 2) {
      return const [];
    }

    // 1. 优先尝试列表式课表（含 WakeUp CSV、教务导出清单 CSV、通用表格 CSV）
    final header = ScheduleTextUtils.detectListHeader(rows);
    if (header != null) {
      final listCourses = <Course>[];
      for (var i = header.rowIndex + 1; i < rows.length; i++) {
        final course = ScheduleTextUtils.listRowToCourse(
          rows[i],
          header.columnMap,
          idPrefix: 'csv-row',
          rowIndex: i,
        );
        if (course != null) {
          listCourses.add(course);
        }
      }
      if (listCourses.isNotEmpty) {
        return ScheduleTextUtils.dedupeAndMergeCourses(listCourses);
      }
    }

    // 2. 尝试二维矩阵式 CSV（表头为星期一~星期日）
    final matrixCourses = ScheduleTextUtils.parseMatrixRows(
      rows,
      idPrefix: 'csv-m',
    );
    if (matrixCourses.isNotEmpty) {
      return matrixCourses;
    }

    // 3. 无表头兜底按每行解析
    final fallback = <Course>[];
    for (var i = 0; i < rows.length; i++) {
      final course = ScheduleTextUtils.parseFreeformLine(
        rows[i].join(','),
        i,
        idPrefix: 'csv-line',
      );
      if (course != null) {
        fallback.add(course);
      }
    }
    return ScheduleTextUtils.dedupeAndMergeCourses(fallback);
  }

  /// 解析 RFC 4180 风格 CSV/TSV 二维数组（正确处理引号包裹的逗号与换行）
  static List<List<String>> parseCsvRows(
    String input, {
    String delimiter = ',',
  }) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(ch);
        }
        continue;
      }

      if (ch == '"') {
        inQuotes = true;
      } else if (ch == delimiter) {
        currentRow.add(buffer.toString().trim());
        buffer.clear();
      } else if (ch == '\r') {
        if (i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        currentRow.add(buffer.toString().trim());
        buffer.clear();
        if (currentRow.any((cell) => cell.isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = <String>[];
      } else if (ch == '\n') {
        currentRow.add(buffer.toString().trim());
        buffer.clear();
        if (currentRow.any((cell) => cell.isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = <String>[];
      } else {
        buffer.write(ch);
      }
    }

    if (buffer.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(buffer.toString().trim());
      if (currentRow.any((cell) => cell.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  static String _detectDelimiter(String sample) {
    final previewLines = sample
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .take(5)
        .toList();
    if (previewLines.isEmpty) {
      return ',';
    }

    const candidates = [',', '\t', ';'];
    var bestDelimiter = ',';
    var bestScore = -1;

    for (final d in candidates) {
      var total = 0;
      for (final line in previewLines) {
        total += d.allMatches(line).length;
      }
      if (total > bestScore) {
        bestScore = total;
        bestDelimiter = d;
      }
    }
    return bestDelimiter;
  }
}

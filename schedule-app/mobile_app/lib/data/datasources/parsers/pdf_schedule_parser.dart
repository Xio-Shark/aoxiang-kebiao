import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../domain/entities/course.dart';
import 'schedule_text_utils.dart';

/// PDF 页面上带坐标的文本片段
class PdfPositionedLine {
  const PdfPositionedLine({
    required this.pageIndex,
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int pageIndex;
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}

/// PDF 课表解析器
/// 支持三层解析：
/// 1. 坐标聚类二维网格课表（适配教务系统打印/导出的 PDF 课表）
/// 2. 坐标聚类列表表格课表（课程清单式 PDF）
/// 3. 纯文本行兜底解析
class PdfScheduleParser {
  const PdfScheduleParser._();

  static List<Course> parseBytes(List<int> bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final positioned = <PdfPositionedLine>[];

      for (var p = 0; p < document.pages.count; p++) {
        final lines = extractor.extractTextLines(
          startPageIndex: p,
          endPageIndex: p,
        );
        for (final line in lines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;
          final bounds = line.bounds;
          positioned.add(
            PdfPositionedLine(
              pageIndex: p,
              text: text,
              left: bounds.left,
              top: bounds.top,
              width: bounds.width,
              height: bounds.height,
            ),
          );
        }
      }

      if (positioned.isNotEmpty) {
        final layoutCourses = parsePositionedLines(positioned);
        if (layoutCourses.isNotEmpty) {
          return layoutCourses;
        }
      }

      final plainText = extractor.extractText();
      return parsePlainText(plainText);
    } finally {
      document.dispose();
    }
  }

  /// 基于坐标的通用 PDF 课表解析（暴露供纯单元测试调用）
  static List<Course> parsePositionedLines(List<PdfPositionedLine> lines) {
    if (lines.isEmpty) {
      return const [];
    }

    // 按页分组处理
    final byPage = <int, List<PdfPositionedLine>>{};
    for (final line in lines) {
      byPage.putIfAbsent(line.pageIndex, () => []).add(line);
    }

    final allCourses = <Course>[];
    final sortedPages = byPage.keys.toList()..sort();

    for (final pageIndex in sortedPages) {
      final pageLines = byPage[pageIndex]!;

      // 策略 1：尝试二维矩阵网格课表重建
      final matrixCourses = _parseCoordinateMatrix(pageLines, pageIndex);
      if (matrixCourses.isNotEmpty) {
        allCourses.addAll(matrixCourses);
        continue;
      }

      // 策略 2：按 Y 坐标聚类成行、按 X 坐标排序为列，走列表表格识别
      final tableRows = _clusterIntoRows(pageLines);
      final header = ScheduleTextUtils.detectListHeader(tableRows);
      if (header != null) {
        for (var i = header.rowIndex + 1; i < tableRows.length; i++) {
          final c = ScheduleTextUtils.listRowToCourse(
            tableRows[i],
            header.columnMap,
            idPrefix: 'pdf-p$pageIndex-row',
            rowIndex: i,
          );
          if (c != null) {
            allCourses.add(c);
          }
        }
        continue;
      }

      // 策略 3：行级自由文本解析
      for (var i = 0; i < tableRows.length; i++) {
        final joined = tableRows[i].join(' ');
        final c = ScheduleTextUtils.parseFreeformLine(
          joined,
          i,
          idPrefix: 'pdf-p$pageIndex-line',
        );
        if (c != null) {
          allCourses.add(c);
        }
      }
    }

    return ScheduleTextUtils.dedupeAndMergeCourses(allCourses);
  }

  /// 纯文本兜底解析
  static List<Course> parsePlainText(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final courses = <Course>[];
    for (var i = 0; i < lines.length; i++) {
      final parsed = ScheduleTextUtils.parseFreeformLine(
        lines[i],
        i,
        idPrefix: 'pdf-txt',
      );
      if (parsed != null) {
        courses.add(parsed);
      }
    }
    return ScheduleTextUtils.dedupeAndMergeCourses(courses);
  }

  /// 坐标聚类重建二维网格课表
  static List<Course> _parseCoordinateMatrix(
    List<PdfPositionedLine> pageLines,
    int pageIndex,
  ) {
    // 1. 寻找星期列头（同一 Y 水平带内出现 >= 5 个星期标签）
    final weekdayCandidates = <PdfPositionedLine>[];
    for (final line in pageLines) {
      if (line.text.length > 14 || RegExp(r'^\d+$').hasMatch(line.text)) {
        continue;
      }
      if (ScheduleTextUtils.parseWeekday(line.text) != null) {
        weekdayCandidates.add(line);
      }
    }
    if (weekdayCandidates.length < 5) {
      return const [];
    }

    // 找到包含最多不重复星期的水平带
    List<PdfPositionedLine> bestHeaderBand = const [];
    var bestUniqueDays = 0;

    for (final anchor in weekdayCandidates) {
      final band = weekdayCandidates
          .where((l) => (l.centerY - anchor.centerY).abs() <= 16)
          .toList();
      final days = band
          .map((l) => ScheduleTextUtils.parseWeekday(l.text))
          .whereType<int>()
          .toSet();
      if (days.length > bestUniqueDays) {
        bestUniqueDays = days.length;
        bestHeaderBand = band;
      }
    }

    if (bestUniqueDays < 5) {
      return const [];
    }

    // 按 X 坐标排序列头，构建每个星期的中心 X 与列边界
    final colHeaders = <({int weekday, double centerX, double left})>[];
    final seenDays = <int>{};
    final sortedHeader = [...bestHeaderBand]
      ..sort((a, b) => a.centerX.compareTo(b.centerX));

    for (final h in sortedHeader) {
      final wd = ScheduleTextUtils.parseWeekday(h.text);
      if (wd != null && seenDays.add(wd)) {
        colHeaders.add((weekday: wd, centerX: h.centerX, left: h.left));
      }
    }

    final headerBottomY = bestHeaderBand
        .map((h) => h.bottom)
        .reduce((a, b) => a > b ? a : b);
    final firstColLeft = colHeaders.first.left;

    // 计算每个星期列的水平区间 [minX, maxX)
    final colRanges = <({int weekday, double minX, double maxX})>[];
    for (var i = 0; i < colHeaders.length; i++) {
      final prevMid = i == 0
          ? (colHeaders[0].left - 18)
          : (colHeaders[i - 1].centerX + colHeaders[i].centerX) / 2;
      final nextMid = i == colHeaders.length - 1
          ? double.infinity
          : (colHeaders[i].centerX + colHeaders[i + 1].centerX) / 2;
      colRanges.add((weekday: colHeaders[i].weekday, minX: prevMid, maxX: nextMid));
    }

    // 2. 在最左侧区域识别节次行锚点
    final bodyLines = pageLines
        .where((l) => l.top >= headerBottomY - 2)
        .toList();
    final leftAnchors = <({int section, double top, double centerY})>[];

    for (final l in bodyLines) {
      if (l.centerX >= firstColLeft - 4) continue;
      final sec = ScheduleTextUtils.parseSection(l.text);
      if (sec != null) {
        leftAnchors.add((section: sec.start, top: l.top, centerY: l.centerY));
      }
    }
    leftAnchors.sort((a, b) => a.centerY.compareTo(b.centerY));

    // 去重相近 Y 的节次锚点
    final rowAnchors = <({int section, double centerY})>[];
    for (final a in leftAnchors) {
      if (rowAnchors.isEmpty || (a.centerY - rowAnchors.last.centerY).abs() > 14) {
        rowAnchors.add((section: a.section, centerY: a.centerY));
      }
    }

    // 如果左侧没有节次锚点，则按内容行直接聚类到列内解析
    final courses = <Course>[];
    if (rowAnchors.isEmpty) {
      for (final col in colRanges) {
        final colLines = bodyLines
            .where((l) => l.centerX >= col.minX && l.centerX < col.maxX)
            .toList()
          ..sort((a, b) => a.top.compareTo(b.top));
        if (colLines.isEmpty) continue;

        final blocks = _groupByVerticalGaps(colLines, gapThreshold: 14);
        for (var b = 0; b < blocks.length; b++) {
          final cellText = blocks[b].map((e) => e.text).join('\n');
          courses.addAll(
            ScheduleTextUtils.parseMatrixCell(
              cellText: cellText,
              weekday: col.weekday,
              fallbackStartSection: (b * 2 + 1).clamp(1, 11),
              idPrefix: 'pdf-p$pageIndex-d${col.weekday}-b$b',
            ),
          );
        }
      }
      return courses;
    }

    // 3. 构建每行的 Y 区间，把每个文本片段落入 (rowIndex, weekday) 网格中
    final gridCells = <String, List<PdfPositionedLine>>{};
    for (final l in bodyLines) {
      if (l.centerX < colRanges.first.minX) continue;
      int? matchedWeekday;
      for (final col in colRanges) {
        if (l.centerX >= col.minX && l.centerX < col.maxX) {
          matchedWeekday = col.weekday;
          break;
        }
      }
      if (matchedWeekday == null) continue;

      var bestRowIdx = 0;
      var bestDist = double.infinity;
      for (var r = 0; r < rowAnchors.length; r++) {
        final dist = (l.centerY - rowAnchors[r].centerY).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestRowIdx = r;
        }
      }

      final key = '$bestRowIdx|$matchedWeekday';
      gridCells.putIfAbsent(key, () => []).add(l);
    }

    for (final entry in gridCells.entries) {
      final parts = entry.key.split('|');
      final rowIdx = int.parse(parts[0]);
      final weekday = int.parse(parts[1]);
      final cellLines = entry.value
        ..sort((a, b) {
          final dy = (a.top - b.top).abs();
          if (dy > 4) return a.top.compareTo(b.top);
          return a.left.compareTo(b.left);
        });
      final text = cellLines.map((e) => e.text).join('\n');
      final fallbackSection = rowAnchors[rowIdx].section;

      courses.addAll(
        ScheduleTextUtils.parseMatrixCell(
          cellText: text,
          weekday: weekday,
          fallbackStartSection: fallbackSection,
          idPrefix: 'pdf-p$pageIndex-r$rowIdx-d$weekday',
        ),
      );
    }

    return courses;
  }

  static List<List<String>> _clusterIntoRows(List<PdfPositionedLine> pageLines) {
    final sorted = [...pageLines]..sort((a, b) => a.top.compareTo(b.top));
    final grouped = <List<PdfPositionedLine>>[];

    for (final line in sorted) {
      if (grouped.isEmpty) {
        grouped.add([line]);
        continue;
      }
      final lastRow = grouped.last;
      final avgY = lastRow.map((e) => e.centerY).reduce((a, b) => a + b) /
          lastRow.length;
      final tolerance = (line.height * 0.65).clamp(5.0, 12.0);
      if ((line.centerY - avgY).abs() <= tolerance) {
        lastRow.add(line);
      } else {
        grouped.add([line]);
      }
    }

    return grouped.map((row) {
      row.sort((a, b) => a.left.compareTo(b.left));
      return row.map((e) => e.text).toList();
    }).toList();
  }

  static List<List<PdfPositionedLine>> _groupByVerticalGaps(
    List<PdfPositionedLine> sortedLines, {
    required double gapThreshold,
  }) {
    if (sortedLines.isEmpty) return const [];
    final blocks = <List<PdfPositionedLine>>[
      [sortedLines.first],
    ];
    for (var i = 1; i < sortedLines.length; i++) {
      final prev = sortedLines[i - 1];
      final curr = sortedLines[i];
      if (curr.top - prev.bottom > gapThreshold) {
        blocks.add([curr]);
      } else {
        blocks.last.add(curr);
      }
    }
    return blocks;
  }
}

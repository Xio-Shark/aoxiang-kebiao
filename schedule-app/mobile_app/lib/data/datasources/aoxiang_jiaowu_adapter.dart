/// 西工大翱翔教务（jwxt.nwpu.edu.cn）与通用教务系统同步适配器
/// 负责：
/// 1. 注入 WebView 网络响应嗅探脚本与主动同源 API 拉取脚本
/// 2. 清洗解析树维 EAMS5（studentTableVm/activities）、正方、强智 JSON 与 HTML 课表

import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../domain/entities/course.dart';
import '../../domain/entities/section_time.dart';
import 'parsers/json_schedule_parser.dart';
import 'parsers/schedule_text_utils.dart';

/// 教务解析结果（包含课程列表、识别来源、可选开学第一周日期与教务作息时间表）
class JiaowuParseResult {
  const JiaowuParseResult({
    required this.courses,
    required this.sourceLabel,
    this.semesterStartDate,
    this.detectedTimeTable,
  });

  final List<Course> courses;
  final String sourceLabel;
  final DateTime? semesterStartDate;
  final SectionTimeTable? detectedTimeTable;
}

class AoxiangJiaowuAdapter {
  AoxiangJiaowuAdapter();

  /// 西工大翱翔教务学生首页（主适配入口）
  static const String homeUrl = 'https://jwxt.nwpu.edu.cn/student/home';

  /// 西工大翱翔教务我的课表页
  static const String courseTableUrl =
      'https://jwxt.nwpu.edu.cn/student/for-std/course-table';

  /// AT_DOCUMENT_START 注入的轻量级 XHR / Fetch 课表响应拦截脚本
  /// 在用户浏览 jwxt.nwpu.edu.cn 时自动无感捕获后端返回的树维课表 JSON
  static String buildSnifferUserScript() {
    return r'''
(function() {
  if (window.__aoxiangSnifferInstalled) return;
  window.__aoxiangSnifferInstalled = true;
  window.__aoxiangCapturedPayloads = window.__aoxiangCapturedPayloads || [];

  function isLikelyScheduleUrl(url) {
    if (!url) return false;
    var s = String(url).toLowerCase();
    return s.indexOf('course-table') !== -1 ||
      s.indexOf('print-data') !== -1 ||
      s.indexOf('get-data') !== -1 ||
      s.indexOf('xskbcx') !== -1 ||
      s.indexOf('kbxx') !== -1 ||
      s.indexOf('schedule') !== -1;
  }

  function isLikelyScheduleBody(text) {
    if (!text || text.length < 40) return false;
    return text.indexOf('studentTableVm') !== -1 ||
      text.indexOf('"activities"') !== -1 ||
      text.indexOf('"weekIndexes"') !== -1 ||
      text.indexOf('"kbList"') !== -1 ||
      text.indexOf('"arrangedLessonSearchVms"') !== -1;
  }

  function recordPayload(url, text) {
    try {
      if (!isLikelyScheduleUrl(url) && !isLikelyScheduleBody(text)) return;
      if (!isLikelyScheduleBody(text)) return;
      window.__aoxiangCapturedPayloads.push({
        url: String(url || ''),
        body: text,
        ts: Date.now()
      });
      if (window.__aoxiangCapturedPayloads.length > 8) {
        window.__aoxiangCapturedPayloads.shift();
      }
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('onScheduleCaptured', {
          url: String(url || ''),
          length: text.length
        });
      }
    } catch (_) {}
  }

  if (window.fetch) {
    var origFetch = window.fetch;
    window.fetch = function() {
      var reqUrl = '';
      try {
        var first = arguments[0];
        reqUrl = typeof first === 'string' ? first : (first && first.url ? first.url : '');
      } catch (_) {}
      return origFetch.apply(this, arguments).then(function(resp) {
        try {
          if (resp && resp.clone) {
            resp.clone().text().then(function(txt) {
              recordPayload(reqUrl || resp.url, txt);
            }).catch(function() {});
          }
        } catch (_) {}
        return resp;
      });
    };
  }

  var origOpen = XMLHttpRequest.prototype.open;
  var origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) {
    this.__aoxiangUrl = url;
    return origOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    this.addEventListener('load', function() {
      try {
        if (this.responseType === '' || this.responseType === 'text') {
          recordPayload(this.__aoxiangUrl || this.responseURL, this.responseText);
        }
      } catch (_) {}
    });
    return origSend.apply(this, arguments);
  };
})();
''';
  }

  /// 点击「一键导入」时执行的主动异步提取脚本（支持 callAsyncJavaScript）
  /// 四重提取链路：
  /// 1. XHR/Fetch 拦截器已捕获的树维 JSON
  /// 2. 在 jwxt.nwpu.edu.cn 同源会话内主动拉取 course-table 页面与 print-data / get-data 接口
  /// 3. 检查页面/iframe 全局变量（studentTableVm / kbList / courseData）
  /// 4. 提取主文档与所有同源 iframe 中的课表 HTML 表格
  static String buildActiveExtractionAsyncScript() {
    return r'''
try {
  // 1. 优先返回已拦截到的最新课表接口 JSON
  if (Array.isArray(window.__aoxiangCapturedPayloads) && window.__aoxiangCapturedPayloads.length > 0) {
    var latest = window.__aoxiangCapturedPayloads[window.__aoxiangCapturedPayloads.length - 1];
    if (latest && latest.body && latest.body.length > 40) {
      return JSON.stringify({
        kind: 'captured_api',
        url: latest.url || location.href,
        payload: latest.body
      });
    }
  }

  // 2. 若在西工大教务域名下（包括 /student/home），尝试主动拉取我的课表数据接口
  if (location.hostname && location.hostname.indexOf('jwxt.nwpu.edu.cn') !== -1) {
    try {
      var tablePageResp = await fetch('/student/for-std/course-table', {
        credentials: 'include'
      });
      if (tablePageResp && tablePageResp.ok) {
        var pageHtml = await tablePageResp.text();
        var stdMatch = pageHtml.match(/var\s+dataId\s*=\s*['"]?(\d+)['"]?/i) ||
                       pageHtml.match(/studentId['"]?\s*[:=]\s*['"]?(\d+)['"]?/i) ||
                       pageHtml.match(/\/course-table\/info\/(\d+)/i);
        var semMatch = pageHtml.match(/var\s+semesterId\s*=\s*['"]?(\d+)['"]?/i) ||
                       pageHtml.match(/currentSemesterId['"]?\s*[:=]\s*['"]?(\d+)['"]?/i) ||
                       pageHtml.match(/semester['"]?\s*[:=]\s*\{[^}]*?['"]?id['"]?\s*:\s*(\d+)/i) ||
                       pageHtml.match(/selected="selected"[^>]*value="(\d+)"/i) ||
                       pageHtml.match(/value="(\d+)"[^>]*selected="selected"/i);
        var bizMatch = pageHtml.match(/var\s+bizTypeId\s*=\s*['"]?(\d+)['"]?/i);

        var studentId = stdMatch ? stdMatch[1] : null;
        var semesterId = semMatch ? semMatch[1] : null;
        var bizTypeId = bizMatch ? bizMatch[1] : '2';

        // 先看当前页面下拉框中选中的学期
        if (!semesterId) {
          var sel = document.querySelector('select#allSemesters, select[name*="semester"], select.semester-select');
          if (sel && sel.value) semesterId = sel.value;
        }

        if (studentId && semesterId) {
          var endpoints = [
            '/student/for-std/course-table/semester/' + semesterId + '/print-data/' + studentId + '?hasExperiment=true',
            '/student/for-std/course-table/get-data?bizTypeId=' + bizTypeId + '&semesterId=' + semesterId + '&dataId=' + studentId
          ];
          for (var i = 0; i < endpoints.length; i++) {
            try {
              var apiResp = await fetch(endpoints[i], { credentials: 'include' });
              if (apiResp && apiResp.ok) {
                var apiText = await apiResp.text();
                if (apiText && (apiText.indexOf('activities') !== -1 || apiText.indexOf('studentTableVm') !== -1 || apiText.indexOf('weekIndexes') !== -1)) {
                  return JSON.stringify({
                    kind: 'nwpu_api',
                    url: endpoints[i],
                    payload: apiText
                  });
                }
              }
            } catch (_) {}
          }
        }

        // 如果 course-table HTML 内嵌了 studentTableVm 或完整表格，也直接返回
        if (pageHtml.indexOf('studentTableVm') !== -1 || pageHtml.indexOf('activities') !== -1) {
          return JSON.stringify({
            kind: 'nwpu_page_script',
            url: '/student/for-std/course-table',
            payload: pageHtml
          });
        }
      }
    } catch (_) {}
  }

  // 3. 检查主文档与同源 iframe 的全局变量和课表 DOM
  function inspectWindow(win) {
    try {
      if (win.studentTableVm) {
        return { kind: 'window_var', payload: JSON.stringify({ studentTableVm: win.studentTableVm }) };
      }
      if (win.kbList && Array.isArray(win.kbList)) {
        return { kind: 'window_var', payload: JSON.stringify({ kbList: win.kbList }) };
      }
      if (win.courseData) {
        return { kind: 'window_var', payload: JSON.stringify(win.courseData) };
      }
      var doc = win.document;
      if (!doc) return null;
      var table = doc.querySelector('#kbtable') ||
                  doc.querySelector('#courseTable') ||
                  doc.querySelector('.course-table') ||
                  doc.querySelector('.kb_table') ||
                  doc.querySelector('table.table-bordered');
      if (table && table.querySelectorAll('tr').length >= 4) {
        return { kind: 'dom_table', payload: table.outerHTML };
      }
      var allTables = doc.querySelectorAll('table');
      for (var t = 0; t < allTables.length; t++) {
        var txt = allTables[t].innerText || '';
        if ((txt.indexOf('星期一') !== -1 || txt.indexOf('周一') !== -1) &&
            allTables[t].querySelectorAll('tr').length >= 4) {
          return { kind: 'dom_table', payload: allTables[t].outerHTML };
        }
      }
    } catch (_) {}
    return null;
  }

  var mainResult = inspectWindow(window);
  if (mainResult) {
    mainResult.url = location.href;
    return JSON.stringify(mainResult);
  }

  var frames = document.querySelectorAll('iframe');
  for (var f = 0; f < frames.length; f++) {
    try {
      if (frames[f].contentWindow) {
        var frameResult = inspectWindow(frames[f].contentWindow);
        if (frameResult) {
          frameResult.url = location.href;
          return JSON.stringify(frameResult);
        }
      }
    } catch (_) {}
  }

  return JSON.stringify({
    kind: 'document_html',
    url: location.href,
    payload: document.documentElement ? document.documentElement.outerHTML : ''
  });
} catch (err) {
  return JSON.stringify({
    kind: 'error',
    error: String(err)
  });
}
''';
  }

  /// 解析提取结果，同时附带识别来源与开学第一周日期（若接口中存在）
  JiaowuParseResult parseExtractedPayload(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) {
      return const JiaowuParseResult(courses: [], sourceLabel: '空内容');
    }

    var actualPayload = trimmed;
    var sourceLabel = '教务网页';

    // 解包来自 buildActiveExtractionAsyncScript 的封装结构
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map && decoded.containsKey('kind') && decoded.containsKey('payload')) {
          final kind = decoded['kind']?.toString() ?? '';
          actualPayload = decoded['payload']?.toString() ?? '';
          sourceLabel = switch (kind) {
            'captured_api' => '翱翔教务实时接口',
            'nwpu_api' => '西工大教务 API',
            'nwpu_page_script' => '西工大教务页面数据',
            'window_var' => '教务页面数据对象',
            'dom_table' => '教务网页课表表格',
            _ => '教务网页',
          };
        }
      } catch (_) {}
    }

    final semesterStart = _extractSemesterStartDate(actualPayload);
    final detectedTable = _extractSectionTimeTable(actualPayload);
    final courses = parseRawContent(actualPayload);
    return JiaowuParseResult(
      courses: courses,
      sourceLabel: sourceLabel,
      semesterStartDate: semesterStart,
      detectedTimeTable: detectedTable,
    );
  }

  /// 从网页 HTML 内容或 JSON 响应中解析课程（保持既有公开 API 兼容）
  List<Course> parseRawContent(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) return [];

    // 1. 尝试作为 JSON 直接解析（支持树维 studentTableVm / 正方 kbList / 强智 / 本应用）
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final jsonCourses = JsonScheduleParser.parseString(trimmed);
      if (jsonCourses.isNotEmpty) {
        return jsonCourses;
      }
    }

    // 2. 尝试从 HTML 内嵌 <script> 中嗅探树维 studentTableVm / activities / kbList JSON
    final embeddedPatterns = [
      RegExp(
        r'studentTableVm\s*[:=]\s*(\{[\s\S]*?"activities"\s*:\s*\[[\s\S]*?\]\s*[\s\S]*?\})\s*[;,]',
      ),
      RegExp(r'"activities"\s*:\s*(\[\s*\{[\s\S]*?\}\s*\])'),
      RegExp(r'kbList\s*[:=]\s*(\[[\s\S]*?\])\s*;?'),
    ];
    for (final pattern in embeddedPatterns) {
      final match = pattern.firstMatch(trimmed);
      if (match != null && match.groupCount >= 1) {
        final candidate = match.group(1)!;
        final parsed = JsonScheduleParser.parseString(candidate);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    }

    // 3. 尝试解析 HTML 课表表格
    final htmlCourses = parseHtmlSchedule(trimmed);
    if (htmlCourses.isNotEmpty) {
      return htmlCourses;
    }

    return const [];
  }

  /// 从教务 JSON 响应结构中转换课程列表（保持既有公开 API 兼容）
  List<Course> parseJiaowuResponse(Map<String, dynamic> jsonResponse) {
    return ScheduleTextUtils.dedupeAndMergeCourses(
      JsonScheduleParser.parseDecoded(jsonResponse),
    );
  }

  /// 从 HTML 课表提取课程（支持 colspan/rowspan 展开、多表格择优、矩阵课表与列表课表）
  List<Course> parseHtmlSchedule(String html) {
    try {
      final doc = html_parser.parse(html);
      final tables = doc.querySelectorAll('table');
      if (tables.isEmpty) return const [];

      final candidates = <List<Course>>[];
      for (var t = 0; t < tables.length; t++) {
        final rows = _extractHtmlTableGrid(tables[t]);
        if (rows.length < 2) continue;

        final matrix = ScheduleTextUtils.parseMatrixRows(
          rows,
          idPrefix: 'html-t$t-m',
        );
        if (matrix.isNotEmpty) {
          candidates.add(matrix);
          continue;
        }

        final header = ScheduleTextUtils.detectListHeader(rows);
        if (header != null) {
          final listCourses = <Course>[];
          for (var i = header.rowIndex + 1; i < rows.length; i++) {
            final c = ScheduleTextUtils.listRowToCourse(
              rows[i],
              header.columnMap,
              idPrefix: 'html-t$t-row',
              rowIndex: i,
            );
            if (c != null) listCourses.add(c);
          }
          if (listCourses.isNotEmpty) {
            candidates.add(ScheduleTextUtils.dedupeAndMergeCourses(listCourses));
          }
        }
      }

      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.length.compareTo(a.length));
        return candidates.first;
      }
    } catch (_) {}

    return const [];
  }

  /// 将 HTML <table> 展开为精确对齐的二维字符串矩阵（正确处理 colspan 与 rowspan）
  List<List<String>> _extractHtmlTableGrid(dom.Element table) {
    final trList = table.querySelectorAll('tr');
    if (trList.isEmpty) return const [];

    final grid = <int, Map<int, String>>{};
    var maxCol = 0;

    for (var r = 0; r < trList.length; r++) {
      final cells = trList[r].querySelectorAll('th, td');
      var c = 0;
      for (final cell in cells) {
        while (grid[r]?.containsKey(c) ?? false) {
          c++;
        }

        final rowSpan =
            (int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 1).clamp(1, 16);
        final colSpan =
            (int.tryParse(cell.attributes['colspan'] ?? '1') ?? 1).clamp(1, 12);
        final text = _extractHtmlCellText(cell);

        for (var dr = 0; dr < rowSpan; dr++) {
          final targetRow = grid.putIfAbsent(r + dr, () => <int, String>{});
          for (var dc = 0; dc < colSpan; dc++) {
            // 只在左上角放文本，其余占位为空串避免重复解析同一课程
            targetRow[c + dc] = (dr == 0 && dc == 0) ? text : '';
            if (c + dc > maxCol) {
              maxCol = c + dc;
            }
          }
        }
        c += colSpan;
      }
    }

    final result = <List<String>>[];
    for (var r = 0; r < trList.length; r++) {
      final rowMap = grid[r];
      if (rowMap == null) continue;
      final row = List.generate(maxCol + 1, (col) => rowMap[col] ?? '');
      if (row.any((cell) => cell.trim().isNotEmpty)) {
        result.add(row);
      }
    }
    return result;
  }

  String _extractHtmlCellText(dom.Element cell) {
    final withBreaks = cell.innerHtml
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(?:div|p|li|tr)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n---\n');
    final parsed = html_parser.parseFragment(withBreaks).text ?? '';
    return parsed
        .split('\n')
        .map((s) => s.replaceAll('\u00A0', ' ').trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  /// 尝试从树维 JSON 中提取学期第一周起始日期（如 startDate: "2026-09-07"）
  DateTime? _extractSemesterStartDate(String raw) {
    final match = RegExp(
      r'"(?:startDate|firstWeekMonday|termStartDate)"\s*:\s*"(\d{4}-\d{2}-\d{2})"',
    ).firstMatch(raw);
    if (match == null) return null;
    return DateTime.tryParse(match.group(1)!);
  }

  /// 尝试从树维 JSON 中提取每节课的真实上下课时间表（courseUnitList / units）
  SectionTimeTable? _extractSectionTimeTable(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        return JsonScheduleParser.extractSectionTimeTable(decoded);
      } catch (_) {}
    }
    return null;
  }
}

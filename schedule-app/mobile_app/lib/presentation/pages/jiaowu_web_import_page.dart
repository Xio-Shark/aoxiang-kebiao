import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';
import '../../domain/entities/course.dart';

/// 教务系统直接导入页面
/// 内嵌 WebView 支持统一身份认证登录与一键课表嗅探抓取
class JiaowuWebImportPage extends ConsumerStatefulWidget {
  const JiaowuWebImportPage({super.key});

  @override
  ConsumerState<JiaowuWebImportPage> createState() => _JiaowuWebImportPageState();
}

class _JiaowuWebImportPageState extends ConsumerState<JiaowuWebImportPage> {
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isExtracting = false;
  String _currentUrl = '';

  static const String _defaultUrl = 'https://uis.nwpu.edu.cn/cas/login';

  Future<void> _extractSchedule() async {
    final controller = _webViewController;
    if (controller == null) return;

    setState(() {
      _isExtracting = true;
    });

    try {
      // 1. 尝试从页面全局变量、数据接口或 DOM 提取课表数据
      final dynamic evalResult = await controller.evaluateJavascript(
        source: """
          (function() {
            try {
              // 优先查找教务系统常见的全局课表缓存变量
              if (window.kbList && Array.isArray(window.kbList)) {
                return JSON.stringify({ kbList: window.kbList });
              }
              if (window.courseData) {
                return JSON.stringify(window.courseData);
              }
              
              // 抓取包含课表的表格或主体
              const table = document.querySelector("#kbtable") || 
                            document.querySelector(".kb_table") || 
                            document.querySelector("table");
              if (table) {
                return table.outerHTML;
              }
              return document.documentElement.outerHTML;
            } catch(e) {
              return document.documentElement.outerHTML;
            }
          })();
        """,
      );

      final rawContent = evalResult?.toString() ?? '';
      if (rawContent.isEmpty) {
        throw Exception('未从当前页面检测到课表数据，请确认已进入教务系统「我的课表」页面');
      }

      final adapter = ref.read(aoxiangJiaowuAdapterProvider);
      final courses = adapter.parseRawContent(rawContent);

      if (courses.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未解析到有效课程，请确保当前已跳转至课表表格页面'),
          ),
        );
        return;
      }

      final importResult = await ref.read(importScheduleUseCaseProvider).execute(
            courses,
            replaceExisting: true,
          );

      if (!mounted) return;

      importResult.when(
        success: (_) {
          final targetWeek = _resolveTargetWeek(courses);
          ref.read(selectedWeekProvider.notifier).state = targetWeek;
          ref.invalidate(scheduleProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功直接导入 ${courses.length} 门课程！')),
          );
          Navigator.of(context).pop();
        },
        failure: (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入失败: ${failure.message}')),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('抓取异常: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  int _resolveTargetWeek(List<Course> courses) {
    if (courses.isEmpty) return 1;
    final minWeek = courses
        .map((c) => c.startWeek)
        .reduce((min, val) => val < min ? val : min);
    return minWeek.clamp(1, 25);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '教务系统直接导入',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_currentUrl.isNotEmpty)
              Text(
                _currentUrl,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新网页',
            onPressed: () => _webViewController?.reload(),
          ),
        ],
        bottom: _progress < 1.0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_defaultUrl)),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              javaScriptEnabled: true,
              isInspectable: true,
              supportMultipleWindows: false,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _currentUrl = url?.toString() ?? '';
              });
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            onLoadStop: (controller, url) {
              setState(() {
                _progress = 1.0;
                _currentUrl = url?.toString() ?? '';
              });
            },
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isExtracting ? null : _extractSchedule,
                  icon: _isExtracting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_done_rounded, size: 22),
                  label: Text(
                    _isExtracting ? '正在抓取并解析...' : '一键导入当前页课表',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';
import '../../data/datasources/aoxiang_jiaowu_adapter.dart';
import '../../domain/entities/course.dart';
import '../widgets/import_preview_sheet.dart';
import '../widgets/motion_widgets.dart';

/// 西工大翱翔教务官网直接导入页面
/// 主适配入口：https://jwxt.nwpu.edu.cn/student/home
/// 同时兼容其他高校教务系统网址输入与通用课表抓取
class JiaowuWebImportPage extends ConsumerStatefulWidget {
  const JiaowuWebImportPage({
    super.key,
    this.initialUrl,
  });

  final String? initialUrl;

  @override
  ConsumerState<JiaowuWebImportPage> createState() =>
      _JiaowuWebImportPageState();
}

class _JiaowuWebImportPageState extends ConsumerState<JiaowuWebImportPage> {
  InAppWebViewController? _webViewController;
  final TextEditingController _urlController = TextEditingController();

  double _progress = 0;
  bool _isExtracting = false;
  bool _showAddressBar = false;
  bool _showGuideBanner = true;
  bool _hasCapturedApiPayload = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = AoxiangJiaowuAdapter.homeUrl;

  String get _entryUrl => widget.initialUrl ?? AoxiangJiaowuAdapter.homeUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = _entryUrl;
    _urlController.text = _entryUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _updateNavState() async {
    final ctrl = _webViewController;
    if (ctrl == null) return;
    final back = await ctrl.canGoBack();
    final forward = await ctrl.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _navigateTo(String rawUrl) async {
    var target = rawUrl.trim();
    if (target.isEmpty) return;
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      target = 'https://$target';
    }
    setState(() {
      _hasCapturedApiPayload = false;
      _showAddressBar = false;
    });
    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(target)),
    );
  }

  Future<void> _extractSchedule() async {
    final controller = _webViewController;
    if (controller == null) return;

    setState(() {
      _isExtracting = true;
    });

    try {
      // 执行异步四重提取脚本（捕获的 XHR/Fetch JSON -> 主动同源拉取西工大 API -> 全局变量 -> iframe/DOM 表格）
      final asyncResult = await controller.callAsyncJavaScript(
        functionBody: AoxiangJiaowuAdapter.buildActiveExtractionAsyncScript(),
      );

      final rawContent = asyncResult?.value?.toString() ?? '';
      if (rawContent.isEmpty) {
        throw Exception('未从当前页面检测到课表数据，请先完成登录或点击上方「我的课表」');
      }

      final adapter = ref.read(aoxiangJiaowuAdapterProvider);
      final parsed = adapter.parseExtractedPayload(rawContent);

      if (parsed.courses.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '当前页未检测到课程数据，请先登录教务系统并点击上方「我的课表」进入课表页后再点提取',
            ),
            action: SnackBarAction(
              label: '去我的课表',
              onPressed: () => _navigateTo(AoxiangJiaowuAdapter.courseTableUrl),
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      final confirm = await ImportPreviewSheet.show(
        context,
        courses: parsed.courses,
        sourceLabel: parsed.sourceLabel,
        timeTable: ref.read(sectionTimeTableProvider),
        initialReplaceExisting: true,
        detectedTermStartDate: parsed.semesterStartDate,
        detectedTimeTable: parsed.detectedTimeTable,
      );
      if (confirm == null || !mounted) {
        return;
      }

      final importResult = await ref.read(importScheduleUseCaseProvider).execute(
            parsed.courses,
            replaceExisting: confirm.replaceExisting,
          );

      if (!mounted) return;

      await importResult.when<Future<void>>(
        success: (_) async {
          if (confirm.syncTermStartDate && parsed.semesterStartDate != null) {
            await ref
                .read(termStartDateProvider.notifier)
                .setDate(parsed.semesterStartDate!);
          }
          if (confirm.syncTimeTable && parsed.detectedTimeTable != null) {
            await ref
                .read(sectionTimeTableProvider.notifier)
                .applyPreset(parsed.detectedTimeTable!);
          }
          invalidateAllScheduleCaches(ref);
          await syncCourseReminders(ref);
          final targetWeek = _resolveTargetWeek(parsed.courses);
          ref.read(selectedWeekProvider.notifier).state = targetWeek;
          if (mounted) {
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已成功导入 ${parsed.courses.length} 条排课记录'),
              ),
            );
            Navigator.of(context).pop();
          }
        },
        failure: (failure) async {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('导入失败: ${failure.message}')),
            );
          }
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
    final currentWeek = ref.read(currentWeekProvider);
    if (courses.any((c) => c.isVisibleInWeek(currentWeek))) {
      return currentWeek;
    }
    final minWeek = courses
        .map((c) => c.startWeek)
        .reduce((min, val) => val < min ? val : min);
    return minWeek.clamp(1, 25);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnCourseTable = _currentUrl.contains('course-table');
    final isOnNwpuHome = _currentUrl.contains('jwxt.nwpu.edu.cn/student/home');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '西工大翱翔教务导入',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
            ),
            Text(
              _currentUrl,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
            tooltip: '后退',
            onPressed: _canGoBack
                ? () async {
                    await _webViewController?.goBack();
                    await _updateNavState();
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
            tooltip: '前进',
            onPressed: _canGoForward
                ? () async {
                    await _webViewController?.goForward();
                    await _updateNavState();
                  }
                : null,
          ),
          IconButton(
            icon: Icon(
              _showAddressBar ? Icons.close_rounded : Icons.edit_location_alt_outlined,
              size: 20,
            ),
            tooltip: '自定义教务网址',
            onPressed: () {
              setState(() {
                _showAddressBar = !_showAddressBar;
                if (_showAddressBar) {
                  _urlController.text = _currentUrl;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21),
            tooltip: '刷新网页',
            onPressed: () => _webViewController?.reload(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_progress < 1.0 ? 3 : 1),
          child: _progress < 1.0
              ? LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2.5,
                )
              : Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
        ),
      ),
      body: Column(
        children: [
          // 可折叠自定义网址栏（兼容其他高校教务）
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _showAddressBar
                ? Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.go,
                            onSubmitted: _navigateTo,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: '输入其他高校教务系统网址...',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _navigateTo(_urlController.text),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(56, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text('前往'),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // 快捷跳转与状态条
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
            child: Row(
              children: [
                _QuickNavChip(
                  label: '教务首页',
                  icon: Icons.home_rounded,
                  selected: isOnNwpuHome,
                  onTap: () => _navigateTo(AoxiangJiaowuAdapter.homeUrl),
                ),
                const SizedBox(width: 8),
                _QuickNavChip(
                  label: '我的课表',
                  icon: Icons.table_chart_rounded,
                  selected: isOnCourseTable,
                  onTap: () => _navigateTo(AoxiangJiaowuAdapter.courseTableUrl),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => _showGuideBanner = !_showGuideBanner);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          size: 15,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _showGuideBanner ? '收起指引' : '导入指引',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 可折叠轻指引
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _showGuideBanner
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 8),
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.42),
                    child: Text(
                      '① 登录西工大统一身份认证进入首页 → ② 点上方「我的课表」或直接点下方一键提取（自动识别课表接口与表格）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // WebView 主体 + 悬浮操作栏
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_entryUrl)),
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: AoxiangJiaowuAdapter.buildSnifferUserScript(),
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  ]),
                  initialSettings: InAppWebViewSettings(
                    useShouldOverrideUrlLoading: false,
                    mediaPlaybackRequiresUserGesture: false,
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    sharedCookiesEnabled: true,
                    isInspectable: true,
                    supportMultipleWindows: false,
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'onScheduleCaptured',
                      callback: (args) {
                        if (mounted && !_hasCapturedApiPayload) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _hasCapturedApiPayload = true;
                          });
                        }
                        return {'ok': true};
                      },
                    );
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _currentUrl = url?.toString() ?? _currentUrl;
                    });
                    _updateNavState();
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100;
                    });
                  },
                  onLoadStop: (controller, url) {
                    setState(() {
                      _progress = 1.0;
                      _currentUrl = url?.toString() ?? _currentUrl;
                    });
                    _updateNavState();
                  },
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: BouncyTap(
                      onTap: _isExtracting ? null : _extractSchedule,
                      scaleDown: 0.96,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _hasCapturedApiPayload
                                ? [
                                    const Color(0xFF15803D),
                                    const Color(0xFF0E7C73),
                                  ]
                                : [
                                    theme.colorScheme.primary,
                                    Color.lerp(
                                      theme.colorScheme.primary,
                                      theme.colorScheme.tertiary,
                                      0.32,
                                    )!,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: (_hasCapturedApiPayload
                                      ? const Color(0xFF15803D)
                                      : theme.colorScheme.primary)
                                  .withValues(alpha: 0.36),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isExtracting)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            else if (_hasCapturedApiPayload)
                              const PulseDot(color: Colors.white, size: 7)
                            else
                              const Icon(
                                Icons.download_done_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            const SizedBox(width: 9),
                            Text(
                              _isExtracting
                                  ? '正在解析教务课表...'
                                  : (_hasCapturedApiPayload
                                      ? '已捕获课表接口 · 立即预览导入'
                                      : '一键提取并导入当前课表'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickNavChip extends StatelessWidget {
  const _QuickNavChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BouncyTap(
      onTap: onTap,
      scaleDown: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

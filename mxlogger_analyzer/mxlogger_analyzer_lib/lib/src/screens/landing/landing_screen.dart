import 'dart:io';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/crypt_entry_list.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_icon_button.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_logo.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/import_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/import_loading_view.dart';
import 'package:mxlogger_analyzer_lib/src/screens/landing/widget/mx_crypto_bg.dart';

enum _WizardStep { files, crypt }

/// 首次使用三步向导：
/// ① 拖入/选择日志文件 → 下一步 ② 输入 KEY/IV → 开始导入 ③ 真实进度 loading。
/// 导入成功由 MainScreen 切入数据页；失败回退到对应步骤。
class LandingScreen extends MXConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  LandingScreenState createState() => LandingScreenState();
}

class LandingScreenState extends MXConsumerState<LandingScreen> {
  /// 进入第二步时代入的已存解密参数组（编辑中的值即时保存进 store）
  late final List<CryptEntry> _initialEntries;
  _WizardStep _step = _WizardStep.files;

  /// 转场方向：前进新页从右滑入，回退从左滑入
  bool _forward = true;
  bool _dragover = false;

  @override
  void initState() {
    super.initState();
    _initialEntries = store.crypt.value.entries;
    // 导入失败回退：读取失败/文件里没有日志回第一步（换文件），
    // 解析失败（多为 Key/IV 错误）回第二步
    ref.listen(store.importer, (ImportState previous, ImportState next) {
      if (!mounted || previous.status == next.status) return;
      if (next.status == ImportStatus.failure) {
        _goTo(
          next.error == ImportError.parseFailed
              ? _WizardStep.crypt
              : _WizardStep.files,
          forward: false,
        );
      }
    });
  }

  void _goTo(_WizardStep step, {required bool forward}) {
    setState(() {
      _step = step;
      _forward = forward;
    });
  }

  /// 输入即保存，导入流程从 store 读取
  void _saveCrypt(List<CryptEntry> entries) {
    store.crypt.saveEntries(entries);
  }

  /// 选择能力由宿主注入（桌面壳用 file_picker 实现），未注入时不动作
  Future<void> _pickFiles() async {
    final MXPickLogFiles? pickLogFiles = store.host.pickLogFiles;
    if (pickLogFiles == null) return;
    final List<String> paths = await pickLogFiles();
    if (paths.isEmpty || !mounted) return;
    _addFiles(paths);
  }

  /// 追加文件到已选列表（去重，保留原顺序），支持分多次选择/拖入累积
  void _addFiles(List<String> paths) {
    final List<String> merged = store.wizardPaths.value.toList();
    for (final String path in paths) {
      if (!merged.contains(path)) merged.add(path);
    }
    store.wizardPaths.value = merged;
  }

  void _startImport() {
    final List<String> paths = store.wizardPaths.value;
    if (paths.isEmpty) return;
    store.importer.importFiles(paths);
  }

  /// 移除一个已选文件（全部移除后回到未选状态，「下一步」重新禁用）
  void _removeFile(String path) {
    store.wizardPaths.value = store.wizardPaths.value.toList()..remove(path);
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final ImportState importState = ref.watch(store.importer);
    final bool isDark = ref.watch(store.themeMode) == ThemeMode.dark;

    // success 到 MainScreen 复位之间的过渡帧仍算第三步，
    // 避免切入数据页前向导闪回第一步
    final bool importBusy =
        importState.isRunning || importState.status == ImportStatus.success;
    final int wizardIndex = importBusy
        ? 2
        : (_step == _WizardStep.files ? 0 : 1);

    // 拖入能力由宿主注入（桌面壳用 desktop_drop 实现），未注入时原样渲染
    return store.host.wrapDropTarget(
      onDragOver: (bool over) => setState(() => _dragover = over),
      onDrop: (List<String> paths) {
        setState(() => _dragover = false);
        if (importBusy || paths.isEmpty) return;
        // 追加到已选列表，支持多次拖入累积
        _addFiles(paths);
        // 拖入即视为完成第一步选择
        if (_step != _WizardStep.files) {
          _goTo(_WizardStep.files, forward: false);
        }
      },
      child: Stack(
        children: [
          // 背景动画铺满最底层（对齐设计稿 <mx-crypto-bg>），不拦截交互
          const Positioned.fill(child: IgnorePointer(child: MXCryptoBg())),
          // 小窗口下卡片内容可滚动，避免溢出
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: _card(tokens, importState, wizardIndex),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MXIconButton(
                  tooltip: isDark
                      ? context.l10n.themeToLight
                      : context.l10n.themeToDark,
                  icon: Icon(
                    isDark
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_outlined,
                    size: 15,
                  ),
                  size: context.mxTopButtonSize,
                  onTap: store.themeMode.toggle,
                ),
                const SizedBox(width: 7),
                MXIconButton(
                  tooltip: context.l10n.languageTip,
                  icon: const Icon(Icons.translate, size: 15),
                  size: context.mxTopButtonSize,
                  onTap: store.locale.toggle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(MXTokens tokens, ImportState importState, int wizardIndex) {
    // 仅第一步（选择文件）响应拖入高亮
    final bool highlightDrop = _dragover && wizardIndex == 0;
    return AnimatedScale(
      scale: highlightDrop ? 1.01 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: highlightDrop ? tokens.accent : tokens.border,
            radius: 18,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            // 移动端收窄内边距（设计稿 drop-card 34px 18px 30px）
            padding: context.isMobileLayout
                ? const EdgeInsets.fromLTRB(18, 34, 18, 30)
                : const EdgeInsets.fromLTRB(32, 48, 32, 40),
            decoration: BoxDecoration(
              color: highlightDrop
                  ? Color.alphaBlend(
                      tokens.accent.withValues(alpha: 0.07),
                      tokens.panel,
                    )
                  : tokens.panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // 拉伸使各步骤宽度恒等于卡片内宽，转场只动画高度不动画宽度，
              // 避免窄步骤→宽步骤过渡帧把定宽的 KEY/IV 输入框压到溢出
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _brandBlock(tokens),
                const SizedBox(height: 24),
                // 窄屏（尤其英文文案更长）步骤条按比例缩放，不换行不溢出
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _StepIndicator(current: wizardIndex),
                  ),
                ),
                const SizedBox(height: 24),
                // 步骤转场：前进从右滑入，回退从左滑入。
                // 出场页用 Positioned 脱离 Stack 高度测量，卡片高度只由目标页决定，
                // 高度差交给 AnimatedSize 平滑过渡，避免三步高度不一致导致的跳动
                AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          final bool incoming =
                              child.key == ValueKey<int>(wizardIndex);
                          final double beginX = incoming
                              ? (_forward ? 0.12 : -0.12)
                              : (_forward ? -0.12 : 0.12);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(beginX, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    layoutBuilder:
                        (Widget? currentChild, List<Widget> previousChildren) {
                          return Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              for (final Widget child in previousChildren)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: child,
                                ),
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                    child: KeyedSubtree(
                      key: ValueKey<int>(wizardIndex),
                      child: switch (wizardIndex) {
                        0 => _filesStep(tokens),
                        1 => _cryptStep(tokens),
                        _ => ImportLoadingView(state: importState),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 品牌区：logo + MXLogger + 副标题 + 平台 chips
  Widget _brandBlock(MXTokens tokens) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MXLogo(size: 56),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "MX",
                style: TextStyle(color: tokens.accent),
              ),
              const TextSpan(text: "Logger"),
            ],
          ),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.22,
            color: tokens.text,
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: context.l10n.landingSubtitlePrefix),
              TextSpan(
                text: "mmap",
                style: TextStyle(
                  color: tokens.accent,
                  fontFamilyFallback: MXTheme.monoFontFallback,
                ),
              ),
              TextSpan(text: context.l10n.landingSubtitleSuffix),
              TextSpan(
                text: "  ·  ",
                style: TextStyle(color: tokens.faint),
              ),
              TextSpan(text: context.l10n.landingDot1),
              TextSpan(
                text: "  ·  ",
                style: TextStyle(color: tokens.faint),
              ),
              TextSpan(text: context.l10n.landingDot2),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            letterSpacing: 0.25,
            color: tokens.muted,
          ),
        ),
      ],
    );
  }

  /// 第一步：选择文件 + 下一步
  Widget _filesStep(MXTokens tokens) {
    final List<String> paths = ref.watch(store.wizardPaths);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 点击图标即打开文件选择（拖入由外层 DropTarget 处理）
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _pickFiles,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tokens.panel2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.border),
              ),
              child: Icon(
                Icons.upload_file_outlined,
                size: 28,
                color: tokens.accent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.landingFilesTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.text,
          ),
        ),
        const SizedBox(height: 8),
        // 未选文件：提示语；已选：提示语让位给单行可横向滚动的文件名
        if (paths.isEmpty)
          Text(
            context.l10n.landingFilesDesc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.7, color: tokens.muted),
          )
        else ...[
          Text(
            context.l10n.selectedFiles(paths.length),
            style: TextStyle(fontSize: 11.5, color: tokens.faint),
          ),
          const SizedBox(height: 8),
          _selectedFileRow(tokens, paths),
        ],
        const SizedBox(height: 22),
        _PrimaryButton(
          icon: Icons.arrow_forward,
          label: context.l10n.nextStep,
          enabled: paths.isNotEmpty,
          onTap: () => _goTo(_WizardStep.crypt, forward: true),
        ),
      ],
    );
  }

  /// 已选文件单行展示：横向排列，放不下则横向滚动；内容窄于卡片时居中。
  Widget _selectedFileRow(MXTokens tokens, List<String> paths) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final String path in paths)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding:
                        const EdgeInsets.only(left: 10, right: 5, top: 3, bottom: 3),
                    decoration: BoxDecoration(
                      color: tokens.panel2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tokens.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            path.split(Platform.pathSeparator).last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.text,
                              fontFamilyFallback: MXTheme.monoFontFallback,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _RemoveChipButton(onTap: () => _removeFile(path)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 第二步：KEY/IV + 开始导入
  Widget _cryptStep(MXTokens tokens) {
    final int fileCount = ref.watch(store.wizardPaths).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: tokens.panel2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: Icon(Icons.key_outlined, size: 28, color: tokens.accent),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.wizardStepCrypt,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.cryptNote,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.7, color: tokens.muted),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.selectedFiles(fileCount),
          style: TextStyle(fontSize: 11.5, color: tokens.faint),
        ),
        const SizedBox(height: 20),
        // 多组 KEY/IV：勾选的组按序号依次尝试解密（组件内部已做移动端换行）
        CryptEntryList(
          initialEntries: _initialEntries,
          onChanged: _saveCrypt,
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          icon: Icons.play_arrow_rounded,
          label: context.l10n.startImport,
          enabled: true,
          onTap: _startImport,
        ),
        const SizedBox(height: 16),
        _LinkButton(
          label: context.l10n.prevStep,
          onTap: () => _goTo(_WizardStep.files, forward: false),
        ),
      ],
    );
  }
}

/// 三步指示器：编号圈 + 步骤名全程可见，用户在任一步都能预知前后步骤。
/// 已完成步显示对勾，当前步强调色高亮，未到步灰显。
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final List<String> labels = [
      context.l10n.wizardStepFiles,
      context.l10n.wizardStepCrypt,
      context.l10n.wizardStepImport,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 22,
              height: 1.2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: i <= current
                  ? tokens.accent.withValues(alpha: 0.6)
                  : tokens.border,
            ),
          _stepItem(tokens, i, labels[i]),
        ],
      ],
    );
  }

  Widget _stepItem(MXTokens tokens, int index, String label) {
    final bool done = index < current;
    final bool active = index == current;
    final Color circleBg = done || active ? tokens.accent : Colors.transparent;
    final Color circleBorder = done || active ? tokens.accent : tokens.faint;
    final Color labelColor = active
        ? tokens.accent
        : (done ? tokens.muted : tokens.faint);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleBg,
            border: Border.all(color: circleBorder),
          ),
          alignment: Alignment.center,
          child: done
              ? Icon(Icons.check, size: 11, color: tokens.onAccent)
              : Text(
                  "${index + 1}",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: active ? tokens.onAccent : tokens.faint,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

/// 已选文件 chip 上的移除按钮：hover 变错误色，点击移除该文件。
class _RemoveChipButton extends StatefulWidget {
  const _RemoveChipButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RemoveChipButton> createState() => _RemoveChipButtonState();
}

class _RemoveChipButtonState extends State<_RemoveChipButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovering ? tokens.lvError.withValues(alpha: 0.15) : Colors.transparent,
          ),
          child: Icon(
            Icons.close,
            size: 12,
            color: _hovering ? tokens.lvError : tokens.faint,
          ),
        ),
      ),
    );
  }
}

/// 主按钮（accent 底白字，hover 提亮；disabled 灰化）。
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Color bg;
    final Color fg;
    if (!widget.enabled) {
      bg = tokens.panel2;
      fg = tokens.faint;
    } else {
      bg = _hovering
          ? Color.alphaBlend(Colors.white.withValues(alpha: 0.1), tokens.accent)
          : tokens.accent;
      fg = Colors.white;
    }
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: fg),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 次级链接按钮（上一步）。
class _LinkButton extends StatefulWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 12.5,
            color: _hovering ? tokens.accent : tokens.faint,
            decoration: _hovering
                ? TextDecoration.underline
                : TextDecoration.none,
            decorationColor: tokens.accent,
          ),
        ),
      ),
    );
  }
}

/// 圆角虚线描边（Flutter 无原生 dashed border）。
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    const double dash = 6;
    const double gap = 5;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

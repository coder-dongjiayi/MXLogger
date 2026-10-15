import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_open_link.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';

Future<void> showSupportAuthorDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierColor: MXTokens.of(context).mask,
    builder: (BuildContext context) => const _SupportAuthorDialog(),
  );
}

class _SupportAuthorDialog extends StatelessWidget {
  const _SupportAuthorDialog();

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final AppLocalizations l10n = context.l10n;
    return Dialog(
      backgroundColor: tokens.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.isMobileLayout ? 16 : 40,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.coffee_outlined,
                    size: 28,
                    color: tokens.lvWarning,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      icon: Icon(Icons.close, size: 18, color: tokens.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  l10n.supportTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.supportMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 22),
              const _PayPalSupportCard(),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget wechat = _PaymentCard(
                    label: l10n.supportWechat,
                    hint: l10n.supportWechatHint,
                    asset: 'assets/support/wechat_qr.png',
                    icon: Icon(Icons.wechat, color: tokens.jsonStr, size: 24),
                  );
                  final Widget alipay = _PaymentCard(
                    label: l10n.supportAlipay,
                    hint: l10n.supportAlipayHint,
                    asset: 'assets/support/alipay_qr.png',
                    icon: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '支',
                        style: TextStyle(
                          color: MXTokens.light.panel,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                  if (constraints.maxWidth < 480) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [wechat, const SizedBox(height: 16), alipay],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: wechat),
                      const SizedBox(width: 16),
                      Expanded(child: alipay),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Text(
                l10n.supportVoluntary,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayPalSupportCard extends StatelessWidget {
  const _PayPalSupportCard();

  static const Color _brandBlue = Color(0xFF0070BA);

  // 请求金额在 PayPal 页面展示，弹窗显示作者主页地址。
  static final Uri _url = Uri.https('paypal.me', '/djy068150/9.99USD');

  Future<void> _copyLink(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: _url.toString()));
      if (context.mounted) showMXToast(context, context.l10n.copied);
    } catch (_) {
      if (context.mounted) showMXToast(context, context.l10n.openLinkFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final AppLocalizations l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.08),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Widget details = Row(
            children: [
              const _PayPalLogo(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PayPal',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.supportPayPalHint,
                      style: TextStyle(color: tokens.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      '${_url.host}/${_url.pathSegments.first}',
                      style: TextStyle(color: tokens.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          );
          final Widget actions = Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => mxOpenExternalLink(context, _url),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: Text(l10n.supportPayPal),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _brandBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.supportCopyLink,
                onPressed: () => _copyLink(context),
                icon: Icon(Icons.copy_outlined, size: 16, color: tokens.muted),
              ),
            ],
          );
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 12), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _PayPalLogo extends StatelessWidget {
  const _PayPalLogo();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 17,
              top: 11,
              child: Text(
                'P',
                style: TextStyle(
                  color: const Color(0xFF009CDE),
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 5,
              child: Text(
                'P',
                style: TextStyle(
                  color: const Color(0xFF003087),
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.label,
    required this.hint,
    required this.asset,
    required this.icon,
  });

  final String label;
  final String hint;
  final String asset;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PaymentQr(asset: asset, label: label, hint: hint),
          const SizedBox(height: 12),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.supportEnlargeQr,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.faint, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PaymentQr extends StatelessWidget {
  const _PaymentQr({
    required this.asset,
    required this.label,
    required this.hint,
  });

  final String asset;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return SizedBox(
      width: 192,
      child: AspectRatio(
        aspectRatio: 1,
        child: OutlinedButton(
          onPressed: () => showDialog<void>(
            context: context,
            useRootNavigator: false,
            barrierColor: tokens.mask,
            builder: (context) =>
                _QrPreviewDialog(asset: asset, label: label, hint: hint),
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: MXTokens.light.panel,
            side: BorderSide(color: MXTokens.light.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _QrImage(
            asset: asset,
            semanticLabel: '$label · ${context.l10n.supportEnlargeQr}',
          ),
        ),
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  const _QrImage({required this.asset, required this.semanticLabel});

  final String asset;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    package: 'mxlogger_analyzer_lib',
    fit: BoxFit.contain,
    filterQuality: FilterQuality.none,
    semanticLabel: semanticLabel,
  );
}

class _QrPreviewDialog extends StatelessWidget {
  const _QrPreviewDialog({
    required this.asset,
    required this.label,
    required this.hint,
  });

  final String asset;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Dialog(
      backgroundColor: tokens.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 18, color: tokens.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _QrImage(asset: asset, semanticLabel: label),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

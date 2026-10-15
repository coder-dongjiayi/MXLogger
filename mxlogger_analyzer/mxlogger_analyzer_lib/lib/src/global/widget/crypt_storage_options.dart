import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';

/// Web 解密入口共用的本地处理说明与可选持久化开关。
class CryptStorageOptions extends MXConsumerStatefulWidget {
  const CryptStorageOptions({super.key});

  @override
  MXConsumerState<CryptStorageOptions> createState() =>
      _CryptStorageOptionsState();
}

class _CryptStorageOptionsState extends MXConsumerState<CryptStorageOptions> {
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final tokens = MXTokens.of(context);
    final crypt = store.crypt;
    final remember = crypt.persistEntries;
    final privacy = remember
        ? context.l10n.cryptPrivacyLocal
        : context.l10n.cryptPrivacySession;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: privacy,
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 15, color: tokens.muted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    privacy,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.6,
                      color: tokens.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (crypt.canChoosePersistence) ...[
            const SizedBox(height: 10),
            Semantics(
              label: context.l10n.rememberCrypt,
              checked: remember,
              onTap: () => _toggle(!remember),
              excludeSemantics: true,
              child: InkWell(
                onTap: () => _toggle(!remember),
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: remember,
                        activeColor: tokens.accent,
                        checkColor: tokens.onAccent,
                        side: BorderSide(color: tokens.faint),
                        onChanged: (value) => _toggle(value!),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        context.l10n.rememberCrypt,
                        style: TextStyle(fontSize: 12, color: tokens.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 29, top: 4),
              child: Text(
                context.l10n.rememberCryptHint,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: tokens.faint,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggle(bool enabled) {
    store.crypt.setPersistEntries(enabled);
    setState(() {});
  }
}

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../main.dart';
import '../theme.dart';

/// Compact entry; the 21-language list opens in a scrollable remote-friendly dialog.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final selected = appState.languageTag;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.translate_outlined, color: AppTheme.accent),
          title: Text(tr(context, 'Language')),
          subtitle: Text(
            selected.isEmpty
                ? tr(context, 'System default')
                : languageNames[selected] ?? selected,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguages(context),
        );
      },
    );
  }

  Future<void> _showLanguages(BuildContext context) async {
    final selected = appState.languageTag;
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * .78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr(dialogContext, 'Language'),
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: supportedLanguageTags.length + 1,
                  itemBuilder: (context, index) {
                    final tag = index == 0
                        ? ''
                        : supportedLanguageTags[index - 1];
                    return ListTile(
                      dense: true,
                      title: Text(
                        tag.isEmpty
                            ? tr(context, 'System default')
                            : languageNames[tag]!,
                      ),
                      trailing: tag == selected
                          ? Icon(Icons.check, color: AppTheme.accent)
                          : null,
                      onTap: () => Navigator.pop(context, tag),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) await appState.setLanguageTag(chosen);
  }
}

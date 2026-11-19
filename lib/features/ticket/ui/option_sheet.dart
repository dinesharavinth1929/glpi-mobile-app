import 'package:flutter/material.dart';

import '../../../core/a11y/contrast.dart';
import '../../../core/utils/layout.dart';

/// A generic single-choice bottom sheet used for priority / urgency / type /
/// location edits. Returns the chosen value's id, or null if dismissed.
class OptionSheet extends StatefulWidget {
  const OptionSheet({
    super.key,
    required this.title,
    required this.options,
    required this.current,
  });

  final String title;
  final List<OptionItem> options;
  final int current;

  static Future<int?> show(
    BuildContext context, {
    required String title,
    required List<OptionItem> options,
    required int current,
  }) => showModalBottomSheet<int>(
    useSafeArea: true,
    // Root navigator: from the embedded two-pane detail the nearest
    // navigator is the shell branch, whose barrier misses the rail,
    // bottom bar, and shell FAB (they overlap the sheet on a foldable).
    useRootNavigator: true,
    context: context,
    constraints: sheetConstraints(context),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        OptionSheet(title: title, options: options, current: current),
  );

  @override
  State<OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<OptionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final showSearch = widget.options.length > 8;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : [
            for (final o in widget.options)
              if (o.label.toLowerCase().contains(q)) o,
          ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
            if (showSearch) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.title.toLowerCase()}…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear search',
                            onPressed: () => setState(() => _query = ''),
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ],
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: sheetContentHeight(context, fraction: 0.6),
              ),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No matching ${widget.title.toLowerCase()}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final o = filtered[index];
                        return ListTile(
                          leading: o.color == null
                              ? null
                              : Icon(
                                  Icons.circle,
                                  size: 14,
                                  color: ensureContrast(
                                    o.color!,
                                    Theme.of(context).colorScheme.surface,
                                    minRatio: wcagAaGraphics,
                                  ),
                                ),
                          title: Text(o.label),
                          selected: o.value == widget.current,
                          trailing: o.value == widget.current
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onTap: () => Navigator.pop(context, o.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class OptionItem {
  const OptionItem({required this.value, required this.label, this.color});
  final int value;
  final String label;
  final Color? color;
}
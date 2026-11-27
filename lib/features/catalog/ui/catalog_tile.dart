import 'package:material_ui/material_ui.dart';

import '../../../core/models/catalog_item.dart';

/// Displays a single GLPI catalog record in lists and scan results.
class CatalogTile extends StatelessWidget {
  const CatalogTile({
    super.key,
    required this.item,
    this.showType = false,
    this.onTap,
  });

  final CatalogItem item;
  final bool showType;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleText = item.name.trim().isNotEmpty
        ? item.name.trim()
        : '${item.itemtype} #${item.serverId}';

    final metaParts = <String>[
      if (showType) item.itemtype,
      if (item.serial != null && item.serial!.trim().isNotEmpty)
        'S/N: ${item.serial!.trim()}',
      if (item.otherserial != null && item.otherserial!.trim().isNotEmpty)
        'Tag: ${item.otherserial!.trim()}',
      if (item.statusName != null && item.statusName!.trim().isNotEmpty)
        item.statusName!.trim(),
      if (item.locationName != null && item.locationName!.trim().isNotEmpty)
        item.locationName!.trim(),
    ];

    return ListTile(
      leading: Icon(_iconForItemtype(item.itemtype)),
      title: Text(
        titleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: metaParts.isEmpty
          ? null
          : Text(
              metaParts.join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
      trailing: item.pending
          ? Icon(
              Icons.sync,
              size: 18,
              color: theme.colorScheme.primary,
              semanticLabel: 'Pending sync',
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap ??
          () {
            Navigator.of(context).pushNamed(
              '/catalog/detail',
              arguments: item,
            );
          },
    );
  }

  IconData _iconForItemtype(String itemtype) {
    switch (itemtype) {
      case 'Computer':
        return Icons.laptop;
      case 'Monitor':
        return Icons.desktop_windows;
      case 'NetworkEquipment':
        return Icons.router;
      case 'Peripheral':
        return Icons.devices_other;
      case 'Printer':
        return Icons.print;
      case 'Phone':
        return Icons.phone_android;
      case 'Rack':
      case 'Enclosure':
      case 'Datacenter':
        return Icons.dns;
      case 'Software':
      case 'SoftwareLicense':
        return Icons.apps;
      case 'Certificate':
        return Icons.verified_user;
      case 'Document':
      case 'Contract':
        return Icons.description;
      default:
        return Icons.inventory_2;
    }
  }
}
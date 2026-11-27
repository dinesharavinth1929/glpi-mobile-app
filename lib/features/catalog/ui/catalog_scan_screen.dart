import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/a11y/a11y.dart';
import '../../../core/models/catalog_item.dart';
import '../../../core/providers.dart';
import 'catalog_tile.dart';

/// Point the camera at an asset label: supports both GLPI's built-in Asset URL
/// QR codes (`.../front/computer.form.php?id=1`) and plain serial / asset-tag
/// barcodes across the primary asset types.
class CatalogScanScreen extends ConsumerStatefulWidget {
  const CatalogScanScreen({super.key});

  @override
  ConsumerState<CatalogScanScreen> createState() => _CatalogScanScreenState();
}

class _CatalogScanScreenState extends ConsumerState<CatalogScanScreen> {
  final _scanner = MobileScannerController();
  final _manual = TextEditingController();
  bool _busy = false;
  String? _message;
  List<CatalogItem> _matches = const [];

  @override
  void dispose() {
    _scanner.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> openCatalogItem(
    BuildContext context,
    WidgetRef ref,
    CatalogItem item,
  ) async {
    if (!context.mounted) return;
    await Navigator.of(context).pushNamed(
      '/catalog/detail',
      arguments: item,
    );
  }

  /// Parses GLPI web URLs such as `http://10.10.0.170/front/computer.form.php?id=1`
  /// into their domain, GLPI itemtype, and numeric server ID.
  ({String domain, String itemtype, int id})? _parseGlpiUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final id = int.tryParse(uri.queryParameters['id'] ?? '');
    if (id == null || id <= 0) return null;

    final lastSegment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last.toLowerCase()
        : '';
    if (!lastSegment.endsWith('.form.php')) return null;

    const assetMap = <String, String>{
      'computer.form.php': 'Computer',
      'monitor.form.php': 'Monitor',
      'networkequipment.form.php': 'NetworkEquipment',
      'peripheral.form.php': 'Peripheral',
      'printer.form.php': 'Printer',
      'phone.form.php': 'Phone',
      'rack.form.php': 'Rack',
      'enclosure.form.php': 'Enclosure',
      'pdu.form.php': 'PDU',
      'cable.form.php': 'Cable',
      'certificate.form.php': 'Certificate',
      'software.form.php': 'Software',
      'softwarelicense.form.php': 'SoftwareLicense',
      'cartridgeitem.form.php': 'CartridgeItem',
      'consumableitem.form.php': 'ConsumableItem',
      'appliance.form.php': 'Appliance',
      'cluster.form.php': 'Cluster',
      'datacenter.form.php': 'Datacenter',
      'domain.form.php': 'Domain',
      'database.form.php': 'Database',
      'databaseinstance.form.php': 'DatabaseInstance',
    };

    final assetType = assetMap[lastSegment];
    if (assetType != null) {
      return (domain: 'Assets', itemtype: assetType, id: id);
    }

    const managementMap = <String, String>{
      'document.form.php': 'Document',
      'contract.form.php': 'Contract',
      'supplier.form.php': 'Supplier',
      'contact.form.php': 'Contact',
      'line.form.php': 'Line',
      'budget.form.php': 'Budget',
    };

    final mgmtType = managementMap[lastSegment];
    if (mgmtType != null) {
      return (domain: 'Management', itemtype: mgmtType, id: id);
    }

    return null;
  }

  Future<void> _lookup(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _matches = const [];
    });

    final repo = ref.read(catalogRepositoryProvider);

    // 1. Handle GLPI's built-in Asset URL QR code directly.
    final parsedUrl = _parseGlpiUrl(trimmed);
    if (parsedUrl != null) {
      if (repo == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _message = 'Lookup failed — check the connection';
          });
        }
        return;
      }
      try {
        final localId = await repo.localIdFor(
          parsedUrl.domain,
          parsedUrl.itemtype,
          parsedUrl.id,
        );
        if (!mounted) return;
        setState(() => _busy = false);
        if (localId == null || localId.isEmpty) {
          setState(
            () => _message = 'No ${parsedUrl.itemtype} #${parsedUrl.id} found',
          );
          announce(context, 'No ${parsedUrl.itemtype} ${parsedUrl.id} found');
          await _scanner.start();
          return;
        }
        final item = CatalogItem(
          localId: localId,
          domain: parsedUrl.domain,
          itemtype: parsedUrl.itemtype,
          serverId: parsedUrl.id,
          name: '',
          serial: null,
          otherserial: null,
          statusName: null,
          locationName: null,
          userName: null,
          groupName: null,
          manufacturerName: null,
          modelName: null,
          typeName: null,
          entityName: null,
          expiryDate: null,
          fields: const {},
          pending: false,
        );
        Navigator.of(context).pop();
        await openCatalogItem(context, ref, item);
        return;
      } on Exception {
        if (mounted) {
          setState(() {
            _busy = false;
            _message = 'Lookup failed — check the connection';
          });
        }
        return;
      }
    }

    // 2. Otherwise search by serial number or asset tag.
    List<CatalogItem> hits = const [];
    try {
      hits =
          await repo?.searchAcross('Assets', primaryAssetTypes, trimmed) ??
          const [];
    } on Exception {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = 'Lookup failed — check the connection';
        });
      }
      return;
    }

    final exact = [
      for (final h in hits)
        if ((h.serial ?? '').toLowerCase() == trimmed.toLowerCase() ||
            (h.otherserial ?? '').toLowerCase() == trimmed.toLowerCase())
          h,
    ];
    final result = exact.isNotEmpty ? exact : hits;
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isEmpty) {
      setState(() => _message = 'No asset with code "$trimmed"');
      announce(context, 'No asset with code $trimmed');
      await _scanner.start();
      return;
    }
    if (result.length == 1) {
      Navigator.of(context).pop();
      await openCatalogItem(context, ref, result.first);
      return;
    }
    setState(() => _matches = result);
    announce(context, '${result.length} matching assets');
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.trim().isEmpty) continue;
      await _scanner.stop();
      await _lookup(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan asset')),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: Semantics(
              label:
                  'Camera viewfinder. Point it at the asset label, or type '
                  'the code below.',
              excludeSemantics: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(controller: _scanner, onDetect: _onDetect),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  if (_busy)
                    const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Looking up',
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Or type the code',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _lookup,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _lookup(_manual.text),
                  child: const Text('Find'),
                ),
              ],
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          if (_matches.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: _matches.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) =>
                    CatalogTile(item: _matches[i], showType: true),
              ),
            ),
        ],
      ),
    );
  }
}
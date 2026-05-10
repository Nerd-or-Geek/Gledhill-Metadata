import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../application/rename_library_controller.dart';
import '../../../services/import_export_service.dart';
import '../../../models/rename_convention.dart';
import '../../../models/template_folder_node.dart';
import '../../../state/providers.dart';
import '../../../utils/rename_pattern.dart';

enum _ImportConflictAction { replace, keepBoth, cancel }

class RenameScreen extends ConsumerWidget {
  const RenameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(renameLibraryControllerProvider);
    final controller = ref.read(renameLibraryControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rename Conventions'),
        actions: [
          TextButton.icon(
            onPressed: () => _importConventions(context, ref, controller, state.selectedFolderPath),
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Import'),
          ),
          TextButton.icon(
            onPressed: () => _exportAll(context, ref),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Export All'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 320,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                            child: Row(
                              children: [
                                Icon(Icons.account_tree_outlined,
                                    size: 18, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('Folder Structure', style: Theme.of(context).textTheme.titleSmall),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  state.selectedFolderPath.isEmpty
                                      ? 'Selected: Root'
                                      : 'Selected: ${state.selectedFolderPath}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          _FolderToolbar(
                            onCreate: () => _createFolder(context, controller, state.selectedFolderPath),
                            onRename: () => _renameFolder(context, controller, state.selectedFolderPath),
                            onDelete: state.selectedFolderPath.isEmpty
                                ? null
                                : () => _deleteFolder(context, controller, state.selectedFolderPath),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: state.folderTree == null
                                ? const Center(child: Text('No folders found.'))
                                : ListView(
                                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                                    children: [
                                      _FolderTreeNode(
                                        node: state.folderTree!,
                                        selectedPath: state.selectedFolderPath,
                                        onSelect: controller.selectFolder,
                                        onExportFolder: (folderPath) => _exportFolder(context, ref, folderPath),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SearchBar(
                                hintText: 'Search conventions',
                                leading: const Icon(Icons.search),
                                onChanged: controller.setSearchQuery,
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () => _openConventionEditor(context, ref, controller),
                              icon: const Icon(Icons.add),
                              label: const Text('New Convention'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: state.filteredConventions.isEmpty
                              ? const Center(child: Text('No conventions in this folder.'))
                              : ListView.separated(
                                  itemCount: state.filteredConventions.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final convention = state.filteredConventions[index];
                                    return ListTile(
                                      title: InkWell(
                                        onTap: () => _openConventionEditor(
                                          context,
                                          ref,
                                          controller,
                                          existing: convention,
                                        ),
                                        child: Text(convention.name),
                                      ),
                                      subtitle: Text(convention.pattern),
                                      trailing: Wrap(
                                        spacing: 4,
                                        children: [
                                          IconButton(
                                            onPressed: () async {
                                              await controller.saveConvention(
                                                convention.copyWith(isFavorite: !convention.isFavorite),
                                                originalId: convention.id,
                                              );
                                              await ref
                                                  .read(libraryCatalogControllerProvider.notifier)
                                                  .refresh();
                                            },
                                            icon: Icon(
                                              convention.isFavorite ? Icons.star : Icons.star_border,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => _openConventionEditor(
                                              context,
                                              ref,
                                              controller,
                                              existing: convention,
                                            ),
                                            child: const Text('Edit'),
                                          ),
                                          TextButton(
                                            onPressed: () => _duplicateConvention(
                                              context,
                                              ref,
                                              controller,
                                              convention,
                                            ),
                                            child: const Text('Duplicate'),
                                          ),
                                          TextButton(
                                            onPressed: () => _exportSingleConvention(context, ref, convention),
                                            child: const Text('Export'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              // Clear default if this convention is the default
                                              if (ref.read(appSettingsControllerProvider).defaultConventionId == convention.id) {
                                                await ref.read(appSettingsControllerProvider.notifier).setDefaultConventionId(null);
                                              }
                                              await controller.deleteConvention(convention);
                                              await ref
                                                  .read(libraryCatalogControllerProvider.notifier)
                                                  .refresh();
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _duplicateConvention(
    BuildContext context,
    WidgetRef ref,
    RenameLibraryController controller,
    RenameConvention original,
  ) async {
    final duplicateName = 'Copy of ${original.name}';
    final duplicate = original.copyWith(
      id: duplicateName,
      name: duplicateName,
      isFavorite: false,
    );

    await controller.saveConvention(duplicate);
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();

    RenameConvention target = duplicate;
    for (final item in ref.read(renameLibraryControllerProvider).conventions) {
      if (item.name == duplicateName) {
        target = item;
        break;
      }
    }

    if (!context.mounted) {
      return;
    }

    await _openConventionEditor(context, ref, controller, existing: target);
  }

  Future<void> _exportSingleConvention(
    BuildContext context,
    WidgetRef ref,
    RenameConvention convention,
  ) async {
    final service = ref.read(importExportServiceProvider);
    final path = await service.chooseSavePath(
      dialogTitle: 'Export naming convention',
      defaultFileName: '${convention.name}.json',
      allowedExtensions: const ['json'],
    );

    if (path == null) {
      return;
    }

    await service.exportSingleJson(
      payload: service.renameExportJson(convention),
      outputPath: path,
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Convention exported: ${p.basename(path)}')),
    );
  }

  Future<void> _exportFolder(BuildContext context, WidgetRef ref, String folderPath) async {
    final service = ref.read(importExportServiceProvider);
    final storage = ref.read(renameConventionStorageServiceProvider);

    final savePath = await service.chooseSavePath(
      dialogTitle: 'Export folder',
      defaultFileName: '${folderPath.isEmpty ? 'conventions' : p.basename(folderPath)}.zip',
      allowedExtensions: const ['zip'],
    );

    if (savePath == null) {
      return;
    }

    final root = await storage.ensureRootDirectory();
    await service.exportDirectoryAsZip(
      rootDirectory: root,
      relativeFolderPath: folderPath,
      outputPath: savePath,
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder exported: ${p.basename(savePath)}')),
    );
  }

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final service = ref.read(importExportServiceProvider);
    final storage = ref.read(renameConventionStorageServiceProvider);

    final savePath = await service.chooseSavePath(
      dialogTitle: 'Export all conventions',
      defaultFileName: 'all_rename_conventions.zip',
      allowedExtensions: const ['zip'],
    );

    if (savePath == null) {
      return;
    }

    final root = await storage.ensureRootDirectory();
    await service.exportAllAsZip(rootDirectory: root, outputPath: savePath);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('All conventions exported: ${p.basename(savePath)}')),
    );
  }

  Future<void> _importConventions(
    BuildContext context,
    WidgetRef ref,
    RenameLibraryController controller,
    String selectedFolder,
  ) async {
    final service = ref.read(importExportServiceProvider);
    final paths = await service.chooseImportFiles();
    if (paths.isEmpty) {
      return;
    }

    final payloads = await service.loadImportPayloads(paths);
    final conventionPayloads = payloads.where((p) => p.kind == ImportItemKind.renameConvention).toList();
    final invalidCount = payloads.length - conventionPayloads.length;

    final targetFolder = selectedFolder.isEmpty ? 'Imported' : selectedFolder;
    if (selectedFolder.isEmpty) {
      await controller.createFolder(parentRelativePath: '', folderName: 'Imported');
    }

    await controller.selectFolder(targetFolder);

    var importedCount = 0;
    final current = [...ref.read(renameLibraryControllerProvider).conventions];

    for (final payload in conventionPayloads) {
      var incoming = service.toConvention(payload.rawJson).copyWith(isFavorite: false);

      RenameConvention? existing;
      for (final item in current) {
        if (item.name.toLowerCase() == incoming.name.toLowerCase()) {
          existing = item;
          break;
        }
      }

      if (existing != null) {
        if (!context.mounted) {
          return;
        }
        final action = await _askImportConflict(context, incoming.name, itemLabel: 'convention');
        if (action == _ImportConflictAction.cancel) {
          continue;
        }
        if (action == _ImportConflictAction.keepBoth) {
          incoming = incoming.copyWith(name: _resolveImportedName(incoming.name, current.map((e) => e.name).toSet().cast<String>()));
          await controller.saveConvention(incoming);
          current.add(incoming);
          importedCount++;
        } else {
          await controller.saveConvention(incoming, originalId: existing.id);
          current.removeWhere((e) => e.id == existing!.id);
          current.add(incoming);
          importedCount++;
        }
      } else {
        await controller.saveConvention(incoming);
        current.add(incoming);
        importedCount++;
      }
    }

    await ref.read(libraryCatalogControllerProvider.notifier).refresh();

    if (!context.mounted) {
      return;
    }

    final invalidSuffix = invalidCount > 0 ? ' ($invalidCount file(s) skipped: wrong type)' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$importedCount conventions imported successfully$invalidSuffix')),
    );
  }

  Future<void> _createFolder(
    BuildContext context,
    RenameLibraryController controller,
    String parentRelativePath,
  ) async {
    final input = await _askText(context, 'Create Folder', 'Folder name');
    if (input == null || input.isEmpty) {
      return;
    }
    await controller.createFolder(parentRelativePath: parentRelativePath, folderName: input);
  }

  Future<void> _renameFolder(
    BuildContext context,
    RenameLibraryController controller,
    String relativePath,
  ) async {
    if (relativePath.isEmpty) {
      return;
    }
    final input = await _askText(context, 'Rename Folder', 'New folder name');
    if (input == null || input.isEmpty) {
      return;
    }
    await controller.renameFolder(relativePath: relativePath, newName: input);
  }

  Future<void> _deleteFolder(
    BuildContext context,
    RenameLibraryController controller,
    String relativePath,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text('Delete folder "$relativePath" and all conventions inside it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.deleteFolder(relativePath);
    }
  }

  Future<void> _openConventionEditor(
    BuildContext context,
    WidgetRef ref,
    RenameLibraryController controller, {
    RenameConvention? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final patternController = TextEditingController(
      text: existing?.pattern ?? '{year}-{month}-{day}_{sequence:3}_{metadata:author}',
    );
    final patternFocusNode = FocusNode();

    const metadataChoices = <String>[
      'author',
      'camera model',
      'iso',
      'lensmodel',
      'datetimeoriginal',
    ];

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();
            final samples = List.generate(5, (index) {
              return applyRenamePattern(
                pattern: patternController.text,
                date: now,
                sequence: index + 1,
                title: 'Sample ${index + 1}',
                metadata: const {
                  'author': 'alex_gledhill',
                  'camera model': 'Sony_A7R_V',
                  'iso': '400',
                  'lensmodel': '35mm_f1.4',
                  'datetimeoriginal': '2026:05:01_10:30:22',
                },
                extension: '.jpg',
              );
            });

            void insertToken(String token) {
              final old = patternController.text;
              final selection = patternController.selection;
              final start = selection.start < 0 ? old.length : selection.start;
              final end = selection.end < 0 ? old.length : selection.end;
              final updated = old.replaceRange(start, end, token);
              patternController.value = TextEditingValue(
                text: updated,
                selection: TextSelection.collapsed(offset: start + token.length),
              );
              patternFocusNode.requestFocus();
              setModalState(() {});
            }

            return AlertDialog(
              title: Text(existing == null ? 'Create Rename Convention' : 'Edit Rename Convention'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Convention name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: patternController,
                        focusNode: patternFocusNode,
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Pattern',
                          border: OutlineInputBorder(),
                          helperText:
                              'Example: {year}-{month}-{day}_{sequence:3}_{metadata:author}_custom',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final token in const [
                            '{year}',
                            '{month}',
                            '{day}',
                            '{hour}',
                            '{minute}',
                            '{second}',
                            '{sequence}',
                            '{sequence:3}',
                          ])
                            Focus(
                              canRequestFocus: false,
                              child: OutlinedButton(
                                onPressed: () => insertToken(token),
                                child: Text(token),
                              ),
                            ),
                          Focus(
                            canRequestFocus: false,
                            child: DropdownButton<String>(
                              hint: const Text('Insert metadata token'),
                              items: metadataChoices
                                  .map(
                                    (field) => DropdownMenuItem(
                                      value: field,
                                      child: Text(field),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                insertToken('{metadata:$value}');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Live preview', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final sample in samples)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $sample'),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (saved != true || nameController.text.trim().isEmpty) {
      nameController.dispose();
      patternController.dispose();
      patternFocusNode.dispose();
      return;
    }

    await controller.saveConvention(
      RenameConvention(
        id: existing?.id ?? nameController.text.trim(),
        name: nameController.text.trim(),
        isFavorite: existing?.isFavorite ?? false,
        folderPath: existing?.folderPath ?? '',
        pattern: patternController.text.trim(),
      ),
      originalId: existing?.id,
    );

    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
    
    nameController.dispose();
    patternController.dispose();
    patternFocusNode.dispose();
  }

  Future<String?> _askText(BuildContext context, String title, String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _FolderToolbar extends StatelessWidget {
  const _FolderToolbar({
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  final VoidCallback onCreate;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.create_new_folder, size: 18),
            label: const Text('Create'),
          ),
          OutlinedButton.icon(
            onPressed: onRename,
            icon: const Icon(Icons.drive_file_rename_outline, size: 18),
            label: const Text('Rename'),
          ),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _FolderTreeNode extends StatelessWidget {
  const _FolderTreeNode({
    required this.node,
    required this.selectedPath,
    required this.onSelect,
    required this.onExportFolder,
  });

  final TemplateFolderNode node;
  final String selectedPath;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onExportFolder;

  @override
  Widget build(BuildContext context) {
    final isSelected = node.relativePath == selectedPath;
    final colorScheme = Theme.of(context).colorScheme;
    final hasChildren = node.children.isNotEmpty;
    final folderIcon = hasChildren ? Icons.folder_open_outlined : Icons.folder_outlined;

    return ExpansionTile(
      initiallyExpanded: isSelected,
      iconColor: colorScheme.primary,
      collapsedIconColor: colorScheme.onSurfaceVariant,
      title: Row(
        children: [
          Icon(folderIcon, size: 18, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onSelect(node.relativePath),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colorScheme.primary : null,
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Folder actions',
            onSelected: (value) {
              if (value == 'export') {
                onExportFolder(node.relativePath);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('Export folder')),
            ],
          ),
        ],
      ),
      children: [
        for (final child in node.children)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _FolderTreeNode(
              node: child,
              selectedPath: selectedPath,
              onSelect: onSelect,
              onExportFolder: onExportFolder,
            ),
          ),
      ],
    );
  }
}

Future<_ImportConflictAction> _askImportConflict(
  BuildContext context,
  String name, {
  required String itemLabel,
}) async {
  final action = await showDialog<_ImportConflictAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$itemLabel already exists'),
      content: Text(
        'A $itemLabel named "$name" already exists. Replace it, keep both, or cancel?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _ImportConflictAction.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ImportConflictAction.keepBoth),
          child: const Text('Keep both'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ImportConflictAction.replace),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  return action ?? _ImportConflictAction.cancel;
}

String _resolveImportedName(String baseName, Set<String> existingNames) {
  var candidate = '$baseName imported';
  var i = 2;
  while (existingNames.any((name) => name.toLowerCase() == candidate.toLowerCase())) {
    candidate = '$baseName imported $i';
    i++;
  }
  return candidate;
}

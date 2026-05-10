import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/metadata_template.dart';
import '../models/rename_convention.dart';

enum ImportItemKind {
  metadataTemplate,
  renameConvention,
  unknown,
}

class ImportPayload {
  const ImportPayload({
    required this.fileName,
    required this.rawJson,
    required this.kind,
    required this.sourcePath,
  });

  final String fileName;
  final Map<String, dynamic> rawJson;
  final ImportItemKind kind;
  final String sourcePath;
}

class ImportExportService {
  static const formatVersion = '2.0';

  Future<String?> chooseSavePath({
    required String dialogTitle,
    required String defaultFileName,
    required List<String> allowedExtensions,
  }) async {
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      lockParentWindow: true,
    );
  }

  Future<List<String>> chooseImportFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['json', 'zip'],
      lockParentWindow: true,
    );

    if (result == null) {
      return const [];
    }

    return result.paths.whereType<String>().toList(growable: false);
  }

  Map<String, dynamic> templateExportJson(MetadataTemplate template) {
    return {
      'gledhillForgeVersion': formatVersion,
      'type': 'metadataTemplate',
      'name': template.name,
      'isFavorite': template.isFavorite,
      'fields': template.fields,
    };
  }

  Map<String, dynamic> renameExportJson(RenameConvention convention) {
    return {
      'gledhillForgeVersion': formatVersion,
      'type': 'renameConvention',
      'name': convention.name,
      'isFavorite': convention.isFavorite,
      'pattern': convention.pattern,
    };
  }

  Future<void> exportSingleJson({
    required Map<String, dynamic> payload,
    required String outputPath,
  }) async {
    final file = File(outputPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  }

  Future<void> exportDirectoryAsZip({
    required Directory rootDirectory,
    required String relativeFolderPath,
    required String outputPath,
  }) async {
    final folderPath = relativeFolderPath.isEmpty
        ? rootDirectory.path
        : p.join(rootDirectory.path, relativeFolderPath);
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      throw StateError('Folder does not exist: $relativeFolderPath');
    }

    final archive = Archive();
    final entities = folder.listSync(recursive: true).whereType<File>();

    for (final file in entities) {
      if (!file.path.toLowerCase().endsWith('.json')) {
        continue;
      }

      final relative = p.relative(file.path, from: folder.path);
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    await File(outputPath).writeAsBytes(encoded);
  }

  Future<void> exportAllAsZip({
    required Directory rootDirectory,
    required String outputPath,
  }) async {
    final archive = Archive();
    final entities = rootDirectory.listSync(recursive: true).whereType<File>();

    for (final file in entities) {
      if (!file.path.toLowerCase().endsWith('.json')) {
        continue;
      }

      final relative = p.relative(file.path, from: rootDirectory.path);
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    await File(outputPath).writeAsBytes(encoded);
  }

  Future<List<ImportPayload>> loadImportPayloads(List<String> paths) async {
    final payloads = <ImportPayload>[];

    for (final path in paths) {
      final extension = p.extension(path).toLowerCase();
      if (extension == '.json') {
        final json = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
        final normalized = _normalizeImportJson(json);
        payloads.add(
          ImportPayload(
            fileName: p.basename(path),
            rawJson: normalized,
            kind: detectKind(normalized),
            sourcePath: path,
          ),
        );
      } else if (extension == '.zip') {
        final bytes = await File(path).readAsBytes();
        payloads.addAll(_loadZipPayloads(bytes, sourcePath: path));
      }
    }

    return payloads;
  }

  List<ImportPayload> _loadZipPayloads(Uint8List bytes, {required String sourcePath}) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final payloads = <ImportPayload>[];

    for (final entry in archive) {
      if (!entry.isFile || !entry.name.toLowerCase().endsWith('.json')) {
        continue;
      }

      final data = entry.content;
      final entryBytes = data as List<int>;
      final json = jsonDecode(utf8.decode(entryBytes)) as Map<String, dynamic>;
      final normalized = _normalizeImportJson(json);

      payloads.add(
        ImportPayload(
          fileName: p.basename(entry.name),
          rawJson: normalized,
          kind: detectKind(normalized),
          sourcePath: sourcePath,
        ),
      );
    }

    return payloads;
  }

  ImportItemKind detectKind(Map<String, dynamic> json) {
    final rawType = (json['type'] as String?)?.trim().toLowerCase();
    final type = rawType?.replaceAll(RegExp(r'[^a-z]'), '');
    if (type == 'metadatatemplate' || type == 'template') {
      return ImportItemKind.metadataTemplate;
    }
    if (type == 'renameconvention' || type == 'rename') {
      return ImportItemKind.renameConvention;
    }

    if (json.containsKey('fields')) {
      return ImportItemKind.metadataTemplate;
    }
    if (json.containsKey('pattern')) {
      return ImportItemKind.renameConvention;
    }

    return ImportItemKind.unknown;
  }

  Map<String, dynamic> _normalizeImportJson(Map<String, dynamic> rawJson) {
    final normalized = Map<String, dynamic>.from(rawJson);

    if (normalized['gledhillForgeVersion'] != formatVersion) {
      normalized['gledhillForgeVersion'] = formatVersion;
    }

    if (normalized.containsKey('fields')) {
      normalized['fields'] = _normalizeFields(normalized['fields']);
    } else {
      final fields = <String, String>{};
      if (normalized['exif'] is Map) {
        fields.addAll(_normalizeFields(normalized['exif']));
      }
      if (normalized['xmp'] is Map) {
        fields.addAll(_normalizeFields(normalized['xmp']));
      }
      if (fields.isNotEmpty) {
        normalized['fields'] = fields;
      }
    }

    if (!normalized.containsKey('type') && normalized.containsKey('fields')) {
      normalized['type'] = 'metadataTemplate';
    }

    if (normalized.containsKey('pattern')) {
      normalized['pattern'] = _normalizePattern(normalized['pattern'] as String? ?? '');
    }

    return normalized;
  }

  Map<String, String> _normalizeFields(dynamic rawFields) {
    if (rawFields is! Map) {
      return const {};
    }

    final result = <String, String>{};
    for (final entry in rawFields.entries) {
      final rawKey = entry.key?.toString() ?? '';
      final rawValue = entry.value?.toString() ?? '';
      final normalizedKey = _normalizeFieldKey(rawKey);
      if (normalizedKey != null && normalizedKey.isNotEmpty) {
        result[normalizedKey] = rawValue;
      }
    }
    return result;
  }

  String? _normalizeFieldKey(String rawKey) {
    final key = rawKey.trim();
    if (key.isEmpty) {
      return null;
    }

    final lower = key.toLowerCase().replaceAll(':', '.');
    if (lower.startsWith('exif.')) {
      if (lower == 'exif.imagedescription') {
        return 'XMP.Description';
      }
      if (lower == 'exif.artist') {
        return 'XMP.Creator';
      }
      if (lower == 'exif.copyright') {
        return 'XMP.Copyright';
      }
      return null;
    }

    if (lower.startsWith('xmp.')) {
      final field = lower.substring(4);
      switch (field) {
        case 'subject':
          return 'XMP.Keywords';
        case 'title':
          return 'XMP.Title';
        case 'description':
          return 'XMP.Description';
        case 'creator':
          return 'XMP.Creator';
        case 'rights':
        case 'copyright':
          return 'XMP.Copyright';
        case 'headline':
          return 'XMP.Headline';
        case 'creatorcontactinfo':
          return 'XMP.CreatorContactInfo';
        default:
          return 'XMP.${field.split('.').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join('.')}';
      }
    }

    if (key.startsWith('XMP:')) {
      return key.replaceFirst('XMP:', 'XMP.');
    }
    if (key.startsWith('XMP.')) {
      return key;
    }

    return null;
  }

  String _normalizePattern(String pattern) {
    if (pattern.isEmpty) {
      return pattern;
    }

    var normalized = pattern;
    normalized = normalized.replaceAllMapped(
      RegExp(r'\{sequence:(0*)(\d+)d\}', caseSensitive: false),
      (match) {
        final width = int.tryParse(match.group(2) ?? '') ?? 3;
        return '{sequence:$width}';
      },
    );
    normalized = normalized.replaceAllMapped(
      RegExp(r'\{sequence:(\d+)d\}', caseSensitive: false),
      (match) {
        final width = int.tryParse(match.group(1) ?? '') ?? 3;
        return '{sequence:$width}';
      },
    );
    normalized = normalized.replaceAllMapped(
      RegExp(r'\{Sequence:(\d+)d\}', caseSensitive: false),
      (match) {
        final width = int.tryParse(match.group(1) ?? '') ?? 3;
        return '{sequence:$width}';
      },
    );
    return normalized;
  }

  MetadataTemplate toTemplate(Map<String, dynamic> json) {
    return MetadataTemplate(
      id: (json['id'] as String?) ?? (json['name'] as String? ?? 'Imported Template'),
      name: (json['name'] as String? ?? 'Imported Template').trim(),
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      fields: _normalizeFields(json['fields'] as Map? ?? const {}),
    );
  }

  RenameConvention toConvention(Map<String, dynamic> json) {
    return RenameConvention(
      id: (json['id'] as String?) ?? (json['name'] as String? ?? 'Imported Convention'),
      name: (json['name'] as String? ?? 'Imported Convention').trim(),
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      pattern: _normalizePattern((json['pattern'] as String?) ?? '{year}-{month}-{day}_{sequence:3}'),
    );
  }
}

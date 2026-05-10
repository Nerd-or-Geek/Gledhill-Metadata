import 'package:flutter_test/flutter_test.dart';
import 'package:gledhill_metadata/src/services/import_export_service.dart';

void main() {
  group('ImportExportService', () {
    late ImportExportService service;

    setUp(() {
      service = ImportExportService();
    });

    test('normalizes legacy rename pattern {sequence:02d} to {sequence:2}', () {
      final convention = service.toConvention({
        'id': 'legacy-rename',
        'name': 'Legacy Rename',
        'pattern': '{year}-{month}-{day}_{sequence:02d}',
      });

      expect(convention.pattern, '{year}-{month}-{day}_{sequence:2}');
    });

    test('normalizes legacy rename pattern {sequence:2d} to {sequence:2}', () {
      final convention = service.toConvention({
        'id': 'legacy-rename',
        'name': 'Legacy Rename',
        'pattern': '{year}-{month}-{day}_{sequence:2d}',
      });

      expect(convention.pattern, '{year}-{month}-{day}_{sequence:2}');
    });

    test('keeps current supported rename pattern unchanged', () {
      final convention = service.toConvention({
        'id': 'current-rename',
        'name': 'Current Rename',
        'pattern': '{year}-{month}-{day}_{sequence:3}',
      });

      expect(convention.pattern, '{year}-{month}-{day}_{sequence:3}');
    });
  });
}

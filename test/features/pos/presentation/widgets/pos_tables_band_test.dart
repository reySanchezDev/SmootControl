import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_tables_band.dart';

void main() {
  test('swapPosTablesForDrop exchanges only dragged and target tables', () {
    final result = swapPosTablesForDrop(
      draggedTableId: 'table-3',
      tableIds: const ['table-1', 'table-2', 'table-3', 'table-4'],
      targetTableId: 'table-1',
    );

    expect(result, const ['table-3', 'table-2', 'table-1', 'table-4']);
  });
}

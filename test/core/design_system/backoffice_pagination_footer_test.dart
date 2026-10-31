import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/backoffice_pagination_footer.dart';

void main() {
  Widget buildFooter() => MaterialApp(
    home: Scaffold(
      body: BackofficePaginationFooter(
        rowsPerPage: 15,
        onRowsPerPageChanged: (_) {},
        firstIndex: 0,
        visibleCount: 15,
        totalCount: 144,
        pageIndex: 0,
        pageCount: 10,
        onPrevious: null,
        onNext: () {},
      ),
    ),
  );

  testWidgets('UX-038 desktop footer keeps page size left and navigation right', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1366, 768);
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildFooter());
    final pageSize = tester.getTopLeft(find.text('Registros por página'));
    final range = tester.getTopLeft(find.text('1–15 de 144'));

    expect(pageSize.dx, lessThan(range.dx));
    expect((pageSize.dy - range.dy).abs(), lessThan(30));
    expect(find.text('1 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UX-038 mobile footer stacks consistent groups without overflow', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildFooter());
    final pageSize = tester.getTopLeft(find.text('Registros por página'));
    final range = tester.getTopLeft(find.text('1–15 de 144'));

    expect(pageSize.dy, lessThan(range.dy));
    expect(find.text('1 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

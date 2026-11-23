import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:screen_time_monitor/theme.dart';

void main() {
  testWidgets('主题包含自定义配色扩展', (WidgetTester tester) async {
    final theme = buildAppTheme(Brightness.light);
    expect(theme.extension<AppPalette>(), isNotNull);
    expect(theme.scaffoldBackgroundColor, AppPalette.light.bg);
  });
}

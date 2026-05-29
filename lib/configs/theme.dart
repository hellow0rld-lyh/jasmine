import 'package:event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../basic/commons.dart';
import '../basic/methods.dart';

const _seedColor = Color(0xFF6750A4);

final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
  seedColor: _seedColor,
  brightness: Brightness.light,
);

final ColorScheme _darkColorScheme = ColorScheme.fromSeed(
  seedColor: _seedColor,
  brightness: Brightness.dark,
);

final ThemeData _lightTheme =
    _buildAppTheme(_lightColorScheme, Brightness.light);
final ThemeData _darkTheme = _buildAppTheme(_darkColorScheme, Brightness.dark);

ThemeData get lightTheme => theme != "2" ? _lightTheme : _darkTheme;

ThemeData get darkTheme => theme != "1" ? _darkTheme : _lightTheme;

const _propertyName = "theme";
late String theme = "0";

Map<String, String> _nameMap = {
  "0": "自动 (如果设备支持)",
  "1": "保持亮色",
  "2": "保持暗色",
};

ThemeData _buildAppTheme(ColorScheme scheme, Brightness brightness) {
  final typography = Typography.material2021();
  final textTheme =
      brightness == Brightness.light ? typography.black : typography.white;
  final navLabelStyle = (textTheme.labelSmall ??
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))
      .copyWith(fontWeight: FontWeight.w600);
  final statusBarIconBrightness =
      brightness == Brightness.light ? Brightness.dark : Brightness.light;
  final statusBarBrightness = statusBarIconBrightness;
  final statusBarOverlay = SystemUiOverlayStyle(
    statusBarColor: scheme.surface,
    statusBarIconBrightness: statusBarIconBrightness,
    statusBarBrightness: statusBarBrightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    typography: typography,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      systemOverlayStyle: statusBarOverlay,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      foregroundColor: scheme.onSurface,
      elevation: 1,
      centerTitle: true,
      titleTextStyle:
          textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: scheme.surface,
      elevation: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      indicatorColor: scheme.primaryContainer,
      elevation: 3,
      height: 70,
      labelTextStyle: WidgetStatePropertyAll(navLabelStyle),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 4,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      surfaceTintColor: scheme.surfaceTint,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle:
          textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: textTheme.bodyMedium
          ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w500),
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary),
      ),
      labelStyle:
          textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.secondary),
        foregroundColor: WidgetStatePropertyAll(scheme.onSecondary),
        shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        textStyle: WidgetStatePropertyAll(
          (textTheme.labelLarge ?? const TextStyle(fontWeight: FontWeight.w600))
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.primary),
        foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
        shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        textStyle: WidgetStatePropertyAll(
          (textTheme.labelLarge ?? const TextStyle(fontWeight: FontWeight.w600))
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(scheme.primary),
        shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        overlayColor: WidgetStatePropertyAll(scheme.primary.withOpacity(.12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(scheme.primary),
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.secondaryContainer,
      secondarySelectedColor: scheme.primaryContainer,
      labelStyle: textTheme.bodyMedium,
      secondaryLabelStyle:
          textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.onSurface.withOpacity(.2),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withOpacity(.16),
      trackHeight: 3,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(scheme.primary),
      trackColor: WidgetStatePropertyAll(scheme.primary.withOpacity(.5)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStatePropertyAll(scheme.primary),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStatePropertyAll(scheme.primary),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.8,
    ),
  );
}

Future initTheme() async {
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  theme = await methods.loadProperty(_propertyName);
  if (theme == "") {
    theme = "0";
  }
  themeEvent.broadcast();
}

String themeName() {
  return _nameMap[theme] ?? "-";
}

Future chooseTheme(BuildContext context) async {
  String? choose = await chooseMapDialog(context,
      title: "选择主题",
      values: _nameMap.map((key, value) => MapEntry(value, key)));
  if (choose != null) {
    await methods.saveProperty(_propertyName, choose);
    theme = choose;
    themeEvent.broadcast();
  }
}

final themeEvent = Event();

Widget themeSetting(BuildContext context) {
  return StatefulBuilder(
    builder: (BuildContext context, void Function(void Function()) setState) {
      return ListTile(
        onTap: () async {
          await chooseTheme(context);
          setState(() => {});
        },
        title: const Text("主题"),
        subtitle: Text(_nameMap[theme] ?? ""),
      );
    },
  );
}

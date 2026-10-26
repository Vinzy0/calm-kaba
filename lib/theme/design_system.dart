import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFFDF3A81);
  static const Color secondary = Color(0xFF63C132);
  static const Color tertiary = Color(0xFFEA6AA4);
  
  static const Color willowGreen = Color(0xFF96D289);
  static const Color lightGreen = Color(0xFFA9E99B);
  static const Color celadon = Color(0xFFBBEFA9);
  static const Color teaGreen = Color(0xFFCDF5B7);
  static const Color frostedMint = Color(0xFFDBFDD8);
  static const Color pastelPetal = Color(0xFFFFCAE9);
  static const Color blushPop = Color(0xFFFFA8D9);
  static const Color pinkCarnation = Color(0xFFFF85C8);
  static const Color pinkCarnation2 = Color(0xFFFF7BC4);
  static const Color hotPinkWeb = Color(0xFFFF70BF);
  static const Color elizabeth = Color(0xFF80ED99);
  static const Color arden = Color(0xFF04A777);
  
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF555555);
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color alternate;
  final Color cardBackground;
  final Color secondaryBackground;

  const AppColorsExtension({
    required this.alternate,
    required this.cardBackground,
    required this.secondaryBackground,
  });

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? alternate,
    Color? cardBackground,
    Color? secondaryBackground,
  }) {
    return AppColorsExtension(
      alternate: alternate ?? this.alternate,
      cardBackground: cardBackground ?? this.cardBackground,
      secondaryBackground: secondaryBackground ?? this.secondaryBackground,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
      covariant ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      alternate: Color.lerp(alternate, other.alternate, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      secondaryBackground: Color.lerp(secondaryBackground, other.secondaryBackground, t)!,
    );
  }
}

class AppTypography {
  static TextStyle displayLarge = GoogleFonts.poppins(fontSize: 64, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle displayMedium = GoogleFonts.poppins(fontSize: 44, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle displaySmall = GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  
  static TextStyle headlineLarge = GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle headlineMedium = GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle headlineSmall = GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  
  static TextStyle titleLarge = GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle titleMedium = GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle titleSmall = GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  
  static TextStyle labelLarge = GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.textSecondary);
  static TextStyle labelMedium = GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textSecondary);
  static TextStyle labelSmall = GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textSecondary);
  
  static TextStyle bodyLarge = GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.textPrimary);
  static TextStyle bodyMedium = GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textPrimary);
  static TextStyle bodySmall = GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textPrimary);
}

class AppTheme {
  // We manage the current ThemeMode globally here
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.dark);

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: AppTypography.displayLarge,
      displayMedium: AppTypography.displayMedium,
      displaySmall: AppTypography.displaySmall,
      headlineLarge: AppTypography.headlineLarge,
      headlineMedium: AppTypography.headlineMedium,
      headlineSmall: AppTypography.headlineSmall,
      titleLarge: AppTypography.titleLarge,
      titleMedium: AppTypography.titleMedium,
      titleSmall: AppTypography.titleSmall,
      labelLarge: AppTypography.labelLarge,
      labelMedium: AppTypography.labelMedium,
      labelSmall: AppTypography.labelSmall,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.bodyMedium,
      bodySmall: AppTypography.bodySmall,
    );
  }

  // Dark Theme represents the ORIGINAL layout with vibrant green backgrounds
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: const Color(0xFFC5FF7A), // alternate in dark mode
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: Color(0xFFFFFFFF), // secondaryBackground
      ),
      textTheme: _buildTextTheme(),
      extensions: const <ThemeExtension<dynamic>>[
        AppColorsExtension(
          alternate: Color(0xFFC5FF7A),
          cardBackground: Color(0xFFFFFFFF),
          secondaryBackground: Color(0xFFFFFFFF),
        ),
      ],
    );
  }

  // Light Theme represents the NEW layout with white backgrounds
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: const Color(0xFFFFFFFF), // alternate in light mode
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: Color(0xFFF0F0F0), // secondaryBackground
      ),
      textTheme: _buildTextTheme(),
      extensions: const <ThemeExtension<dynamic>>[
        AppColorsExtension(
          alternate: Color(0xFFFFFFFF),
          cardBackground: Color(0xFFFFCAE9),
          secondaryBackground: Color(0xFFF0F0F0),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Recovera Design System ─────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Primary — Deep Navy
  static const Color navyDark  = Color(0xFF0D1B3E);  // sidebar bg
  static const Color navy      = Color(0xFF1A2E5A);  // primary buttons, header
  static const Color navyLight = Color(0xFF253F7A);  // hover states

  // Accent — Slate Blue
  static const Color accent    = Color(0xFF3B6FD4);  // interactive highlights
  static const Color accentBg  = Color(0xFFEEF3FB);  // selected item bg tint

  // Neutral Grays
  static const Color bgPage    = Color(0xFFF4F6FA);  // page scaffold background
  static const Color bgCard    = Color(0xFFFFFFFF);
  static const Color border    = Color(0xFFE2E8F0);
  static const Color borderMid = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textBody  = Color(0xFF1E293B);
  static const Color textHead  = Color(0xFF0F172A);

  // Sidebar text
  static const Color sidebarText     = Color(0xFFB0BEC5);
  static const Color sidebarTextActive = Color(0xFFFFFFFF);
  static const Color sidebarSection  = Color(0xFF546E7A);

  // Status / Tag colors
  static const Color statusGreen    = Color(0xFF16A34A);
  static const Color statusGreenBg  = Color(0xFFDCFCE7);
  static const Color statusAmber    = Color(0xFFD97706);
  static const Color statusAmberBg  = Color(0xFFFEF3C7);
  static const Color statusRed      = Color(0xFFDC2626);
  static const Color statusRedBg    = Color(0xFFFEE2E2);
  static const Color statusBlue     = Color(0xFF2563EB);
  static const Color statusBlueBg   = Color(0xFFDBEAFE);
  static const Color statusGray     = Color(0xFF475569);
  static const Color statusGrayBg   = Color(0xFFF1F5F9);
  static const Color statusPurple   = Color(0xFF7C3AED);
  static const Color statusPurpleBg = Color(0xFFEDE9FE);
}

class AppTypography {
  AppTypography._();

  static TextStyle pageTitle(BuildContext context) => GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textHead, letterSpacing: -0.3,
  );

  static TextStyle sectionHeader(BuildContext context) => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textHead, letterSpacing: 0.1,
  );

  static TextStyle tableHeader(BuildContext context) => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5,
  );

  static TextStyle bodyMedium(BuildContext context) => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textBody,
  );

  static TextStyle labelSmall(BuildContext context) => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: false,
      primaryColor: AppColors.navy,
      scaffoldBackgroundColor: AppColors.bgPage,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
        secondary: AppColors.accent,
        background: AppColors.bgPage,
        surface: AppColors.bgCard,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: AppColors.textBody,
        onSurface: AppColors.textBody,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textBody,
        displayColor: AppColors.textHead,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgCard,
        foregroundColor: AppColors.textHead,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.statusRed),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.borderMid),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.navy,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: AppColors.border,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgPage,
        selectedColor: AppColors.accentBg,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        elevation: 8,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minLeadingWidth: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textHead,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.bgCard),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          elevation: const WidgetStatePropertyAll(4),
        ),
      ),
    );
  }
}

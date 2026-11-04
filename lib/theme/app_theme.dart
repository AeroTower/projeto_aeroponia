import 'package:flutter/material.dart';

/// Paleta "orgânica" da página inicial (aerotower.com.br).
/// É o único lugar do app onde uma cor deve ser escrita em hexadecimal.
class AeroColors {
  // Fundos
  static const bg = Color(0xFFF5EAD8); // creme da página
  static const areia = Color(0xFFEBDCC5); // cards de números da página
  static const creme = Color(0xFFFBF4E8); // campos e cards que pedem destaque
  static const mint = Color(0xFFF0FAE1); // cards de "Como funciona"
  static const mintForte = Color(0xFFE0EECD); // círculos numerados
  static const borda = Color(0xFFE3D6C2);

  // Marca
  static const terracota = Color(0xFFC6713A); // detalhes e ícones grandes
  static const terracotaBotao = Color(0xFFA9592A); // fundo com texto branco
  static const terracotaEscuro = Color(0xFF7F4119); // texto sobre fundo claro
  static const terracotaClara = Color(0xFFFEE1CF); // fundo do logo
  static const blush = Color(0xFFFFF2EC); // etiquetas rosadas
  static const musgo = Color(0xFF55633F); // verde dos botões e do "tudo certo"

  // Texto
  static const tinta = Color(0xFF241B12);
  static const tintaSuave = Color(0xFF5E5A4F);

  // Estados
  static const erro = Color(0xFFA63D2A);
  static const erroFundo = Color(0xFFFBE3DA);
  static const alerta = Color(0xFF85550B);
  static const alertaFundo = Color(0xFFFAEBCF);
  static const agua = Color(0xFF2F6A78);
  static const aguaFundo = Color(0xFFDDEBEA);
}

/// Famílias declaradas no pubspec.yaml (arquivos em assets/fonts).
class AeroFonts {
  static const titulo = 'Fraunces';
  static const corpo = 'Figtree';
}

/// Raios de canto: a página usa cantos bem arredondados e botões em pílula.
class AeroRadius {
  static const card = 28.0;
  static const campo = 16.0;
  static const pilula = 999.0;
}

class AppTheme {
  /// O tema escuro saiu: todas as telas partem deste aqui.
  static final ThemeData lightTheme = _criar();

  static ThemeData _criar() {
    // Define os componentes uma vez só; as telas não precisam repetir estilo
    // de botão, campo, diálogo etc.
    const esquema = ColorScheme.light(
      primary: AeroColors.musgo,
      onPrimary: Colors.white,
      secondary: AeroColors.terracotaBotao,
      onSecondary: Colors.white,
      surface: AeroColors.creme,
      onSurface: AeroColors.tinta,
      error: AeroColors.erro,
    );

    final bordaCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AeroRadius.campo),
      borderSide: const BorderSide(color: AeroColors.borda),
    );

    return ThemeData(
      useMaterial3: true,
      // Sem isto o Flutter encolhe os botões no computador.
      visualDensity: VisualDensity.standard,
      colorScheme: esquema,
      primaryColor: AeroColors.musgo,
      scaffoldBackgroundColor: AeroColors.bg,
      fontFamily: AeroFonts.corpo,
      appBarTheme: const AppBarTheme(
        backgroundColor: AeroColors.bg,
        foregroundColor: AeroColors.tinta,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: AeroFonts.titulo,
          fontWeight: FontWeight.w900,
          fontSize: 20,
          color: AeroColors.tinta,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AeroColors.terracotaBotao,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AeroColors.areia,
          disabledForegroundColor: AeroColors.tintaSuave,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: AeroFonts.corpo,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AeroColors.terracotaEscuro,
          textStyle: const TextStyle(
            fontFamily: AeroFonts.corpo,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AeroColors.creme,
        labelStyle: const TextStyle(color: AeroColors.tintaSuave),
        hintStyle: const TextStyle(color: AeroColors.tintaSuave),
        border: bordaCampo,
        enabledBorder: bordaCampo,
        focusedBorder: bordaCampo.copyWith(
          borderSide: const BorderSide(color: AeroColors.musgo, width: 1.5),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AeroColors.tinta,
        contentTextStyle: TextStyle(
          fontFamily: AeroFonts.corpo,
          color: AeroColors.creme,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AeroColors.creme,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AeroRadius.card),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AeroColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AeroColors.terracota,
      ),
    );
  }
}

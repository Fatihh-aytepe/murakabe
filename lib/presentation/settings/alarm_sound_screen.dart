import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/alarm_service.dart';

/// Alarm sesi seçim ve yönetim ekranı. Hazır 7 sesin yanı sıra kullanıcının
/// cihazından yüklediği özel sesleri de listeler; her ses için önizleme
/// (çal/durdur) sunar, özel sesler ayrıca silinebilir. Hazır sesler
/// assets/sounds/*.mp3 üzerinden audioplayers ile, özel (content:// URI'li)
/// sesler ise native MediaPlayer üzerinden (AlarmService.previewCustomSound)
/// önizlenir — content:// URI oynatma desteği paket sürümüne göre
/// değişebildiği için native taraf garanti çalışan yoldur.
class AlarmSoundScreen extends StatefulWidget {
  const AlarmSoundScreen({super.key});

  @override
  State<AlarmSoundScreen> createState() => _AlarmSoundScreenState();
}

class _AlarmSoundScreenState extends State<AlarmSoundScreen> {
  final _alarmService = AlarmService();
  final _previewPlayer = AudioPlayer();

  late String _selectedId;
  String? _previewingId;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedId = _alarmService.selectedSound.id;
    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewingId = null);
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    _alarmService.stopCustomPreview();
    super.dispose();
  }

  Future<void> _select(AlarmSound sound) async {
    await _alarmService.setSelectedSound(sound);
    if (mounted) setState(() => _selectedId = sound.id);
  }

  Future<void> _togglePreview(AlarmSound sound) async {
    if (_previewingId == sound.id) {
      await _previewPlayer.stop();
      await _alarmService.stopCustomPreview();
      if (mounted) setState(() => _previewingId = null);
      return;
    }

    await _previewPlayer.stop();
    await _alarmService.stopCustomPreview();
    if (mounted) setState(() => _previewingId = sound.id);

    try {
      if (sound.isCustom) {
        await _alarmService.previewCustomSound(sound);
        // Native MediaPlayer'ın bitiş bildirimi yok — süresi bilinmeyen
        // dosyalar için makul bir üst sınır sonra otomatik "durdu" göster.
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted && _previewingId == sound.id) {
            setState(() => _previewingId = null);
          }
        });
      } else {
        await _previewPlayer.play(AssetSource('sounds/${sound.id}.mp3'));
      }
    } catch (_) {
      if (mounted) setState(() => _previewingId = null);
    }
  }

  Future<void> _uploadCustomSound() async {
    setState(() => _isUploading = true);
    try {
      final sound = await _alarmService.pickAndAddCustomSound();
      if (sound == null) return; // Kullanıcı iptal etti.
      await _select(sound);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${sound.label}" eklendi ve seçildi')),
        );
      }
    } on AlarmSoundException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteCustomSound(AlarmSound sound) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sesi Sil'),
        content: Text('"${sound.label}" cihazından tamamen silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (_previewingId == sound.id) {
      await _previewPlayer.stop();
      await _alarmService.stopCustomPreview();
    }
    await _alarmService.removeCustomSound(sound);
    if (mounted) {
      setState(() => _selectedId = _alarmService.selectedSound.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F2F5);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final custom = _alarmService.customSounds;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Alarm Sesi',
          style: GoogleFonts.playfairDisplay(
            color: isDark ? AppColors.gold : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            _uploadButton(isDark),
            const SizedBox(height: 20),
            if (custom.isNotEmpty) ...[
              _sectionTitle('KENDİ SESLERİN', isDark),
              const SizedBox(height: 8),
              ...custom.map((s) => _soundTile(s, isDark, custom: true)),
              const SizedBox(height: 20),
            ],
            _sectionTitle('HAZIR SESLER', isDark),
            const SizedBox(height: 8),
            ...AlarmService.availableSounds
                .map((s) => _soundTile(s, isDark, custom: false)),
            const SizedBox(height: 16),
            Text(
              'Yüklediğin sesler yalnızca bu cihazda saklanır; Teheccüd '
              'alarmında seçtiğin ses çalar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: isDark ? Colors.white38 : AppColors.textLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, bool isDark) => Text(
        text,
        style: GoogleFonts.notoSans(
          color: isDark ? Colors.white70 : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      );

  Widget _uploadButton(bool isDark) {
    return GestureDetector(
      onTap: _isUploading ? null : _uploadCustomSound,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (_isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 2.2),
              )
            else
              const Icon(Icons.upload_file_rounded,
                  color: AppColors.gold, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isUploading
                    ? 'Ses cihazına ekleniyor...'
                    : 'Kendi Sesini Yükle',
                style: GoogleFonts.notoSans(
                  color: AppColors.gold,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _soundTile(AlarmSound sound, bool isDark, {required bool custom}) {
    final selected = _selectedId == sound.id;
    final previewing = _previewingId == sound.id;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _select(sound),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.14)
                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : (isDark ? Colors.white12 : Colors.black12),
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? AppColors.gold
                    : (isDark ? Colors.white24 : Colors.black26),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sound.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSans(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _togglePreview(sound),
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: previewing
                        ? Colors.red.withValues(alpha: 0.15)
                        : AppColors.gold.withValues(alpha: 0.12),
                    border: Border.all(
                      color: previewing ? Colors.red : AppColors.gold,
                    ),
                  ),
                  child: Icon(
                    previewing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: previewing ? Colors.red : AppColors.gold,
                    size: 17,
                  ),
                ),
              ),
              if (custom)
                GestureDetector(
                  onTap: () => _deleteCustomSound(sound),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.delete_outline,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

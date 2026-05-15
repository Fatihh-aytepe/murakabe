import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/quran_repository.dart';

// audioplayers paketi gerekli — pubspec.yaml'a ekle:
// audioplayers: ^5.2.1
import 'package:audioplayers/audioplayers.dart';

class QuranAudioBar extends StatefulWidget {
  final QuranAyah? ayah;
  final Qari qari;
  final List<Qari> availableQariler;
  final void Function(Qari) onQariChanged;
  final String Function(QuranAyah, Qari) audioUrlBuilder;

  const QuranAudioBar({
    super.key,
    required this.ayah,
    required this.qari,
    required this.availableQariler,
    required this.onQariChanged,
    required this.audioUrlBuilder,
  });

  @override
  State<QuranAudioBar> createState() => _QuranAudioBarState();
}

class _QuranAudioBarState extends State<QuranAudioBar> {
  final AudioPlayer _player = AudioPlayer();

  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void didUpdateWidget(QuranAudioBar old) {
    super.didUpdateWidget(old);
    // Ayet değişince otomatik yeni ayeti yükle (oynatmaz, hazırlar)
    if (old.ayah?.globalNumber != widget.ayah?.globalNumber ||
        old.qari.id != widget.qari.id) {
      _player.stop();
      setState(() {
        _position = Duration.zero;
        _duration = Duration.zero;
        _playerState = PlayerState.stopped;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.ayah == null) return;

    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }

    if (_playerState == PlayerState.paused) {
      await _player.resume();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = widget.audioUrlBuilder(widget.ayah!, widget.qari);
      await _player.setSourceUrl(url);
      await _player.resume();
    } catch (_) {
      // Fallback: everyayah.com ile aynı kariyi dene
      try {
        final padded =
            widget.ayah!.globalNumber.toString().padLeft(6, '0');
        final fallback =
            'https://everyayah.com/data/${widget.qari.identifier}/$padded.mp3';
        await _player.setSourceUrl(fallback);
        await _player.resume();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${widget.ayah!.surahNumber}:${widget.ayah!.number} ayeti yüklenemedi. '
                'Farklı bir kari deneyin.',
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() => _position = Duration.zero);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2035) : Colors.white;
    final hasAyah = widget.ayah != null;
    final isPlaying = _playerState == PlayerState.playing;
    final isPaused = _playerState == PlayerState.paused;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.15),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Ayet bilgisi + kontroller ──
          Row(
            children: [
              // Kari seçici
              GestureDetector(
                onTap: _showQariSheet,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withValues(alpha:0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic_none,
                          color: AppColors.gold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        widget.qari.name.split(' ').last,
                        style: GoogleFonts.notoSans(
                            color: AppColors.gold, fontSize: 11),
                      ),
                      const Icon(Icons.expand_more,
                          color: AppColors.gold, size: 14),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Ayet bilgisi
              Expanded(
                child: hasAyah
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.ayah!.surahNumber}:${widget.ayah!.number}. Ayet',
                            style: GoogleFonts.notoSans(
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            widget.ayah!.arabic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.scheherazadeNew(
                              color: AppColors.gold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Bir ayete dokun',
                        style: GoogleFonts.notoSans(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
              ),

              // Durdur
              if (isPlaying || isPaused)
                IconButton(
                  icon: const Icon(Icons.stop_rounded),
                  color: Colors.grey,
                  onPressed: _stop,
                ),

              // Oynat / Duraklat
              GestureDetector(
                onTap: hasAyah ? _togglePlay : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasAyah ? AppColors.gold : Colors.grey.shade300,
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
              ),
            ],
          ),

          // ── İlerleme çubuğu ──
          if (hasAyah && (isPlaying || isPaused)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: GoogleFonts.notoSans(color: Colors.grey, fontSize: 10),
                ),
                Expanded(
                  child: Slider(
                    value: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds / _duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0,
                    onChanged: (v) async {
                      final pos = Duration(
                          milliseconds: (v * _duration.inMilliseconds).toInt());
                      await _player.seek(pos);
                    },
                    activeColor: AppColors.gold,
                    inactiveColor: Colors.grey.shade300,
                    thumbColor: AppColors.gold,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: GoogleFonts.notoSans(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showQariSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A2035),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Kari Seç',
                style: GoogleFonts.playfairDisplay(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...widget.availableQariler.map((q) {
              final isSelected = q.id == widget.qari.id;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? AppColors.gold : Colors.white38,
                ),
                title: Text(q.name,
                    style: GoogleFonts.notoSans(
                      color: isSelected ? AppColors.gold : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    )),
                onTap: () {
                  Navigator.pop(context);
                  widget.onQariChanged(q);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

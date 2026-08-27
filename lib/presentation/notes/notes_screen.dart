import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/note_model.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/local/local_storage.dart';
import '../../data/local/note_file_storage.dart';

/// Bir not resmine dokunulduğunda tam ekran, yakınlaştırılabilir önizleme açar.
void openImageViewer(BuildContext context, String path, {String? heroTag}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _FullScreenImageViewer(
        path: path,
        heroTag: heroTag,
      ),
    ),
  );
}

class _FullScreenImageViewer extends StatelessWidget {
  final String path;
  final String? heroTag;
  const _FullScreenImageViewer({required this.path, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: heroTag != null
                    ? Hero(
                        tag: heroTag!,
                        child: Image.file(File(path), fit: BoxFit.contain),
                      )
                    : Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Not editörünü herhangi bir ekrandan açmak için paylaşılan giriş noktası.
/// - Mevcut bir notu düzenlemek için [note] ver.
/// - Yeni, önceden doldurulmuş bir not (örn. "Ayeti Notlarıma Ekle" kısayolu)
///   için [note]'u boş bırakıp [prefillTitle] / [prefillDocument] /
///   [prefillTags] kullan.
/// [onSaved] kayıt tamamlandığında çağrılır (liste yenileme, snackbar vb. için).
Future<void> showNoteEditor(
  BuildContext context, {
  NoteModel? note,
  String? prefillTitle,
  quill.Document? prefillDocument,
  List<String> prefillTags = const [],
  VoidCallback? onSaved,
}) {
  final repo = NoteRepository();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => NoteEditorSheet(
      note: note,
      prefillTitle: prefillTitle,
      prefillDocument: prefillDocument,
      prefillTags: prefillTags,
      onSave: (draft) async {
        if (note != null) {
          await repo.updateNote(NoteModel(
            id: note.id,
            title: draft.title,
            content: draft.content,
            contentDelta: draft.contentDelta,
            tags: draft.tags,
            color: draft.color,
            isPinned: draft.isPinned,
            imagePaths: draft.imagePaths,
            audioPaths: draft.audioPaths,
            reminderAt: draft.reminderAt,
            createdAt: note.createdAt,
            updatedAt: DateTime.now(),
          ));
        } else {
          await repo.addNote(
            title: draft.title,
            content: draft.content,
            contentDelta: draft.contentDelta,
            tags: draft.tags,
            color: draft.color,
            isPinned: draft.isPinned,
            imagePaths: draft.imagePaths,
            audioPaths: draft.audioPaths,
            reminderAt: draft.reminderAt,
          );
        }
        onSaved?.call();
      },
    ),
  );
}

class NotesScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const NotesScreen({super.key, this.onMenuTap});

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  final _repo = NoteRepository();
  final _storage = LocalStorage();
  List<NoteModel> _notes = [];
  String _viewMode = 'list'; // 'list' | 'grid'
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _viewMode = _storage.notesViewMode;
    _loadNotes();
  }

  void reload() => _loadNotes();

  Future<void> _loadNotes() async {
    final notes = await _repo.getNotes();
    if (mounted) {
      setState(() {
        _notes = notes;
        // Filtrelenen tag artık hiçbir notta yoksa filtreyi temizle
        if (_selectedTag != null &&
            !_notes.any((n) => n.tags.contains(_selectedTag))) {
          _selectedTag = null;
        }
      });
    }
  }

  List<NoteModel> get _filteredNotes {
    if (_selectedTag == null) return _notes;
    return _notes.where((n) => n.tags.contains(_selectedTag)).toList();
  }

  List<String> get _allTags {
    final set = <String>{};
    for (final n in _notes) {
      set.addAll(n.tags);
    }
    final list = set.toList()..sort();
    return list;
  }

  void _toggleViewMode() {
    final next = _viewMode == 'list' ? 'grid' : 'list';
    setState(() => _viewMode = next);
    _storage.setNotesViewMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;
    final tags = _allTags;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadNotes,
        color: AppColors.gold,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onMenuTap,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.menu,
                                color: AppColors.gold, size: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Notlarım',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 26,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '${_notes.length} not',
                          style: GoogleFonts.notoSans(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _toggleViewMode,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.4)),
                            ),
                            child: Icon(
                              _viewMode == 'list'
                                  ? Icons.grid_view_rounded
                                  : Icons.view_list_rounded,
                              color: AppColors.gold,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (tags.isNotEmpty)
              SliverToBoxAdapter(child: _buildTagFilterBar(tags)),
            if (_notes.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_outlined,
                          size: 64,
                          color: AppColors.textLight.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz not yok\nSağ alttaki + ile not ekle',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Bu etikette not yok',
                    style: GoogleFonts.notoSans(
                        color: AppColors.textLight, fontSize: 14),
                  ),
                ),
              )
            else if (_viewMode == 'grid')
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childCount: filtered.length,
                  itemBuilder: (_, i) => _buildNoteCard(filtered[i]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildNoteCard(filtered[i]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNoteEditor(),
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTagFilterBar(List<String> tags) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildTagChip('Tümü', _selectedTag == null,
              () => setState(() => _selectedTag = null), isDark),
          const SizedBox(width: 8),
          for (final tag in tags) ...[
            _buildTagChip('#$tag', _selectedTag == tag,
                () => setState(() => _selectedTag = tag), isDark),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTagChip(
      String label, bool selected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold
              : (isDark ? const Color(0xFF1A2035) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : AppColors.textLight.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.notoSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white70 : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(NoteModel note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.textSecondary;
    final dateColor = isDark ? Colors.white38 : AppColors.textLight;
    final accent = NoteColors.colorFor(note.color);
    final hasColor = accent != null;
    final accentColor = hasColor ? Color(accent) : AppColors.gold;

    return GestureDetector(
      onTap: () => _openNoteEditor(note: note),
      child: Container(
        decoration: BoxDecoration(
          // Seçilen renk artık ince bir çizgi değil, net görünen bir üst
          // bant + hafif arkaplan tonuyla gösteriliyor.
          color: hasColor
              ? Color.alphaBlend(accentColor.withValues(alpha: 0.10), cardColor)
              : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: hasColor
              ? Border.all(
                  color: accentColor.withValues(alpha: 0.35), width: 1.2)
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasColor) Container(height: 6, color: accentColor),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isNotEmpty ? note.title : 'Başlıksız Not',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await _repo.togglePin(note);
                          await _loadNotes();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            note.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            color: note.isPinned ? AppColors.gold : dateColor,
                            size: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _deleteNote(note),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  if (note.imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => openImageViewer(
                          context, note.imagePaths.first,
                          heroTag: 'note_img_${note.id}_0'),
                      child: Hero(
                        tag: 'note_img_${note.id}_0',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(note.imagePaths.first),
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    if (note.imagePaths.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${note.imagePaths.length - 1} resim daha',
                          style: GoogleFonts.notoSans(
                              fontSize: 11, color: dateColor),
                        ),
                      ),
                  ],
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        color: subColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: note.tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '#$t',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatDate(note.updatedAt),
                        style: GoogleFonts.notoSans(
                            fontSize: 11, color: dateColor),
                      ),
                      if (note.reminderAt != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.alarm, size: 12, color: AppColors.gold),
                        const SizedBox(width: 2),
                        Text(
                          DateFormat('d MMM, HH:mm', 'tr_TR')
                              .format(note.reminderAt!),
                          style: GoogleFonts.notoSans(
                              fontSize: 11, color: AppColors.gold),
                        ),
                      ],
                      if (note.audioPaths.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.mic, size: 12, color: dateColor),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNoteEditor({NoteModel? note}) {
    showNoteEditor(context, note: note, onSaved: _loadNotes);
  }

  Future<void> _deleteNote(NoteModel note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notu Sil'),
        content: const Text('Bu notu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _repo.deleteNote(note.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not silinemedi: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) await _loadNotes();
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── NOT EDİTÖRÜ ──────────────────────────────────────────────────────────────

/// Not editörünün kaydet anında ürettiği taslak veri paketi. Uzun,
/// hataya açık pozisyonel parametre listesi yerine kullanılır.
class NoteDraft {
  final String title;
  final String content;
  final String contentDelta;
  final List<String> tags;
  final String color;
  final bool isPinned;
  final List<String> imagePaths;
  final List<String> audioPaths;
  final DateTime? reminderAt;

  const NoteDraft({
    required this.title,
    required this.content,
    required this.contentDelta,
    required this.tags,
    required this.color,
    required this.isPinned,
    required this.imagePaths,
    required this.audioPaths,
    required this.reminderAt,
  });
}

class NoteEditorSheet extends StatefulWidget {
  final NoteModel? note;
  // Yeni not için önceden doldurma (örn. "Notlarıma Ekle" kısayolu). note
  // verilmişse bu alanlar yok sayılır.
  final String? prefillTitle;
  final quill.Document? prefillDocument;
  final List<String> prefillTags;
  final void Function(NoteDraft draft) onSave;

  const NoteEditorSheet({
    super.key,
    this.note,
    this.prefillTitle,
    this.prefillDocument,
    this.prefillTags = const [],
    required this.onSave,
  });

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _tagInputCtrl;
  late quill.QuillController _quillController;
  final FocusNode _contentFocus = FocusNode();
  late List<String> _tags;
  late String _color;
  late bool _isPinned;
  late List<String> _imagePaths;
  late List<String> _audioPaths;
  DateTime? _reminderAt;
  // "Eklentiler" paneli (etiket + resim + ses) varsayılan olarak
  // DARALTILMIŞ — dokunulmazsa gizli kalır. Notta zaten eklenti varsa
  // (düzenlerken) kullanıcı hemen görsün diye açık başlıyor.
  late bool _attachmentsExpanded;

  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  // Ses kaydı sırasında "Ses Ekle" butonunda yanıp sönen kırmızı nokta —
  // kaydın gerçekten sürdüğünü görsel olarak belli etsin diye.
  Timer? _recordingPulseTimer;
  bool _recordingPulseOn = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
        text: widget.note?.title ?? widget.prefillTitle ?? '');
    _tagInputCtrl = TextEditingController();
    _quillController = _buildQuillController(widget.note);
    _tags = List<String>.from(widget.note?.tags ??
        (widget.note == null ? widget.prefillTags : const []));
    _color = widget.note?.color ?? '';
    _isPinned = widget.note?.isPinned ?? false;
    _imagePaths = List<String>.from(widget.note?.imagePaths ?? const []);
    _audioPaths = List<String>.from(widget.note?.audioPaths ?? const []);
    _reminderAt = widget.note?.reminderAt;
    _attachmentsExpanded =
        _tags.isNotEmpty || _imagePaths.isNotEmpty || _audioPaths.isNotEmpty;
    // İçerik kutusu odaklanınca/odaktan çıkınca üst kısmı gizleyip
    // gösterecek olan "odak modu" — bkz. _handleFocusChange.
    _contentFocus.addListener(_handleFocusChange);
  }

  // İçerik kutusuna dokunup klavye açıldığında (veya kapandığında) yeniden
  // çizilmesi için — build() içinde doğrudan _contentFocus.hasFocus okunuyor,
  // ayrı bir bool state tutmaya gerek yok, bu sadece rebuild tetikliyor.
  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {});
  }

  // Notun içeriğini Quill dokümanına çevirir.
  // - Var olan not, formatlı içerik (contentDelta): doğrudan yüklenir.
  // - Var olan not, eski/düz metin: content, tek paragraflık bir doküman
  //   olarak sarmalanır.
  // - Yeni not + prefillDocument verilmiş (örn. ayet/hadis aktarımı): o
  //   doküman yüklenir, imleç sonuna konumlanır ki kullanıcı hemen kendi
  //   notunu ekleyebilsin.
  quill.QuillController _buildQuillController(NoteModel? note) {
    if (note != null && note.contentDelta.isNotEmpty) {
      try {
        final delta = jsonDecode(note.contentDelta) as List<dynamic>;
        return quill.QuillController(
          document: quill.Document.fromJson(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        // Bozuk delta — düz metne düş
      }
    }
    if (note == null && widget.prefillDocument != null) {
      final doc = widget.prefillDocument!;
      return quill.QuillController(
        document: doc,
        selection: TextSelection.collapsed(offset: doc.length),
      );
    }
    final plain = note?.content ?? '';
    if (plain.isEmpty) return quill.QuillController.basic();
    return quill.QuillController(
      document: quill.Document.fromJson([
        {'insert': '$plain\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagInputCtrl.dispose();
    _quillController.dispose();
    _contentFocus.removeListener(_handleFocusChange);
    _contentFocus.dispose();
    _recordingPulseTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _addTagFromInput() {
    final raw = _tagInputCtrl.text.trim().replaceAll('#', '');
    if (raw.isEmpty) return;
    // Virgülle ayrılmış birden fazla etiket girilebilir
    final newTags = raw
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty && !_tags.contains(t));
    setState(() {
      _tags.addAll(newTags);
      _tagInputCtrl.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  // "Etiket Ekle" butonuna basınca sayfanın üstünde açılan küçük pencere.
  // Var olan etiket ekleme mantığına (_addTagFromInput/_removeTag) dokunmuyor
  // — sadece giriş alanının göründüğü yeri değiştiriyor. Dialog kendi
  // StatefulBuilder'ı ile anlık güncelleniyor, kapanınca dış state de
  // (Eklentiler özeti) tazeleniyor.
  void _showTagPopup(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final popupBg = isDark ? const Color(0xFF1A2035) : Colors.white;
    final hintColor = isDark ? Colors.white38 : AppColors.textLight;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black45,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void addTag() {
              _addTagFromInput();
              setDialogState(() {});
            }

            void removeTag(String tag) {
              _removeTag(tag);
              setDialogState(() {});
            }

            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 90, left: 20, right: 20),
                child: Material(
                  color: popupBg,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Etiket Ekle',
                              style: GoogleFonts.notoSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(dialogCtx),
                              child:
                                  Icon(Icons.close, size: 18, color: hintColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _tagInputCtrl,
                                autofocus: true,
                                style: GoogleFonts.notoSans(
                                    fontSize: 13, color: titleColor),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => addTag(),
                                decoration: InputDecoration(
                                  hintText: 'Etiket gir',
                                  hintStyle: GoogleFonts.notoSans(
                                      fontSize: 13, color: hintColor),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color:
                                            hintColor.withValues(alpha: 0.4)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: AppColors.gold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: addTag,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        if (_tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in _tags)
                                Chip(
                                  label: Text('#$tag',
                                      style:
                                          GoogleFonts.notoSans(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () => removeTag(tag),
                                  backgroundColor:
                                      AppColors.gold.withValues(alpha: 0.12),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Popup kapanınca eklenen etiketler "Eklentiler" özetinde görünsün.
      if (mounted) setState(() {});
    });
  }

  // Görsel Ekle / Etiket Ekle / Ses Ekle satırındaki tek bir buton —
  // ses kaydı sürerken "active" haliyle kırmızı zeminli, yanıp sönen bir
  // noktayla gösterilir (bkz. _recordingPulseOn).
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color borderColor,
    required Color textColor,
    bool active = false,
    bool pulse = false,
  }) {
    const activeColor = Colors.red;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? activeColor.withValues(alpha: 0.12) : null,
            border: Border.all(
              color: active ? activeColor.withValues(alpha: 0.6) : borderColor,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: active ? activeColor : textColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSans(
                    fontSize: 12.5,
                    color: active ? activeColor : textColor,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                AnimatedOpacity(
                  opacity: pulse ? 1 : 0.25,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.fiber_manual_record,
                      size: 9, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Fotoğraf çek'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final permanentPath = await NoteFileStorage.persistImage(picked.path);
      setState(() => _imagePaths = [..._imagePaths, permanentPath]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resim eklenemedi')),
      );
    }
  }

  void _removeImage(String path) {
    setState(() => _imagePaths = _imagePaths.where((p) => p != path).toList());
    NoteFileStorage.deleteIfExists(path);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _recordingPulseTimer?.cancel();
      _recordingPulseTimer = null;
      setState(() {
        _isRecording = false;
        _recordingPulseOn = false;
      });
      if (path != null) {
        setState(() {
          _audioPaths = [..._audioPaths, path];
          // Yeni ses kaydedildi — kullanıcı hemen görsün diye ekler paneli aç.
          _attachmentsExpanded = true;
        });
      }
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mikrofon izni gerekli')),
      );
      return;
    }
    final targetPath = await NoteFileStorage.newAudioTargetPath();
    await _recorder.start(const RecordConfig(), path: targetPath);
    setState(() => _isRecording = true);
    // "Ses Ekle" butonundaki kırmızı nokta yanıp söner — kayıt sürüyor hissi.
    _recordingPulseTimer =
        Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      setState(() => _recordingPulseOn = !_recordingPulseOn);
    });
  }

  void _removeAudio(String path) {
    setState(() => _audioPaths = _audioPaths.where((p) => p != path).toList());
    NoteFileStorage.deleteIfExists(path);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _reminderAt ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _reminderAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _clearReminder() => setState(() => _reminderAt = null);

  void _handleSave() {
    final title = _titleCtrl.text.trim();
    final plainText = _quillController.document.toPlainText().trim();
    final deltaJson = jsonEncode(_quillController.document.toDelta().toJson());
    widget.onSave(NoteDraft(
      title: title,
      content: plainText,
      contentDelta: deltaJson,
      tags: _tags,
      color: _color,
      isPinned: _isPinned,
      imagePaths: _imagePaths,
      audioPaths: _audioPaths,
      reminderAt: _reminderAt,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom = klavye yüksekliği
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final hintColor = isDark ? Colors.white38 : AppColors.textLight;
    final borderColor = AppColors.textLight.withValues(alpha: 0.3);
    // İçerik kutusu odaklanmışsa (klavye açık) — başlık/eklentiler alanı
    // gizlenip yazma alanına yer açılır (bkz. o bölümdeki AnimatedSize).
    final editorFocused = _contentFocus.hasFocus;

    return AnimatedPadding(
      // Klavye açılınca sheet yukarı kayar
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: DraggableScrollableSheet(
        initialChildSize: 0.94,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Tutamaç
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Başlık satırı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.note != null ? 'Notu Düzenle' : 'Yeni Not',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          'Notlarını düzenle, düşüncelerini kaydet.',
                          style: GoogleFonts.notoSans(
                            fontSize: 11.5,
                            color: hintColor,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // NOT: "Hatırlatıcı ekle" ve "Başa sabitle" düğmeleri
                    // buradan kaldırıldı — dar ekranlarda Kaydet düğmesiyle
                    // birlikte satıra sığmıyor, Kaydet'e dokunmayı
                    // zorlaştırıyordu. Sabitleme zaten not listesinden
                    // (uzun basma/ikon) yapılabiliyor; zaten kurulu bir
                    // hatırlatıcı varsa aşağıdaki etiket olarak gösterilmeye
                    // devam ediyor.
                    TextButton(
                      onPressed: _handleSave,
                      child: const Text('Kaydet',
                          style: TextStyle(color: AppColors.gold)),
                    ),
                  ],
                ),
              ),

              Divider(color: AppColors.textLight.withValues(alpha: 0.2)),

              // ── Başlık + Eklentiler + Görsel/Etiket/Ses Ekle ──────────────
              // İçerik kutusu odaklanınca (klavye açılınca) bu bölüm tamamen
              // gizlenir — yazma alanına yer açılır. Odak kaybolunca (geri
              // tuşu / klavye kapanması) AnimatedSize ile geri gelir.
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: editorFocused
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Başlık alanı
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _titleCtrl,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(context)
                                    .requestFocus(_contentFocus),
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Başlık',
                                  hintStyle: GoogleFonts.playfairDisplay(
                                    color: hintColor,
                                    fontSize: 18,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),

                          if (_reminderAt != null)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Chip(
                                  avatar: const Icon(Icons.alarm,
                                      size: 16, color: AppColors.gold),
                                  label: Text(
                                    DateFormat('d MMMM y, HH:mm', 'tr_TR')
                                        .format(_reminderAt!),
                                    style: GoogleFonts.notoSans(fontSize: 12),
                                  ),
                                  deleteIcon:
                                      const Icon(Icons.close, size: 14),
                                  onDeleted: _clearReminder,
                                  backgroundColor:
                                      AppColors.gold.withValues(alpha: 0.12),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),

                          // ── Eklentiler ───────────────────────────────────
                          // Eskiden burada "#etiket ekle" kutusu dururdu.
                          // Artık kayıtlı görsel/ses/etiketlerin özetlendiği
                          // TEK bir panel — tıklanınca aşağı doğru açılır,
                          // dokunulmazsa kapalı (gizli) kalır.
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: GestureDetector(
                              onTap: () => setState(() =>
                                  _attachmentsExpanded =
                                      !_attachmentsExpanded),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: borderColor),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.attach_file,
                                        size: 17, color: hintColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Eklentiler',
                                      style: GoogleFonts.notoSans(
                                          fontSize: 13, color: hintColor),
                                    ),
                                    if (_tags.isNotEmpty ||
                                        _imagePaths.isNotEmpty ||
                                        _audioPaths.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${_tags.length + _imagePaths.length + _audioPaths.length})',
                                        style: GoogleFonts.notoSans(
                                            fontSize: 12, color: hintColor),
                                      ),
                                    ],
                                    const Spacer(),
                                    Icon(
                                      _attachmentsExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: hintColor,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_attachmentsExpanded)
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxHeight: 220),
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 8, 16, 0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_tags.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              for (final tag in _tags)
                                                Chip(
                                                  label: Text('#$tag',
                                                      style: GoogleFonts
                                                          .notoSans(
                                                              fontSize: 11)),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  deleteIcon: const Icon(
                                                      Icons.close, size: 14),
                                                  onDeleted: () =>
                                                      _removeTag(tag),
                                                  backgroundColor: AppColors
                                                      .gold
                                                      .withValues(alpha: 0.12),
                                                ),
                                            ],
                                          ),
                                        ),
                                      if (_imagePaths.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 4),
                                          child: SizedBox(
                                            height: 56,
                                            child: ListView(
                                              scrollDirection:
                                                  Axis.horizontal,
                                              children: [
                                                for (final path
                                                    in _imagePaths)
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .only(right: 8),
                                                    child: Stack(
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () =>
                                                              openImageViewer(
                                                                  context,
                                                                  path),
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            child: Image.file(
                                                              File(path),
                                                              width: 56,
                                                              height: 56,
                                                              fit: BoxFit
                                                                  .cover,
                                                              errorBuilder:
                                                                  (_, __,
                                                                          ___) =>
                                                                      Container(
                                                                width: 56,
                                                                height: 56,
                                                                color: Colors
                                                                    .black12,
                                                                child: const Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                    size: 18),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Positioned(
                                                          top: 2,
                                                          right: 2,
                                                          child:
                                                              GestureDetector(
                                                            onTap: () =>
                                                                _removeImage(
                                                                    path),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(2),
                                                              decoration:
                                                                  const BoxDecoration(
                                                                color: Colors
                                                                    .black54,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              child: const Icon(
                                                                  Icons.close,
                                                                  size: 11,
                                                                  color: Colors
                                                                      .white),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (_audioPaths.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 4),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxHeight: 180),
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const ClampingScrollPhysics(),
                                              itemCount: _audioPaths.length,
                                              itemBuilder: (_, i) =>
                                                  _AudioTile(
                                                path: _audioPaths[i],
                                                onDelete: () => _removeAudio(
                                                    _audioPaths[i]),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_tags.isEmpty &&
                                          _imagePaths.isEmpty &&
                                          _audioPaths.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8),
                                          child: Text(
                                            'Henüz eklenti yok',
                                            style: GoogleFonts.notoSans(
                                                fontSize: 12,
                                                color: hintColor),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // ── Görsel / Etiket / Ses Ekle ───────────────────
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 10, 16, 12),
                            child: Row(
                              children: [
                                _buildActionButton(
                                  icon: Icons.add_photo_alternate_outlined,
                                  label: 'Görsel Ekle',
                                  onTap: () =>
                                      _showImageSourceSheet(context),
                                  borderColor: borderColor,
                                  textColor: hintColor,
                                ),
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  icon: Icons.local_offer_outlined,
                                  label: 'Etiket Ekle',
                                  onTap: () => _showTagPopup(context),
                                  borderColor: borderColor,
                                  textColor: hintColor,
                                ),
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  icon: _isRecording
                                      ? Icons.stop_circle
                                      : Icons.mic_none,
                                  label: _isRecording
                                      ? 'Kaydediliyor'
                                      : 'Ses Ekle',
                                  onTap: _toggleRecording,
                                  borderColor: borderColor,
                                  textColor: hintColor,
                                  active: _isRecording,
                                  pulse: _recordingPulseOn,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 4),

              // Minimalist biçimlendirme araç çubuğu
              // NOT: Daha önce bu bar koyu temada "boş gri şerit" gibi
              // görünüyordu — sebebi ikonların Quill'in varsayılan Theme
              // ikon rengini (koyu arkaplanda koyu ikon) kullanmasıydı.
              // Theme override ile ikon/metin rengini bilinçli olarak
              // arkaplanla kontrast oluşturacak şekilde zorluyoruz.
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141A2E)
                      : const Color(0xFFF7F5F0),
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.textLight.withValues(alpha: 0.15)),
                  ),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    brightness: isDark ? Brightness.dark : Brightness.light,
                    iconTheme: IconThemeData(
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                    textTheme: Theme.of(context).textTheme.apply(
                          bodyColor:
                              isDark ? Colors.white70 : AppColors.textPrimary,
                          displayColor:
                              isDark ? Colors.white70 : AppColors.textPrimary,
                        ),
                  ),
                  child: quill.QuillSimpleToolbar(
                    controller: _quillController,
                    config: const quill.QuillSimpleToolbarConfig(
                      multiRowsDisplay: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: true,
                      showStrikeThrough: true,
                      showColorButton: true,
                      showBackgroundColorButton: true,
                      showClearFormat: false,
                      showAlignmentButtons: false,
                      showHeaderStyle: true,
                      showListNumbers: true,
                      showListBullets: true,
                      showListCheck: true,
                      showCodeBlock: false,
                      showQuote: true,
                      showIndent: false,
                      showLink: false,
                      showUndo: true,
                      showRedo: true,
                      showDirection: false,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                      showInlineCode: false,
                      showDividers: true,
                    ),
                  ),
                ),
              ),

              // İçerik alanı — zengin metin editörü
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: quill.QuillEditor(
                    controller: _quillController,
                    focusNode: _contentFocus,
                    scrollController: ScrollController(),
                    config: quill.QuillEditorConfig(
                      placeholder: 'Notunu buraya yaz...',
                      padding: EdgeInsets.zero,
                      expands: true,
                      scrollable: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SES NOTU OYNATICI ─────────────────────────────────────────────────────
// Kapalı hâlde küçük bir kart olarak görünür (oynat/duraklat + süre + sil).
// Karta dokununca genişler ve ilerleme çubuğu, ileri/geri 10sn atlama ve
// 1x / 1.5x / 2x oynatma hızı seçenekleri ortaya çıkar.

class _AudioTile extends StatefulWidget {
  final String path;
  final VoidCallback onDelete;

  const _AudioTile({required this.path, required this.onDelete});

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isExpanded = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;

  static const _speeds = [1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_position == Duration.zero) {
        await _player.play(DeviceFileSource(widget.path));
        await _player.setPlaybackRate(_speed);
      } else {
        await _player.resume();
      }
    }
    if (mounted) setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _seekRelative(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration
            ? _duration
            : target);
    await _player.seek(clamped);
    if (mounted) setState(() => _position = clamped);
  }

  Future<void> _cycleSpeed() async {
    final nextIndex = (_speeds.indexOf(_speed) + 1) % _speeds.length;
    final next = _speeds[nextIndex];
    await _player.setPlaybackRate(next);
    if (mounted) setState(() => _speed = next);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final cardBg = isDark ? const Color(0xFF20273D) : const Color(0xFFF7F5F0);
    final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final curMs = _position.inMilliseconds.clamp(0, maxMs);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggle,
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: AppColors.gold,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sesli not',
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _duration > Duration.zero
                            ? _fmt(_duration)
                            : (_isPlaying || _position > Duration.zero
                                ? _fmt(_position)
                                : ''),
                        style: GoogleFonts.notoSans(
                            fontSize: 11, color: textColor),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: textColor,
                      ),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.close, size: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  if (_isExpanded) ...[
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: curMs.toDouble(),
                        min: 0,
                        max: maxMs.toDouble(),
                        activeColor: AppColors.gold,
                        inactiveColor: AppColors.gold.withValues(alpha: 0.2),
                        onChanged: (v) {
                          setState(() =>
                              _position = Duration(milliseconds: v.round()));
                        },
                        onChangeEnd: (v) =>
                            _player.seek(Duration(milliseconds: v.round())),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(_position),
                            style: GoogleFonts.notoSans(
                                fontSize: 10, color: textColor)),
                        Text(
                            _duration > Duration.zero
                                ? _fmt(_duration)
                                : '--:--',
                            style: GoogleFonts.notoSans(
                                fontSize: 10, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _seekRelative(-10),
                          child: Icon(Icons.replay_10,
                              color: AppColors.gold, size: 22),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () => _seekRelative(10),
                          child: Icon(Icons.forward_10,
                              color: AppColors.gold, size: 22),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: _cycleSpeed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

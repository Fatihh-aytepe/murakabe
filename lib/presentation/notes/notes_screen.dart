import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/note_model.dart';
import '../../data/repositories/note_repository.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  final _repo = NoteRepository();
  List<NoteModel> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void reload() => _loadNotes();

  Future<void> _loadNotes() async {
    final notes = await _repo.getNotes();
    if (mounted) setState(() => _notes = notes);
  }

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      'Notlarım',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_notes.length} not',
                      style: GoogleFonts.notoSans(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildNoteCard(_notes[i]),
                    childCount: _notes.length,
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

  Widget _buildNoteCard(NoteModel note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.textSecondary;
    final dateColor = isDark ? Colors.white38 : AppColors.textLight;

    return GestureDetector(
      onTap: () => _openNoteEditor(note: note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => _deleteNote(note),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
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
            const SizedBox(height: 8),
            Text(
              _formatDate(note.updatedAt),
              style: GoogleFonts.notoSans(fontSize: 11, color: dateColor),
            ),
          ],
        ),
      ),
    );
  }

  void _openNoteEditor({NoteModel? note}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Klavye açılınca sheet otomatik yukarı kayar
      useSafeArea: true,
      builder: (_) => _NoteEditorSheet(
        note: note,
        onSave: (title, content) async {
          if (note != null) {
            await _repo.updateNote(NoteModel(
              id: note.id,
              title: title,
              content: content,
              createdAt: note.createdAt,
              updatedAt: DateTime.now(),
            ));
          } else {
            await _repo.addNote(title: title, content: content);
          }
          await _loadNotes();
        },
      ),
    );
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
      await _repo.deleteNote(note.id);
      await _loadNotes();
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── NOT EDİTÖRÜ ──────────────────────────────────────────────────────────────

class _NoteEditorSheet extends StatefulWidget {
  final NoteModel? note;
  final Function(String title, String content) onSave;

  const _NoteEditorSheet({this.note, required this.onSave});

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  final FocusNode _contentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom = klavye yüksekliği
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final hintColor = isDark ? Colors.white38 : AppColors.textLight;
    final contentColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return AnimatedPadding(
      // Klavye açılınca sheet yukarı kayar
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Container(
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
                  children: [
                    Text(
                      widget.note != null ? 'Notu Düzenle' : 'Yeni Not',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        widget.onSave(
                          _titleCtrl.text.trim(),
                          _contentCtrl.text.trim(),
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Kaydet',
                          style: TextStyle(color: AppColors.gold)),
                    ),
                  ],
                ),
              ),

              Divider(color: AppColors.textLight.withValues(alpha: 0.2)),

              // Form alanları — Expanded + SingleChildScrollView klavyeyle uyumlu
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  // Klavye açıkken içerik görünür kalsın
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık alanı
                      TextField(
                        controller: _titleCtrl,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_contentFocus),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Başlık',
                          hintStyle: GoogleFonts.playfairDisplay(
                            color: hintColor,
                            fontSize: 20,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: AppColors.textLight.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),

                      // İçerik alanı — minLines ile başlangıç yüksekliği verildi
                      TextField(
                        controller: _contentCtrl,
                        focusNode: _contentFocus,
                        maxLines: null,
                        minLines: 12,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          height: 1.7,
                          color: contentColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Notunu buraya yaz...',
                          hintStyle: GoogleFonts.notoSans(
                            color: hintColor,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          // İçerik büyüdükçe alan genişlesin
                          isDense: false,
                        ),
                      ),
                    ],
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

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'murakabe.db');
    return openDatabase(
      path,
      version:
          9, // 7 → 8: notes.imagePaths / audioPaths / reminderAt | 8 → 9: notes.imageUrls / audioUrls (Firebase Storage yedek linkleri)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Kullanıcı tablosu
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        nameSurname TEXT,
        phone TEXT,
        email TEXT,
        createdAt TEXT,
        quranReadDays INTEGER DEFAULT 0,
        missedQuranDays TEXT DEFAULT '[]',
        tahajjudAlarmEnabled INTEGER DEFAULT 0,
        tahajjudAlarmTimes TEXT DEFAULT '[]',
        streakDays INTEGER DEFAULT 0,
        mercyDaysUsed INTEGER DEFAULT 0,
        lastStreakDate TEXT DEFAULT '',
        bio TEXT DEFAULT '',
        gender TEXT DEFAULT '',
        photoUrl TEXT DEFAULT '',
        isEmailVerified INTEGER DEFAULT 0
      )
    ''');

    // Kaydedilen içerikler
    await db.execute('''
      CREATE TABLE saved_content (
        id TEXT PRIMARY KEY,
        type TEXT,
        contentId INTEGER,
        savedAt TEXT
      )
    ''');

    // Notlar
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT,
        content TEXT,
        contentDelta TEXT DEFAULT '',
        tags TEXT DEFAULT '[]',
        color TEXT DEFAULT '',
        isPinned INTEGER DEFAULT 0,
        imagePaths TEXT DEFAULT '[]',
        audioPaths TEXT DEFAULT '[]',
        imageUrls TEXT DEFAULT '[]',
        audioUrls TEXT DEFAULT '[]',
        reminderAt TEXT DEFAULT '',
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    // Kuran okuma takibi
    await db.execute('''
      CREATE TABLE quran_tracking (
        date TEXT PRIMARY KEY,
        isRead INTEGER DEFAULT 0,
        readAt TEXT
      )
    ''');

    // Teheccüd takibi
    await db.execute('''
      CREATE TABLE tahajjud_tracking (
        date TEXT PRIMARY KEY,
        isPrayed INTEGER DEFAULT 0,
        prayedAt TEXT
      )
    ''');

    // Hatırlatıcılar
    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        title TEXT,
        content TEXT,
        reminderTime TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT
      )
    ''');

    // Günlük içerik indeksi
    await db.execute('''
      CREATE TABLE daily_index (
        date TEXT PRIMARY KEY,
        esmaIndex INTEGER DEFAULT 0,
        hadisIndex INTEGER DEFAULT 0,
        ayetIndex INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE rewards (
        id TEXT PRIMARY KEY,
        type TEXT,
        title TEXT,
        message TEXT,
        earnedAt TEXT
      )
    ''');

    await _createCustomTaskTables(db);
    await _createBadgesTable(db);
  }

  Future<void> _createBadgesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS badges (
        id TEXT PRIMARY KEY,
        badgeId TEXT NOT NULL,
        earnedAt TEXT NOT NULL,
        isDisplayed INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createCustomTaskTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_tasks (
        id TEXT PRIMARY KEY,
        userId TEXT DEFAULT '',
        title TEXT,
        description TEXT DEFAULT '',
        emoji TEXT DEFAULT '📝',
        isActive INTEGER DEFAULT 1,
        notificationTime TEXT DEFAULT '',
        createdAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_task_completions (
        id TEXT PRIMARY KEY,
        taskId TEXT,
        completedDate TEXT,
        completedAt TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createCustomTaskTables(db);
    }
    if (oldVersion < 3) {
      // Profil alanları migration — ALTER TABLE ile eklenir
      final cols = ['bio', 'gender', 'photoUrl', 'isEmailVerified'];
      final defaults = ["''", "''", "''", '0'];
      final types = ['TEXT', 'TEXT', 'TEXT', 'INTEGER'];
      for (var i = 0; i < cols.length; i++) {
        try {
          await db.execute(
            'ALTER TABLE users ADD COLUMN ${cols[i]} ${types[i]} DEFAULT ${defaults[i]}',
          );
        } catch (_) {}
      }
    }
    if (oldVersion < 4) {
      await _createBadgesTable(db);
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
            'ALTER TABLE custom_tasks ADD COLUMN userId TEXT DEFAULT ""');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
            "ALTER TABLE notes ADD COLUMN contentDelta TEXT DEFAULT ''");
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute("ALTER TABLE notes ADD COLUMN tags TEXT DEFAULT '[]'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE notes ADD COLUMN color TEXT DEFAULT ''");
      } catch (_) {}
      try {
        await db
            .execute('ALTER TABLE notes ADD COLUMN isPinned INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute(
            "ALTER TABLE notes ADD COLUMN imagePaths TEXT DEFAULT '[]'");
      } catch (_) {}
      try {
        await db.execute(
            "ALTER TABLE notes ADD COLUMN audioPaths TEXT DEFAULT '[]'");
      } catch (_) {}
      try {
        await db
            .execute("ALTER TABLE notes ADD COLUMN reminderAt TEXT DEFAULT ''");
      } catch (_) {}
    }
    if (oldVersion < 9) {
      // Not eklerinin (resim/ses) Firebase Storage'daki yedek linkleri.
      // Cihazda dosya silinirse (uygulama kaldırılıp tekrar yüklenirse) bu
      // URL'ler üzerinden dosyalar tekrar indirilip yerel path'e kopyalanır.
      try {
        await db.execute(
            "ALTER TABLE notes ADD COLUMN imageUrls TEXT DEFAULT '[]'");
      } catch (_) {}
      try {
        await db.execute(
            "ALTER TABLE notes ADD COLUMN audioUrls TEXT DEFAULT '[]'");
      } catch (_) {}
    }
  }

  // ─── Genel metodlar ───────────────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<int> rawUpdate(String sql, List<Object?> args) async {
    final db = await database;
    return db.rawUpdate(sql, args);
  }

  /// Hesap kalıcı olarak silinirken çağrılır: cihazdaki TÜM yerel verileri
  /// (kullanıcı satırı, notlar, hatırlatıcılar, ödüller, rozetler, görevler,
  /// takip kayıtları) siler. Yerel veritabanı tek aktif hesabı tuttuğundan
  /// (bkz. tablo şemaları — çoğu tabloda userId kolonu yok) tam temizlik
  /// güvenlidir ve hiçbir başka hesabın verisini etkilemez.
  Future<void> wipeAllTables() async {
    final db = await database;
    const tables = [
      'users',
      'saved_content',
      'notes',
      'quran_tracking',
      'tahajjud_tracking',
      'reminders',
      'daily_index',
      'rewards',
      'badges',
      'custom_tasks',
      'custom_task_completions',
    ];
    final batch = db.batch();
    for (final t in tables) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }
}

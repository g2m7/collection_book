import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._();
  factory BackupService() => _instance;
  BackupService._();

  DateTime? _lastBackup;
  static const _backupPrefix = 'rent_ledger_backup_';
  static const _minBackupInterval = Duration(minutes: 5);

  Future<Directory> get _backupDir async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'RentLedgerBackups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<String> backup() async {
    final dbPath = await DatabaseService().getDatabasePath();
    final sourceFile = File(dbPath);
    if (!await sourceFile.exists()) {
      throw Exception('Database file not found');
    }

    final dir = await _backupDir;
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupPath = p.join(dir.path, '$_backupPrefix$timestamp.db');

    await sourceFile.copy(backupPath);
    _lastBackup = DateTime.now();

    await _cleanOldBackups();
    return backupPath;
  }

  void autoBackup() async {
    if (_lastBackup != null &&
        DateTime.now().difference(_lastBackup!) < _minBackupInterval) {
      return;
    }
    try {
      await backup();
    } catch (_) {
      // Silent fail for auto-backup
    }
  }

  Future<void> restoreFromFile(String filePath) async {
    await DatabaseService().replaceDatabase(filePath);
  }

  Future<List<FileSystemEntity>> listBackups() async {
    final dir = await _backupDir;
    if (!await dir.exists()) return [];

    final files = await dir
        .list()
        .where((f) => f is File && f.path.endsWith('.db'))
        .toList();

    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> shareBackup() async {
    final path = await backup();
    await Share.shareXFiles([XFile(path)]);
  }

  Future<DateTime?> getLastBackupTime() async {
    final backups = await listBackups();
    if (backups.isEmpty) return null;

    final stat = await backups.first.stat();
    return stat.modified;
  }

  Future<void> _cleanOldBackups() async {
    final backups = await listBackups();
    if (backups.length <= 10) return;

    for (var i = 10; i < backups.length; i++) {
      try {
        await backups[i].delete();
      } catch (_) {}
    }
  }

  Future<String> getBackupDirPath() async {
    final dir = await _backupDir;
    return dir.path;
  }
}

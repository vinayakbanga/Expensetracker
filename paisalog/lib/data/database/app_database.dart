/// Drift AppDatabase definition.
/// Run `dart run build_runner build --delete-conflicting-outputs` to generate
/// the companion AppDatabase class and all DAO helpers.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  AccountsTable,
  CategoriesTable,
  TransactionsTable,
  IngestionQueueTable,
  UserCorrectionsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing — pass an in-memory connection.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedSystemCategories();
        },
        onUpgrade: (m, from, to) async {
          // Future migrations go here.
        },
      );

  /// Seed built-in system categories that users cannot delete.
  Future<void> _seedSystemCategories() async {
    final now = DateTime.now();
    final systemCategories = [
      CategoriesTableCompanion.insert(
        id: 'food_dining',
        name: 'Food & Dining',
        iconKey: 'restaurant',
        colorHex: '#FF6B35',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'shopping',
        name: 'Shopping',
        iconKey: 'shopping_bag',
        colorHex: '#A855F7',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'transport',
        name: 'Transport',
        iconKey: 'directions_car',
        colorHex: '#3B82F6',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'entertainment',
        name: 'Entertainment',
        iconKey: 'movie',
        colorHex: '#EC4899',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'utilities',
        name: 'Utilities',
        iconKey: 'bolt',
        colorHex: '#F59E0B',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'healthcare',
        name: 'Healthcare',
        iconKey: 'local_hospital',
        colorHex: '#10B981',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'education',
        name: 'Education',
        iconKey: 'school',
        colorHex: '#06B6D4',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'housing',
        name: 'Housing & Rent',
        iconKey: 'home',
        colorHex: '#8B5CF6',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'income_salary',
        name: 'Salary',
        iconKey: 'payments',
        colorHex: '#22C55E',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'transfer',
        name: 'Transfer',
        iconKey: 'swap_horiz',
        colorHex: '#94A3B8',
        isSystem: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        id: 'other',
        name: 'Other',
        iconKey: 'more_horiz',
        colorHex: '#64748B',
        isSystem: const Value(true),
      ),
    ];

    for (final cat in systemCategories) {
      await into(categoriesTable).insertOnConflictUpdate(cat);
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'paisalog.db'));
    return NativeDatabase(file);
    // NOTE: SQLCipher upgrade tracked in DECISIONS.md D-003.
    // Once flutter_sqlcipher is verified on iOS, replace with:
    // return NativeDatabase(file, setup: (db) { db.execute("PRAGMA key='...'"); });
    // Key must come from flutter_secure_storage / Keychain, NEVER hardcoded.
  });
}


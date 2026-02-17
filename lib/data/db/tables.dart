import 'package:drift/drift.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // 1..5
  IntColumn get priority => integer().withDefault(const Constant(3))();

  // migration-added field (we keep it in schema v2)
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class TaskTags extends Table {
  IntColumn get taskId => integer().references(
        Tasks,
        #id,
        onDelete: KeyAction.cascade,
      )();

  IntColumn get tagId => integer().references(
        Tags,
        #id,
        onDelete: KeyAction.cascade,
      )();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

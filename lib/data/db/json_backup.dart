import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

class JsonBackup {
  final AppDatabase db;
  JsonBackup(this.db);

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'backup.json'));
  }

  Future<void> exportToJson() async {
    final tasksList = await db.select(db.tasks).get();
    final tagsList = await db.select(db.tags).get();
    final linksList = await db.select(db.taskTags).get();

    final data = <String, dynamic>{
      "tasks": tasksList
          .map((t) => {
                "id": t.id,
                "title": t.title,
                "description": t.description,
                "createdAt": t.createdAt.toIso8601String(),
                "priority": t.priority,
                "completed": t.completed,
              })
          .toList(),
      "tags": tagsList.map((t) => {"id": t.id, "name": t.name}).toList(),
      "taskTags": linksList
          .map((x) => {"taskId": x.taskId, "tagId": x.tagId})
          .toList(),
    };

    final f = await _file();
    await f.writeAsString(jsonEncode(data));
  }

  Future<void> importFromJson() async {
    final f = await _file();
    if (!await f.exists()) return;

    final raw = await f.readAsString();
    final map = jsonDecode(raw) as Map<String, dynamic>;

    await db.transaction(() async {
      await db.delete(db.taskTags).go();
      await db.delete(db.tasks).go();
      await db.delete(db.tags).go();

      final tasksList = (map["tasks"] as List).cast<Map<String, dynamic>>();
      for (final t in tasksList) {
        await db.into(db.tasks).insert(
              db.tasks.map({
                db.tasks.id: t["id"] as int,
                db.tasks.title: t["title"] as String,
                db.tasks.description: t["description"],
                db.tasks.createdAt: DateTime.parse(t["createdAt"] as String),
                db.tasks.priority: t["priority"] as int,
                db.tasks.completed: (t["completed"] as bool?) ?? false,
              }),
              mode: InsertMode.insertOrReplace,
            );
      }

      final tagsList = (map["tags"] as List).cast<Map<String, dynamic>>();
      for (final tag in tagsList) {
        await db.into(db.tags).insert(
              db.tags.map({
                db.tags.id: tag["id"] as int,
                db.tags.name: (tag["name"] as String),
              }),
              mode: InsertMode.insertOrReplace,
            );
      }

      final links = (map["taskTags"] as List).cast<Map<String, dynamic>>();
      for (final l in links) {
        await db.into(db.taskTags).insert(
              db.taskTags.map({
                db.taskTags.taskId: l["taskId"] as int,
                db.taskTags.tagId: l["tagId"] as int,
              }),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }
}

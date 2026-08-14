import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:task_manager/models/task_model.dart';

class TaskService {
  final CollectionReference<Map<String, dynamic>> _taskCollection =
      FirebaseFirestore.instance.collection('tasks');

      Stream<List<TaskModel>> getTasks() {
    return _taskCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => TaskModel.fromDocument(document))
              .toList(),
        );
  }

  Future<void> addTask({
    required String title,
    required String description,
  }) async {
    await _taskCollection.add({
      'title': title.trim(),
      'description': description.trim(),
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

   Future<void> updateTask({
    required String taskId,
    required String title,
    required String description,
  }) async {
    await _taskCollection.doc(taskId).update({
      'title': title.trim(),
      'description': description.trim(),
    });
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required bool isCompleted,
  }) async {
    await _taskCollection.doc(taskId).update({
      'isCompleted': isCompleted,
    });
  }

  Future<void> deleteTask(String taskId) async {
    await _taskCollection.doc(taskId).delete();
  }
}

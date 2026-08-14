import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TaskService _taskService = TaskService();

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getErrorMessage(Object error) {
    if (error is FirebaseException) {
      return error.message ?? 'A Firebase error occurred.';
    }

    return 'Something went wrong. Please try again.';
  }

  Future<void> _showTaskDialog({TaskModel? task}) async {
    final bool isEditing = task != null;
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController(
      text: task?.title ?? '',
    );

    final descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Update Task' : 'Add Task'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Task title',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a task title';
                          }

                          if (value.trim().length < 3) {
                            return 'Title must contain at least 3 characters';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            if (isEditing) {
                              await _taskService.updateTask(
                                taskId: task.id,
                                title: titleController.text,
                                description: descriptionController.text,
                              );
                            } else {
                              await _taskService.addTask(
                                title: titleController.text,
                                description: descriptionController.text,
                              );
                            }

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);

                            _showMessage(
                              isEditing
                                  ? 'Task updated successfully'
                                  : 'Task added successfully',
                            );
                          } catch (error) {
                            setDialogState(() {
                              isSaving = false;
                            });

                            _showMessage(
                              _getErrorMessage(error),
                              isError: true,
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(isEditing ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> _changeTaskStatus(
    TaskModel task,
    bool? newValue,
  ) async {
    if (newValue == null) return;

    try {
      await _taskService.updateTaskStatus(
        taskId: task.id,
        isCompleted: newValue,
      );

      _showMessage(
        newValue ? 'Task completed' : 'Task marked as incomplete',
      );
    } catch (error) {
      _showMessage(
        _getErrorMessage(error),
        isError: true,
      );
    }
  }

  Future<void> _confirmDelete(TaskModel task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Text(
            'Are you sure you want to delete "${task.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _taskService.deleteTask(task.id);
      _showMessage('Task deleted successfully');
    } catch (error) {
      _showMessage(
        _getErrorMessage(error),
        isError: true,
      );
    }
  }

  Widget _buildTaskCard(TaskModel task) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 7,
      ),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (value) => _changeTaskStatus(task, value),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration:
                task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            task.description,
            style: TextStyle(
              decoration:
                  task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showTaskDialog(task: task);
            } else if (value == 'delete') {
              _confirmDelete(task);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 10),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Task Manager'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _taskService.getTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load tasks',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getErrorMessage(snapshot.error!),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No tasks available',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Press the + button to add a task.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              return _buildTaskCard(tasks[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }
}
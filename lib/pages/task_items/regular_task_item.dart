import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tasks/main.dart';
import 'package:tasks/models/subtodo.dart';
import 'package:tasks/models/todo_collection.dart';
import 'package:tasks/models/todo_regular.dart';
import 'package:tasks/services/sub_tasks_service.dart';
import 'package:tasks/services/update_provider.dart';

class RegularTaskItem extends StatefulWidget {
  final TodoRegular task;
  final ToDoCollection? collection;
  final Function(bool?, int?) onTaskStateChanged;
  final Function(int) onTaskTap;
  final Function(int) onCollectionTap;

  const RegularTaskItem({
    super.key,
    required this.task,
    required this.onTaskStateChanged,
    required this.onTaskTap,
    required this.onCollectionTap,
    required this.collection,
  });

  @override
  State<RegularTaskItem> createState() => _RegularTaskItemState();
}

class _RegularTaskItemState extends State<RegularTaskItem> {
  final _subTasksService = locator<SubTasksService>();
  final _updateProvider = locator<UpdateProvider>();
  List<SubTodo> _subTasks = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadSubTasks();
    _updateProvider.addListener(_loadSubTasks);
  }

  @override
  void dispose() {
    _updateProvider.removeListener(_loadSubTasks);
    super.dispose();
  }

  Future<void> _loadSubTasks() async {
    final subTasks = await _subTasksService.getItemsByField<SubTodo>({
      'task_id': widget.task.id,
    });
    setState(() {
      _subTasks = subTasks ?? [];
    });
  }

  String _daysDifferenceText(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference.abs() < 60) {
      return '$difference d.';
    } else if (difference.abs() < 730) {
      final months = (difference / 30).round();
      return '$months m.';
    } else {
      final years = (difference / 365).round();
      return '$years y.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dueDate = widget.task.dueDate;

    Color borderColor = Colors.grey;

    if (dueDate != null && !widget.task.isCompleted) {
      final isOverdue = dueDate.isBefore(now);
      final isToday = dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;

      if (isToday) {
        borderColor = Colors.yellow;
      } else if (isOverdue) {
        borderColor = Colors.red;
      }
    } else {
      borderColor = Colors.transparent;
    }

    bool showCollection = widget.collection != null && widget.collection!.id != 0;

    Widget urgencyIcon = Row(
      children: [
        Text(
          '!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.task.urgency == 2 ? Colors.red : Colors.orange,
          ),
        ),
      ],
    );

    Widget urgencyPlaceholder = const SizedBox(width: 6);

    Widget taskContent = Padding(
      padding: const EdgeInsets.all(5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.task.urgency == 0 ? urgencyPlaceholder : urgencyIcon,
              Checkbox(
                visualDensity: VisualDensity.compact,
                value: widget.task.isCompleted,
                onChanged: (bool? value) => widget.onTaskStateChanged(value, widget.task.id),
              ),
            ],
          ),
          Expanded(
              child: InkWell(
            onTap: () => widget.onTaskTap(widget.task.id), // Переход к задаче при нажатии на текст
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.task.name,
                  style: TextStyle(
                    decoration: widget.task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (widget.task.description != null && widget.task.description!.isNotEmpty)
                  Text(
                    widget.task.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      decorationStyle: TextDecorationStyle.wavy,
                    ),
                  ),
              ],
            ),
          )),
          if (widget.task.dueDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 0.0),
              child: Text(
                showCollection
                    ? (widget.task.isCompleted ? '' : _daysDifferenceText(widget.task.dueDate!))
                    : DateFormat('dd.MM.yyyy').format(widget.task.dueDate!),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          if (_subTasks.isNotEmpty) // Кнопка "развернуть", если есть подзадачи
            SizedBox(
              width: 25, // Фиксированная ширина для кнопки
              child: Center(
                child: IconButton(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(0),
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ),
            )
          else
            SizedBox(width: 25),
        ],
      ),
    );
    Widget subTasksList = _isExpanded && _subTasks.isNotEmpty
        ? Container(
            padding: const EdgeInsets.only(left: 8.0, right: 16.0, top: 8.0, bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _subTasks.map((subTask) {
                Widget urgencyIconForSubtask = Row(
                  children: [
                    Text(
                      '!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.task.urgency == 2 ? Colors.red : Colors.orange,
                      ),
                    ),
                  ],
                );

                return Row(
                  children: [
                    (subTask.urgency == 0 || subTask.urgency == null) ? urgencyPlaceholder : urgencyIconForSubtask,
                    Checkbox(
                      visualDensity: VisualDensity.compact,
                      value: subTask.isCompleted,
                      onChanged: (bool? value) async {
                        await _subTasksService.updateItemById(subTask.id, {
                          'is_completed': value == true ? 1 : 0,
                        });
                        _updateProvider.notifyListeners();
                        _loadSubTasks();
                      },
                    ),
                    Expanded(
                      child: Text(
                        subTask.name,
                        style: TextStyle(
                          decoration: subTask.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (subTask.dueDate != null)
                      Text(
                        DateFormat('dd.MM.yyyy').format(subTask.dueDate!),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                );
              }).toList(),
            ),
          )
        : const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        boxShadow: const [
          BoxShadow(
            blurStyle: BlurStyle.outer,
            color: Colors.black12,
            spreadRadius: 0,
            blurRadius: 1,
            offset: Offset(0, 0),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 4.0,
          ),
        ),
      ),
      child: Column(
        children: [
          showCollection
              ? Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: taskContent,
                    ),
                    Container(
                        width: 90,
                        padding: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: Colors.black12)),
                        ),
                        child: InkWell(
                          onTap: () => widget.onCollectionTap(widget.task.collectionId),
                          child: Text(
                            widget.collection!.name,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        )),
                  ],
                )
              : taskContent,
          subTasksList, // Добавляем список подзадач под задачу
        ],
      ),
    );
  }
}

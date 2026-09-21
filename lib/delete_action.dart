import 'package:flutter/material.dart';

Future<bool> confirmDelete(
  BuildContext context,
  String kind,
  Future<void> Function() remove, {
  String? detail,
}) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $kind?'),
      content: Text(
        detail ?? 'This recording will be removed from your library.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (yes != true) return false;
  try {
    await remove();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete. Please retry.')),
      );
    }
    return false;
  }
}

class SwipeDelete extends StatefulWidget {
  const SwipeDelete({super.key, required this.child, required this.onDelete});
  final Widget child;
  final VoidCallback onDelete;
  @override
  State<SwipeDelete> createState() => _SwipeDeleteState();
}

class _SwipeDeleteState extends State<SwipeDelete> {
  double offset = 0;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Stack(
      children: [
        if (offset < 0)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 100,
                height: double.infinity,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 80,
                      height: double.infinity,
                      child: IconButton(
                        tooltip: 'Delete',
                        onPressed: offset < -30 ? widget.onDelete : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        GestureDetector(
          onHorizontalDragUpdate: (d) => setState(() {
            offset = (offset + d.delta.dx).clamp(-80, 0);
          }),
          onHorizontalDragEnd: (_) => setState(() {
            offset = offset < -30 ? -80 : 0;
          }),
          child: Transform.translate(
            offset: Offset(offset, 0),
            child: widget.child,
          ),
        ),
      ],
    ),
  );
}

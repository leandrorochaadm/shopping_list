import 'package:flutter/material.dart';

/// Centered message that stays SCROLLABLE.
/// Without this the RefreshIndicator does not trigger on the empty and error
/// states — precisely where users pull to refresh the most.
class MessageView extends StatelessWidget {
  const MessageView(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
  );
}

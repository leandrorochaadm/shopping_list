import 'package:flutter/material.dart';

/// Centered message that stays SCROLLABLE.
/// Without this the RefreshIndicator does not trigger on the empty and error
/// states — precisely where users pull to refresh the most.
class MessageView extends StatelessWidget {
  const MessageView(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Already INSIDE a scrollable: a ListView hands its children an
      // unbounded height, so there is no viewport to fill — and a
      // `minHeight` of infinity is the assertion "BoxConstraints forces an
      // infinite height", which is what this arm exists to avoid. A second
      // SingleChildScrollView here would also swallow the outer pull to
      // refresh, which is the very thing this widget was written for.
      if (!constraints.hasBoundedHeight) return _message;

      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: _message),
        ),
      );
    },
  );

  Widget get _message => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(text, textAlign: TextAlign.center),
  );
}

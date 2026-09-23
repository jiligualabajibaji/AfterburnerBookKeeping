import 'dart:async';
import 'package:flutter/material.dart';

/// 按需构建日期分组，并在搜索跳转时找到尚未进入视口的记录。
class TransactionLocatorList extends StatefulWidget {
  final List<Widget> children;
  final GlobalKey<TransactionHighlightState>? targetKey;

  const TransactionLocatorList({super.key, required this.children, this.targetKey});

  @override
  State<TransactionLocatorList> createState() => _TransactionLocatorListState();
}

class _TransactionLocatorListState extends State<TransactionLocatorList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleLocate();
  }

  @override
  void didUpdateWidget(TransactionLocatorList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey) _scheduleLocate();
  }

  void _scheduleLocate() {
    final targetKey = widget.targetKey;
    if (targetKey == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate(targetKey));
  }

  Future<void> _locate(GlobalKey<TransactionHighlightState> targetKey) async {
    bool isCurrent() => mounted && widget.targetKey == targetKey && _controller.hasClients;
    if (!isCurrent()) return;
    // 每次从顶部开始，避免重复跳转时目标位于当前视口之前。
    _controller.jumpTo(0);
    await WidgetsBinding.instance.endOfFrame;
    while (isCurrent()) {
      final targetContext = targetKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        // 仅移动竖向流水列表，不让 ensureVisible 改变外层月份 PageView。
        await _controller.position.ensureVisible(
          targetContext.findRenderObject()!,
          alignment: 0.4,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        if (isCurrent()) targetKey.currentState?.flash();
        return;
      }
      final position = _controller.position;
      final next = (position.pixels + position.viewportDimension * 0.8)
          .clamp(0.0, position.maxScrollExtent);
      if (next <= position.pixels) return;
      _controller.jumpTo(next);
      // ListView 的离屏分组是懒加载的；布局后再读取真实高度和目标位置。
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: _controller,
    children: widget.children,
  );
}

/// 定位完成后保持高亮两秒，再淡出；不影响批量删除的选中状态。
class TransactionHighlight extends StatefulWidget {
  final Widget child;
  final Color color;

  const TransactionHighlight({super.key, required this.child, required this.color});

  @override
  State<TransactionHighlight> createState() => TransactionHighlightState();
}

class TransactionHighlightState extends State<TransactionHighlight>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 800));
  Timer? _holdTimer;

  void flash() {
    _holdTimer?.cancel();
    _animation.value = 1;
    _holdTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _animation.reverse();
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color.withAlpha((55 * _animation.value).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color.withAlpha((200 * _animation.value).round()), width: 2),
      ),
      child: child,
    ),
  );
}

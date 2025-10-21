import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:value_layout_builder/value_layout_builder.dart';

/// Signature used by [SliverStickyHeader.builder] to build the header
/// when the sticky header state has changed.
typedef SliverStickyHeaderWidgetBuilder = Widget Function(
  BuildContext context,
  SliverStickyHeaderState state,
);

/// A simple state object exposed to [SliverStickyHeader.builder].
@immutable
class SliverStickyHeaderState {
  const SliverStickyHeaderState(this.scrollPercentage, this.isPinned);

  /// From 0.0 to 1.0 representing how much of the header has been scrolled
  /// off the viewport while it is pinned.
  final double scrollPercentage;

  /// Whether the header is currently pinned to the viewport edge.
  final bool isPinned;
}

/// Controls and observes sticky header behaviors.
class StickyHeaderController with ChangeNotifier {
  double _stickyHeaderScrollOffset = 0.0;

  /// The offset to the first item of the current sticky header.
  double get stickyHeaderScrollOffset => _stickyHeaderScrollOffset;

  set stickyHeaderScrollOffset(double value) {
    if (value == _stickyHeaderScrollOffset) return;
    _stickyHeaderScrollOffset = value;
    notifyListeners();
  }
}

/// A sliver with a [RenderBox] as header and a [RenderSliver] as child.
///
/// When [sticky] is true (default), the [header] sticks to the
/// leading edge of the viewport (top/left) while its content scrolls,
/// and is pushed away by the next header. If [reverse] is true, the
/// behavior is mirrored and the header sticks to the trailing edge
/// (bottom/right).
class SliverStickyHeader extends RenderObjectWidget {
  const SliverStickyHeader({
    super.key,
    this.header,
    required this.sliver,
    this.overlapsContent = false,
    this.sticky = true,
    this.reverse = false,
    this.controller,
  });

  /// Creates a widget that builds the header each time its sticky
  /// state changes (scroll percentage or pinned state).
  factory SliverStickyHeader.builder({
    Key? key,
    required SliverStickyHeaderWidgetBuilder builder,
    required Widget sliver,
    bool overlapsContent = false,
    bool sticky = true,
    bool reverse = false,
    StickyHeaderController? controller,
  }) {
    return SliverStickyHeader(
      key: key,
      header: ValueLayoutBuilder<BoxValueConstraints<SliverStickyHeaderState>>(
        builder: (context, constraints) {
          final SliverStickyHeaderState state = constraints.value.value;
          return builder(context, state);
        },
      ),
      sliver: sliver,
      overlapsContent: overlapsContent,
      sticky: sticky,
      reverse: reverse,
      controller: controller,
    );
  }

  /// The header [Widget].
  final Widget? header;

  /// The single sliver child.
  final Widget sliver;

  /// If true, the [header] will paint over its [sliver] instead of
  /// taking layout space.
  final bool overlapsContent;

  /// If false, the [header] will scroll with the content and never pin.
  final bool sticky;

  /// Mirrors the behavior so that the header sticks to the trailing
  /// edge of the viewport (bottom/right).
  final bool reverse;

  /// Optional controller to expose the current sticky header scroll offset.
  final StickyHeaderController? controller;

  @override
  RenderSliverStickyHeader createRenderObject(BuildContext context) {
    return RenderSliverStickyHeader(
      overlapsContent: overlapsContent,
      sticky: sticky,
      reverse: reverse,
      controller: controller,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSliverStickyHeader renderObject,
  ) {
    renderObject
      ..overlapsContent = overlapsContent
      ..sticky = sticky
      ..reverse = reverse
      ..controller = controller;
  }

  @override
  _SliverStickyHeaderElement createElement() => _SliverStickyHeaderElement(this);
}

enum _SliverStickyHeaderSlot { header, sliver }

class _SliverStickyHeaderElement extends RenderObjectElement {
  _SliverStickyHeaderElement(SliverStickyHeader widget) : super(widget);

  Element? _header;
  Element? _sliver;

  @override
  SliverStickyHeader get widget => super.widget as SliverStickyHeader;

  @override
  RenderSliverStickyHeader get renderObject => super.renderObject as RenderSliverStickyHeader;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _header = updateChild(_header, widget.header, _SliverStickyHeaderSlot.header);
    _sliver = updateChild(_sliver, widget.sliver, _SliverStickyHeaderSlot.sliver);
  }

  @override
  void update(covariant SliverStickyHeader newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _header = updateChild(_header, widget.header, _SliverStickyHeaderSlot.header);
    _sliver = updateChild(_sliver, widget.sliver, _SliverStickyHeaderSlot.sliver);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    final Element? header = _header;
    if (header != null) visitor(header);
    final Element? sliver = _sliver;
    if (sliver != null) visitor(sliver);
  }

  @override
  void forgetChild(Element child) {
    assert(child == _header || child == _sliver);
    if (_header == child) _header = null;
    if (_sliver == child) _sliver = null;
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    assert(slot is _SliverStickyHeaderSlot);
    if (slot == _SliverStickyHeaderSlot.header) {
      renderObject.header = child as RenderBox;
    } else {
      renderObject.child = child as RenderSliver;
    }
  }

  @override
  void moveRenderObjectChild(
    RenderObject child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    // No reordering.
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    if (renderObject.header == child) {
      renderObject.header = null;
    } else if (renderObject.child == child) {
      renderObject.child = null;
    }
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:value_layout_builder/value_layout_builder.dart';

/// The render object that implements the sticky behavior.
class RenderSliverStickyHeader extends RenderSliver with RenderSliverHelpers {
  RenderSliverStickyHeader({
    RenderBox? header,
    RenderSliver? child,
    bool overlapsContent = false,
    bool sticky = true,
    bool reverse = false,
    StickyHeaderController? controller,
  })  : _overlapsContent = overlapsContent,
        _sticky = sticky,
        _reverse = reverse,
        _controller = controller {
    this.header = header;
    this.child = child;
  }

  // ---- Configuration ----
  bool _overlapsContent;
  bool get overlapsContent => _overlapsContent;
  set overlapsContent(bool value) {
    if (_overlapsContent == value) return;
    _overlapsContent = value;
    markNeedsLayout();
  }

  bool _sticky;
  bool get sticky => _sticky;
  set sticky(bool value) {
    if (_sticky == value) return;
    _sticky = value;
    markNeedsLayout();
  }

  bool _reverse;
  bool get reverse => _reverse;
  set reverse(bool value) {
    if (_reverse == value) return;
    _reverse = value;
    markNeedsLayout();
  }

  StickyHeaderController? _controller;
  StickyHeaderController? get controller => _controller;
  set controller(StickyHeaderController? value) {
    if (identical(_controller, value)) return;
    if (_controller != null && value != null) {
      value.stickyHeaderScrollOffset = _controller!.stickyHeaderScrollOffset;
    }
    _controller = value;
  }

  // ---- Children ----

  RenderBox? _header;
  RenderBox? get header => _header;
  set header(RenderBox? value) {
    if (_header != null) dropChild(_header!);
    _header = value;
    if (_header != null) adoptChild(_header!);
  }

  RenderSliver? _child;
  RenderSliver? get child => _child;
  set child(RenderSliver? value) {
    if (_child != null) dropChild(_child!);
    _child = value;
    if (_child != null) adoptChild(_child!);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _oldState = null; // Force first layout to propagate state.
  }

  @override
  void redepthChildren() {
    if (_header != null) redepthChild(_header!);
    if (_child != null) redepthChild(_child!);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_header != null) visitor(_header!);
    if (_child != null) visitor(_child!);
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalParentData) {
      child.parentData = SliverPhysicalParentData();
    }
  }

  // ---- Internal state ----

  SliverStickyHeaderState? _oldState;
  double _headerExtent = 0.0; // along main axis
  bool _isPinned = false;

  double _computeHeaderExtent() {
    if (_header == null) return 0.0;
    switch (constraints.axis) {
      case Axis.vertical:
        return _header!.size.height.isFinite ? _header!.size.height : 0.0;
      case Axis.horizontal:
        return _header!.size.width.isFinite ? _header!.size.width : 0.0;
    }
  }

  @override
  void performLayout() {
    if (_header == null && _child == null) {
      geometry = SliverGeometry.zero;
      return;
    }

    // Paint direction may be flipped for reverse; layout stays in original coord system.
    final AxisDirection paintAxisDirection =
        _reverse ? flipAxisDirection(constraints.axisDirection) : constraints.axisDirection;

    // ---- Layout header ----
    if (_header != null) {
      // Convert sliver constraints to box constraints: full cross axis, unconstrained main axis.
      final BoxConstraints headerBox = constraints.asBoxConstraints(crossAxisExtent: constraints.crossAxisExtent);
      _header!.layout(
        BoxValueConstraints<SliverStickyHeaderState>(
          value: _oldState ?? const SliverStickyHeaderState(0.0, false),
          constraints: headerBox,
        ),
        parentUsesSize: true,
      );
      _headerExtent = _computeHeaderExtent();
      if (!_headerExtent.isFinite || _headerExtent.isNaN) {
        _headerExtent = 0.0;
      }
    } else {
      _headerExtent = 0.0;
    }

    // ---- Child constraints (shift coord system by header "before" extent) ----
    final double beforeExtent = overlapsContent ? 0.0 : _headerExtent;

    // How much of the header occupies paint today (used for remainingPaintExtent shift).
    final double beforePaint = calculatePaintOffset(constraints, from: 0.0, to: beforeExtent);

    // Effective scroll offset for the child (never negative).
    final double childScrollOffset = math.max(0.0, constraints.scrollOffset - beforeExtent);

    // Cache origin must move forward by the same amount as the child coord shift.
    final double childCacheOrigin = math.min(0.0, constraints.cacheOrigin + beforeExtent);

    // Remaining paint extent reduced by the paint-space taken by the header before the child.
    final double childRemainingPaintExtent = math.max(0.0, constraints.remainingPaintExtent - beforePaint);

    final SliverConstraints childConstraints = constraints.copyWith(
      scrollOffset: childScrollOffset,
      cacheOrigin: childCacheOrigin,
      remainingPaintExtent: childRemainingPaintExtent,
      precedingScrollExtent: constraints.precedingScrollExtent + beforeExtent,
    );

    // ---- Layout child ----
    if (_child != null) {
      _child!.layout(childConstraints, parentUsesSize: true);
    }

    final SliverGeometry childGeometry = _child?.geometry ?? SliverGeometry.zero;
    final double childScrollExtent = childGeometry.scrollExtent;
    final double childPaintExtent = childGeometry.paintExtent;

    // ---- Sticky header positioning ----

    // Base position along the "leading" side (for DOWN/RIGHT). We'll mirror later for UP/LEFT.
    double headerPosition;
    if (!_sticky) {
      headerPosition = -constraints.scrollOffset;
    } else {
      // Header pins to the edge (leading for DOWN/RIGHT) and gets pushed by the child.
      // Equivalent to: move with scroll until 0, then stay pinned until pushed by end of child.
      final double maxPinPush = childScrollExtent - childScrollOffset - (overlapsContent ? _headerExtent : 0.0);
      headerPosition = math.min(constraints.overlap, maxPinPush);
    }

    _isPinned = _sticky &&
        ((constraints.scrollOffset + constraints.overlap) > 0.0 ||
            constraints.remainingPaintExtent == constraints.viewportMainAxisExtent);

    // ---- Builder state (only if header is ValueLayoutBuilder) ----
    final double headerScrollRatio =
        _headerExtent > 0.0 ? ((headerPosition - constraints.overlap).abs() / _headerExtent) : 0.0;
    final double ratioClamped = headerScrollRatio.isFinite ? headerScrollRatio.clamp(0.0, 1.0) : 0.0;

    if (_header is RenderConstrainedLayoutBuilder<BoxValueConstraints<SliverStickyHeaderState>, RenderBox>) {
      final SliverStickyHeaderState newState = SliverStickyHeaderState(ratioClamped, _isPinned);
      if (_oldState == null ||
          _oldState!.scrollPercentage != newState.scrollPercentage ||
          _oldState!.isPinned != newState.isPinned) {
        _oldState = newState;
        final BoxConstraints headerBox = constraints.asBoxConstraints(crossAxisExtent: constraints.crossAxisExtent);
        _header!.layout(
          BoxValueConstraints<SliverStickyHeaderState>(
            value: newState,
            constraints: headerBox,
          ),
          parentUsesSize: true,
        );
        _headerExtent = _computeHeaderExtent();
      }
    }

    // ---- Paint offsets for header/child ----

    final SliverPhysicalParentData? childParentData = _child?.parentData as SliverPhysicalParentData?;
    final SliverPhysicalParentData? headerParentData = _header?.parentData as SliverPhysicalParentData?;

    // Reserve paint space in front of the child only when header doesn't overlap.
    final double reservedPaintBefore = overlapsContent ? 0.0 : beforePaint;

    switch (paintAxisDirection) {
      case AxisDirection.down:
        if (childParentData != null) {
          childParentData.paintOffset = Offset(0.0, reservedPaintBefore);
        }
        if (headerParentData != null) {
          headerParentData.paintOffset = Offset(0.0, headerPosition);
        }
        break;
      case AxisDirection.up:
        if (childParentData != null) {
          childParentData.paintOffset =
              Offset(0.0, constraints.remainingPaintExtent - childPaintExtent - reservedPaintBefore);
        }
        if (headerParentData != null) {
          headerParentData.paintOffset = Offset(0.0, constraints.remainingPaintExtent - _headerExtent - headerPosition);
        }
        break;
      case AxisDirection.right:
        if (childParentData != null) {
          childParentData.paintOffset = Offset(reservedPaintBefore, 0.0);
        }
        if (headerParentData != null) {
          headerParentData.paintOffset = Offset(headerPosition, 0.0);
        }
        break;
      case AxisDirection.left:
        if (childParentData != null) {
          childParentData.paintOffset = Offset(
            constraints.remainingPaintExtent - childPaintExtent - reservedPaintBefore,
            0.0,
          );
        }
        if (headerParentData != null) {
          headerParentData.paintOffset = Offset(
            constraints.remainingPaintExtent - _headerExtent - headerPosition,
            0.0,
          );
        }
        break;
    }

    // ---- Geometry ----

    final double headerPaintExtent = calculatePaintOffset(constraints, from: 0.0, to: _headerExtent);
    final double paintExtent = math.min(
      constraints.remainingPaintExtent,
      childPaintExtent + headerPaintExtent,
    );
    final double maxPaintExtent = childGeometry.maxPaintExtent + _headerExtent;

    geometry = SliverGeometry(
      scrollExtent: childScrollExtent + (overlapsContent ? 0.0 : _headerExtent),
      paintExtent: paintExtent,
      maxPaintExtent: maxPaintExtent,
      paintOrigin: 0.0,
      hitTestExtent: math.max(paintExtent, 0.0),
      hasVisualOverflow: childGeometry.hasVisualOverflow ||
          (constraints.scrollOffset > 0.0) ||
          (constraints.remainingPaintExtent < constraints.viewportMainAxisExtent),
    );

    // ---- Controller notify (optional) ----
    if (_isPinned && ratioClamped <= 1.0) {
      _controller?.stickyHeaderScrollOffset = constraints.precedingScrollExtent;
    }
  }

  @override
  double? childScrollOffset(RenderObject child) {
    assert(child.parent == this);
    if (child == _child) {
      // Child begins right after the header when the header occupies layout extent.
      return overlapsContent ? 0.0 : _headerExtent;
    }
    return super.childScrollOffset(child);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final SliverPhysicalParentData parentData = child.parentData as SliverPhysicalParentData;
    parentData.applyPaintTransform(transform);
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    bool hit = false;

    // Test header first so it captures gestures while pinned/overlapping.
    if (_header != null && _header!.hasSize) {
      final SliverPhysicalParentData parentData = _header!.parentData as SliverPhysicalParentData;
      final Offset paintOffset = parentData.paintOffset;
      final double headerMainDelta = constraints.axis == Axis.vertical ? paintOffset.dy : paintOffset.dx;
      final double headerCrossDelta = constraints.axis == Axis.vertical ? paintOffset.dx : paintOffset.dy;

      hit = hitTestBoxChild(
        BoxHitTestResult.wrap(result),
        _header!,
        mainAxisPosition: mainAxisPosition - headerMainDelta,
        crossAxisPosition: crossAxisPosition - headerCrossDelta,
      );
      if (hit) return true;
    }

    if (_child != null) {
      hit = _child!.hitTest(
            result,
            mainAxisPosition: mainAxisPosition,
            crossAxisPosition: crossAxisPosition,
          ) ||
          hit;
    }

    return hit;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (geometry == null || !geometry!.visible) return;

    if (_child != null && _child!.geometry!.visible) {
      final SliverPhysicalParentData childParentData = _child!.parentData as SliverPhysicalParentData;
      context.paintChild(_child!, offset + childParentData.paintOffset);
    }

    if (_header != null) {
      final SliverPhysicalParentData headerParentData = _header!.parentData as SliverPhysicalParentData;
      context.paintChild(_header!, offset + headerParentData.paintOffset);
    }
  }
}

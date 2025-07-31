import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:value_layout_builder/value_layout_builder.dart';

/// A sliver with a [RenderBox] as header and a [RenderSliver] as child.
///
/// The [header] stays pinned when it hits the start of the viewport until
/// the [child] scrolls off the viewport.
class RenderSliverStickyHeader extends RenderSliver with RenderSliverHelpers {
  RenderSliverStickyHeader({
    RenderObject? header,
    RenderObject? footer,
    RenderSliver? child,
    bool overlapsContent = false,
    bool overlapsFooterContent = false,
    bool sticky = true,
    bool stickyFooter = true,
    StickyHeaderController? controller,
  })  : _overlapsContent = overlapsContent,
        _overlapsFooterContent = overlapsFooterContent,
        _sticky = sticky,
        _stickyFooter = stickyFooter,
        _controller = controller {
    this.header = header as RenderBox?;
    this.footer = footer as RenderBox?;
    this.child = child;
  }

  SliverStickyHeaderState? _oldState;
  double? _headerExtent;
  late bool _isPinned;

  bool get overlapsContent => _overlapsContent;
  bool _overlapsContent;

  set overlapsContent(bool value) {
    if (_overlapsContent == value) return;
    _overlapsContent = value;
    markNeedsLayout();
  }

  bool get overlapsFooterContent => _overlapsFooterContent;
  bool _overlapsFooterContent;

  set overlapsFooterContent(bool value) {
    if (_overlapsFooterContent == value) return;
    _overlapsFooterContent = value;
    markNeedsLayout();
  }

  bool get sticky => _sticky;
  bool _sticky;

  set sticky(bool value) {
    if (_sticky == value) return;
    _sticky = value;
    markNeedsLayout();
  }

  StickyHeaderController? get controller => _controller;
  StickyHeaderController? _controller;

  set controller(StickyHeaderController? value) {
    if (_controller == value) return;
    if (_controller != null && value != null) {
      // We copy the state of the old controller.
      value.stickyHeaderScrollOffset = _controller!.stickyHeaderScrollOffset;
    }
    _controller = value;
  }

  /// The render object's header
  RenderBox? get header => _header;
  RenderBox? _header;

  set header(RenderBox? value) {
    if (_header != null) dropChild(_header!);
    _header = value;
    if (_header != null) adoptChild(_header!);
  }

  // Добавить переменные для footer
  RenderBox? get footer => _footer;
  RenderBox? _footer;
  double? _footerExtent;
  bool _isFooterPinned = false;

  bool get stickyFooter => _stickyFooter;
  bool _stickyFooter;

  set stickyFooter(bool value) {
    if (_stickyFooter == value) return;
    _stickyFooter = value;
    markNeedsLayout();
  }

  set footer(RenderBox? value) {
    if (_footer != null) dropChild(_footer!);
    _footer = value;
    if (_footer != null) adoptChild(_footer!);
  }

  /// The render object's unique child
  RenderSliver? get child => _child;
  RenderSliver? _child;

  set child(RenderSliver? value) {
    if (_child != null) dropChild(_child!);
    _child = value;
    if (_child != null) adoptChild(_child!);
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalParentData) child.parentData = SliverPhysicalParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_header != null) _header!.attach(owner);
    if (_child != null) _child!.attach(owner);
    if (_footer != null) _footer!.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    if (_header != null) _header!.detach();
    if (_child != null) _child!.detach();
    if (_footer != null) _footer!.detach();
  }

  @override
  void redepthChildren() {
    if (_header != null) redepthChild(_header!);
    if (_child != null) redepthChild(_child!);
    if (_footer != null) redepthChild(_footer!);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_header != null) visitor(_header!);
    if (_child != null) visitor(_child!);
    if (_footer != null) visitor(_footer!);
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    List<DiagnosticsNode> result = <DiagnosticsNode>[];
    if (header != null) {
      result.add(header!.toDiagnosticsNode(name: 'header'));
    }
    if (child != null) {
      result.add(child!.toDiagnosticsNode(name: 'child'));
    }
    if (footer != null) {
      result.add(footer!.toDiagnosticsNode(name: 'footer'));
    }
    return result;
  }

  double computeHeaderExtent() {
    if (header == null) return 0.0;
    assert(header!.hasSize);
    switch (constraints.axis) {
      case Axis.vertical:
        return header!.size.height;
      case Axis.horizontal:
        return header!.size.width;
    }
  }

  // Метод для вычисления размера footer
  double computeFooterExtent() {
    if (footer == null) return 0.0;
    assert(footer!.hasSize);
    switch (constraints.axis) {
      case Axis.vertical:
        return footer!.size.height;
      case Axis.horizontal:
        return footer!.size.width;
    }
  }

  double? get headerLogicalExtent => overlapsContent ? 0.0 : _headerExtent;
  double? get footerLogicalExtent => overlapsFooterContent ? 0.0 : _footerExtent;

// Dart
  @override
  void performLayout() {
    if (header == null && child == null && footer == null) {
      geometry = SliverGeometry.zero;
      return;
    }

    AxisDirection axisDirection =
        applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection);

    // Layout header
    if (header != null) {
      header!.layout(
        BoxValueConstraints<SliverStickyHeaderState>(
          value: _oldState ?? SliverStickyHeaderState(0.0, false),
          constraints: constraints.asBoxConstraints(),
        ),
        parentUsesSize: true,
      );
      _headerExtent = computeHeaderExtent();
    }
    double headerExtent = headerLogicalExtent!; // учитывает overlapsContent
    final double headerPaintExtent = calculatePaintOffset(constraints, from: 0.0, to: headerExtent);
    final double headerCacheExtent = calculateCacheOffset(constraints, from: 0.0, to: headerExtent);

    // Если child отсутствует, задаём геометрию исходя из header
    if (child == null) {
      geometry = SliverGeometry(
        scrollExtent: headerExtent,
        maxPaintExtent: headerExtent,
        paintExtent: headerPaintExtent,
        cacheExtent: headerCacheExtent,
        hitTestExtent: headerPaintExtent,
        hasVisualOverflow: headerExtent > constraints.remainingPaintExtent || constraints.scrollOffset > 0.0,
      );
    } else {
      // Layout child с поправкой на header
      child!.layout(
        constraints.copyWith(
          scrollOffset: math.max(0.0, constraints.scrollOffset - headerExtent),
          cacheOrigin: math.min(0.0, constraints.cacheOrigin + headerExtent),
          overlap: math.min(headerExtent, constraints.scrollOffset) + (sticky ? constraints.overlap : 0),
          remainingPaintExtent: constraints.remainingPaintExtent - headerPaintExtent,
          remainingCacheExtent: constraints.remainingCacheExtent - headerCacheExtent,
        ),
        parentUsesSize: true,
      );
      final SliverGeometry childLayoutGeometry = child!.geometry!;
      if (childLayoutGeometry.scrollOffsetCorrection != null) {
        geometry = SliverGeometry(scrollOffsetCorrection: childLayoutGeometry.scrollOffsetCorrection);
        return;
      }

      double totalScrollExtent = headerExtent + childLayoutGeometry.scrollExtent;
      double additionalFooterExtent = 0.0;

      // Если задан footer, выполняем его layout и рассчитываем позицию
      if (footer != null) {
        footer!.layout(
          constraints.asBoxConstraints(),
          parentUsesSize: true,
        );
        _footerExtent = computeFooterExtent();
        totalScrollExtent += overlapsFooterContent ? 0.0 : _footerExtent!;

        // Определяем, закреплён ли footer
        _isFooterPinned =
            stickyFooter && (constraints.scrollOffset + constraints.viewportMainAxisExtent > totalScrollExtent);

        // Вычисляем позицию футера с учётом overlapsFooterContent
        double footerPosition = _isFooterPinned
            ? constraints.viewportMainAxisExtent - (overlapsFooterContent ? 0.0 : _footerExtent!)
            : headerExtent + (childLayoutGeometry.paintExtent) - (overlapsFooterContent ? _footerExtent! : 0.0);

        final SliverPhysicalParentData footerParentData = footer!.parentData as SliverPhysicalParentData;
        switch (constraints.axisDirection) {
          case AxisDirection.down:
            footerParentData.paintOffset = Offset(0.0, footerPosition);
            break;
          case AxisDirection.up:
            footerParentData.paintOffset = Offset(0.0, geometry?.paintExtent ?? 0.0 - footerPosition - _footerExtent!);
            break;
          case AxisDirection.right:
            footerParentData.paintOffset = Offset(footerPosition, 0.0);
            break;
          case AxisDirection.left:
            footerParentData.paintOffset =
                Offset((geometry?.paintExtent ?? 0.0) - footerPosition - _footerExtent!, 0.0);
            break;
        }
        additionalFooterExtent = _isFooterPinned ? _footerExtent! : 0.0;
      }

      double paintExtent = math.min(
        headerPaintExtent + childLayoutGeometry.paintExtent + additionalFooterExtent,
        constraints.remainingPaintExtent,
      );

      // Итоговая геометрия с учётом footer (если он есть)
      geometry = SliverGeometry(
        scrollExtent: headerExtent +
            childLayoutGeometry.scrollExtent +
            (footer != null ? (overlapsFooterContent ? 0.0 : _footerExtent!) : 0.0),
        maxScrollObstructionExtent: sticky ? headerPaintExtent : 0,
        paintExtent: paintExtent,
        layoutExtent: math.min(headerPaintExtent + childLayoutGeometry.layoutExtent, paintExtent),
        cacheExtent: math.min(headerCacheExtent + childLayoutGeometry.cacheExtent, constraints.remainingCacheExtent),
        maxPaintExtent: headerExtent + childLayoutGeometry.maxPaintExtent,
        hitTestExtent: math.max(
            headerPaintExtent + childLayoutGeometry.paintExtent, headerPaintExtent + childLayoutGeometry.hitTestExtent),
        hasVisualOverflow: childLayoutGeometry.hasVisualOverflow,
      );
    }

    // Устанавливаем позицию для header
    if (header != null) {
      final SliverPhysicalParentData headerParentData = header!.parentData as SliverPhysicalParentData;
      final double childScrollExtent = child?.geometry?.scrollExtent ?? 0.0;
      double headerPosition = sticky
          ? math.min(constraints.overlap,
              childScrollExtent - constraints.scrollOffset - (overlapsContent ? _headerExtent! : 0.0))
          : -constraints.scrollOffset;

      _isPinned = sticky &&
          ((constraints.scrollOffset + constraints.overlap) > 0.0 ||
              constraints.remainingPaintExtent == constraints.viewportMainAxisExtent);

      switch (axisDirection) {
        case AxisDirection.up:
          headerParentData.paintOffset = Offset(0.0, geometry!.paintExtent - headerPosition - _headerExtent!);
          break;
        case AxisDirection.down:
          headerParentData.paintOffset = Offset(0.0, headerPosition);
          break;
        case AxisDirection.left:
          headerParentData.paintOffset = Offset(geometry!.paintExtent - headerPosition - _headerExtent!, 0.0);
          break;
        case AxisDirection.right:
          headerParentData.paintOffset = Offset(headerPosition, 0.0);
          break;
      }
    }
  }

  @override
  bool hitTestChildren(SliverHitTestResult result,
      {required double mainAxisPosition, required double crossAxisPosition}) {
    assert(geometry!.hitTestExtent > 0.0);
    final double childScrollExtent = child?.geometry?.scrollExtent ?? 0.0;
    final double headerPosition = sticky
        ? math.min(constraints.overlap,
            childScrollExtent - constraints.scrollOffset - (overlapsContent ? _headerExtent! : 0.0))
        : -constraints.scrollOffset;

    if (header != null && (mainAxisPosition - headerPosition) <= _headerExtent!) {
      final didHitHeader = hitTestBoxChild(
        BoxHitTestResult.wrap(SliverHitTestResult.wrap(result)),
        header!,
        mainAxisPosition: mainAxisPosition - childMainAxisPosition(header) - headerPosition,
        crossAxisPosition: crossAxisPosition,
      );

      return didHitHeader ||
          (_overlapsContent &&
              child != null &&
              child!.geometry!.hitTestExtent > 0.0 &&
              child!.hitTest(result,
                  mainAxisPosition: mainAxisPosition - childMainAxisPosition(child),
                  crossAxisPosition: crossAxisPosition));
    } else if (child != null && child!.geometry!.hitTestExtent > 0.0) {
      return child!.hitTest(result,
          mainAxisPosition: mainAxisPosition - childMainAxisPosition(child), crossAxisPosition: crossAxisPosition);
    }

    // Добавляем проверку попадания в footer
    if (footer != null) {
      final SliverPhysicalParentData footerParentData = footer!.parentData as SliverPhysicalParentData;
      final double footerTop = footerParentData.paintOffset.dy;

      if (mainAxisPosition >= footerTop && mainAxisPosition <= footerTop + _footerExtent!) {
        final bool hitFooter = hitTestBoxChild(
          BoxHitTestResult.wrap(SliverHitTestResult.wrap(result)),
          footer!,
          mainAxisPosition: mainAxisPosition - footerTop,
          crossAxisPosition: crossAxisPosition,
        );

        return hitFooter ||
            (_overlapsFooterContent &&
                child != null &&
                child!.geometry!.hitTestExtent > 0.0 &&
                child!.hitTest(result,
                    mainAxisPosition: mainAxisPosition - childMainAxisPosition(child),
                    crossAxisPosition: crossAxisPosition));
      }
    }

    return false;
  }

  @override
  double childMainAxisPosition(RenderObject? child) {
    if (child == header) {
      return _isPinned ? 0.0 : -(constraints.scrollOffset + constraints.overlap);
    }
    if (child == this.child) {
      return calculatePaintOffset(constraints, from: 0.0, to: headerLogicalExtent!);
    }
    if (child == footer) {
      final double childPaintExtent = this.child?.geometry?.paintExtent ?? 0.0;
      return calculatePaintOffset(constraints, from: 0.0, to: headerLogicalExtent!) + childPaintExtent;
    }
    return 0.0;
  }

  @override
  double? childScrollOffset(RenderObject child) {
    assert(child.parent == this);
    if (child == this.child) {
      return _headerExtent;
    } else if (child == footer) {
      return (_headerExtent ?? 0.0) + (this.child?.geometry?.scrollExtent ?? 0.0);
    }
    return super.childScrollOffset(child);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final SliverPhysicalParentData childParentData = child.parentData as SliverPhysicalParentData;
    childParentData.applyPaintTransform(transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (geometry!.visible) {
      if (child != null && child!.geometry!.visible) {
        final SliverPhysicalParentData childParentData = child!.parentData as SliverPhysicalParentData;
        context.paintChild(child!, offset + childParentData.paintOffset);
      }

      // The header must be drawn over the sliver.
      if (header != null) {
        final SliverPhysicalParentData headerParentData = header!.parentData as SliverPhysicalParentData;
        context.paintChild(header!, offset + headerParentData.paintOffset);
      }

      // Добавляем отрисовку для footer
      if (footer != null) {
        final SliverPhysicalParentData footerParentData = footer!.parentData as SliverPhysicalParentData;
        context.paintChild(footer!, offset + footerParentData.paintOffset);
      }
    }
  }
}

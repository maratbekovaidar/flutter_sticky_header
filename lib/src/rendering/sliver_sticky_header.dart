import 'dart:math' as math; // Импорт библиотеки для математических операций.

import 'package:flutter/material.dart'; // Импорт основных виджетов Flutter.
import 'package:flutter/rendering.dart'; // Импорт для работы с рендерингом.
import 'package:flutter_sticky_header/flutter_sticky_header.dart'; // Импорт текущего пакета.
import 'package:value_layout_builder/value_layout_builder.dart'; // Импорт для работы с ValueLayoutBuilder.

// Класс, представляющий рендеринг sliver с закрепляемым заголовком.
class RenderSliverStickyHeader extends RenderSliver with RenderSliverHelpers {
  RenderSliverStickyHeader({
    RenderObject? header, // Рендеринг заголовка.
    RenderSliver? child, // Рендеринг дочернего sliver.
    bool overlapsContent = false, // Флаг, перекрывает ли заголовок контент.
    bool sticky = true, // Флаг, закрепляется ли заголовок.
    bool reverse = false, // Флаг, указывающий направление прокрутки.
    StickyHeaderController? controller, // Контроллер для управления заголовком.
  })  : _overlapsContent = overlapsContent,
        _sticky = sticky,
        _reverse = reverse,
        _controller = controller {
    this.header = header as RenderBox?; // Установка заголовка.
    this.child = child; // Установка дочернего sliver.
  }

  SliverStickyHeaderState? _oldState; // Состояние заголовка.
  double? _headerExtent; // Высота или ширина заголовка.
  late bool _isPinned; // Флаг, закреплен ли заголовок.

  // Геттер и сеттер для overlapsContent.
  bool get overlapsContent => _overlapsContent;
  bool _overlapsContent;

  set overlapsContent(bool value) {
    if (_overlapsContent == value) return; // Если значение не изменилось, ничего не делаем.
    _overlapsContent = value;
    markNeedsLayout(); // Помечаем, что требуется перерасчет макета.
  }

  // Геттер и сеттер для sticky.
  bool get sticky => _sticky;
  bool _sticky;

  set sticky(bool value) {
    if (_sticky == value) return; // Если значение не изменилось, ничего не делаем.
    _sticky = value;
    markNeedsLayout(); // Помечаем, что требуется перерасчет макета.
  }

  // Геттер и сеттер для reverse.
  bool get reverse => _reverse;
  bool _reverse;

  set reverse(bool value) {
    if (_reverse == value) return;
    _reverse = value;
    markNeedsLayout();
  }

  // Геттер и сеттер для controller.
  StickyHeaderController? get controller => _controller;
  StickyHeaderController? _controller;

  set controller(StickyHeaderController? value) {
    if (_controller == value) return; // Если значение не изменилось, ничего не делаем.
    if (_controller != null && value != null) {
      // Копируем состояние старого контроллера в новый.
      value.stickyHeaderScrollOffset = _controller!.stickyHeaderScrollOffset;
    }
    _controller = value;
  }

  // Геттер и сеттер для header.
  RenderBox? get header => _header;
  RenderBox? _header;

  set header(RenderBox? value) {
    if (_header != null) dropChild(_header!); // Удаляем старый заголовок.
    _header = value;
    if (_header != null) adoptChild(_header!); // Присоединяем новый заголовок.
  }

  // Геттер и сеттер для child.
  RenderSliver? get child => _child;
  RenderSliver? _child;

  set child(RenderSliver? value) {
    if (_child != null) dropChild(_child!); // Удаляем старый дочерний sliver.
    _child = value;
    if (_child != null) adoptChild(_child!); // Присоединяем новый дочерний sliver.
  }

  @override
  void setupParentData(RenderObject child) {
    // Устанавливаем данные родителя для дочернего объекта.
    if (child.parentData is! SliverPhysicalParentData) child.parentData = SliverPhysicalParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    // Присоединяем рендер-объект к дереву.
    super.attach(owner);
    if (_header != null) _header!.attach(owner);
    if (_child != null) _child!.attach(owner);
  }

  @override
  void detach() {
    // Отсоединяем рендер-объект от дерева.
    super.detach();
    if (_header != null) _header!.detach();
    if (_child != null) _child!.detach();
  }

  @override
  void redepthChildren() {
    // Перемещаем дочерние элементы на новый уровень глубины.
    if (_header != null) redepthChild(_header!);
    if (_child != null) redepthChild(_child!);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    // Посещаем дочерние элементы.
    if (_header != null) visitor(_header!);
    if (_child != null) visitor(_child!);
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    // Описание дочерних элементов для отладки.
    List<DiagnosticsNode> result = <DiagnosticsNode>[];
    if (header != null) {
      result.add(header!.toDiagnosticsNode(name: 'header'));
    }
    if (child != null) {
      result.add(child!.toDiagnosticsNode(name: 'child'));
    }
    return result;
  }

  double computeHeaderExtent() {
    // Вычисляем размер заголовка.
    if (header == null) return 0.0;
    assert(header!.hasSize);
    switch (constraints.axis) {
      case Axis.vertical:
        return header!.size.height; // Высота для вертикальной оси.
      case Axis.horizontal:
        return header!.size.width; // Ширина для горизонтальной оси.
    }
  }

  double? get headerLogicalExtent => overlapsContent ? 0.0 : _headerExtent;

  @override
  void performLayout() {
    // Основной метод для расчета макета.

    // Если заголовок и дочерний элемент отсутствуют, ничего не отображаем.
    if (header == null && child == null) {
      geometry = SliverGeometry.zero; // Устанавливаем пустую геометрию.
      return;
    }

    // Определяем направление оси с учетом направления роста.
    AxisDirection axisDirection =
        applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection);
    print('axisDirection: $axisDirection'); // Отладочный вывод направления оси.
    // Если заголовок существует, выполняем его макет.
    if (header != null) {
      header!.layout(
        // Передаем ограничения для заголовка.
        BoxValueConstraints<SliverStickyHeaderState>(
          value: _oldState ?? SliverStickyHeaderState(0.0, false), // Состояние заголовка.
          constraints: constraints.asBoxConstraints(), // Преобразуем ограничения в BoxConstraints.
        ),
        parentUsesSize: true, // Указываем, что родитель использует размер заголовка.
      );
      _headerExtent = computeHeaderExtent(); // Вычисляем размер заголовка.
    }

    // Вычисляем логическую высоту заголовка.
    double headerExtent = headerLogicalExtent!;
    // Вычисляем, сколько пространства заголовок занимает для рисования.
    final double headerPaintExtent = calculatePaintOffset(constraints, from: 0.0, to: headerExtent);
    // Вычисляем, сколько пространства заголовок занимает для кэширования.
    final double headerCacheExtent = calculateCacheOffset(constraints, from: 0.0, to: headerExtent);

    // Если дочерний элемент отсутствует, создаем геометрию только для заголовка.
    if (child == null) {
      geometry = SliverGeometry(
          scrollExtent: headerExtent, // Общая высота для прокрутки.
          maxPaintExtent: headerExtent, // Максимальная высота для рисования.
          paintExtent: headerPaintExtent, // Высота, которая будет нарисована.
          cacheExtent: headerCacheExtent, // Высота, которая будет закэширована.
          hitTestExtent: headerPaintExtent, // Высота для обработки событий.
          hasVisualOverflow: headerExtent > constraints.remainingPaintExtent ||
              constraints.scrollOffset > 0.0); // Проверяем, есть ли переполнение.
    } else {
      // Выполняем макет дочернего элемента с обновленными ограничениями.
      child!.layout(
        constraints.copyWith(
          scrollOffset: math.max(
              0.0, constraints.scrollOffset - headerExtent), // Уменьшаем смещение прокрутки на высоту заголовка.
          cacheOrigin: math.min(0.0, constraints.cacheOrigin + headerExtent), // Обновляем начало кэша.
          overlap: math.min(headerExtent, constraints.scrollOffset) +
              (sticky ? constraints.overlap : 0), // Учитываем перекрытие.
          remainingPaintExtent:
              constraints.remainingPaintExtent - headerPaintExtent, // Оставшееся пространство для рисования.
          remainingCacheExtent:
              constraints.remainingCacheExtent - headerCacheExtent, // Оставшееся пространство для кэширования.
        ),
        parentUsesSize: true, // Указываем, что родитель использует размер дочернего элемента.
      );

      // Получаем геометрию дочернего элемента.
      final SliverGeometry childLayoutGeometry = child!.geometry!;
      // Если дочерний элемент требует корректировки смещения прокрутки, применяем ее.
      if (childLayoutGeometry.scrollOffsetCorrection != null) {
        geometry = SliverGeometry(
          scrollOffsetCorrection: childLayoutGeometry.scrollOffsetCorrection,
        );
        return;
      }

      // Вычисляем общую высоту для рисования, включая заголовок и дочерний элемент.
      final double paintExtent = math.min(
        headerPaintExtent + math.max(childLayoutGeometry.paintExtent, childLayoutGeometry.layoutExtent),
        constraints.remainingPaintExtent,
      );

      // Устанавливаем геометрию для текущего sliver.
      geometry = SliverGeometry(
        scrollExtent: headerExtent + childLayoutGeometry.scrollExtent, // Общая высота для прокрутки.
        maxScrollObstructionExtent: sticky ? headerPaintExtent : 0, // Максимальная высота, блокирующая прокрутку.
        paintExtent: paintExtent, // Высота, которая будет нарисована.
        layoutExtent: math.min(
            headerPaintExtent + childLayoutGeometry.layoutExtent, paintExtent), // Высота, используемая для макета.
        cacheExtent: math.min(headerCacheExtent + childLayoutGeometry.cacheExtent,
            constraints.remainingCacheExtent), // Высота, которая будет закэширована.
        maxPaintExtent: headerExtent + childLayoutGeometry.maxPaintExtent, // Максимальная высота для рисования.
        hitTestExtent: math.max(headerPaintExtent + childLayoutGeometry.paintExtent,
            headerPaintExtent + childLayoutGeometry.hitTestExtent), // Высота для обработки событий.
        hasVisualOverflow: childLayoutGeometry.hasVisualOverflow, // Проверяем, есть ли переполнение.
      );

      // Устанавливаем смещение для дочернего элемента.
      final SliverPhysicalParentData? childParentData = child!.parentData as SliverPhysicalParentData?;
      switch (axisDirection) {
        case AxisDirection.up:
          // old impl
          // childParentData!.paintOffset = Offset.zero; // Смещение для оси вверх.
          // this was working ... but maybe this is getting in the way of what we should be re-positioning
          if (_reverse)
            childParentData!.paintOffset = Offset(0.0, -headerExtent);
          else
            childParentData!.paintOffset = Offset.zero; // reverse
          break;
        case AxisDirection.right:
          childParentData!.paintOffset =
              Offset(calculatePaintOffset(constraints, from: 0.0, to: headerExtent), 0.0); // Смещение для оси вправо.
          break;
        case AxisDirection.down:
          // old impl
          // childParentData!.paintOffset =
          //     Offset(0.0, calculatePaintOffset(constraints, from: 0.0, to: headerExtent)); // Смещение для оси вниз.
          // new impl
          if (_reverse)
            childParentData!.paintOffset = Offset(0.0, -headerExtent);
          else
            childParentData!.paintOffset = Offset(0.0, calculatePaintOffset(constraints, from: 0.0, to: headerExtent));
          break;
        case AxisDirection.left:
          childParentData!.paintOffset = Offset.zero; // Смещение для оси влево.
          break;
      }
    }

    // Если заголовок существует, обновляем его позицию.
    if (header != null) {
      final SliverPhysicalParentData? headerParentData = header!.parentData as SliverPhysicalParentData?;
      final double childScrollExtent = child?.geometry?.scrollExtent ?? 0.0;
      final double headerPosition = sticky
          ? math.min(
              constraints.overlap,
              childScrollExtent -
                  constraints.scrollOffset -
                  (overlapsContent ? _headerExtent! : 0.0)) // Позиция заголовка при закреплении.
          : -constraints.scrollOffset; // Позиция заголовка без закрепления.

      // old impl
      // _isPinned = sticky &&
      //     ((constraints.scrollOffset + constraints.overlap) > 0.0 ||
      //         constraints.remainingPaintExtent ==
      //             constraints.viewportMainAxisExtent); // Проверяем, закреплен ли заголовок.
      // new impl
      // Проверяем, закреплен ли заголовок.
      _isPinned = () {
        if (!sticky) return false;
        if (_reverse)
          return (constraints.remainingPaintExtent <
              (constraints.viewportMainAxisExtent -
                  ((child!.parentData as SliverPhysicalParentData?)?.paintOffset.distance ?? 0)));
        else
          return ((constraints.scrollOffset + constraints.overlap) > 0.0 ||
              constraints.remainingPaintExtent == constraints.viewportMainAxisExtent);
      }();

      final double headerScrollRatio =
          ((headerPosition - constraints.overlap).abs() / _headerExtent!); // Вычисляем процент прокрутки заголовка.
      if (_isPinned && headerScrollRatio <= 1) {
        controller?.stickyHeaderScrollOffset =
            constraints.precedingScrollExtent; // Обновляем смещение прокрутки в контроллере.
      }

      // Если заголовок является RenderStickyHeaderLayoutBuilder, выполняем повторный макет.
      if (header is RenderConstrainedLayoutBuilder<BoxValueConstraints<SliverStickyHeaderState>, RenderBox>) {
        double headerScrollRatioClamped = headerScrollRatio.clamp(0.0, 1.0); // Ограничиваем процент прокрутки.

        SliverStickyHeaderState state =
            SliverStickyHeaderState(headerScrollRatioClamped, _isPinned); // Создаем новое состояние заголовка.
        if (_oldState != state) {
          _oldState = state; // Обновляем состояние.
          header!.layout(
            BoxValueConstraints<SliverStickyHeaderState>(
              value: _oldState!,
              constraints: constraints.asBoxConstraints(),
            ),
            parentUsesSize: true,
          );
        }
      }

      // Устанавливаем смещение для заголовка в зависимости от направления оси.
      switch (axisDirection) {
        case AxisDirection.up:
          // old impl
          // headerParentData!.paintOffset = Offset(0.0, geometry!.paintExtent - headerPosition - _headerExtent!);
          // new impl
          double headerOffset = -headerPosition - _headerExtent!;
          if (_reverse)
            headerParentData!.paintOffset = Offset(0.0,
                0.0 + (constraints.remainingPaintExtent < _headerExtent! ? (geometry!.paintExtent + headerOffset) : 0));
          else
            headerParentData!.paintOffset = Offset(0.0, geometry!.paintExtent + headerOffset);
          break;
        case AxisDirection.down:
          headerParentData!.paintOffset = Offset(0.0, headerPosition);
          break;
        case AxisDirection.left:
          headerParentData!.paintOffset = Offset(geometry!.paintExtent - headerPosition - _headerExtent!, 0.0);
          break;
        case AxisDirection.right:
          headerParentData!.paintOffset = Offset(headerPosition, 0.0);
          break;
      }
    }
  }

  @override
  bool hitTestChildren(SliverHitTestResult result,
      {required double mainAxisPosition, required double crossAxisPosition}) {
    // Проверяем, попадает ли точка в дочерние элементы.
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
    return false;
  }

  @override
  double childMainAxisPosition(RenderObject? child) {
    if (child == header) {
      if (_isPinned) return 0;
      if (!_reverse) return _isPinned ? 0.0 : -(constraints.scrollOffset + constraints.overlap);
      return (constraints.scrollOffset + constraints.overlap);
    } else if (child == this.child) {
      return calculatePaintOffset(constraints, from: 0.0, to: headerLogicalExtent!);
    }
    return 0;
  }

  @override
  double? childScrollOffset(RenderObject child) {
    // Вычисляем смещение прокрутки для дочернего элемента.
    assert(child.parent == this);
    if (child == this.child) {
      return 0;
      // if (_reverse)
      // return 0;
      //   return _headerExtent;
      // } else if (_reverse && child == this._header) {
      //   return _headerExtent;
    } else {
      return super.childScrollOffset(child);
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    // Применяем трансформацию для рисования.
    final SliverPhysicalParentData childParentData = child.parentData as SliverPhysicalParentData;
    childParentData.applyPaintTransform(transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Рисуем заголовок и дочерний элемент.
    if (geometry!.visible) {
      if (child != null && child!.geometry!.visible) {
        final SliverPhysicalParentData childParentData = child!.parentData as SliverPhysicalParentData;
        context.paintChild(child!, offset + (_reverse ? -childParentData.paintOffset : childParentData.paintOffset));
      }

      // Заголовок должен рисоваться поверх sliver.
      if (header != null) {
        final SliverPhysicalParentData headerParentData = header!.parentData as SliverPhysicalParentData;
        context.paintChild(header!, offset + headerParentData.paintOffset);
      }
    }
  }
}

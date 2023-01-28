import 'package:flutter/material.dart';
import 'component/resizer.dart';
import 'component/resizer_toggle.dart';
import '../src/data/resizer_data.dart';
import 'data/resizer_toggle_data.dart';
import '../src/data/side_menu_data.dart';
import 'data/side_menu_builder_data.dart';
import 'side_menu_body.dart';
import 'side_menu_controller.dart';
import 'side_menu_mode.dart';
import 'side_menu_position.dart';
import 'side_menu_priority.dart';
import 'side_menu_width_mixin.dart';
import 'utils/constants.dart';

/// Signature for the `builder` function which take the `SideMenuBuilderData`
/// is responsible for returning a widget which is to be rendered.
typedef SideMenuBuilder = SideMenuData Function(SideMenuBuilderData data);

class SideMenu extends StatefulWidget {
  const SideMenu({
    Key? key,
    required this.builder,
    this.controller,
    this.mode = SideMenuMode.auto,
    this.priority = SideMenuPriority.mode,
    this.position = SideMenuPosition.left,
    this.minWidth = Constants.minWidth,
    this.maxWidth = Constants.maxWidth,
    this.hasResizer = true,
    this.hasResizerToggle = true,
    this.resizerData,
    this.resizerToggleData,
    this.backgroundColor = Constants.backgroundColor,
  })  : assert(minWidth >= 0.0),
        assert(maxWidth > 0.0),
        assert(priority == SideMenuPriority.sizer ? hasResizer : true),
        assert(resizerData != null ? hasResizer : true),
        assert(resizerToggleData != null ? hasResizerToggle : true),
        super(key: key);

  /// The [builder] function which will be invoked on each widget build.
  /// The [builder] takes the `SideMenuBuilderData` and must return
  /// a [SideMenuData] that includes headers, footers, items, or custom child                                       .
  ///
  /// You must provide items or customChild.
  ///
  /// ```dart
  /// SideMenu(
  ///   builder: (data) => SideMenuData(
  ///     header: Container(
  ///     items: [
  ///       SideMenuItemData(
  ///         isSelected: true,
  ///         onTap: () {},
  ///         title: 'Item 1',
  ///         icon: Icons.home,
  ///       ),
  ///     ],
  ///     footer: const Text('Footer'),
  ///   ),
  /// ),
  /// ```dart
  final SideMenuBuilder builder;

  /// The [controller] that can be used to open, close, or toggle side menu.
  final SideMenuController? controller;

  /// The [SideMenuMode] which is auto, open or compact.
  ///
  /// In [SideMenuMode.auto], the side menu is visible when the screen is
  /// wide enough and changes to compact mode when the screen is narrow.
  ///
  /// In [SideMenuMode.compact], the side menu closed based on [minWidth] value.
  ///
  /// In [SideMenuMode.open], the side menu opens based on [maxWidth] value.
  final SideMenuMode mode;

  /// The [SideMenuPriority] which is mode or sizer.
  ///
  /// In [SideMenuPriority.mode], the side menu width change based on [mode]
  /// value.
  ///
  /// In [SideMenuPriority.sizer], the side menu width not change if user set
  /// custom size with [Resizer].
  /// meaning of custom size is size that user want
  /// and it's opposing [minWidth] and [maxWidth] values.
  ///
  /// The [SideMenuPriority.sizer] available only if [hasResizer] is true.
  final SideMenuPriority priority;

  /// The [SideMenuPosition] which is left or right.
  final SideMenuPosition position;

  /// The [minWidth] and [maxWidth] values which are used to determine the
  /// side menu width.
  ///
  /// The [minWidth] value is used to determine the side menu width in the
  /// smallest case.
  ///
  /// It's used to determine the side menu width in [SideMenuMode.open] or
  /// [SideMenuMode.auto].
  ///
  /// The [maxWidth] value is used to determine the side menu width in the
  /// largest case
  ///
  /// It's used to determine the side menu width in [SideMenuMode.compact]
  /// or [SideMenuMode.auto].
  final double minWidth, maxWidth;

  /// The [hasResizer] enable [Resizer] widget for side menu.
  /// With [Resizer] the side menu width can be customized by the user.
  final bool hasResizer;

  /// The [ResizerData] that can set custom style for a [Resizer].
  final ResizerData? resizerData;

  /// The [hasResizerToggle] enable [ResizerToggle] widget for side menu.
  /// With [ResizerToggle] button you can toggle the width of the side menu
  /// between [minWidth] or [maxWidth].
  final bool hasResizerToggle;

  /// The [resizerToggleData] that can set custom style for a [ResizerToggle].
  final ResizerToggleData? resizerToggleData;

  /// The [backgroundColor] it's used to determine the side menu background
  /// color.
  final Color backgroundColor;

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> with SideMenuWidthMixin {
  double _currentWidth = Constants.zeroWidth;

  @override
  void initState() {
    if (widget.controller != null) {
      widget.controller?.open = _openMenu;
      widget.controller?.close = _closeMenu;
      widget.controller?.toggle = _toggleMenu;
    }
    super.initState();
  }

  void _openMenu() {
    setState(() {
      _currentWidth = widget.maxWidth;
    });
  }

  void _closeMenu() {
    setState(() {
      _currentWidth = widget.minWidth;
    });
  }

  void _toggleMenu() {
    setState(() {
      _currentWidth =
          _currentWidth == widget.minWidth ? widget.maxWidth : widget.minWidth;
    });
  }

  @override
  void didUpdateWidget(covariant SideMenu oldWidget) {
    if (oldWidget.mode != widget.mode ||
        oldWidget.priority != widget.priority ||
        oldWidget.hasResizer != widget.hasResizer ||
        oldWidget.minWidth != widget.minWidth ||
        oldWidget.maxWidth != widget.maxWidth) {
      _calculateMenuWidthSize();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    _calculateMenuWidthSize();
    super.didChangeDependencies();
  }

  void _calculateMenuWidthSize() {
    _currentWidth = calculateWidthSize(
      priority: widget.priority,
      hasResizer: widget.hasResizer,
      minWidth: widget.minWidth,
      maxWidth: widget.maxWidth,
      currentWidth: _currentWidth,
      mode: widget.mode,
      deviceWidth: MediaQuery.of(context).size.width,
    );
  }

  @override
  Widget build(BuildContext context) => _createView();

  Widget _createView() {
    final size = MediaQuery.of(context).size;
    final content = _content(size);

    if (widget.hasResizer || widget.hasResizerToggle) {
      if (widget.hasResizer && widget.hasResizerToggle) {
        return _hasResizerToggle(
          child: _hasResizer(child: content),
        );
      } else if (widget.hasResizer) {
        return _hasResizer(child: content);
      } else {
        return _hasResizerToggle(child: content);
      }
    } else {
      return content;
    }
  }

  Widget _content(Size size) {
    return AnimatedContainer(
      duration: Constants.duration,
      width: _currentWidth,
      color: widget.backgroundColor,
      constraints: BoxConstraints(
        minHeight: size.height,
        maxHeight: size.height,
        minWidth: widget.minWidth,
        maxWidth: widget.maxWidth,
      ),
      child: SideMenuBody(
        isOpen: _currentWidth != widget.minWidth,
        minWidth: widget.minWidth,
        data: _builder(),
      ),
    );
  }

  SideMenuData _builder() {
    return widget.builder(SideMenuBuilderData(
      currentWidth: _currentWidth,
      minWidth: widget.minWidth,
      maxWidth: widget.maxWidth,
      isOpen: _currentWidth != widget.minWidth,
    ));
  }

  Widget _resizer() {
    return Resizer(
      data: widget.resizerData,
      onPanUpdate: (details) {
        late final double x;
        if (widget.position == SideMenuPosition.left) {
          x = details.globalPosition.dx;
        } else {
          x = MediaQuery.of(context).size.width - details.globalPosition.dx;
        }
        if (x >= widget.minWidth && x <= widget.maxWidth) {
          setState(() {
            _currentWidth = x;
          });
        } else if (x < Constants.minWidth && _currentWidth != widget.minWidth) {
          setState(() {
            _currentWidth = widget.minWidth;
          });
        } else if (x > Constants.maxWidth && _currentWidth != widget.maxWidth) {
          setState(() {
            _currentWidth = widget.maxWidth;
          });
        }
      },
    );
  }

  Widget _hasResizer({required Widget child}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.position == SideMenuPosition.right) _resizer(),
        child,
        if (widget.position == SideMenuPosition.left) _resizer(),
      ],
    );
  }

  Widget _resizerToggle() {
    return ResizerToggle(
      data: widget.resizerToggleData,
      rightArrow: _currentWidth == widget.minWidth,
      leftPosition: widget.position == SideMenuPosition.left,
      onTap: () => _toggleMenu(),
    );
  }

  Widget _hasResizerToggle({required Widget child}) {
    return Stack(
      alignment: widget.position == SideMenuPosition.left
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      children: [
        child,
        _resizerToggle(),
      ],
    );
  }
}

class SideMenuBuilderData {
  SideMenuBuilderData({
    required this.isOpen,
    required this.minWidth,
    required this.maxWidth,
    required this.currentWidth,
  });

  final bool isOpen;
  final double minWidth, maxWidth, currentWidth;

  @override
  String toString() {
    return 'SideMenuBuilderData'
        '{'
        'isOpen: $isOpen'
        'minWidth: $minWidth,'
        'maxWidth: $maxWidth,'
        'currentWidth: $currentWidth,'
        '}';
  }
}

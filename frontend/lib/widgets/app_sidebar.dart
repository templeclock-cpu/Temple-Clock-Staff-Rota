import 'package:flutter/material.dart';
import '../core/constants.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final int index;
  final int badgeCount;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.index,
    this.badgeCount = 0,
  });
}

/// Desktop sidebar with a Reddit-style collapsible "More" section.
///
/// The first [primaryCount] items are always visible at the top.
/// Remaining items sit inside a collapsible "MORE" group that the user can
/// expand / collapse with a single click — exactly like the Reddit sidebar.
class AppSidebar extends StatefulWidget {
  final int selectedIndex;
  final List<SidebarItem> items;
  final void Function(int index) onItemTap;
  final VoidCallback onSignOut;
  final String? userName;
  final String? userRole;
  final Widget? trailing;

  /// How many items are shown in the always-visible top section.
  /// Defaults to 5 (Dashboard, Rota, Timesheets, Staff, Leave).
  final int primaryCount;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onItemTap,
    required this.onSignOut,
    this.userName,
    this.userRole,
    this.trailing,
    this.primaryCount = 5,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  bool _moreExpanded = false;

  /// Auto-expand the "More" section when a secondary item is selected so the
  /// user can see the active highlight.
  @override
  void didUpdateWidget(covariant AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_moreExpanded && _isSecondarySelected) {
      setState(() => _moreExpanded = true);
    }
  }

  bool get _isSecondarySelected {
    final secondaryIndices =
        widget.items.skip(widget.primaryCount).map((e) => e.index).toSet();
    return secondaryIndices.contains(widget.selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.items.take(widget.primaryCount).toList();
    final secondary = widget.items.skip(widget.primaryCount).toList();

    return Container(
      width: 236,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F2C59), Color(0xFF0D2550)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Brand header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 28),
                  const SizedBox(width: 10),
                  const Text('Temple Clock',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3)),
                ],
              ),
            ),

            // ── User info strip ─────────────────────────────────────────
            if (widget.userName != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.teal.withValues(alpha: 0.25),
                      child: Text(
                        widget.userName!.isNotEmpty
                            ? widget.userName![0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.userName!.split(' ').first,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.userRole != null)
                            Text(widget.userRole!,
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.55),
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(color: Color(0x22FFFFFF), height: 1),

            // ── Scrollable nav area ─────────────────────────────────────
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  // ── Primary items (always visible) ────────────────────
                  ...primary.map((item) => _buildNavTile(item)),

                  // ── Divider + "MORE" header ───────────────────────────
                  if (secondary.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Divider(
                          color: Colors.white.withValues(alpha: 0.10),
                          height: 1),
                    ),
                    _buildMoreHeader(),
                    // ── Secondary items (collapsible) ───────────────────
                    AnimatedCrossFade(
                      firstChild: Column(
                        children:
                            secondary.map((item) => _buildNavTile(item)).toList(),
                      ),
                      secondChild: const SizedBox.shrink(),
                      crossFadeState: _moreExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 200),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ],
                ],
              ),
            ),

            const Divider(color: Color(0x22FFFFFF), height: 1),

            // ── Trailing widget (e.g. notification bell) ────────────────
            if (widget.trailing != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: widget.trailing!,
              ),

            // ── Sign out ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: widget.onSignOut,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.65)),
                        const SizedBox(width: 10),
                        Text('Sign Out',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color:
                                    Colors.white.withValues(alpha: 0.65))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  // ── "MORE" collapsible header (Reddit-style) ────────────────────────────
  Widget _buildMoreHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _moreExpanded = !_moreExpanded),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Text(
                  'MORE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.40),
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _moreExpanded ? 0.0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.40),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Single nav tile ─────────────────────────────────────────────────────
  Widget _buildNavTile(SidebarItem item) {
    final selected = item.index == widget.selectedIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => widget.onItemTap(item.index),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.12))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: selected
                      ? AppColors.teal
                      : Colors.white.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                if (item.badgeCount > 0) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.badgeCount > 9 ? '9+' : item.badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

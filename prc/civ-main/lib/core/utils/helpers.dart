import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class AppHelpers {
  AppHelpers._();

  // ── Date / Time ───────────────────────────────────────────────────────────
  static String formatDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  static String formatDateTime(DateTime date) =>
      DateFormat('MMM d, yyyy • h:mm a').format(date);

  static String formatTime(DateTime date) => DateFormat('h:mm a').format(date);

  static String formatDateShort(DateTime date) =>
      DateFormat('MMM d').format(date);

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24)
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return formatDate(date);
  }

  // ── Greeting ──────────────────────────────────────────────────────────────
  static String getGreeting() {
    return 'Good day,';
  }

  // ── Reference Number ──────────────────────────────────────────────────────
  static String generateRefNumber() {
    final year = DateTime.now().year;
    final seq = (DateTime.now().millisecondsSinceEpoch % 100000)
        .toString()
        .padLeft(5, '0');
    return 'CW-$year-$seq';
  }

  // ── Status Helpers ────────────────────────────────────────────────────────
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return AppColors.statusSubmitted;
      case 'pending validation':
      case 'pending':
        return AppColors.statusPending;
      case 'assigned to office':
      case 'assigned':
        return AppColors.statusAssigned;
      case 'in progress':
        return AppColors.statusInProgress;
      case 'resolved':
        return AppColors.statusResolved;
      default:
        return AppColors.textSecondary;
    }
  }

  static Color getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return AppColors.statusSubmittedBg;
      case 'pending validation':
      case 'pending':
        return AppColors.statusPendingBg;
      case 'assigned to office':
      case 'assigned':
        return AppColors.statusAssignedBg;
      case 'in progress':
        return AppColors.statusInProgressBg;
      case 'resolved':
        return AppColors.statusResolvedBg;
      default:
        return AppColors.background;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Icons.check_circle_rounded;
      case 'pending validation':
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'assigned to office':
      case 'assigned':
        return Icons.business_rounded;
      case 'in progress':
        return Icons.construction_rounded;
      case 'resolved':
        return Icons.task_alt_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  // ── Category Helpers ─────────────────────────────────────────────────────
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'infrastructure':
        return AppColors.infrastructure;
      case 'environment':
        return AppColors.environment;
      case 'others':
        return AppColors.statusSubmitted;
      default:
        return AppColors.textSecondary;
    }
  }

  static Color getCategoryBgColor(String category) {
    switch (category.toLowerCase()) {
      case 'infrastructure':
        return AppColors.infrastructureBg;
      case 'environment':
        return AppColors.environmentBg;
      case 'others':
        return AppColors.statusSubmittedBg;
      default:
        return AppColors.background;
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'infrastructure':
        return Icons.construction_rounded;
      case 'environment':
        return Icons.eco_rounded;
      case 'others':
        return Icons.more_horiz_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }

  static IconData getIssueIcon(String issue) => getConcernIcon(issue);

  static IconData getConcernIcon(String concern) {
    switch (concern.toLowerCase()) {
      // ── Infrastructure concerns ──────────────────────────────────────────
      case 'road repair':
        return Icons.add_road_rounded;
      case 'road graveling':
      case 'road gravelling': // legacy spelling
        return Icons.terrain_rounded;
      case 'streetlight / light pole concern':
      case 'broken streetlight': // legacy
        return Icons.light_rounded;
      case 'blocked canal':
        return Icons.water_damage_rounded;
      case 'others':
        return Icons.more_horiz_rounded;
      // ── Environment concerns ─────────────────────────────────────────────
      case 'illegal dumping':
        return Icons.delete_sweep_rounded;
      case 'garbage collection':
        return Icons.recycling_rounded;
      // ── Legacy concerns (kept for existing dummy reports) ────────────────
      case 'road shouldering':
        return Icons.straighten_rounded;
      case 'overgrown grass':
      case 'overgrown vegetation':
        return Icons.grass_rounded;
      case 'garbage disposal':
        return Icons.delete_sweep_rounded;
      case 'damaged road':
        return Icons.add_road_rounded;
      case 'damaged sidewalk':
        return Icons.directions_walk_rounded;
      case 'blocked drainage':
        return Icons.water_rounded;
      case 'damaged bridge':
        return Icons.directions_rounded;
      case 'road sign damage':
        return Icons.signpost_rounded;
      case 'soil erosion':
        return Icons.terrain_rounded;
      default:
        return Icons.report_problem_rounded;
    }
  }

  // ── Severity Helpers ──────────────────────────────────────────────────────
  static Color getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
      case 'minor':
        return const Color(0xFF16A34A); // green
      case 'medium':
      case 'moderate':
        return const Color(0xFFF59E0B); // orange
      case 'high':
      case 'severe':
        return const Color(0xFFDC2626); // red
      default:
        return const Color(0xFF64748B);
    }
  }

  static Color getSeverityBgColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
      case 'minor':
        return const Color(0xFFF0FDF4);
      case 'medium':
      case 'moderate':
        return const Color(0xFFFFFBEB);
      case 'high':
      case 'severe':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  /// Normalises legacy severity values to the new Low/Medium/High labels.
  static String normaliseSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'minor':
        return 'Low';
      case 'moderate':
        return 'Medium';
      case 'severe':
        return 'High';
      default:
        return severity;
    }
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────
  static void showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

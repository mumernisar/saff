import 'package:flutter/material.dart';
import 'package:saff_ui/src/saff_theme.dart';
import 'package:saff_ui/src/tokens/saff_colors.dart';
import 'package:saff_ui/src/tokens/saff_tokens.dart';

/// A member's live status (`PRODUCT.md` §6.2).
enum MemberStatus {
  /// Ringing, not started.
  asleep,

  /// Snoozed.
  snoozed,

  /// Playing the round.
  playing,

  /// Finished.
  done,

  /// Skipping this morning.
  skipped,

  /// Phone never reported ringing.
  offline,

  /// Deadline passed without playing.
  missed,
}

/// The colour of a status dot.
Color statusColor(SaffColors c, MemberStatus s) => switch (s) {
  MemberStatus.asleep ||
  MemberStatus.snoozed ||
  MemberStatus.skipped => c.asleep,
  MemberStatus.playing => c.playing,
  MemberStatus.done => c.done,
  MemberStatus.offline || MemberStatus.missed => c.error,
};

/// Round avatar with initials and an optional status dot.
class SaffAvatar extends StatelessWidget {
  /// Creates the avatar.
  const SaffAvatar({
    required this.name,
    this.colorIndex = 0,
    this.size = 40,
    this.status,
    super.key,
  });

  /// Display name; the first letter is shown.
  final String name;

  /// Index into [avatarColors].
  final int colorIndex;

  /// Diameter.
  final double size;

  /// Optional live status.
  final MemberStatus? status;

  @override
  Widget build(BuildContext context) {
    final c = context.saff;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: avatarColors[colorIndex % avatarColors.length],
            child: Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF161A22),
              ),
            ),
          ),
          if (status != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: statusColor(c, status!),
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A rounded surface with the standard border.
class SaffCard extends StatelessWidget {
  /// Creates the card.
  const SaffCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(SaffSpacing.lg),
    this.color,
    super.key,
  });

  /// Content.
  final Widget child;

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Overrides the surface colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.saff;
    return Material(
      color: color ?? c.surface,
      borderRadius: BorderRadius.circular(SaffRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(SaffRadii.md),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SaffRadii.md),
            border: Border.all(color: c.line),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A small label chip, optionally selected.
class SaffChip extends StatelessWidget {
  /// Creates the chip.
  const SaffChip({
    required this.label,
    this.selected = false,
    this.onTap,
    super.key,
  });

  /// Text.
  final String label;

  /// Selected state.
  final bool selected;

  /// Tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.saff;
    return InkWell(
      borderRadius: BorderRadius.circular(SaffRadii.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(SaffRadii.pill),
          border: Border.all(color: selected ? c.accent : c.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF161A22) : c.text,
          ),
        ),
      ),
    );
  }
}

/// A section title.
class SectionHeader extends StatelessWidget {
  /// Creates the header.
  const SectionHeader(this.title, {this.trailing, super.key});

  /// Title text.
  final String title;

  /// Optional trailing widget.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      SaffSpacing.lg,
      SaffSpacing.xl,
      SaffSpacing.lg,
      SaffSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: context.saff.muted,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A centred message with an optional action, for empty states.
class EmptyState extends StatelessWidget {
  /// Creates the empty state.
  const EmptyState({
    required this.title,
    this.message,
    this.icon = Icons.wb_twilight,
    this.action,
    super.key,
  });

  /// Headline.
  final String title;

  /// Supporting text.
  final String? message;

  /// Illustration icon.
  final IconData icon;

  /// Optional call to action.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.saff;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.accent),
            const SizedBox(height: SaffSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: SaffSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: SaffSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A failure shown inline: message plus an optional retry (`ERRORS.md` §7).
class ErrorView extends StatelessWidget {
  /// Creates the view.
  const ErrorView({
    required this.message,
    this.retryLabel,
    this.onRetry,
    super.key,
  });

  /// The user message (never an exception string).
  final String message;

  /// Retry button text.
  final String? retryLabel;

  /// Retry handler.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off,
    title: message,
    action: onRetry == null
        ? null
        : OutlinedButton(onPressed: onRetry, child: Text(retryLabel ?? '')),
  );
}

/// A banner prompting a device fix (permissions, battery).
class DeviceFixBanner extends StatelessWidget {
  /// Creates the banner.
  const DeviceFixBanner({
    required this.message,
    required this.actionLabel,
    required this.onFix,
    super.key,
  });

  /// What is wrong.
  final String message;

  /// Button label.
  final String actionLabel;

  /// Opens the fix.
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final c = context.saff;
    return Container(
      margin: const EdgeInsets.all(SaffSpacing.lg),
      padding: const EdgeInsets.all(SaffSpacing.md),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(SaffRadii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: c.accent),
          const SizedBox(width: SaffSpacing.md),
          Expanded(
            child: Text(message, style: TextStyle(color: c.text)),
          ),
          TextButton(onPressed: onFix, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

/// A thin offline notice.
class OfflineBanner extends StatelessWidget {
  /// Creates the banner.
  const OfflineBanner({required this.message, super.key});

  /// Text.
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: context.saff.muted,
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

/// A gold pill button, matching the mockups' primary action.
class PrimaryButton extends StatelessWidget {
  /// Creates the button.
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  /// Label.
  final String label;

  /// Handler; null disables the button.
  final VoidCallback? onPressed;

  /// Shows a spinner and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    child: loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

/// A background that brightens from night to duha as the ring ramps up.
class WakeBackground extends StatelessWidget {
  /// Creates the background.
  const WakeBackground({
    required this.progress,
    required this.child,
    super.key,
  });

  /// 0..1 progress of the ramp.
  final double progress;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: SaffMotion.slow,
    color: WakePalette.at(progress),
    child: DefaultTextStyle.merge(
      style: TextStyle(
        color: WakePalette.darkText(progress)
            ? const Color(0xFF161A22)
            : const Color(0xFFEEF1F6),
      ),
      child: child,
    ),
  );
}

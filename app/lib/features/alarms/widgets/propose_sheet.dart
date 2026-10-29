import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/data/repositories/alarm_plan_repository.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/alarms/view_models/proposal_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';

/// Opens the propose / change sheet. [existing] makes it a change proposal;
/// [supersedes] makes it a counter-proposal ("Suggest another time").
Future<void> showProposeSheet(
  BuildContext context, {
  required String saffId,
  Alarm? existing,
  String? supersedes,
  Map<String, Object?>? initial,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => ProposeSheet(
    saffId: saffId,
    existing: existing,
    supersedes: supersedes,
    initial: initial,
  ),
);

/// Hour/minute steppers, weekdays, name, then "Send to ..." (frame 6h).
class ProposeSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ProposeSheet({
    required this.saffId,
    this.existing,
    this.supersedes,
    this.initial,
    super.key,
  });

  /// The saff.
  final String saffId;

  /// The alarm being changed, if any.
  final Alarm? existing;

  /// The proposal this replaces, if any.
  final String? supersedes;

  /// Starting values (name, time, days) for counter-proposals.
  final Map<String, Object?>? initial;

  @override
  ConsumerState<ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends ConsumerState<ProposeSheet> {
  late final TextEditingController _name;
  late int _minutes;
  late Set<int> _days;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final e = widget.existing;
    final time = (i?['time'] as String?) ?? e?.time ?? '04:50';
    final parts = time.split(':');
    _minutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    _name = TextEditingController(
      text: (i?['name'] as String?) ?? e?.name ?? 'Fajr',
    );
    _days = {
      ...((i?['days'] as List?)?.cast<int>() ??
          e?.days ??
          const [1, 2, 3, 4, 5, 6, 7]),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _step(int delta) =>
      setState(() => _minutes = (_minutes + delta) % (24 * 60));

  String get _time =>
      '${(_minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(_minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final state = ref.watch(proposalViewModelProvider);
    final tz = ref.watch(deviceTimezoneProvider).value;
    final stepMin = ref
        .watch(environmentConfigProvider)
        .constants
        .alarmPickerStep
        .inMinutes;
    final saff = ref
        .watch(mySaffsProvider)
        .value
        ?.where((s) => s.id == widget.saffId)
        .firstOrNull;
    final other = (ref.watch(membersProvider(widget.saffId)).value ?? const [])
        .where((m) => m.uid != ref.watch(uidProvider).value)
        .map((m) => m.displayName)
        .toList();
    final weekdays = [
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: SaffSpacing.xl,
        right: SaffSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + SaffSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? l10n.proposeAlarm
                  : l10n.changeAlarm(widget.existing!.name),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: SaffSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stepper(
                  value: (_minutes ~/ 60).toString().padLeft(2, '0'),
                  onUp: () => _step(60),
                  onDown: () => _step(-60),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':', style: TextStyle(fontSize: 48)),
                ),
                _Stepper(
                  value: (_minutes % 60).toString().padLeft(2, '0'),
                  onUp: () => _step(stepMin),
                  onDown: () => _step(-stepMin),
                ),
              ],
            ),
            const SizedBox(height: SaffSpacing.lg),
            TextField(
              key: const ValueKey('alarm-name'),
              controller: _name,
              maxLength: 24,
              decoration: InputDecoration(labelText: l10n.alarmName),
            ),
            Wrap(
              spacing: SaffSpacing.sm,
              children: [
                for (var i = 0; i < 7; i++)
                  SaffChip(
                    label: weekdays[i],
                    selected: _days.contains(i + 1),
                    onTap: () => setState(() {
                      if (!_days.remove(i + 1)) _days.add(i + 1);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: SaffSpacing.md),
            if (saff != null && other.isNotEmpty)
              Text(
                saff.isPair
                    ? l10n.needsToAccept(other.join(', '))
                    : l10n.groupOptIn,
                style: TextStyle(color: c.muted),
              ),
            if (state.failure != null)
              Padding(
                padding: const EdgeInsets.only(top: SaffSpacing.md),
                child: Text(
                  failureText(l10n, state.failure!),
                  style: TextStyle(color: c.error),
                ),
              ),
            const SizedBox(height: SaffSpacing.lg),
            PrimaryButton(
              label: l10n.sendProposal,
              loading: state.running,
              onPressed: _days.isEmpty || tz == null
                  ? null
                  : () async {
                      final draft = (
                        name: _name.text.trim(),
                        time: _time,
                        days: (_days.toList()..sort()),
                        timezone: widget.existing?.timezone ?? tz,
                      );
                      final vm = ref.read(proposalViewModelProvider.notifier);
                      final ok = widget.existing == null
                          ? await vm.create(
                              widget.saffId,
                              draft,
                              supersedes: widget.supersedes,
                            )
                          : await vm.change(
                              widget.saffId,
                              widget.existing!.id,
                              draft,
                              supersedes: widget.supersedes,
                            );
                      if (ok && context.mounted) Navigator.pop(context);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onUp,
    required this.onDown,
  });

  final String value;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      IconButton(onPressed: onUp, icon: const Icon(Icons.keyboard_arrow_up)),
      Text(
        value,
        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
      ),
      IconButton(
        onPressed: onDown,
        icon: const Icon(Icons.keyboard_arrow_down),
      ),
    ],
  );
}

/// Alias keeping the draft type visible to callers of this file.
typedef ProposeDraft = AlarmDraft;

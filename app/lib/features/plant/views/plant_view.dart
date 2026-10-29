import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/plant/view_models/plant_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';

/// "Leave Ali a card" (`docs/design/flows.md` frames 9a-9c). Pairs only.
class PlantView extends ConsumerStatefulWidget {
  /// Creates the view.
  const PlantView({required this.saffId, super.key});

  /// The pair saff.
  final String saffId;

  @override
  ConsumerState<PlantView> createState() => _PlantViewState();
}

class _PlantViewState extends ConsumerState<PlantView> {
  final _question = TextEditingController();
  final _answer = TextEditingController();
  final _options = List.generate(4, (_) => TextEditingController());
  String _template = 'quiz';
  int _correct = 0;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final uid = ref.watch(uidProvider).value;
    final others =
        (ref.watch(membersProvider(widget.saffId)).value ?? const <Member>[])
            .where((m) => m.uid != uid);
    final name = others.firstOrNull?.displayName ?? '';
    final state = ref.watch(plantViewModelProvider);
    ref.listen(plantViewModelProvider.select((s) => s.sent), (_, sent) {
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.plantSent(name))),
        );
        context.pop();
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.plantTitle(name))),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        children: [
          Wrap(
            spacing: SaffSpacing.sm,
            children: [
              SaffChip(
                label: l10n.plantQuiz,
                selected: _template == 'quiz',
                onTap: () => setState(() => _template = 'quiz'),
              ),
              SaffChip(
                label: l10n.plantChoice,
                selected: _template == 'quizChoice',
                onTap: () => setState(() => _template = 'quizChoice'),
              ),
              SaffChip(
                label: l10n.plantAskMe,
                selected: _template == 'askMe',
                onTap: () => setState(() => _template = 'askMe'),
              ),
            ],
          ),
          const SizedBox(height: SaffSpacing.lg),
          TextField(
            key: const ValueKey('plant-question'),
            controller: _question,
            maxLength: 200,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.plantQuestion),
          ),
          if (_template == 'quiz')
            TextField(
              controller: _answer,
              decoration: InputDecoration(labelText: l10n.plantAnswer),
            ),
          if (_template == 'quizChoice')
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(top: SaffSpacing.sm),
                child: Row(
                  children: [
                    Radio<int>(
                      value: i,
                      groupValue: _correct,
                      onChanged: (v) => setState(() => _correct = v ?? 0),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _options[i],
                        decoration: InputDecoration(
                          labelText: l10n.plantOption(i + 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (state.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: SaffSpacing.md),
              child: Text(
                failureText(l10n, state.failure!),
                style: TextStyle(color: c.error),
              ),
            ),
          const SizedBox(height: SaffSpacing.xl),
          PrimaryButton(
            label: l10n.plantSend(name),
            loading: state.running,
            onPressed: () => ref
                .read(plantViewModelProvider.notifier)
                .plant(
                  saffId: widget.saffId,
                  template: _template,
                  question: _question.text.trim(),
                  answer: _template == 'quiz' ? _answer.text.trim() : null,
                  options: _template == 'quizChoice'
                      ? _options.map((o) => o.text.trim()).toList()
                      : null,
                  correctIndex: _template == 'quizChoice' ? _correct : null,
                ),
          ),
        ],
      ),
    );
  }
}

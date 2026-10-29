import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/wake/view_models/wake_flow_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';

/// Swipe through each card with everyone's answers and the talk question
/// (`docs/PRODUCT.md` §6.5, frames 4c, 4d).
class ReviewView extends ConsumerStatefulWidget {
  /// Creates the view.
  const ReviewView({required this.morning, required this.onExit, super.key});

  /// The morning.
  final MorningKey morning;

  /// Go to chat.
  final VoidCallback onExit;

  @override
  ConsumerState<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<ReviewView> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final state = ref.watch(wakeFlowProvider(widget.morning));
    final vm = ref.read(wakeFlowProvider(widget.morning).notifier);
    final round = state.round;
    final reveal = state.reveal;
    final uid = ref.watch(uidProvider).value ?? '';
    if (round == null || reveal == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final names = {for (final r in reveal.rows) r.uid: r.name};
    final cards = [...round.cards, ...reveal.bonusCards];
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: vm.closeReview),
        title: Text(l10n.cardReview),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: cards.length,
        itemBuilder: (context, i) {
          final card = cards[i];
          final answers = reveal.perCard[card.id] ?? const <ReviewAnswer>[];
          final last = i == cards.length - 1;
          return ListView(
            padding: const EdgeInsets.all(SaffSpacing.lg),
            children: [
              Text(
                l10n.cardOf(i + 1, cards.length),
                style: TextStyle(color: c.muted),
              ),
              const SizedBox(height: SaffSpacing.sm),
              Text(
                card.question,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SaffSpacing.lg),
              for (final a in answers)
                Padding(
                  padding: const EdgeInsets.only(bottom: SaffSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${a.uid == uid ? l10n.you : names[a.uid] ?? ''}: '
                          '${_answerText(card, a, l10n)}',
                        ),
                      ),
                      Text(
                        a.correct ? l10n.correct : l10n.wrong,
                        style: TextStyle(
                          color: a.correct ? c.done : c.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Text(l10n.answerLabel, style: TextStyle(color: c.muted)),
              Text(
                card.answer,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (card.explanation != null) ...[
                const SizedBox(height: SaffSpacing.md),
                Text(card.explanation!),
              ],
              if (card.source != null) ...[
                const SizedBox(height: SaffSpacing.sm),
                Text(card.source!, style: TextStyle(color: c.muted)),
              ],
              if (card.talk != null) ...[
                const SizedBox(height: SaffSpacing.lg),
                SaffCard(
                  color: c.soft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.talkAboutIt,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(card.talk!),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: SaffSpacing.lg),
              PrimaryButton(
                label: last ? l10n.goToChat : l10n.nextCard,
                onPressed: last
                    ? widget.onExit
                    : () => _pages.nextPage(
                        duration: SaffMotion.normal,
                        curve: Curves.easeOut,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _answerText(RoundCard card, ReviewAnswer a, AppLocalizations l10n) {
    if (!a.answered) return l10n.noAnswer;
    if (card.type == 'choice' &&
        a.choiceIndex != null &&
        a.choiceIndex! < card.options.length) {
      return card.options[a.choiceIndex!];
    }
    return a.answer ?? l10n.noAnswer;
  }
}

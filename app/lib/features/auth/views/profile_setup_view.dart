import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/features/auth/view_models/auth_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_ui/saff_ui.dart';

/// Name and WhatsApp number (`docs/PRODUCT.md` §2).
class ProfileSetupView extends ConsumerStatefulWidget {
  /// Creates the view.
  const ProfileSetupView({this.initialName = '', super.key});

  /// Pre-filled name, e.g. the dev test user's.
  final String initialName;

  @override
  ConsumerState<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends ConsumerState<ProfileSetupView> {
  late final _name = TextEditingController(text: widget.initialName);
  final _phone = TextEditingController(text: '+92');
  int _color = 0;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final state = ref.watch(profileViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        children: [
          Text(l10n.profileBody, style: TextStyle(color: c.muted)),
          const SizedBox(height: SaffSpacing.xl),
          TextField(
            key: const ValueKey('profile-name'),
            controller: _name,
            maxLength: 40,
            decoration: InputDecoration(labelText: l10n.profileName),
          ),
          const SizedBox(height: SaffSpacing.md),
          TextField(
            key: const ValueKey('profile-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.profileWhatsapp,
              helperText: l10n.profileWhatsappHelp,
            ),
          ),
          const SizedBox(height: SaffSpacing.lg),
          Wrap(
            spacing: SaffSpacing.md,
            children: [
              for (var i = 0; i < avatarColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == i ? c.text : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: avatarColors[i],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SaffSpacing.xl),
          if (state.failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: SaffSpacing.md),
              child: Text(
                failureText(l10n, state.failure!),
                style: TextStyle(color: c.error),
              ),
            ),
          PrimaryButton(
            label: l10n.profileSave,
            loading: state.running,
            onPressed: () => ref
                .read(profileViewModelProvider.notifier)
                .save(_name.text, _phone.text, avatarColor: _color),
          ),
        ],
      ),
    );
  }
}

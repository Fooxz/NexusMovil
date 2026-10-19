import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/profile_models.dart';
import '../profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(profileFormControllerProvider.notifier)
        .save(fullName: _name.text, phone: _phone.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(profileFormControllerProvider);

    return NexusPage(
      title: 'EDITAR DATOS',
      showBack: true,
      showCart: false,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.error case final error?) AuthErrorBanner(error),
              AuthField(
                label: 'NOMBRE',
                field: NexusTextField(
                  hint: 'Tu nombre completo',
                  controller: _name,
                  validator: Validators.text(field: 'tu nombre', min: 2, max: 120),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                ),
              ),
              AuthField(
                label: 'TELÉFONO (OPCIONAL)',
                field: NexusTextField(
                  hint: '3001234567',
                  controller: _phone,
                  validator: Validators.optionalPhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
              ),
              const SizedBox(height: 6),
              NexusPrimaryButton(
                label: 'GUARDAR',
                loading: action.isLoading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

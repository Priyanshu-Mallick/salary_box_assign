import 'package:attendance_mobile/src/core/theme/app_colors.dart';
import 'package:attendance_mobile/src/presentation/viewmodels/admin_view_model.dart';
import 'package:attendance_mobile/src/presentation/widgets/atoms/surface_card.dart';
import 'package:attendance_mobile/src/presentation/widgets/compounds/brand_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AddStaffView extends ConsumerStatefulWidget {
  const AddStaffView({super.key});

  @override
  ConsumerState<AddStaffView> createState() => _AddStaffViewState();
}

class _AddStaffViewState extends ConsumerState<AddStaffView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _employeeId = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _employeeId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Add team member')),
      body: BrandBackdrop(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppBrand.violet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppBrand.violet,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Create a staff profile',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add their core identity now. Login access and face enrolment are managed separately.',
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    hintText: 'e.g. Aisha Verma',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) =>
                      value?.trim().isNotEmpty == true ? null : 'Enter a name.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _employeeId,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    hintText: 'e.g. NXA-2048',
                    prefixIcon: Icon(Icons.fingerprint_rounded),
                  ),
                  validator: _validateEmployeeId,
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: const TextStyle(color: AppBrand.danger),
                  ),
                ],
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: state.saving ? null : _save,
                  icon: state.saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    state.saving ? 'Creating profile…' : 'Create staff profile',
                  ),
                ),
                const SizedBox(height: 18),
                const SurfaceCard(
                  color: Color(0xFF101722),
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'You can review privacy consent and enrol their face from the profile after creation.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmployeeId(String? value) {
    final valid = value != null && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
    return valid ? null : 'Use letters, numbers, hyphens, or underscores.';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final item = await ref
        .read(adminViewModelProvider.notifier)
        .create(_name.text, _employeeId.text);
    if (mounted && item != null) context.go('/admin/staff/${item.id}');
  }
}

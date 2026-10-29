/// Categories management screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/empty_state.dart';
import '../../app/widgets/loading_state.dart';
import '../../domain/models/models.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return PaisaColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Category',
            onPressed: () => _showAddCategoryDialog(context, ref),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const LoadingState(message: 'Loading categories…'),
        error: (err, _) => EmptyState.error(
          onRetry: () => ref.invalidate(categoriesFutureProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return EmptyState(
              icon: Icons.label_outline,
              title: 'No categories',
              subtitle: 'Categories help organize and visualize your spending.',
              actionLabel: 'Add Category',
              onAction: () => _showAddCategoryDialog(context, ref),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(PaisaSpacing.md),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: PaisaSpacing.xs),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final color = _parseColor(cat.colorHex);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(Icons.folder_outlined, color: color, size: 20),
                  ),
                  title: Text(
                    cat.name,
                    style: PaisaTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: cat.isSystem
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'System',
                            style: PaisaTextStyles.bodySmall
                                .copyWith(color: PaisaColors.textSecondary),
                          ),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    String selectedColor = '#3B82F6';

    final colors = [
      '#3B82F6', // Blue
      '#10B981', // Green
      '#F59E0B', // Amber
      '#EF4444', // Red
      '#8B5CF6', // Purple
      '#EC4899', // Pink
      '#14B8A6', // Teal
      '#F97316', // Orange
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: PaisaSpacing.lg,
            right: PaisaSpacing.lg,
            top: PaisaSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + PaisaSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New Category',
                style: PaisaTextStyles.body
                    .copyWith(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: PaisaSpacing.md),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Subscriptions, Fitness, Travel',
                ),
                autofocus: true,
              ),
              const SizedBox(height: PaisaSpacing.md),
              Text('Pick a Color', style: PaisaTextStyles.bodySmall),
              const SizedBox(height: PaisaSpacing.xs),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: colors.map((c) {
                  final isSelected = selectedColor == c;
                  final color = _parseColor(c);
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: PaisaSpacing.lg),
              FilledButton(
                onPressed: () async {
                  final input = CategoryInput(
                    name: nameCtrl.text.trim(),
                    colorHex: selectedColor,
                    iconKey: 'folder_outlined',
                  );
                  final repo = ref.read(categoryRepositoryProvider);
                  final res = await repo.createCategory(input);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(categoriesFutureProvider);
                    switch (res) {
                      case Success():
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added "${input.name}"')),
                        );
                      case Failure(:final error):
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.userMessage)),
                        );
                    }
                  }
                },
                child: const Text('Save Category'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

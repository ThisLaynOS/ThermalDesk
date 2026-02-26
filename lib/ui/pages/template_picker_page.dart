import 'package:flutter/material.dart';
import 'package:zebra_label_pro/core/responsive.dart';
import 'package:zebra_label_pro/models/label_job.dart';

class TemplatePicker extends StatelessWidget {
  final LabelTemplate current;
  const TemplatePicker({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = Responsive.isMobile(context);
    final maxExtent = Responsive.value(
      context: context,
      mobile: 200.0,
      tablet: 240.0,
      desktop: 280.0,
    );
    final childAspectRatio = Responsive.value(
      context: context,
      mobile: 1.4,
      tablet: 1.35,
      desktop: 1.3,
    );
    
    return Scaffold(
      appBar: AppBar(title: Text(isMobile ? 'Template' : 'Escolher Template')),
      body: GridView.builder(
        padding: Responsive.padding(context),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          mainAxisSpacing: Responsive.cardSpacing(context),
          crossAxisSpacing: Responsive.cardSpacing(context),
          childAspectRatio: childAspectRatio,
        ),
        itemCount: LabelTemplate.values.length,
        itemBuilder: (context, index) {
          final t = LabelTemplate.values[index];
          final selected = t == current;
          
          return Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              side: selected
                  ? BorderSide(color: colorScheme.primary, width: isMobile ? 2 : 2.5)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(t),
              child: Container(
                decoration: selected ? BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                ) : null,
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 8 : 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                          ),
                          child: Icon(
                            t.icon,
                            size: isMobile ? 18 : 22,
                            color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          Container(
                            padding: EdgeInsets.all(isMobile ? 3 : 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: isMobile ? 12 : 14,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      t.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 13 : 15,
                        color: selected ? colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.description,
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

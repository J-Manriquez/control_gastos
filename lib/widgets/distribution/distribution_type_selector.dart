import 'package:flutter/material.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';

class DistributionTypeSelector extends StatelessWidget {
  final DistributionType selectedType;
  final Function(DistributionType) onTypeChanged;

  const DistributionTypeSelector({
    Key? key,
    required this.selectedType,
    required this.onTypeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Container(
      margin: const EdgeInsets.all(8),
      color: Colors.white,
      child: Padding(
          padding: const EdgeInsets.all(0),
          child: Column(children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tipo de Distribución',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SegmentedButton<DistributionType>(
                    segments: [
                      ButtonSegment<DistributionType>(
                        value: DistributionType.equalParts,
                        label: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.balance,
                                color: selectedType ==
                                        DistributionType.equalParts
                                    ? colorProvider.colors.secondaryTextColor
                                    : colorProvider.colors.primaryTextColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '',
                                style: TextStyle(
                                  color: selectedType ==
                                          DistributionType.equalParts
                                      ? colorProvider.colors.secondaryTextColor
                                      : colorProvider.colors.primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ButtonSegment<DistributionType>(
                        value: DistributionType.percentage,
                        label: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pie_chart,
                                color: selectedType ==
                                        DistributionType.percentage
                                    ? colorProvider.colors.secondaryTextColor
                                    : colorProvider.colors.primaryTextColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '',
                                style: TextStyle(
                                  color: selectedType ==
                                          DistributionType.percentage
                                      ? colorProvider.colors.secondaryTextColor
                                      : colorProvider.colors.primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (Set<DistributionType> newSelection) {
                      onTypeChanged(newSelection.first);
                    },
                    selectedIcon: const Icon(Icons.check, color: Colors.white),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return colorProvider.colors.appBarColor;
                          }
                          return colorProvider.colors.backgroundColor;
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              selectedType == DistributionType.equalParts
                  ? 'El monto se dividirá en partes iguales entre todos los participantes'
                  : 'Asigna un porcentaje personalizado a cada participante',
              style: TextStyle(
                fontSize: 12,
                color: colorProvider.colors.primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ])),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/widgets/distribution/distribution_summary_widget.dart';
import 'package:control_gastos/services/distribution_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DistributionSummaryScreen extends StatefulWidget {
  final SharedExpenseGroup group;
  final String userId;

  const DistributionSummaryScreen({
    Key? key,
    required this.group,
    required this.userId,
  }) : super(key: key);

  @override
  _DistributionSummaryScreenState createState() => _DistributionSummaryScreenState();
}

class _DistributionSummaryScreenState extends State<DistributionSummaryScreen> {
  final CustomLogger _logger = CustomLogger();
  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0,
  );

  late Map<String, String> _userNames = {};
  bool _isLoading = true;
  Map<String, double> _userTotals = {};
  List<MapEntry<String, double>> _sortedTotals = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadUserNames();
      _calculateTotals();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _logger.logError('Error al inicializar resumen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  Future<void> _loadUserNames() async {
    final userIds = widget.group.participants.map((p) => p.userId).toList();
    for (var userId in userIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .get();
        if (doc.exists) {
          _userNames[userId] = doc.data()?['username'] ?? 'Usuario';
        }
      } catch (e) {
        _logger.logError('Error al cargar nombre de usuario $userId: $e');
      }
    }
  }

  void _calculateTotals() {
    _userTotals.clear();

    // Inicializar totales para todos los participantes
    for (var participant in widget.group.participants) {
      _userTotals[participant.userId] = 0.0;
    }

    // Sumar distribuciones de gastos individuales
    widget.group.expenseDistributions.forEach((_, distribution) {
      for (var share in distribution.shares) {
        _userTotals[share.userId] = 
            (_userTotals[share.userId] ?? 0) + share.amount;
      }
    });

    // Sumar distribuciones de subgrupos
    widget.group.subgroupDistributions.forEach((_, distribution) {
      for (var share in distribution.shares) {
        _userTotals[share.userId] = 
            (_userTotals[share.userId] ?? 0) + share.amount;
      }
    });

    // Añadir distribución total si existe
    if (widget.group.totalDistribution != null) {
      for (var share in widget.group.totalDistribution!.shares) {
        _userTotals[share.userId] = 
            (_userTotals[share.userId] ?? 0) + share.amount;
      }
    }

    // Ordenar totales de mayor a menor
    _sortedTotals = _userTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Resumen de Distribución',
          style: TextStyle(
            color: colorProvider.colors.secondaryTextColor,
          ),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(
          color: colorProvider.colors.secondaryTextColor,
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGroupInfo(colorProvider),
                  const SizedBox(height: 24),
                  _buildDistributionsList(colorProvider),
                  const SizedBox(height: 24),
                  _buildTotalsSummary(colorProvider),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupInfo(ColorProvider colorProvider) {
    return Card(
      color: colorProvider.colors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.nombre,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: \$${_currencyFormat.format(widget.group.total)}',
              style: TextStyle(
                fontSize: 20,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Participantes: ${widget.group.participants.length}',
              style: TextStyle(
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Creado: ${DateFormat('dd/MM/yyyy').format(widget.group.creationDate)}',
              style: TextStyle(
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionsList(ColorProvider colorProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distribuciones',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorProvider.colors.primaryTextColor,
          ),
        ),
        const SizedBox(height: 16),
        // Distribuciones de gastos individuales
        if (widget.group.expenseDistributions.isNotEmpty) ...[
          Text(
            'Gastos Individuales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorProvider.colors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.group.expenseDistributions.entries.map((entry) {
            final gasto = widget.group.expenses
                .firstWhere((g) => g.id == entry.value.targetId);
            return DistributionSummaryWidget(
              distribution: entry.value,
              title: gasto.nombre,
              showDetails: true,
            );
          }),
        ],
        const SizedBox(height: 16),
        // Distribuciones de subgrupos
        if (widget.group.subgroupDistributions.isNotEmpty) ...[
          Text(
            'Subgrupos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorProvider.colors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.group.subgroupDistributions.entries.map((entry) {
            return DistributionSummaryWidget(
              distribution: entry.value,
              title: entry.key,
              showDetails: true,
            );
          }),
        ],
        const SizedBox(height: 16),
        // Distribución total
        if (widget.group.totalDistribution != null) ...[
          Text(
            'Distribución Total',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorProvider.colors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          DistributionSummaryWidget(
            distribution: widget.group.totalDistribution!,
            title: 'Total del Grupo',
            showDetails: true,
          ),
        ],
      ],
    );
  }

  Widget _buildTotalsSummary(ColorProvider colorProvider) {
    return Card(
      color: colorProvider.colors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen por Participante',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            ..._sortedTotals.map((entry) {
              final isCurrentUser = entry.key == widget.userId;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _userNames[entry.key] ?? 'Usuario',
                        style: TextStyle(
                          color: colorProvider.colors.primaryTextColor,
                          fontWeight: isCurrentUser ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    Text(
                      '\$${_currencyFormat.format(entry.value)}',
                      style: TextStyle(
                        color: isCurrentUser
                            ? colorProvider.colors.appBarColor
                            : colorProvider.colors.primaryTextColor,
                        fontWeight: isCurrentUser ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
                Text(
                  '\$${_currencyFormat.format(widget.group.total)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
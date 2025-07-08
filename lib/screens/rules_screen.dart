import 'package:flutter/material.dart';
import '../constants.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game Rules', style: AppTextStyles.cosmicTitle(context)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.spaceGradient),
        ),
        foregroundColor: AppColors.starDust,
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.spaceGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              decoration: AppColors.panelDecoration.copyWith(
                color: Colors.black.withAlpha((0.7 * 255).toInt()),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiger Trap Rules',
                      style: AppTextStyles.cosmicTitle(
                        context,
                      ).copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 18),
                    _buildRuleItem(context, 'Tigers start at the 4 corners'),
                    _buildRuleItem(
                      context,
                      'Goats are placed one at a time (20 total)',
                    ),
                    _buildRuleItem(
                      context,
                      'Tigers move first after each goat placement',
                    ),
                    _buildRuleItem(
                      context,
                      'Tigers can capture goats by jumping over them',
                    ),
                    _buildRuleItem(
                      context,
                      'Goats win by blocking all tiger moves',
                    ),
                    _buildRuleItem(context, 'Tigers win by capturing 5 goats'),
                    const SizedBox(height: 32),
                    Text(
                      'Aadu Puli Aatam Rules',
                      style: AppTextStyles.cosmicTitle(context),
                    ),
                    const SizedBox(height: 18),
                    _buildRuleItem(context, '3 Tigers vs 15 Goats'),
                    _buildRuleItem(
                      context,
                      'Tigers start at the top 3 positions',
                    ),
                    _buildRuleItem(context, 'Goats are placed one at a time'),
                    _buildRuleItem(
                      context,
                      'After placing all goats, they can move',
                    ),
                    _buildRuleItem(
                      context,
                      'Tigers move first after each goat placement',
                    ),
                    _buildRuleItem(
                      context,
                      'Tigers can capture goats by jumping over them',
                    ),
                    _buildRuleItem(
                      context,
                      'Goats win by blocking all tiger moves',
                    ),
                    _buildRuleItem(context, 'Tigers win by capturing 5 goats'),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, color: AppColors.stellarGold, size: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTextStyles.nebulaSubtitle(context)),
          ),
        ],
      ),
    );
  }
}

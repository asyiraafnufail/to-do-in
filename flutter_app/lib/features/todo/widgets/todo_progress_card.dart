import 'package:flutter/material.dart';

class TodoProgressCard extends StatelessWidget {
  final int total;
  final int completed;
  final int pending;
  final int citiesCount;
  final double percent;

  const TodoProgressCard({
    super.key,
    required this.total,
    required this.completed,
    required this.pending,
    required this.citiesCount,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final isDoneAll = total > 0 && completed == total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDoneAll
              ? [const Color(0xFF0F766E), const Color(0xFF16A34A)]
              : [const Color(0xFF0F766E), const Color(0xFF115E59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isDoneAll ? Icons.celebration : Icons.luggage_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isDoneAll ? 'Semua Target Selesai!' : 'Rencana Perjalanan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(percent * 100).toInt()}% Selesai',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildBannerStat('$total', 'Total To-Do'),
              Container(
                width: 1,
                height: 26,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildBannerStat('$pending', 'Tersisa'),
              Container(
                width: 1,
                height: 26,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildBannerStat('$citiesCount', 'Kota Tujuan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat(String count, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

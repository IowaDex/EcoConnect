import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../driver/data/mock_trucks.dart';
import '../../driver/models/garbage_truck.dart';
import '../models/trip_ticket.dart';
import '../services/ticket_service.dart';
import '../widgets/ticket_card.dart';

/// Every trip ticket ever issued against one plate.
///
/// Iswim, the barangay and City Hall all open this screen: it is the record of
/// how many rounds the truck actually did.
class TruckHistoryScreen extends StatelessWidget {
  const TruckHistoryScreen({super.key, required this.truckId});

  final String truckId;

  @override
  Widget build(BuildContext context) {
    final truck = truckById(truckId);

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/iswim');
            }
          },
        ),
        title: Text(
          truck?.plateNumber ?? 'Truck',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<List<TripTicket>>(
        stream: TicketService().watchForTruck(truckId),
        builder: (context, snapshot) {
          final tickets = snapshot.data ?? const <TripTicket>[];
          final completed =
              tickets.where((t) => t.status == TicketStatus.completed).length;
          final missed =
              tickets.where((t) => t.status == TicketStatus.missed).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
            children: [
              if (truck != null) _TruckHeader(truck: truck),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric(label: 'Tickets', value: '${tickets.length}'),
                  const SizedBox(width: 8),
                  _Metric(label: 'Completed', value: '$completed'),
                  const SizedBox(width: 8),
                  _Metric(label: 'Missed', value: '$missed'),
                ],
              ),
              const SizedBox(height: 16),
              if (tickets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    'This truck has no trip tickets yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                )
              else
                for (final ticket in tickets) ...[
                  TicketCard(
                    ticket: ticket,
                    onTap: () => context.push('/tickets/${ticket.id}'),
                  ),
                  const SizedBox(height: 9),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _TruckHeader extends StatelessWidget {
  const _TruckHeader({required this.truck});

  final GarbageTruck truck;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  truck.plateNumber,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${truck.description} · ${truck.zone}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xD9FFFFFF),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Driver: ${truck.driverName}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lime,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.local_shipping_rounded,
              size: 30, color: Color(0xCCFFFFFF)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sage),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.forest,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 8, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

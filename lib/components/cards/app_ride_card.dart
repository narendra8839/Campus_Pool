import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../badges/app_status_badge.dart';
import 'app_card.dart';

/// Comprehensive Campus Pool Ride Card based on Stitch matching & dashboard screens
class AppRideCard extends StatelessWidget {
  const AppRideCard({
    super.key,
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.availableSeats,
    required this.price,
    this.driverRating = 4.8,
    this.driverAvatarUrl,
    this.vehicleType = 'Bike',
    this.vehicleModel,
    this.status = RideStatusType.available,
    this.onTap,
    this.onBookTap,
    this.bookButtonText = 'Book Seat',
    this.matchPercentage,
  });

  final String driverName;
  final String origin;
  final String destination;
  final String departureTime;
  final int availableSeats;
  final double price;
  final double driverRating;
  final String? driverAvatarUrl;
  final String vehicleType;
  final String? vehicleModel;
  final RideStatusType status;
  final VoidCallback? onTap;
  final VoidCallback? onBookTap;
  final String bookButtonText;
  final int? matchPercentage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver Header & Status
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryTint,
                backgroundImage: driverAvatarUrl != null ? NetworkImage(driverAvatarUrl!) : null,
                child: driverAvatarUrl == null
                    ? Text(
                        driverName.isNotEmpty ? driverName[0].toUpperCase() : 'U',
                        style: AppTypography.labelLg.copyWith(color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            driverName,
                            style: AppTypography.headlineSm.copyWith(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 16, color: AppColors.primary),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.tertiaryLight),
                        const SizedBox(width: 2),
                        Text(
                          driverRating.toStringAsFixed(1),
                          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('•', style: AppTypography.caption),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          vehicleModel ?? vehicleType,
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (matchPercentage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryTint,
                    borderRadius: AppSpacing.radiusFull,
                    border: Border.all(color: AppColors.secondaryLight.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$matchPercentage% Match',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else ...[
                AppStatusBadge(status: status),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Route Timeline (Origin -> Destination)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppSpacing.radiusMd,
            ),
            child: Row(
              children: [
                // Route line indicators
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 24,
                      color: AppColors.border,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        origin,
                        style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        destination,
                        style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Departure Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Departure',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      departureTime,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Footer: Seats, Price, and Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: AppSpacing.radiusSm,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_seat_rounded, size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '$availableSeats ${availableSeats == 1 ? 'seat' : 'seats'} left',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    price > 0 ? '₹${price.toStringAsFixed(0)}' : 'Free',
                    style: AppTypography.headlineSm.copyWith(
                      color: price > 0 ? AppColors.onSurface : AppColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (onBookTap != null)
                ElevatedButton(
                  onPressed: onBookTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(100, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
                  ),
                  child: Text(
                    bookButtonText,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

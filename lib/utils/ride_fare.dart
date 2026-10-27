const double rideFarePerKilometre = 5;

double estimateRideFare(double distanceMeters) =>
    (distanceMeters / 1000 * rideFarePerKilometre * 100).roundToDouble() / 100;

String formatRideFare(double distanceMeters) =>
    '₹${estimateRideFare(distanceMeters).toStringAsFixed(2)}';

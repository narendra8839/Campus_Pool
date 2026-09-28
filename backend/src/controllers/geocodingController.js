const {
  GeocodingError,
  searchPlaces,
  reverseGeocode,
} = require('../services/nominatimService');

const search = async (req, res, next) => {
  const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
  if (query.length < 3 || query.length > 200) {
    return res.status(400).json({
      success: false,
      message: 'Search query must be between 3 and 200 characters.',
    });
  }

  const requestedLimit = Number.parseInt(req.query.limit, 10);
  const limit = Number.isNaN(requestedLimit)
    ? 5
    : Math.min(Math.max(requestedLimit, 1), 10);

  try {
    const data = await searchPlaces(query, limit);
    return res.json({ success: true, count: data.length, data });
  } catch (error) {
    if (error instanceof GeocodingError) {
      return res.status(error.statusCode).json({ success: false, message: error.message });
    }
    return next(error);
  }
};

const reverse = async (req, res, next) => {
  const latitudeValue = req.query.lat;
  const longitudeValue = req.query.lon;
  const latitude = typeof latitudeValue === 'string' && latitudeValue.trim()
    ? Number(latitudeValue)
    : Number.NaN;
  const longitude = typeof longitudeValue === 'string' && longitudeValue.trim()
    ? Number(longitudeValue)
    : Number.NaN;
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    return res.status(400).json({
      success: false,
      message: 'Valid latitude and longitude are required.',
    });
  }

  try {
    const data = await reverseGeocode(latitude, longitude);
    return res.json({ success: true, data });
  } catch (error) {
    if (error instanceof GeocodingError) {
      return res.status(error.statusCode).json({ success: false, message: error.message });
    }
    return next(error);
  }
};

module.exports = { search, reverse };

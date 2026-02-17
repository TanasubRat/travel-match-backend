// routes/placeRoutes.js
const express = require('express');
const router = express.Router();
const Place = require('../models/Place');

// GET /api/places?location=Bangkok&type=Food & Drink,Attraction&minRating=3&priceLevel=2&maxDistanceKm=10&openNow=true
// All filters use AND logic - place must match ALL criteria
router.get('/', async (req, res) => {
  try {
    const { location, type, minRating, priceLevel, maxDistanceKm, openNow } = req.query;

    const filter = { isActive: true };

    if (location) {
      filter.city = location;
    }

    // Prepare numeric filters
    const minRatingNum = minRating ? parseFloat(minRating) : null;
    const priceLevelNum = (priceLevel !== undefined && priceLevel !== null && priceLevel !== '') ? parseInt(priceLevel, 10) : null;
    const openNowFlag = openNow === 'true';

    if (type) {
      // Relax categories to OR for retrieval, but compute overlap score and sort by it
      const arr = String(type)
        .split(',')
        .map(t => t.trim())
        .filter(Boolean);

      const matchStage = { ...filter };
      if (arr.length) {
        matchStage.categories = { $in: arr };
      }
      if (minRatingNum != null && !isNaN(minRatingNum)) matchStage.rating = { $gte: minRatingNum };
      if (priceLevelNum != null && !isNaN(priceLevelNum)) matchStage.priceLevel = priceLevelNum;
      if (openNowFlag) matchStage.isOpenNow = true;

      // Compute categoryMatchCount and composite score, then sort
      const pipeline = [
        { $match: matchStage },
        {
          $addFields: {
            categoryMatchCount: { $size: { $setIntersection: ['$categories', arr] } }
          }
        },
        // require at least one overlapping category
        { $match: { categoryMatchCount: { $gt: 0 } } },
        {
          $addFields: {
            score: {
              $add: [
                { $multiply: [0.5, { $divide: ['$categoryMatchCount', arr.length] }] },
                { $multiply: [0.3, { $divide: [{ $ifNull: ['$rating', 0] }, 5] }] },
                {
                  $multiply: [
                    0.2,
                    {
                      $cond: [
                        { $ifNull: ['$priceLevel', false] },
                        { $subtract: [1, { $divide: ['$priceLevel', 4] }] },
                        0.5
                      ]
                    }
                  ]
                }
              ]
            }
          }
        },
        { $sort: { score: -1 } },
        { $limit: 200 }
      ];

      const places = await Place.aggregate(pipeline);
      return res.json(places);
    }

    // No category filter provided — use simple field filters
    if (minRatingNum != null && !isNaN(minRatingNum)) filter.rating = { $gte: minRatingNum };
    if (priceLevelNum != null && !isNaN(priceLevelNum)) filter.priceLevel = priceLevelNum;
    if (openNowFlag) filter.isOpenNow = true;

    const places = await Place.find(filter).limit(200).sort({ rating: -1 });
    res.json(places);
  } catch (err) {
    console.error('Get places error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

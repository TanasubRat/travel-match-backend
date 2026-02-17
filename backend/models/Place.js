// models/Place.js
const mongoose = require('mongoose');

const placeSchema = new mongoose.Schema({
  externalId: { type: String }, // optional (Google Places ID)
  name: { type: String, required: true },
  city: { type: String, required: true }, // Bangkok / Chiang Mai / Phuket ...
  address: { type: String },
  latitude: { type: Number },
  longitude: { type: Number },

  priceLevel: { type: Number, min: 0, max: 4 }, // 0-4
  rating: { type: Number, min: 0, max: 5 },
  userRatingsTotal: { type: Number, default: 0 },

  categories: [{ type: String }], // e.g. ['Food & Drink','Nightlife']
  isOpenNow: { type: Boolean, default: true },

  image: { type: String }, // URL รูป
  mapsUrl: { type: String }, // Google Maps Link

  isActive: { type: Boolean, default: true },

  createdAt: { type: Date, default: Date.now }
});

placeSchema.index({ city: 1, isActive: 1 });
placeSchema.index({ categories: 1 });
placeSchema.index({ priceLevel: 1 });
placeSchema.index({ rating: -1 });

module.exports = mongoose.model('Place', placeSchema);

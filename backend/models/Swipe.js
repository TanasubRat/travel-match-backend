// models/Swipe.js
const mongoose = require('mongoose');

const swipeSchema = new mongoose.Schema({
  group: { type: mongoose.Schema.Types.ObjectId, ref: 'Group', required: true },
  user:  { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  place: { type: mongoose.Schema.Types.ObjectId, ref: 'Place', required: true },
  liked: { type: Boolean, required: true },
  createdAt: { type: Date, default: Date.now }
});

swipeSchema.index({ group: 1, user: 1, place: 1 }, { unique: true });

module.exports = mongoose.model('Swipe', swipeSchema);

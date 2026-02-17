// models/Group.js
const mongoose = require('mongoose');

const groupMemberSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  role: { type: String, enum: ['host', 'member'], default: 'member' },
  joinedAt: { type: Date, default: Date.now },
  isActive: { type: Boolean, default: true }
}, { _id: false });

const groupFilterSchema = new mongoose.Schema({
  minPriceLevel: { type: Number, min: 0, max: 4 },
  maxPriceLevel: { type: Number, min: 0, max: 4 },
  categories: [{ type: String }],
  customOptions: [{ type: String }], // List of specific place names
  maxDistanceKm: { type: Number },
  openNow: { type: Boolean }
}, { _id: false });

const groupSchema = new mongoose.Schema({
  name: { type: String, required: true },
  city: { type: String, required: true },

  host: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  members: [groupMemberSchema],

  joinCode: { type: String, required: true, unique: true },

  status: {
    type: String,
    enum: ['PENDING', 'READY', 'IN_PROGRESS', 'COMPLETED'],
    default: 'PENDING'
  },

  maxMembers: { type: Number, default: 10 },

  filters: groupFilterSchema,

  finalPlace: { type: mongoose.Schema.Types.ObjectId, ref: 'Place' },
  finalConfirmedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  finalConfirmedAt: { type: Date },

  createdAt: { type: Date, default: Date.now },
  startedAt: { type: Date },
  completedAt: { type: Date },
  expiresAt: { type: Date }
});

groupSchema.index({ joinCode: 1 });
groupSchema.index({ status: 1 });

module.exports = mongoose.model('Group', groupSchema);

// routes/swipeRoutes.js
const express = require('express');
const router = express.Router();
const requireAuth = require('../middleware/auth');
const Swipe = require('../models/Swipe');
const Group = require('../models/Group');
const Place = require('../models/Place');

// Save or update swipe
router.post('/', requireAuth, async (req, res) => {
  try {
    const { groupId, placeId, liked } = req.body;
    if (!groupId || !placeId || typeof liked !== 'boolean') {
      return res.status(400).json({ error: 'groupId, placeId, liked required' });
    }

    const group = await Group.findById(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const isMember = group.members.some(m => m.user.toString() === req.user.id);
    if (!isMember) {
      return res.status(403).json({ error: 'User not in this group' });
    }

    const place = await Place.findById(placeId);
    if (!place) return res.status(404).json({ error: 'Place not found' });

    const swipe = await Swipe.findOneAndUpdate(
      { group: group._id, user: req.user.id, place: place._id },
      { liked, createdAt: new Date() },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    res.status(201).json(swipe);
  } catch (err) {
    console.error('Swipe save error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

// routes/groupRoutes.js
const express = require('express');
const router = express.Router();
const requireAuth = require('../middleware/auth');
const Group = require('../models/Group');
const Swipe = require('../models/Swipe');
const Place = require('../models/Place');
const User = require('../models/User');
const { nanoid } = require('nanoid');

// GET places for group (city + filters)
router.get('/:id/places', requireAuth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const userLat = parseFloat(req.query.lat);
    const userLng = parseFloat(req.query.lng);

    const f = group.filters || {};
    const categories = (f.categories && Array.isArray(f.categories)) ? f.categories.map(String) : [];
    const minRatingNum = (typeof f.minRating === 'number') ? f.minRating : 0;
    const priceLevelNum = (typeof f.priceLevel === 'number') ? f.priceLevel : null; // This is the "Budget" max
    const openNowFlag = f.openNow === true;

    // Base Match Stage
    const matchStage = { isActive: true };
    if (group.city) matchStage.city = { $regex: new RegExp(group.city, 'i') };
    if (openNowFlag) matchStage.isOpenNow = true;
    if (minRatingNum > 0) matchStage.rating = { $gte: minRatingNum };
    // Note: We don't filter hard on priceLevel here because it's part of the score (Budget), 
    // unless you want a hard cap. The screenshot implies score: "Budget = B80 < B100 -> 0.1". 
    // So if it exceeds, score is 0, but maybe not hidden? 
    // "Hard constraint - excludes out-of-budget places" says the screenshot.
    // Okay, I will add a hard filter for budget IF strictly enforcing, but for now I'll use it as a score factor mostly, 
    // or maybe strict filter for "Budget" means PriceLevel <= Preference.
    if (priceLevelNum != null) {
      // If "Hard constraint" is true, we should filter.
      // Let's keep it as filter to be safe/strict as per "Hard constraint" text.
      matchStage.priceLevel = { $lte: priceLevelNum };
    }

    // Custom Options Filter (Exact Name Match)
    if (f.customOptions && Array.isArray(f.customOptions) && f.customOptions.length > 0) {
      // If custom options exist, restrict results to ONLY these places
      matchStage.name = { $in: f.customOptions.map(opt => new RegExp(`^${opt}$`, 'i')) };
    }

    const pipeline = [
      { $match: matchStage },
    ];

    // Distance Calculation (if lat/lng provided)
    // Using rough Euclidean approximation for speed in aggregation without $geoNear requirement (which needs index)
    // Degree to km conversion: ~111km per degree.
    if (!isNaN(userLat) && !isNaN(userLng)) {
      pipeline.push({
        $addFields: {
          // Distance in degrees approx
          distDeg: {
            $sqrt: {
              $add: [
                { $pow: [{ $subtract: ['$latitude', userLat] }, 2] },
                { $pow: [{ $subtract: ['$longitude', userLng] }, 2] }
              ]
            }
          }
        }
      });
      pipeline.push({
        $addFields: {
          distKm: { $multiply: ['$distDeg', 111] }
        }
      });
    } else {
      pipeline.push({ $addFields: { distKm: 10 } }); // Default dist if no location
    }

    // Scoring Project Stage
    pipeline.push({
      $addFields: {
        // R: Rating (0-1)
        normRating: { $divide: [{ $ifNull: ['$rating', 0] }, 5] },

        // P: Popularity (Log scale 0-1). Cap at 1000 reviews.
        // val = log10(userRatingsTotal + 1). Max ~3 (for 1000). So divide by 3.
        normPopularity: {
          $min: [
            { $divide: [{ $log10: { $add: [{ $ifNull: ['$userRatingsTotal', 0] }, 1] } }, 3] },
            1
          ]
        },

        // D: Distance Score (1 - dist/20km). Max 20km.
        normDistance: {
          $max: [
            0,
            { $subtract: [1, { $divide: ['$distKm', 20] }] }
          ]
        },

        // C: Category Score (1 if specific category requested matches, else 0)
        // If group has no categories, this factor might be irrelevant (or always 1?)
        // Screenshot: "Category = Cafe -> 0.1".
        isCategoryMatch: {
          $cond: [
            { $gt: [{ $size: { $setIntersection: ['$categories', categories] } }, 0] },
            1,
            0
          ]
        },

        // B: Budget Score (1 if priceLevel <= budget)
        // Since we applied hard filter above, this might always be 1?
        // Unless priceLevel is missing.
        isBudgetMatch: {
          $cond: [
            { $lte: [{ $ifNull: ['$priceLevel', 99] }, (priceLevelNum || 4)] },
            1,
            0
          ]
        },

        // E: Random (0 - 0.05)
        randomBoost: { $multiply: [{ $rand: {} }, 0.05] }
      }
    });

    // Final WCRA Sum
    // S = 0.35R + 0.25P + 0.20(1-D) + 0.1C + 0.1B + E
    pipeline.push({
      $addFields: {
        finalScore: {
          $add: [
            { $multiply: ['$normRating', 0.35] },
            { $multiply: ['$normPopularity', 0.25] },
            { $multiply: ['$normDistance', 0.20] }, // Note: normDistance is already (1-D) logic
            { $multiply: ['$isCategoryMatch', 0.1] },
            { $multiply: ['$isBudgetMatch', 0.1] },
            '$randomBoost'
          ]
        }
      }
    });

    pipeline.push({ $sort: { finalScore: -1 } });
    pipeline.push({ $limit: 200 });

    const places = await Place.aggregate(pipeline);
    console.log(`[GroupPlaces] WCRA Scoring (Lat:${userLat}, Lng:${userLng}) | Results: ${places.length}`);
    return res.json(places);
  } catch (err) {
    console.error('Get group places error', err);
    res.status(500).json({ error: 'Server error' });
  }
});


function createJoinCode() {
  return nanoid(6).toUpperCase();
}

// CREATE group (with filters)
router.post('/', requireAuth, async (req, res) => {
  try {
    const { name, city, maxMembers, filters } = req.body;
    if (!name || !city) {
      return res.status(400).json({ error: 'Name and city are required' });
    }

    const joinCode = createJoinCode();

    const group = await Group.create({
      name,
      city,
      host: req.user.id,
      joinCode,
      maxMembers: maxMembers || 10,
      members: [{ user: req.user.id, role: 'host' }],
      filters: {
        ...(filters || {}),
        customOptions: req.body.options || [] // Map frontend "options" to backend "customOptions"
      },
      status: 'PENDING'
    });

    // update user.groupId (optional ถ้า schema มี)
    await User.findByIdAndUpdate(req.user.id, { groupId: group._id }).catch(() => { });

    res.status(201).json(group);
  } catch (err) {
    console.error('Create group error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET group detail
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id)
      .populate('host', 'displayName email')
      .populate('members.user', 'displayName email');
    if (!group) return res.status(404).json({ error: 'Group not found' });
    res.json(group);
  } catch (err) {
    console.error('Get group error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PREVIEW by code (optional)
router.get('/code/:joinCode', requireAuth, async (req, res) => {
  try {
    const group = await Group.findOne({ joinCode: req.params.joinCode })
      .populate('host', 'displayName email')
      .populate('members.user', 'displayName email');
    if (!group) return res.status(404).json({ error: 'Group not found' });
    res.json(group);
  } catch (err) {
    console.error('Preview group error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// JOIN by joinCode (ApiService.joinGroupByCode())
router.post('/join', requireAuth, async (req, res) => {
  try {
    const { joinCode } = req.body;
    if (!joinCode) return res.status(400).json({ error: 'joinCode is required' });

    const group = await Group.findOne({ joinCode: joinCode.toUpperCase() });
    if (!group) return res.status(404).json({ error: 'Group not found' });

    if (group.members.length >= group.maxMembers) {
      return res.status(400).json({ error: 'Group is full' });
    }

    const already = group.members.some(
      (m) => m.user.toString() === req.user.id
    );
    if (!already) {
      group.members.push({ user: req.user.id, role: 'member' });
      await group.save();
    }

    await User.findByIdAndUpdate(req.user.id, { groupId: group._id }).catch(() => { });

    res.json(group);
  } catch (err) {
    console.error('Join group error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// START session (host only)
router.post('/:id/start', requireAuth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    if (group.host.toString() !== req.user.id) {
      return res.status(403).json({ error: 'Only host can start session' });
    }

    group.status = 'IN_PROGRESS';
    group.startedAt = new Date();
    await group.save();

    res.json({ ok: true, group });
  } catch (err) {
    console.error('Start session error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// MATCH: aggregate + weighted score
router.get('/:id/match', requireAuth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const totalMembers = group.members.filter(m => m.isActive !== false).length || 1;

    const pipeline = [
      { $match: { group: group._id, liked: true } },
      {
        $group: {
          _id: '$place',
          likesCount: { $sum: 1 },
        }
      },
      {
        $lookup: {
          from: 'places',
          localField: '_id',
          foreignField: '_id',
          as: 'place'
        }
      },
      { $unwind: '$place' },
      { $match: { 'place.isActive': true } }
    ];

    let rows = await Swipe.aggregate(pipeline);

    if (!rows.length) {
      return res.json({ hasMatch: false, matches: [] });
    }

    // Filter for exact matches only (where all members liked the place)
    rows = rows.filter(r => r.likesCount === totalMembers);

    if (!rows.length) {
      return res.json({ hasMatch: false, matches: [] });
    }

    rows = rows.map(r => {
      const coverage = r.likesCount / totalMembers; // Should be 1.0 for exact matches
      const ratingNorm = (r.place.rating || 0) / 5;
      const priceScore = (r.place.priceLevel != null)
        ? 1 - (r.place.priceLevel / 4)
        : 0.5;

      const score = 0.5 * coverage + 0.3 * ratingNorm + 0.2 * priceScore;

      return {
        placeId: r.place._id,
        name: r.place.name,
        city: r.place.city,
        address: r.place.address,
        image: r.place.image,
        rating: r.place.rating,
        priceLevel: r.place.priceLevel,
        likesCount: r.likesCount,
        coverage,
        score,
      };
    });

    // Sort by score from highest to lowest
    rows.sort((a, b) => b.score - a.score);

    res.json({ hasMatch: rows.length > 0, matches: rows });
  } catch (err) {
    console.error('Match error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// CONFIRM final destination
router.post('/:id/confirm', requireAuth, async (req, res) => {
  try {
    const { placeId } = req.body;
    if (!placeId) return res.status(400).json({ error: 'placeId is required' });

    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const isMember = group.members.some(m => m.user.toString() === req.user.id);
    if (!isMember) {
      return res.status(403).json({ error: 'Not a group member' });
    }

    const place = await Place.findById(placeId);
    if (!place) return res.status(404).json({ error: 'Place not found' });

    group.finalPlace = place._id;
    group.finalConfirmedBy = req.user.id;
    group.finalConfirmedAt = new Date();
    group.status = 'COMPLETED';
    group.completedAt = new Date();

    await group.save();

    res.json({ ok: true, group });
  } catch (err) {
    console.error('Confirm error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// LEAVE group
router.post('/:id/leave', requireAuth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const isHost = group.host.toString() === req.user.id;

    if (isHost) {
      // ถ้า host ออก = ลบทั้ง group
      await Swipe.deleteMany({ group: group._id }).catch(() => { });
      await Group.deleteOne({ _id: group._id });
      await User.updateMany({ groupId: group._id }, { $unset: { groupId: "" } }).catch(() => { });
      return res.json({ ok: true, deleted: true });
    }

    // member ออกจาก group
    group.members = group.members.filter(m => m.user.toString() !== req.user.id);
    await group.save();

    await User.findByIdAndUpdate(req.user.id, { $unset: { groupId: "" } }).catch(() => { });

    res.json({ ok: true });
  } catch (err) {
    console.error('Leave group error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE group (host only)
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    if (group.host.toString() !== req.user.id) {
      return res.status(403).json({ error: 'Only host can delete group' });
    }

    await Swipe.deleteMany({ group: group._id }).catch(() => { });
    await Group.deleteOne({ _id: group._id });
    await User.updateMany({ groupId: group._id }, { $unset: { groupId: "" } }).catch(() => { });

    res.json({ ok: true });
  } catch (err) {
    console.error('Delete group error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// INVITE friend by email
router.post('/invite', requireAuth, async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email is required' });

    // 1. Check if inviter is in a group (and maybe is host?)
    // Requirement says "Invite using email... to start swipe with".
    // Usually means adding them to the CURRENT group.

    // Check if inviter has a groupId
    const inviter = await User.findById(req.user.id);
    if (!inviter.groupId) {
      return res.status(400).json({ error: 'You must create or join a group first' });
    }

    const group = await Group.findById(inviter.groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    // 2. Find target user
    const targetUser = await User.findOne({ email: email.trim().toLowerCase() });
    if (!targetUser) {
      return res.status(404).json({ error: 'User with this email not found' });
    }

    // 3. Check if target is already in THIS group
    const isMember = group.members.some(m => m.user.toString() === targetUser.id);
    if (isMember) {
      return res.status(400).json({ error: 'User is already in the group' });
    }

    // 4. Check if group is full
    if (group.members.length >= group.maxMembers) {
      return res.status(400).json({ error: 'Group is full' });
    }

    // 5. Add to group
    // Note: If target user is in ANOTHER group, we might want to warn or just overwrite.
    // For simplicity, we overwrite their groupId and add them here.
    // If they were host of another group, that group might become headless? 
    // Let's assume standard behavior: just move them.

    group.members.push({ user: targetUser.id, role: 'member' });
    await group.save();

    targetUser.groupId = group._id;
    await targetUser.save();

    res.json({ ok: true, message: 'Friend added to group' });
  } catch (err) {
    console.error('Invite friend error', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

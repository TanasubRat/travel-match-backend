const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const auth = require('../middleware/auth');

const router = express.Router();

// 📌 Helper: generate JWT
function generateToken(user) {
  return jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
    expiresIn: '7d'
  });
}
// Update current user (e.g., displayName or groupId)
router.get('/me', auth, async (req, res) => {
  try {
    const uid = req.user?.id || req.user?._id;
    if (!uid) return res.status(401).json({ error: 'Unauthenticated' });

    const u = await User.findById(uid).lean();
    if (!u) return res.status(404).json({ error: 'User not found' });

    return res.json({
      user: {
        _id: u._id,
        email: u.email,
        displayName: u.displayName,
        groupId: u.groupId ?? null,
      },
    });
  } catch (err) {
    console.error('GET /auth/me error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

/** PATCH /api/auth/me
 *  อนุญาตอัปเดต displayName / groupId (null หรือ string)
 */
router.patch('/me', auth, async (req, res) => {
  try {
    const uid = req.user?.id || req.user?._id;
    if (!uid) return res.status(401).json({ error: 'Unauthenticated' });

    const updates = {};
    if (typeof req.body.displayName === 'string') {
      updates.displayName = req.body.displayName.trim();
    }
    if (req.body.groupId === null) {
      updates.groupId = null;
    } else if (typeof req.body.groupId === 'string') {
      updates.groupId = req.body.groupId;
    }

    const user = await User.findByIdAndUpdate(uid, { $set: updates }, { new: true, lean: true });
    if (!user) return res.status(404).json({ error: 'User not found' });

    return res.json({
      user: {
        _id: user._id,
        email: user.email,
        displayName: user.displayName,
        groupId: user.groupId ?? null,
      },
    });
  } catch (err) {
    console.error('PATCH /auth/me error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// 📌 Register
router.post('/register', async (req, res) => {
  try {
    let { email, password, displayName, betaCode } = req.body;

    email = email.trim().toLowerCase();

    if (process.env.BETA_CODE && betaCode !== process.env.BETA_CODE) {
      return res.status(400).json({ error: 'Invalid beta code' });
    }

    let user = await User.findOne({ email });
    if (user) return res.status(400).json({ error: 'Email already in use' });

    // ❌ Don't hash here — let pre('save') in User.js do it
    user = await User.create({
      email,
      password, // raw password
      displayName: displayName?.trim() || '',
      groupId: null
    });

    const token = generateToken(user);

    res.json({
      token,
      user: {
        id: user._id,
        email: user.email,
        displayName: user.displayName,
        groupId: user.groupId
      }
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// 📌 LOGIN
router.post('/login', async (req, res) => {
  try {
    let { email, password } = req.body;
    email = email.trim().toLowerCase(); // normalize email

    console.log("[LOGIN] Attempt:", { email });

    const user = await User.findOne({ email });
    if (!user) {
      console.warn("[LOGIN] No user found for email:", email);
      return res.status(400).json({ error: 'Invalid credentials' });
    }

    console.log("[LOGIN] Found user:", user._id);

    const isMatch = await bcrypt.compare(password, user.password);
    console.log("[LOGIN] Password match result:", isMatch);

    if (!isMatch) {
      console.warn("[LOGIN] Password mismatch for email:", email);
      return res.status(400).json({ error: 'Invalid credentials' });
    }

    const token = generateToken(user);
    console.log("[LOGIN] Login successful for user:", user._id);

    res.json({
      token,
      user: {
        id: user._id,
        email: user.email,
        displayName: user.displayName,
        groupId: user.groupId
      }
    });
  } catch (err) {
    console.error('[LOGIN] Error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

const jwt = require('jsonwebtoken');

module.exports = function (req, res, next) {
  const authHeader = req.header('Authorization');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token, authorization denied' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // decoded should contain { id: "...", ... }
    if (!decoded.id) {
      return res.status(401).json({ error: 'Invalid token payload' });
    }

    req.user = { id: decoded.id }; // ✅ set user id here
    next();
  } catch (err) {
    console.error('JWT Error:', err);
    res.status(401).json({ error: 'Token is not valid' });
  }
  
};

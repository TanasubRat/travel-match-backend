require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');

const placeRoutes = require('./routes/placeRoutes');
const groupRoutes = require('./routes/groupRoutes');
const swipeRoutes = require('./routes/swipeRoutes');
const authRoutes = require('./routes/authRoutes');
const proxyRoutes = require('./routes/proxyRoutes');

const app = express();
app.use(cors());
app.use(express.json());

// Serve local images permanently
app.use('/images', express.static(path.join(__dirname, 'public/images')));

mongoose.connect(process.env.MONGO_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
}).then(() => console.log('✅ MongoDB connected'));

app.use('/api/places', placeRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/swipes', swipeRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/proxy', proxyRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on http://localhost:${PORT}`));

require('dotenv').config();
const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const Place = require('./models/Place');

// Path to the fetched JSON file (relative to backend folder)
const DATA_FILE = path.join(__dirname, '../../google_maps_fetcher/places_data.json');

async function importData() {
    try {
        if (!process.env.MONGO_URI) {
            throw new Error('MONGO_URI is missing in .env');
        }

        console.log('🔌 Connecting to MongoDB...');
        await mongoose.connect(process.env.MONGO_URI);
        console.log('✅ MongoDB connected');

        if (!fs.existsSync(DATA_FILE)) {
            throw new Error(`Data file not found at: ${DATA_FILE}`);
        }

        console.log(`📂 Reading data from: ${DATA_FILE}`);
        const rawData = fs.readFileSync(DATA_FILE, 'utf-8');
        const places = JSON.parse(rawData);

        // Helper function to map Google types to App categories
        const mapCategories = (googleTypes) => {
            if (!googleTypes || !Array.isArray(googleTypes)) return [];
            const mapped = new Set();

            googleTypes.forEach(type => {
                const t = type.toLowerCase();
                if (['tourist_attraction', 'park', 'museum', 'place_of_worship', 'hindu_temple', 'zoo', 'point_of_interest'].includes(t)) {
                    mapped.add('Attraction');
                }
                if (['restaurant', 'food', 'meal_delivery'].includes(t)) {
                    mapped.add('Food & Drink');
                }
                if (['cafe'].includes(t)) {
                    mapped.add('Cafe');
                }
                if (['shopping_mall', 'clothing_store', 'store', 'market'].includes(t)) {
                    mapped.add('Shopping');
                }
                if (['bar', 'night_club'].includes(t)) {
                    mapped.add('Nightlife');
                }
            });
            return Array.from(mapped);
        };

        const processedPlaces = places.map(p => ({
            ...p,
            categories: mapCategories(p.categories),
            mapsUrl: p.externalId ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(p.name)}&query_place_id=${p.externalId}` : null
        }));

        console.log(`📊 Found ${places.length} places in JSON. Mapped categories.`);

        // Clear existing data
        console.log('🗑️  Clearing existing places in database...');
        await Place.deleteMany({});
        console.log('✅ Cleared old data.');

        // Insert new data
        console.log('📥 Importing new data...');
        await Place.insertMany(processedPlaces);

        console.log(`🎉 Import successful! Added ${processedPlaces.length} places.`);
        process.exit(0);
    } catch (err) {
        console.error('❌ Error:', err);
        process.exit(1);
    }
}

importData();

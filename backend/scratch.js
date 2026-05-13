const mongoose = require('mongoose');
const express = require('express');

console.log("Connecting...");
mongoose.connect('mongodb+srv://bomketar2002:s3AteqWv1bZz6sYl@cluster0.p0t8t.mongodb.net/travel_match_db?retryWrites=true&w=majority', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(async () => {
    console.log("Connected.");
    const Place = require('./routes/../models/Place');
    const Swipe = require('./routes/../models/Swipe');
    const Group = require('./routes/../models/Group');

    const group = await Group.findOne();
    if (!group) return console.log("No group found");

    const userLat = 13.736717; // Bangkok
    const userLng = 100.523186;

    const pipeline = [
      { $match: { } }
    ];

    if (!isNaN(userLat) && !isNaN(userLng)) {
      const LAT_DEG_TO_KM = 111.32;
      const cosLat = Math.cos(userLat * (Math.PI / 180));
      const ROUTING_FACTOR = 1.35; 

      pipeline.push({
        $addFields: {
          straightLineKm: {
            $sqrt: {
              $add: [
                { $pow: [ { $multiply: [ { $subtract: [{ $ifNull: ['$latitude', 0] }, userLat] }, LAT_DEG_TO_KM ] }, 2 ] },
                { $pow: [ { $multiply: [ { $subtract: [{ $ifNull: ['$longitude', 0] }, userLng] }, LAT_DEG_TO_KM * cosLat ] }, 2 ] }
              ]
            }
          }
        }
      });
      pipeline.push({
        $addFields: {
          distKm: { $multiply: ['$straightLineKm', ROUTING_FACTOR] }
        }
      });
    }

    const res = await Place.aggregate(pipeline).limit(5);
    console.log(res.map(r => ({ name: r.name, straightLineKm: r.straightLineKm, distKm: r.distKm })));
    process.exit(0);
})
.catch(e => console.error(e));

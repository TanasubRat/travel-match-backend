'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "8f8b11911c8fa752085b83fe82ba64e1",
"assets/AssetManifest.bin.json": "aea83b5bc58e202f0354e00824a3e632",
"assets/AssetManifest.json": "36bc673953cf3ee579188dd155442fda",
"assets/assets/places/1.jpg": "3bc9e5311bf033569c838f8264a09d44",
"assets/assets/places/10.jpg": "4790c39bff1254b426af1206e29cfe8d",
"assets/assets/places/11.jpg": "b902c6e256d263cadadec180f57345f2",
"assets/assets/places/12.jpg": "1d37cd1ea46a4ef026f46be7ed5d7075",
"assets/assets/places/13.jpg": "422eab95b4288027be38ee54e6d6c6e3",
"assets/assets/places/14.jpg": "d488b3fecb735110215dfdfd6c4c3d79",
"assets/assets/places/15.jpg": "983b79002bd34f8cb60d4679a8c87eda",
"assets/assets/places/16.jpg": "f9d684cb5d0a68201d1d1a8854367ce8",
"assets/assets/places/17.jpg": "91da33383fbacd96869f2940f80c2cb2",
"assets/assets/places/18.jpg": "7e55b07bda55b0946ba70fbc8319a1f2",
"assets/assets/places/19.jpg": "b0577156dae5855218b7cb108d4f09ed",
"assets/assets/places/2.jpg": "bd2b78d4d78b945cd4565854f79b11d8",
"assets/assets/places/20.jpg": "331b5f31bdf68810b84ed334eefa9fc0",
"assets/assets/places/21.jpg": "f12ef79fc4e8146aea500ff53346ac95",
"assets/assets/places/22.jpg": "47629661e010b900f16e84308fffb4be",
"assets/assets/places/23.jpg": "710b7a1991216356e2bd06a6e54977e5",
"assets/assets/places/24.jpg": "0d7e5265be0be089df1cb1fd45672dfa",
"assets/assets/places/25.jpg": "256d7e81910b596130e5b73d69477657",
"assets/assets/places/3.jpg": "4073e6883c0cf91a70833509094d1384",
"assets/assets/places/4.jpg": "693402591479e4df14c53bc786e23a35",
"assets/assets/places/5.jpg": "48e4f15c930af9e3002659aacdd6000b",
"assets/assets/places/6.jpg": "2ba3c06576226315012a0ba377c40946",
"assets/assets/places/7.jpg": "e4279d045c0a1505d4a2431409651cc2",
"assets/assets/places/8.jpg": "012f5b2504cedc20dfe9205b0555e98e",
"assets/assets/places/9.jpg": "c86db2162e7cb3f24708db3ef43c7462",
"assets/assets/places/bangkok.png": "8d1a51a5a3fea13f5ba49161c73bd3ae",
"assets/assets/places/chiang_mai.png": "71bfb745a9d020259a87029de5340e88",
"assets/assets/places/custom.png": "9a46376758d383c6bac7605d2fc6b4ed",
"assets/assets/places/Mahidol.jpg": "2a4ed6de48b9eb500b1af25e46825217",
"assets/assets/places/phuket.png": "2dd3fb3bef8eb45f956915cfb3150226",
"assets/assets/swipe_icon.png": "84f3224a4bdcdec9d64645414a82e428",
"assets/assets/swipe_logo.png": "2590d598f06ad1a5089ad8a715713222",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "46f8e3d36737f1d8b822c3b3499783bb",
"assets/NOTICES": "777d36168e60747b69cee1996f466b6a",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "1284d68b1dee083f671454387a1c22df",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "e50860500f74e43d61346d131851c333",
"/": "e50860500f74e43d61346d131851c333",
"main.dart.js": "f3f8729a127d9d4f732a6c5eb513b0fe",
"manifest.json": "7b149e76952fd848a688bc9e84b1a8db",
"version.json": "49d0e00e5a5c980c24783defde70881d"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}

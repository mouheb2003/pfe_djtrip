const { GoogleGenerativeAI } = require('@google/generative-ai');
const axios = require('axios');
const cloudinary = require('cloudinary').v2;

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Configure Cloudinary (using the same env vars as the main config)
cloudinary.config({
  cloud_name: process.env.CLOUD_NAME,
  api_key: process.env.API_KEY,
  api_secret: process.env.API_SECRET,
});

// Activity category mappings for better fallback prompts - 13 macro-categories
const CATEGORY_PROMPT_TEMPLATES = {
  // 1. ADVENTURE & EXTREME SPORTS
  'Adventure': {
    subject: 'adventure participants',
    action: 'engaging in extreme sport or adventure activity',
    location: 'adventure destination or extreme sports venue',
    mood: 'thrilling, dynamic, adrenaline-fueled',
    elements: 'people, action equipment, dynamic motion, safety gear',
    visualStyle: 'action shot, dynamic motion, cinematic adrenaline, POV GoPro style'
  },
  
  // 2. WATER ACTIVITIES
  'Water': {
    subject: 'water sports participants',
    action: 'engaging in water or marine activity',
    location: 'beach, ocean, lake, or water sports venue',
    mood: 'refreshing, exciting, aquatic',
    elements: 'people, water equipment, wet gear, water splashes',
    visualStyle: 'crystal clear water, underwater cinematic light, tropical ocean, slow motion waves'
  },
  
  // 3. WINTER & MOUNTAIN
  'Winter': {
    subject: 'winter sports participants',
    action: 'engaging in winter or mountain activity',
    location: 'snowy mountain, ski resort, or alpine destination',
    mood: 'energetic, cold, alpine',
    elements: 'people, winter gear, snow equipment, cold weather clothing',
    visualStyle: 'snow cinematic, cold atmosphere, alpine landscape, blue ice glacier'
  },
  
  // 4. CULTURAL & HERITAGE
  'Culture': {
    subject: 'cultural experience participants',
    action: 'experiencing cultural or historical activity',
    location: 'historic site, museum, temple, or cultural venue',
    mood: 'educational, immersive, authentic',
    elements: 'people, traditional clothing, cultural artifacts, ancient architecture',
    visualStyle: 'ancient architecture, golden historical light, cultural immersion, traditional clothing'
  },
  
  // 5. FOOD & GASTRONOMY
  'Gastronomy': {
    subject: 'food enthusiasts',
    action: 'engaging in culinary or food experience',
    location: 'restaurant, kitchen, market, or dining venue',
    mood: 'delightful, appetizing, gastronomic',
    elements: 'people, food dishes, culinary tools, dining setting',
    visualStyle: 'close-up food photography, warm lighting, steam texture detail, authentic cuisine'
  },
  
  // 6. WELLNESS & SPA
  'Wellness': {
    subject: 'wellness participants',
    action: 'engaging in relaxation or wellness activity',
    location: 'spa, hammam, thermal bath, or wellness center',
    mood: 'calm, serene, peaceful',
    elements: 'people, spa equipment, relaxation gear, wellness accessories',
    visualStyle: 'soft light, calm atmosphere, luxury spa interior, steam aesthetic'
  },
  
  // 7. ENTERTAINMENT & NIGHTLIFE
  'Entertainment': {
    subject: 'entertainment participants',
    action: 'engaging in entertainment or nightlife activity',
    location: 'concert venue, club, theater, or entertainment district',
    mood: 'vibrant, energetic, exciting',
    elements: 'people, stage equipment, lighting, crowd',
    visualStyle: 'neon lights, crowd energy, nightlife cinematic, vibrant colors'
  },
  
  // 8. NATURE & WILDLIFE
  'Nature': {
    subject: 'nature experience participants',
    action: 'engaging in wildlife or nature activity',
    location: 'forest, jungle, desert, safari park, or nature reserve',
    mood: 'awe-inspiring, natural, wild',
    elements: 'people, wildlife, nature gear, binoculars, cameras',
    visualStyle: 'wild animals, natural sunlight, documentary style, national geographic look'
  },
  
  // 9. URBAN & CITY TOURISM
  'Urban': {
    subject: 'city tourism participants',
    action: 'exploring urban or city attractions',
    location: 'city center, downtown, or urban landmark',
    mood: 'cosmopolitan, modern, vibrant',
    elements: 'people, city gear, maps, cameras',
    visualStyle: 'aerial city view, modern architecture, night skyline, urban cinematic'
  },
  
  // 10. SPORTS TOURISM
  'Sport': {
    subject: 'sports tourism participants',
    action: 'engaging in sports or athletic activity',
    location: 'stadium, sports venue, or athletic facility',
    mood: 'competitive, energetic, athletic',
    elements: 'people, sports equipment, athletic wear, team gear',
    visualStyle: 'action sports, stadium crowd, energetic motion, competition moment'
  },
  
  // 11. TRANSPORT EXPERIENCE TOURISM
  'Transport': {
    subject: 'transport experience participants',
    action: 'engaging in scenic travel or transport activity',
    location: 'scenic route, train, cable car, or travel destination',
    mood: 'adventurous, scenic, journey-oriented',
    elements: 'people, transport vehicle, travel gear, luggage',
    visualStyle: 'cinematic travel POV, moving landscape, journey aesthetic, golden hour road'
  },
  
  // 12. BEACH & COASTAL
  'Beach': {
    subject: 'beach participants',
    action: 'engaging in beach or coastal activity',
    location: 'beach, coast, island, or tropical destination',
    mood: 'relaxing, tropical, paradise',
    elements: 'people, beach gear, swimwear, coastal accessories',
    visualStyle: 'turquoise water, palm trees, sunset beach, relaxing paradise'
  },
  
  // 13. PHOTOGRAPHY-DRIVEN TOURISM
  'Photography': {
    subject: 'photography tour participants',
    action: 'engaging in photography or sightseeing activity',
    location: 'scenic viewpoint, landmark, or photogenic destination',
    mood: 'artistic, creative, observational',
    elements: 'people, cameras, photography equipment, tripods',
    visualStyle: 'ultra wide angle, 8K realistic, depth of field, cinematic framing'
  },
  
  // Default fallback
  'Other': {
    subject: 'tourism activity participants',
    action: 'engaging in tourism activity',
    location: 'tourism destination or venue',
    mood: 'enjoyable, engaging, memorable',
    elements: 'people, activity equipment, setting',
    visualStyle: 'cinematic, travel photography style'
  }
};

// Location-specific enhancements for Djerba/Mediterranean
const LOCATION_ENHANCEMENTS = {
  default: 'Mediterranean coastal setting, sunny weather, blue sky',
  beach: 'beautiful sandy beach, turquoise Mediterranean water, palm trees',
  desert: 'golden sand dunes, clear sky, warm sunlight',
  forest: 'Mediterranean pine forest, dappled sunlight, natural pathways',
  mountain: 'scenic hilltop view, Mediterranean landscape in background'
};

/**
 * Score prompt quality based on required elements
 * @param {string} prompt - The prompt to score
 * @returns {Object} - Score object with details
 */
function scorePromptQuality(prompt) {
  const lowerPrompt = prompt.toLowerCase();
  let score = 0;
  const missingElements = [];
  
  // Required elements
  const requiredElements = [
    { pattern: /\b(people|person|group|tourist|visitor|participant)\b/, name: 'people presence' },
    { pattern: /\b(activity|action|doing|engaging|performing)\b/, name: 'activity action' },
    { pattern: /\b(cinematic|photography|professional|high quality)\b/, name: 'quality indicator' },
    { pattern: /\b(4k|ultra realistic|detailed|sharp)\b/, name: 'resolution indicator' },
    { pattern: /\b(lighting|light|illuminated|shadows)\b/, name: 'lighting description' },
    { pattern: /\b(composition|framed|angle|perspective)\b/, name: 'composition' }
  ];
  
  requiredElements.forEach(element => {
    if (element.pattern.test(lowerPrompt)) {
      score += 15;
    } else {
      missingElements.push(element.name);
    }
  });
  
  // Length check (prompts should be substantial)
  if (prompt.length > 100) score += 10;
  if (prompt.length > 200) score += 5;
  
  // Negative prompt check
  if (lowerPrompt.includes('no') || lowerPrompt.includes('without') || lowerPrompt.includes('avoid')) {
    score += 10;
  }
  
  return {
    score: Math.min(score, 100),
    isAcceptable: score >= 60,
    missingElements
  };
}

/**
 * Generate optimized prompt for image generation using Gemini AI with structured output
 * @param {string} title - Activity title
 * @param {string} description - Activity description
 * @param {string} category - Activity category (optional)
 * @returns {Promise<Object>} - Object with prompt, score, and metadata
 */
async function generateOptimizedPrompt(title, description, category = 'Other') {
  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = `
You are an expert prompt engineer for AI image generation specializing in travel and activity photography.

TASK: Create a highly structured, deterministic Stable Diffusion prompt for the following activity:

TITLE: ${title}
DESCRIPTION: ${description}
CATEGORY: ${category}

REQUIREMENTS - Your output MUST follow this EXACT structure:

=== MAIN SUBJECT ===
[Describe the main subject clearly - MUST include people/tourists/participants engaged in the activity]

=== LOCATION ===
[Describe the location - be specific about the setting, environment, and Mediterranean/Djerba context]

=== ACTIVITY ===
[Describe what the people are doing - specific action verbs, clear activity representation]

=== MOOD ===
[Describe the emotional atmosphere - joyful, adventurous, relaxed, exciting, etc.]

=== LIGHTING ===
[Describe lighting conditions - golden hour, bright daylight, soft shadows, etc.]

=== COMPOSITION ===
[Describe camera angle and composition - wide angle, close-up, rule of thirds, etc.]

=== STYLE ===
[Use EXACTLY: "cinematic, ultra realistic, travel photography, 4K, professional photography, high detail, sharp focus"]

=== NEGATIVE PROMPT ===
[Use EXACTLY: "no text, no watermark, no logos, no blur, no distortion, no cartoon, no illustration, no abstract, no peopleless scenes, no empty landscapes"]

CRITICAL RULES:
1. MUST include visible people/tourists/participants in every image
2. MUST show clear activity/action - no static or passive poses
3. MUST avoid empty landscapes or scenes without people
4. MUST be specific and concrete - no vague descriptions
5. MUST use English language only
6. Keep each section concise but descriptive
7. Total prompt should be 150-250 words

Return ONLY the structured prompt above, nothing else.
`;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    let rawPrompt = response.text().trim();
    
    // Clean up the prompt - remove section headers if present
    rawPrompt = rawPrompt
      .replace(/===.*===/g, '')
      .replace(/\n\n+/g, ', ')
      .replace(/\n/g, ', ')
      .trim();
    
    console.log('[AI Image Generator] Raw Gemini prompt:', rawPrompt);
    
    // Validate and score the prompt
    const qualityScore = scorePromptQuality(rawPrompt);
    console.log('[AI Image Generator] Prompt quality score:', qualityScore.score, '/ 100');
    
    if (!qualityScore.isAcceptable) {
      console.log('[AI Image Generator] Prompt quality below threshold, using structured fallback');
      console.log('[AI Image Generator] Missing elements:', qualityScore.missingElements.join(', '));
      return generateStructuredFallbackPrompt(title, description, category);
    }
    
    return {
      prompt: rawPrompt,
      score: qualityScore.score,
      method: 'gemini',
      isValid: true
    };
  } catch (error) {
    console.error('[AI Image Generator] Error generating optimized prompt with Gemini:', error.message);
    console.log('[AI Image Generator] Using structured fallback prompt generation');
    return generateStructuredFallbackPrompt(title, description, category);
  }
}

/**
 * Generate a structured fallback prompt using category templates with specific keywords
 * @param {string} title - Activity title
 * @param {string} description - Activity description
 * @param {string} category - Activity category
 * @returns {Object} - Object with prompt, score, and metadata
 */
function generateStructuredFallbackPrompt(title, description, category = 'Other') {
  const template = CATEGORY_PROMPT_TEMPLATES[category] || CATEGORY_PROMPT_TEMPLATES['Other'];
  
  // Extract specific activity keywords from title and description
  const specificKeywords = [];
  const combinedText = `${title} ${description}`.toLowerCase();
  
  // Comprehensive tourism taxonomy keywords - 13 macro-categories
  const activityKeywords = [
    // 1. ADVENTURE & EXTREME SPORTS
    'quad', 'quad bike', 'atv', 'off-road', 'desert driving',
    'skydiving', 'paragliding', 'zipline', 'rafting', 'white water',
    'mountain climbing', 'trekking', 'bungee jumping', 'canyoning',
    'abseiling', 'cliff', 'rock climbing', 'adrenaline',
    
    // 2. WATER ACTIVITIES
    'scuba diving', 'snorkeling', 'jet ski', 'kayaking', 'canoe',
    'surfing', 'yacht', 'cruising', 'sailing', 'sailboat', 'catamaran',
    'water ski', 'wakeboard', 'submarine', 'aquarium',
    'crystal clear water', 'underwater', 'tropical ocean',
    
    // 3. WINTER & MOUNTAIN
    'skiing', 'snowboarding', 'glacier trekking', 'ice climbing',
    'camping in mountains', 'snow', 'ice', 'alpine', 'glacier',
    'blue ice', 'snow cinematic', 'cold atmosphere',
    
    // 4. CULTURAL & HERITAGE
    'medina', 'souk', 'market', 'bazaar', 'craft',
    'castle', 'ruins', 'temple', 'museum', 'gallery',
    'art', 'exhibition', 'monument', 'palace', 'fortress',
    'archaeological', 'church', 'cathedral', 'mosque', 'shrine',
    'historic', 'heritage', 'ancient', 'traditional', 'cultural',
    'ancient architecture', 'golden historical light',
    
    // 5. FOOD & GASTRONOMY
    'street food', 'fine dining', 'chef experience', 'wine tasting',
    'vineyard', 'couscous', 'tajine', 'cooking', 'cuisine',
    'local markets', 'restaurant', 'cafe', 'bistro', 'bakery',
    'close-up food', 'warm lighting', 'steam', 'texture detail',
    'authentic cuisine', 'olive oil', 'spice', 'herb',
    
    // 6. WELLNESS & SPA
    'hammam', 'massage', 'spa', 'sauna', 'thermal baths',
    'yoga retreat', 'wellness', 'soft light', 'calm atmosphere',
    'luxury spa interior', 'steam aesthetic', 'peaceful', 'serene',
    
    // 7. ENTERTAINMENT & NIGHTLIFE
    'concert', 'festival', 'club', 'theater', 'night market',
    'neon lights', 'crowd energy', 'nightlife', 'vibrant colors',
    'show', 'performance', 'nightclub', 'bar', 'pub', 'disco',
    
    // 8. NATURE & WILDLIFE
    'desert safari', 'jungle', 'wildlife safari', 'oasis',
    'forest', 'rainforest', 'park', 'reserve', 'botanical garden',
    'zoo', 'wild animals', 'natural sunlight', 'documentary style',
    'national geographic', 'nature', 'animal', 'bird',
    
    // 9. URBAN & CITY TOURISM
    'skyline', 'architecture', 'tour', 'shopping', 'sightseeing',
    'aerial city view', 'modern architecture', 'night skyline',
    'urban cinematic', 'city', 'downtown', 'building', 'tower', 'bridge',
    
    // 10. SPORTS TOURISM
    'football', 'stadium', 'tennis', 'golf', 'gym', 'marathon',
    'action sports', 'stadium crowd', 'energetic motion', 'competition',
    'soccer', 'basketball', 'arena', 'court', 'field',
    
    // 11. TRANSPORT EXPERIENCE
    'cable car', 'train', 'scenic ride', 'gondola', 'ferry',
    'road trip', 'cinematic travel POV', 'moving landscape',
    'journey aesthetic', 'golden hour road', 'tram', 'bus', 'taxi', 'metro',
    'funicular',
    
    // 12. BEACH & COASTAL
    'tropical beach', 'sunbathing', 'island', 'coral reefs',
    'turquoise water', 'palm trees', 'sunset beach', 'relaxing paradise',
    'coast', 'snorkeling', 'beach volleyball', 'beach soccer',
    'sun', 'sunset', 'sunrise', 'palm', 'coconut',
    
    // 13. PHOTOGRAPHY-DRIVEN
    'panoramic', 'drone shots', 'cinematic landscapes', 'seascapes',
    'travel photography', 'POV', 'ultra wide angle', '8K realistic',
    'depth of field', 'cinematic framing', 'photography', 'photo',
    
    // Additional terms
    'bike', 'bicycle', 'motorcycle', 'horse', 'camel', 'donkey',
    'jeep', '4x4', 'truck', 'car', 'boat', 'parachute', 'hot air balloon',
    'balloon', 'surfboard', 'windsurf', 'kitesurf', 'paddleboard',
    'dive', 'fish', 'fishing', 'waterfall', 'snowshoe', 'sleigh', 'igloo',
    'peak', 'summit', 'hike', 'trek', 'trail', 'walk', 'camp', 'tent',
    'rv', 'caravan', 'craft', 'wine', 'winery', 'tasting', 'sommelier',
    'food', 'dish', 'meal', 'dining', 'gourmet', 'pizza', 'pasta', 'sushi',
    'meditation', 'thermal', 'hot spring', 'relax', 'relaxation',
    'music', 'cinema', 'movie', 'casino', 'desert', 'dune', 'canyon', 'valley',
    'town', 'village', 'mall', 'boutique', 'store', 'guide', 'landmark',
    'pool', 'fitness', 'swim', 'swimming'
  ];
  
  // Find matching keywords with prioritization
  activityKeywords.forEach(keyword => {
    if (combinedText.includes(keyword)) {
      // Prioritize multi-word terms over single words
      if (keyword.includes(' ')) {
        specificKeywords.unshift(keyword); // Add to beginning
      } else {
        specificKeywords.push(keyword);
      }
    }
  });
  
  // Special handling for quad bikes - ensure specificity
  if (combinedText.includes('quad') && !combinedText.includes('quad bike') && !combinedText.includes('atv')) {
    // If "quad" is present but not "quad bike" or "atv", add both for clarity
    specificKeywords.unshift('quad bike', 'atv');
  }
  
  // Extract location hints from description
  let locationEnhancement = LOCATION_ENHANCEMENTS.default;
  const lowerDesc = description.toLowerCase();
  if (lowerDesc.includes('beach') || lowerDesc.includes('sea') || lowerDesc.includes('water')) {
    locationEnhancement = LOCATION_ENHANCEMENTS.beach;
  } else if (lowerDesc.includes('desert') || lowerDesc.includes('sand')) {
    locationEnhancement = LOCATION_ENHANCEMENTS.desert;
  } else if (lowerDesc.includes('forest') || lowerDesc.includes('tree') || lowerDesc.includes('nature')) {
    locationEnhancement = LOCATION_ENHANCEMENTS.forest;
  } else if (lowerDesc.includes('mountain') || lowerDesc.includes('hill') || lowerDesc.includes('view')) {
    locationEnhancement = LOCATION_ENHANCEMENTS.mountain;
  }
  
  // Build structured prompt with specific keywords and visual style
  const keywordString = specificKeywords.length > 0 ? specificKeywords.join(', ') + ', ' : '';
  const visualStyle = template.visualStyle || 'cinematic, travel photography style';
  const structuredPrompt = 
    `${keywordString}${template.subject}, ${template.action}, ${template.location}, ${locationEnhancement}, ` +
    `${template.mood}, ${template.elements}, ` +
    `${visualStyle}, ` +
    `visible people, tourists, participants in the scene, multiple people engaging in activity, ` +
    `photorealistic, hyperrealistic, ultra realistic, extremely detailed, realistic skin texture, realistic clothing, realistic lighting, realistic shadows, ` +
    `cinematic, ultra realistic, travel photography, 8K, professional photography, high detail, sharp focus, ` +
    `beautiful lighting, natural colors, wide angle composition, ` +
    `no text, no watermark, no logos, no blur, no distortion, no cartoon, no illustration, no abstract, no peopleless scenes, no empty landscapes, no landscapes without people`;
  
  const qualityScore = scorePromptQuality(structuredPrompt);
  
  console.log('[AI Image Generator] Structured fallback prompt:', structuredPrompt);
  console.log('[AI Image Generator] Extracted keywords:', specificKeywords.join(', ') || 'none');
  console.log('[AI Image Generator] Fallback prompt quality score:', qualityScore.score, '/ 100');
  
  return {
    prompt: structuredPrompt,
    score: qualityScore.score,
    method: 'structured_fallback',
    isValid: qualityScore.isAcceptable
  };
}

/**
 * Generate image using Pollinations.ai (free, no API key)
 * @param {string} prompt - Optimized prompt for image generation
 * @param {string} title - Activity title for seed generation
 * @param {string} description - Activity description
 * @param {number} count - Number of images to generate (default: 2)
 * @returns {Promise<Object>} - Object with image buffers and metadata
 */
async function generateImageWithPollinations(prompt, title, description, count = 2) {
  try {
    console.log(`[AI Image Generator] Calling Pollinations.ai to generate ${count} images...`);
    console.log(`[AI Image Generator] Prompt length: ${prompt.length} characters`);

    // Use a seed for consistency (based on title hash)
    const seed = title.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0) % 1000000;
    console.log(`[AI Image Generator] Using seed: ${seed} for consistency`);

    // Encode prompt once for all images
    const encodedPrompt = encodeURIComponent(prompt);

    // Create all image fetch promises in parallel
    const imagePromises = [];
    
    for (let i = 0; i < count; i++) {
      // Create unique seed for each image
      const imageSeed = seed + i * 1000;
      
      // Pollinations.ai URL - free, no API key needed
      const pollinationsUrl = `https://image.pollinations.ai/prompt/${encodedPrompt}?width=1024&height=1024&seed=${imageSeed}&nologo=true&enhance=true`;
      
      console.log(`[AI Image Generator] Starting fetch for image ${i + 1} (seed: ${imageSeed})...`);
      
      const promise = axios.get(pollinationsUrl, {
        responseType: 'arraybuffer',
        timeout: 90000, // 90 second timeout per image
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      }).then(response => {
        console.log(`[AI Image Generator] Image ${i + 1} generated successfully (seed: ${imageSeed})`);
        return { index: i, data: response.data };
      }).catch(error => {
        console.error(`[AI Image Generator] Failed to fetch image ${i + 1}:`, error.message);
        return null;
      });
      
      imagePromises.push(promise);
    }

    // Wait for all images to complete
    const results = await Promise.all(imagePromises);
    
    // Filter out failed requests and sort by index
    const imageBuffers = results
      .filter(result => result !== null)
      .sort((a, b) => a.index - b.index)
      .map(result => result.data);

    console.log(`[AI Image Generator] ${imageBuffers.length} images generated successfully via Pollinations.ai`);
    return {
      buffers: imageBuffers,
      method: 'pollinations',
      metadata: {
        seed,
        service: 'Pollinations.ai',
        width: 1024,
        height: 1024
      }
    };
  } catch (error) {
    console.error('[AI Image Generator] Error generating image with Pollinations.ai:', error.message);
    
    if (error.response) {
      console.error('[AI Image Generator] API Response Status:', error.response.status);
    }
    
    console.log('[AI Image Generator] Using category-based placeholder fallback');
    return generateCategoryPlaceholderImages(count, title, description);
  }
}

/**
 * Generate category-based placeholder images using reliable services
 * @param {number} count - Number of placeholder images to generate
 * @param {string} title - Activity title
 * @param {string} description - Activity description
 * @returns {Promise<Object>} - Object with image URLs and metadata
 */
async function generateCategoryPlaceholderImages(count = 4, title = '', description = '') {
  try {
    // Determine category from description for better matching
    let category = 'travel';
    const lowerDesc = description.toLowerCase();
    
    if (lowerDesc.includes('beach') || lowerDesc.includes('sea') || lowerDesc.includes('swim')) {
      category = 'beach';
    } else if (lowerDesc.includes('mountain') || lowerDesc.includes('hike')) {
      category = 'mountain';
    } else if (lowerDesc.includes('food') || lowerDesc.includes('eat') || lowerDesc.includes('restaurant')) {
      category = 'food';
    } else if (lowerDesc.includes('culture') || lowerDesc.includes('museum') || lowerDesc.includes('historic')) {
      category = 'architecture';
    } else if (lowerDesc.includes('adventure') || lowerDesc.includes('sport')) {
      category = 'adventure';
    }
    
    console.log(`[AI Image Generator] Using category: ${category} for placeholder images`);
    
    // Use Picsum for reliable placeholder images with category-specific seeds
    const imageUrls = [];
    const baseSeed = title.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    
    for (let i = 0; i < count; i++) {
      // Use different seeds for variety but consistent for same title
      const seed = baseSeed + i * 1000;
      const imageUrl = `https://picsum.photos/seed/${seed}/1024/1024`;
      imageUrls.push(imageUrl);
    }
    
    console.log(`[AI Image Generator] Generated ${imageUrls.length} placeholder image URLs`);
    return {
      urls: imageUrls,
      method: 'placeholder',
      metadata: {
        category,
        seed: baseSeed,
        note: 'Using placeholder images - AI generation unavailable'
      }
    };
  } catch (error) {
    console.error('[AI Image Generator] Error generating placeholder images:', error.message);
    
    // Final fallback to generic URLs
    const imageUrls = [];
    for (let i = 0; i < count; i++) {
      imageUrls.push(`https://picsum.photos/1024/1024?random=${Date.now()}_${i}`);
    }
    
    return {
      urls: imageUrls,
      method: 'placeholder_fallback',
      metadata: {
        note: 'Using random placeholder images - all methods failed'
      }
    };
  }
}


/**
 * Upload multiple images to Cloudinary with enhanced settings
 * @param {Buffer[]} imageBuffers - Array of image buffers
 * @returns {Promise<string[]>} - Array of Cloudinary image URLs
 */
async function uploadToCloudinary(imageBuffers) {
  try {
    const uploadPromises = imageBuffers.map((buffer, index) => {
      return new Promise((resolve, reject) => {
        cloudinary.uploader.upload_stream(
          {
            resource_type: 'image',
            folder: 'djtrip/activities',
            quality: 'auto:best',
            fetch_format: 'auto',
            public_id: `activity_${Date.now()}_${index}`,
            transformation: [
              { width: 1024, height: 1024, crop: 'fill', quality: 'auto:best' },
              { fetch_format: 'auto' }
            ]
          },
          (error, result) => {
            if (error) {
              console.error(`Error uploading image ${index} to Cloudinary:`, error);
              reject(error);
            } else {
              console.log(`[AI Image Generator] Image ${index} uploaded to Cloudinary:`, result.secure_url);
              resolve(result.secure_url);
            }
          }
        ).end(buffer);
      });
    });

    const imageUrls = await Promise.all(uploadPromises);
    console.log(`[AI Image Generator] All ${imageUrls.length} images uploaded successfully with optimization`);
    return imageUrls;
  } catch (error) {
    console.error('[AI Image Generator] Error in uploadToCloudinary:', error);
    throw new Error('Failed to upload images');
  }
}

/**
 * Main controller function to generate activity images with enhanced pipeline
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
async function generateActivityImage(req, res) {
  const startTime = Date.now();
  let responseSent = false;
  
  try {
    const { title, description, category } = req.body;

    console.log('[AI Image Generator] ===== START =====');
    console.log('[AI Image Generator] Title:', title);
    console.log('[AI Image Generator] Description:', description);
    console.log('[AI Image Generator] Category:', category || 'Not provided');

    // Validate input
    if (!title || !description) {
      console.log('[AI Image Generator] Validation failed: Missing title or description');
      if (!responseSent) {
        responseSent = true;
        return res.status(400).json({
          success: false,
          message: 'Title and description are required',
        });
      }
      return;
    }

    if (title.length < 3 || description.length < 10) {
      console.log('[AI Image Generator] Validation failed: Title too short or description too short');
      if (!responseSent) {
        responseSent = true;
        return res.status(400).json({
          success: false,
          message: 'Title must be at least 3 characters and description at least 10 characters',
        });
      }
      return;
    }

    console.log('[AI Image Generator] Validation passed');

    // Step 1: Generate optimized prompt using Gemini with validation
    console.log('[AI Image Generator] Step 1: Generating optimized prompt with validation...');
    const promptResult = await generateOptimizedPrompt(title, description, category || 'Other');
    console.log('[AI Image Generator] Step 1 complete - Prompt method:', promptResult.method);
    console.log('[AI Image Generator] Step 1 complete - Prompt score:', promptResult.score, '/ 100');
    console.log('[AI Image Generator] Step 1 complete - Prompt length:', promptResult.prompt.length, 'characters');
    
    if (!promptResult.isValid) {
      console.log('[AI Image Generator] Warning: Prompt quality is below optimal threshold');
    }

    // Step 2: Generate images using Pollinations.ai (free, no API key)
    const imageCount = 3; // Increased to 3 for better variety
    console.log(`[AI Image Generator] Step 2: Generating ${imageCount} images with Pollinations.ai...`);
    
    const generationResult = await generateImageWithPollinations(
      promptResult.prompt, 
      title, 
      description, 
      imageCount
    );
    
    console.log(`[AI Image Generator] Step 2 complete - Generation method:`, generationResult.method);
    
    let imageUrls;
    let finalMethod;
    
    if (generationResult.method === 'pollinations') {
      // Step 3: Upload AI-generated images to Cloudinary
      console.log('[AI Image Generator] Step 3: Uploading AI-generated images to Cloudinary...');
      imageUrls = await uploadToCloudinary(generationResult.buffers);
      finalMethod = 'ai_generated';
      console.log(`[AI Image Generator] Step 3 complete - ${imageUrls.length} images uploaded to Cloudinary`);
    } else {
      // Use placeholder URLs directly
      imageUrls = generationResult.urls;
      finalMethod = 'placeholder';
      console.log(`[AI Image Generator] Using ${imageUrls.length} placeholder image URLs`);
    }
    
    const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);
    
    // Return success response with comprehensive metadata
    console.log('[AI Image Generator] ===== SUCCESS =====');
    console.log(`[AI Image Generator] Total time: ${totalTime}s`);
    console.log('[AI Image Generator] Final method:', finalMethod);
    console.log('[AI Image Generator] Sending response with image URLs:', imageUrls);
    
    // Only send response if we have images
    if (imageUrls.length === 0) {
      console.log('[AI Image Generator] No images to send, using fallback');
      throw new Error('No images generated');
    }
    
    if (!responseSent) {
      responseSent = true;
      res.status(200).json({
        success: true,
        message: `${imageUrls.length} images generated successfully`,
        data: {
          images: imageUrls,
          prompt: promptResult.prompt,
          promptScore: promptResult.score,
          method: finalMethod,
          generationMethod: generationResult.method,
          metadata: generationResult.metadata || null,
          processingTime: totalTime
        },
      });
    }
    return; // Prevent further execution and middleware interference
  } catch (error) {
    const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);
    console.error('[AI Image Generator] ===== ERROR =====');
    console.error('[AI Image Generator] Error:', error.message);
    console.error('[AI Image Generator] Error stack:', error.stack);
    console.error(`[AI Image Generator] Failed after ${totalTime}s`);
    
    // Only send fallback response if no response has been sent yet
    if (!responseSent) {
      // Final fallback: Return category-based placeholder URLs
      console.log('[AI Image Generator] Using final fallback with category-based placeholders');
      const { title, description, category } = req.body;
      const fallbackResult = await generateCategoryPlaceholderImages(3, title, description);
      
      responseSent = true;
      res.status(200).json({
        success: true,
        message: 'Images generated (using fallback - AI unavailable)',
        data: {
          images: fallbackResult.urls,
          prompt: 'fallback',
          promptScore: 0,
          method: 'fallback',
          generationMethod: 'placeholder',
          metadata: fallbackResult.metadata,
          processingTime: totalTime
        },
      });
    } else {
      console.log('[AI Image Generator] Response already sent, skipping fallback');
    }
  }
}

module.exports = {
  generateActivityImage,
};

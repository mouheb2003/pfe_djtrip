# AI Image Generator Setup Guide

## Overview

The AI Image Generator feature allows organizers to automatically generate stunning images for their activities using AI. The system uses:
- **Google Gemini AI** for prompt engineering (converting activity title + description into optimized image prompts)
- **Stability AI (Stable Diffusion)** for image generation
- **Cloudinary** for image storage and delivery

## Required Environment Variables

Add the following environment variables to your `.env` file:

```bash
# Google Gemini API
GEMINI_API_KEY=your_gemini_api_key_here

# Stability AI API
STABILITY_API_KEY=your_stability_api_key_here

# Cloudinary (already configured in your project)
CLOUDINARY_CLOUD_NAME=your_cloudinary_cloud_name
CLOUDINARY_API_KEY=your_cloudinary_api_key
CLOUDINARY_API_SECRET=your_cloudinary_api_secret
```

## API Key Setup

### 1. Google Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Create a new API key
4. Copy the API key and add it to your `.env` file as `GEMINI_API_KEY`

### 2. Stability AI API Key

1. Go to [Stability AI Platform](https://platform.stability.ai/)
2. Sign up for an account
3. Navigate to API Keys section
4. Generate a new API key
5. Copy the API key and add it to your `.env` file as `STABILITY_API_KEY`

**Note**: Stability AI offers free credits for testing. Check their pricing for production usage.

## How It Works

### Backend Flow

1. **Request**: Frontend sends POST request to `/api/v1/activites/generate-image` with:
   ```json
   {
     "title": "Sunset Kayaking in Blue Grotto",
     "description": "Experience the magical sunset while kayaking through the crystal clear waters of Djerba's famous Blue Grotto..."
   }
   ```

2. **Prompt Engineering**: Gemini AI converts the title + description into an optimized prompt:
   ```
   "cinematic, ultra realistic, travel photography, 4k, no text, no watermark, sunset kayaking, blue grotto, crystal clear water, djerba island, mediterranean coast, golden hour lighting, wide angle shot"
   ```

3. **Image Generation**: Stability AI generates a 1024x1024 image based on the optimized prompt

4. **Cloudinary Upload**: Generated image is uploaded to Cloudinary for storage and CDN delivery

5. **Response**: Backend returns the Cloudinary URL:
   ```json
   {
     "success": true,
     "message": "Image generated successfully",
     "data": {
       "image": "https://res.cloudinary.com/your-cloud/image/upload/v1234567890/djtrip/activities/xyz.jpg",
       "prompt": "cinematic, ultra realistic, travel photography, 4k..."
     }
   }
   ```

### Frontend Flow

1. User fills in activity title and description
2. "Generate with AI" button becomes active
3. User clicks "Generate with AI"
4. Loading state shows "Generating your image..."
5. Generated image displays in a card with animations
6. User can:
   - **Regenerate**: Create a new variation
   - **Remove**: Delete the generated image
   - **Use**: The image URL is stored for activity creation

## Features

### UI/UX Features
- **Modern Design**: Consistent with DJTrip's travel/booking theme
- **Smooth Animations**: Fade and scale transitions for image display
- **Loading States**: Visual feedback during generation
- **Error Handling**: Clear error messages for users
- **Responsive**: Works on all screen sizes

### Technical Features
- **Prompt Engineering**: AI-optimized prompts for high-quality images
- **No Text/Watermarks**: Ensures clean, professional images
- **Travel Photography Style**: Cinematic, ultra-realistic output
- **Cloud Storage**: Automatic Cloudinary integration
- **CDN Delivery**: Fast image loading via Cloudinary CDN

## Usage Example

### In Create Activity Screen

```dart
AIImageGeneratorWidget(
  titleController: _titleCtrl,
  descriptionController: _descCtrl,
  onImageGenerated: (imageUrl) {
    // Handle generated image URL
    print('Generated image: $imageUrl');
  },
  existingPhotos: _photos,
)
```

## Troubleshooting

### Common Issues

**Issue**: "GEMINI_API_KEY not configured"
- **Solution**: Add your Gemini API key to `.env` file

**Issue**: "STABILITY_API_KEY not configured"
- **Solution**: Add your Stability AI API key to `.env` file

**Issue**: "Failed to generate image"
- **Solution**: Check API key validity and account credits

**Issue**: "Failed to upload image"
- **Solution**: Verify Cloudinary credentials are correct

### Testing

To test the feature:

1. Ensure all environment variables are set
2. Start the backend server: `npm run dev`
3. Open the Flutter app
4. Navigate to Create Activity screen
5. Fill in title and description
6. Click "Generate with AI"
7. Wait for image generation (may take 10-30 seconds)

## Cost Considerations

- **Gemini AI**: Free tier available, check [Google AI pricing](https://ai.google.dev/pricing)
- **Stability AI**: Free credits for testing, check [Stability AI pricing](https://platform.stability.ai/pricing)
- **Cloudinary**: Free tier available, check [Cloudinary pricing](https://cloudinary.com/pricing)

## Production Recommendations

1. **Rate Limiting**: Implement rate limiting to prevent abuse
2. **Caching**: Cache generated images to reduce API costs
3. **Error Handling**: Implement robust error handling and retry logic
4. **Monitoring**: Add logging and monitoring for API usage
5. **Cost Tracking**: Monitor API usage and costs

## Security Notes

- Never commit `.env` file to version control
- Use environment-specific API keys (dev/staging/prod)
- Implement proper authentication on the endpoint
- Validate user input before processing
- Sanitize prompts to prevent injection attacks

## Future Enhancements

Potential improvements:
- Multiple image generation (carousel)
- Style selection (photography, illustration, etc.)
- Custom prompt editing
- Image history/favorites
- Batch generation for multiple activities
- AI image editing (enhance, resize, etc.)

## Support

For issues or questions:
- Check the backend logs: `Back/controllers/aiImageGenerator.js`
- Check Flutter logs in the app
- Verify API keys are valid
- Check API service status pages

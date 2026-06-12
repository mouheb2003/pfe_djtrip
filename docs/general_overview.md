# DJTrip - Application Overview

## The Concept (Idea)
**DJTrip (Djerba Trip)** is an innovative, all-in-one mobile platform designed to revolutionize tourism on the island of Djerba, Tunisia. It connects tourists looking for authentic, well-organized experiences directly with local organizers and guides.

Unlike standard booking platforms, DJTrip offers a highly social and interactive experience where tourists can discover hidden gems, participate in events, and share their experiences, while organizers have powerful tools to manage and promote their activities.

## Target Audience
1. **Tourists / Travelers**: People visiting Djerba who want to easily find, book, and review local activities (excursions, boat trips, quad biking, cultural tours, etc.).
2. **Organizers / Locals**: Local businesses, guides, or individuals who create, manage, and host these activities.
3. **Admins**: Platform managers who oversee the ecosystem through a dedicated web dashboard.

## Key Features

### For Tourists
- **Explore & Discover**: A dynamic map and feed showing nearby or upcoming activities categorized by type (Adventure, Culture, Relax, etc.).
- **Booking & Enrollment**: Seamless booking process for activities with limited spots.
- **Social Feed**: A timeline where tourists can post photos, share experiences, and see what others are doing.
- **Public Profiles**: Ability to view organizers' profiles to check their ratings, reviews, and past activities.
- **Chat**: Real-time private messaging to ask organizers questions before or after booking.
- **Reviews**: Leave ratings and written reviews after participating in an activity.

### For Organizers
- **Activity Management**: Create detailed activities with photos, schedules, pricing, capacity limits, and exact locations on the map.
- **Dashboard & Stats**: View participant lists, revenue statistics, and track the popularity of their events.
- **Professional Profile**: Maintain a public organizer profile highlighting specialties, spoken languages, and overall ratings.
- **Engagement**: Post updates to the social feed to attract more tourists to their upcoming events.

## Technical Architecture
- **Frontend (Mobile)**: Built with **Flutter**, providing a native-like, premium user experience on both iOS and Android. Uses modern UI/UX paradigms (glassmorphism, smooth animations, dark/light mode).
- **Backend (API)**: Built with **Node.js & Express**, utilizing a **MongoDB** database for flexible and scalable data storage.
- **Real-time**: Implements **Socket.io** for real-time chat, notifications, and location tracking.
- **AI Integration**: Features a specialized **Gemini AI Chatbot** capable of reading this documentation and answering user queries interactively.
- **Admin Dashboard**: A separate React/Next.js interface for platform administrators to moderate content and users.

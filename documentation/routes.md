# Routes (Frontend + App)

## Flutter (navigation) routes

Ces routes correspondent à `Front/lib/config/app_routes.dart`.

1. `/`  
   - `SplashScreen`

2. `/welcome`  
   - `WelcomeScreen`

3. `/login`  
   - `LoginScreen`

4. `/signup`  
   - `SignupScreen`

5. `/tourist/main`  
   - `TouristMainScreen`

6. `/organizer/main`  
   - `OrganizerMainScreen`

7. `/profile/{id}?type=organizer|tourist`  
   - `PublicOrganizerProfileScreen` si `type=organizer`
   - `PublicUserProfileScreen` sinon (par défaut : `tourist`)

8. Toute autre route  
   - `NotFoundScreen`

## Backend (REST) + WebSocket

La documentation détaillée des endpoints backend REST est dans `documentation/API_REFERENCE.md`.  
Les événements Socket.IO utilisés pour la présence (`user_status`) et la messagerie (`new_message`) sont gérés côté serveur (`Back/server.js`) et consommés côté mobile (ex: `MessagesScreen` / `ChatConversationScreen`).


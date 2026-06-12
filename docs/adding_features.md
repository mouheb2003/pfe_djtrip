# Adding Features to DJTrip

This guide explains the step-by-step process for adding a new feature (e.g., a new screen, a new data entity) to the DJTrip platform, and how to ensure the AI Docs Chatbot indexes it correctly.

## 1. Backend Implementation (Node.js/Express)
1. **Define the Mongoose Model**: Create a new schema in `Back/models/`. Ensure you define the data types, required fields, and references to other models (like `User` or `Activity`).
2. **Create the Controller**: In `Back/controllers/`, create the functions to handle the business logic (e.g., `create`, `getAll`, `getById`, `update`, `delete`).
3. **Define Routes**: In `Back/routes/`, map the HTTP endpoints to your controller functions. Protect the routes using the `authMiddleware` if the user needs to be logged in.
4. **Register Route**: Mount the new route file in `Back/src/server.js`.

## 2. Frontend Implementation (Flutter)
1. **Create the Model**: In `Front/lib/models/`, create a Dart class that maps exactly to your backend JSON response. Use a `fromJson` factory method to parse incoming data.
2. **Create the Service**: In `Front/lib/services/`, create a new service file (e.g., `new_feature_service.dart`). Use `ApiClient` to make HTTP requests to the new backend endpoints. Ensure proper error handling.
3. **Build the UI Screen**: In `Front/lib/screens/`, create the Flutter widget. 
   - Use `StatefulWidget` if you need to fetch data `onInit`.
   - Use `flutter_screenutil` (e.g., `.w`, `.h`, `.sp`) for responsive sizing.
   - Use `AppTheme.dart` for colors and fonts.
4. **Navigation**: Add the route or navigation button to access your new screen from existing tabs (like the Explore or Profile tabs).

## 3. Documentation & AI Indexing
For the AI Docs Chatbot to be aware of the new feature and answer user queries about it, you MUST document it:

1. **Write Documentation**: Open the `docs/` folder in the root of the repository.
   - If it's a new screen, add details to `docs/screens.md`.
   - If it's a new service, add details to `docs/services.md`.
   - Or create a new dedicated `.md` file for major features.
2. **Commit and Push**: The AI Chatbot indexes documentation directly from the GitHub repository (`mouheb2003/pfe_djtrip`).
   ```bash
   git add docs/
   git commit -m "docs: add documentation for new feature"
   git push origin main
   ```
3. **Wait for Sync**: The AI Chatbot will automatically fetch and index the new markdown files from the `docs/` folder on GitHub. Once indexed, the AI can assist users or developers with the new feature!

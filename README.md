# Wisheyy MVP (Flutter + Firebase)

Wisheyy is an emotional storytelling app for creating and sharing interactive digital wishes in under 3 minutes.

## MVP scope

- **3 templates only**: Romantic, Birthday, Friendship
- Add **3–5 images**
- Add short message slides
- Customize theme color + animation (fade/slide/zoom)
- Instant shareable URL generation
- Interactive player with tap, swipe, long-press, shake
- Optional premium mode in Romantic template: **Open When…** (tap open, hold reveal, shake surprise)

---

## Project structure

```txt
lib/
  animations/
    story_transition.dart
  interactions/
    interaction_handler.dart
  models/
    wish_model.dart
  screens/
    home_screen.dart
    template_selection_screen.dart
    editor_screen.dart
    player_screen.dart
  services/
    storage_service.dart
    wish_repository.dart
    share_service.dart
  theme/
    app_theme.dart
  utils/
    responsive.dart
  widgets/
    adaptive_scaffold.dart
    template_card.dart
  app.dart
  main.dart
```

---

## Firebase setup

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. Login and configure:
   ```bash
   firebase login
   flutterfire configure
   ```
3. Enable Firebase services:
   - Firestore (Native mode)
   - Storage
   - Hosting
4. Add generated `firebase_options.dart` and initialize in `main.dart`.
5. Firestore rule starter:
   ```txt
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /wishes/{wishId} {
         allow read: if true;
         allow write: if true;
       }
     }
   }
   ```
6. Storage rule starter:
   ```txt
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /wishes/{wishId}/{allPaths=**} {
         allow read, write: if true;
       }
     }
   }
   ```

---

## Firestore schema

Collection: `wishes`

```json
{
  "id": "uuid",
  "templateType": "romantic | birthday | friendship",
  "photos": ["https://..."],
  "messages": ["slide 1", "slide 2"],
  "theme": "#6E56F8",
  "animationType": "fade | slide | zoom",
  "musicUrl": "https://... or null",
  "interactionConfig": {
    "tapEnabled": true,
    "swipeEnabled": true,
    "holdEnabled": false,
    "shakeEnabled": true
  },
  "createdAt": "timestamp"
}
```

---

## Share URL strategy

- Basic: `https://wisheyy.web.app/player/{wishId}`
- WhatsApp text format: `I made something special for you 💌\n{url}`
- Future: Firebase Dynamic Links for campaign analytics.

---

## Platform adaptation

- iOS: `CupertinoApp` + `CupertinoPageScaffold`
- Android/Web/Desktop: Material 3
- Desktop: optional sidebar layout in `AdaptiveScaffold`
- Breakpoints in `Responsive`:
  - Mobile `<600`
  - Tablet `600–1023`
  - Desktop `>=1024`

---

## Interaction system

- `GestureDetector` for tap, swipe, long-press
- `sensors_plus` for shake detection
- Reusable `InteractionHandler` class
- Template interaction load kept at 1–2 main interactions

---

## Run locally

```bash
flutter pub get
flutter run
```

For web player testing:

```bash
flutter run -d chrome
```

---

## Production notes

- Compress uploaded images before storage for fast load.
- Pre-cache player images for smoother transition.
- Add Remote Config for template tuning.
- Add moderation and abuse controls before public release.

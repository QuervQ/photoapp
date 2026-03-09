# photoapp

Flutter frontend for `photoapp-backend`.

## Environment variables

Set the backend base URL in `.env`:

```dotenv
BACKEND_BASE_URL=http://127.0.0.1:8080
```

## Current frontend flow

- Email/password signup & login via backend `/auth/signup` and `/auth/login`
- Room create/list/join via backend `/rooms` APIs
- Invite code creation via `/rooms/{room_id}/invite`
- Multiplayer event subscription via backend WebSocket `/ws`

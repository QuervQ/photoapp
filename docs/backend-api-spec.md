# PhotoApp Backend API Specification

Status: draft for Swift frontend rebuild

This document defines the backend contract for a Supabase-free PhotoApp backend. It is based on the current Flutter client contract and the new `PhotoAppSwift` client.

## Goals

- Do not depend on Supabase Auth, Supabase Storage, Supabase Realtime, or Supabase database APIs.
- Keep the frontend contract simple: REST for commands/queries, WebSocket for realtime room events, signed URLs for binary uploads/downloads.
- Let the backend own authorization checks. Clients must never decide room access by themselves.
- Keep JSON keys in `snake_case`.

## Recommended Architecture

- API server: any backend framework is fine.
- Database: PostgreSQL, MySQL, SQLite, or another app-owned DB.
- Auth: backend-owned email/password auth with JWT access tokens and refresh tokens.
- Object storage:
  - Production: S3-compatible storage such as AWS S3, Cloudflare R2, MinIO.
  - Local development: filesystem storage served by the backend.
- Realtime: backend WebSocket hub. No Supabase Realtime.

## Environment Variables

```dotenv
PUBLIC_BASE_URL=http://127.0.0.1:8080
DATABASE_URL=postgres://user:password@localhost:5432/photoapp
JWT_SECRET=change-me
ACCESS_TOKEN_TTL_SECONDS=3600
REFRESH_TOKEN_TTL_SECONDS=2592000

# local | s3
OBJECT_STORAGE_DRIVER=local
LOCAL_STORAGE_DIR=./storage

# Required when OBJECT_STORAGE_DRIVER=s3
S3_ENDPOINT=
S3_REGION=
S3_BUCKET=
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
```

## Common Rules

Base URL:

```text
http://127.0.0.1:8080
```

Authenticated requests use:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

All timestamps are ISO 8601 strings.

Error response shape:

```json
{
  "error": {
    "code": "room_not_found",
    "message": "Room not found"
  }
}
```

Recommended status codes:

- `200`: success
- `201`: created
- `400`: invalid request
- `401`: missing/invalid/expired token
- `403`: authenticated but not allowed
- `404`: not found
- `409`: conflict
- `413`: upload too large
- `500`: server error

## Auth

Passwords must be hashed server-side with Argon2id or bcrypt. Store refresh tokens hashed in the database.

### POST `/auth/signup`

Request:

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

Response `201`:

```json
{
  "access_token": "jwt-access-token",
  "refresh_token": "opaque-refresh-token",
  "user_id": "usr_01",
  "email": "user@example.com"
}
```

### POST `/auth/login`

Request:

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

Response `200`: same as signup.

### POST `/auth/refresh`

Recommended for the Swift app, even if the first version does not store sessions yet.

Request:

```json
{
  "refresh_token": "opaque-refresh-token"
}
```

Response `200`:

```json
{
  "access_token": "new-jwt-access-token",
  "refresh_token": "new-opaque-refresh-token",
  "user_id": "usr_01",
  "email": "user@example.com"
}
```

### POST `/auth/logout`

Request:

```json
{
  "refresh_token": "opaque-refresh-token"
}
```

Response `204`: empty.

## Rooms

A room is a multiplayer AR space. Only room members can read or write room data.

Room response:

```json
{
  "id": "room_01",
  "name": "Living Room",
  "created_by": "usr_01",
  "created_at": "2026-05-07T03:00:00Z"
}
```

### GET `/rooms`

Returns rooms where the authenticated user is a member.

Response `200`:

```json
[
  {
    "id": "room_01",
    "name": "Living Room",
    "created_by": "usr_01",
    "created_at": "2026-05-07T03:00:00Z"
  }
]
```

### POST `/rooms`

Creates a room and adds the creator as owner/member.

Request:

```json
{
  "name": "Living Room"
}
```

Response `201`: room response.

### POST `/rooms/join`

Joins a room by invite code.

Request:

```json
{
  "invite_code": "ABCD-1234"
}
```

Response `200`:

```json
{
  "room_id": "room_01"
}
```

### POST `/rooms/{room_id}/invite`

Creates a short-lived invite code. Caller must be a room member.

Request:

```json
{}
```

Response `201`:

```json
{
  "invite_code": "ABCD-1234",
  "expires_at": "2026-05-08T03:00:00Z"
}
```

## Assets

Assets are binary files owned by the backend: images and ARWorldMap blobs.

Supported `kind` values:

- `image`
- `worldmap`

The backend may implement signed URLs in either of these ways:

- S3/R2/MinIO pre-signed PUT/GET URLs.
- Backend-generated one-time URLs, for example `/assets/{asset_id}/upload?token=...`.

The frontend only requires `upload_url` and `download_url`; it does not care which storage provider is behind them.

### POST `/assets/upload-url`

Request:

```json
{
  "kind": "image",
  "content_type": "image/jpeg",
  "byte_size": 123456
}
```

Response `201`:

```json
{
  "asset_id": "asset_01",
  "upload_url": "http://127.0.0.1:8080/assets/asset_01/upload?token=signed-token",
  "expires_at": "2026-05-07T03:10:00Z"
}
```

Validation:

- `kind=image`: allow `image/jpeg`, `image/png`, `image/heic`, `image/webp`.
- `kind=worldmap`: allow `application/octet-stream`.
- Reject excessive `byte_size`.

### PUT `upload_url`

Request:

```http
PUT <upload_url>
Content-Type: image/jpeg

<binary bytes>
```

Response:

- `200`, `201`, or `204` is success.

### GET `/assets/{asset_id}/download-url`

Caller must have access to a room that references the asset, or own the asset.

Response `200`:

```json
{
  "download_url": "http://127.0.0.1:8080/assets/asset_01/download?token=signed-token",
  "expires_at": "2026-05-07T03:10:00Z"
}
```

### GET `download_url`

Response:

```http
200 OK
Content-Type: image/jpeg

<binary bytes>
```

## Placements

A placement stores an image asset transform in AR world space.

Placement response:

```json
{
  "id": "placement_01",
  "room_id": "room_01",
  "image_asset_id": "asset_01",
  "image_download_url": "http://127.0.0.1:8080/assets/asset_01/download?token=signed-token",
  "transform": [
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, -1.2, 1.0
  ],
  "width_m": 0.6,
  "height_m": 0.4,
  "created_by": "usr_01",
  "created_at": "2026-05-07T03:00:00Z"
}
```

### GET `/rooms/{room_id}/placements`

Response `200`:

```json
[
  {
    "id": "placement_01",
    "room_id": "room_01",
    "image_asset_id": "asset_01",
    "image_download_url": "http://127.0.0.1:8080/assets/asset_01/download?token=signed-token",
    "transform": [
      1.0, 0.0, 0.0, 0.0,
      0.0, 1.0, 0.0, 0.0,
      0.0, 0.0, 1.0, 0.0,
      0.0, 0.0, -1.2, 1.0
    ],
    "width_m": 0.6,
    "height_m": 0.4,
    "created_by": "usr_01",
    "created_at": "2026-05-07T03:00:00Z"
  }
]
```

### POST `/rooms/{room_id}/placements`

Request:

```json
{
  "image_asset_id": "asset_01",
  "transform": [
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, -1.2, 1.0
  ],
  "width_m": 0.6,
  "height_m": 0.4
}
```

Response `201`: placement response.

Side effect:

- Broadcast `placement_created` to room WebSocket subscribers.

## WorldMap

A room has zero or one latest ARWorldMap. The backend stores versions so older maps can be audited or rolled back.

### GET `/rooms/{room_id}/worldmap`

Response `200`:

```json
{
  "asset_id": "asset_worldmap_01",
  "download_url": "http://127.0.0.1:8080/assets/asset_worldmap_01/download?token=signed-token",
  "version": 3,
  "created_by": "usr_01",
  "created_at": "2026-05-07T03:00:00Z"
}
```

Response `404`:

```json
{
  "error": {
    "code": "worldmap_not_found",
    "message": "WorldMap not found"
  }
}
```

### POST `/rooms/{room_id}/worldmap`

Request:

```json
{
  "asset_id": "asset_worldmap_01"
}
```

Response `201`:

```json
{
  "asset_id": "asset_worldmap_01",
  "version": 3,
  "created_by": "usr_01",
  "created_at": "2026-05-07T03:00:00Z"
}
```

Side effect:

- Broadcast `worldmap_updated` to room WebSocket subscribers.

## WebSocket

Endpoint:

```text
GET /ws?token=<access_token>&room_id=<room_id>
```

Authentication:

- The server validates `token`.
- If `room_id` is present, the user must be a member of the room.

Client may send an explicit subscribe message after connect:

```json
{
  "type": "subscribe",
  "room_id": "room_01"
}
```

Server event: placement created

```json
{
  "type": "placement_created",
  "room_id": "room_01",
  "placement": {
    "id": "placement_01",
    "room_id": "room_01",
    "image_asset_id": "asset_01",
    "image_download_url": "http://127.0.0.1:8080/assets/asset_01/download?token=signed-token",
    "transform": [
      1.0, 0.0, 0.0, 0.0,
      0.0, 1.0, 0.0, 0.0,
      0.0, 0.0, 1.0, 0.0,
      0.0, 0.0, -1.2, 1.0
    ],
    "width_m": 0.6,
    "height_m": 0.4,
    "created_by": "usr_01",
    "created_at": "2026-05-07T03:00:00Z"
  }
}
```

Server event: worldmap updated

```json
{
  "type": "worldmap_updated",
  "room_id": "room_01",
  "worldmap": {
    "asset_id": "asset_worldmap_01",
    "version": 3,
    "created_by": "usr_01",
    "created_at": "2026-05-07T03:00:00Z"
  }
}
```

Recommended heartbeat:

```json
{
  "type": "ping",
  "sent_at": "2026-05-07T03:00:00Z"
}
```

Server response:

```json
{
  "type": "pong",
  "sent_at": "2026-05-07T03:00:00Z"
}
```

## Database Model

Use IDs as UUID/ULID/string. Prefixes such as `usr_`, `room_`, `asset_` are optional but helpful.

### `users`

| column | type | notes |
| --- | --- | --- |
| id | text pk | user id |
| email | text unique | lowercased |
| password_hash | text | Argon2id or bcrypt |
| created_at | timestamp | |
| updated_at | timestamp | |

### `refresh_tokens`

| column | type | notes |
| --- | --- | --- |
| id | text pk | |
| user_id | text fk users.id | |
| token_hash | text unique | store hash only |
| expires_at | timestamp | |
| revoked_at | timestamp nullable | |
| created_at | timestamp | |

### `rooms`

| column | type | notes |
| --- | --- | --- |
| id | text pk | |
| name | text | |
| created_by | text fk users.id | |
| created_at | timestamp | |

### `room_members`

| column | type | notes |
| --- | --- | --- |
| room_id | text fk rooms.id | composite unique with user_id |
| user_id | text fk users.id | |
| role | text | `owner` or `member` |
| joined_at | timestamp | |

### `room_invites`

| column | type | notes |
| --- | --- | --- |
| id | text pk | |
| room_id | text fk rooms.id | |
| invite_code_hash | text unique | store hash if codes are sensitive |
| expires_at | timestamp | |
| created_by | text fk users.id | |
| used_by | text nullable | optional |
| used_at | timestamp nullable | optional |
| created_at | timestamp | |

### `assets`

| column | type | notes |
| --- | --- | --- |
| id | text pk | |
| owner_id | text fk users.id | uploader |
| kind | text | `image` or `worldmap` |
| storage_key | text unique | local path or object key |
| content_type | text | |
| byte_size | integer | |
| upload_status | text | `pending`, `uploaded`, `failed` |
| created_at | timestamp | |

### `placements`

| column | type | notes |
| --- | --- | --- |
| id | text pk | |
| room_id | text fk rooms.id | |
| image_asset_id | text fk assets.id | |
| transform | json | array of 16 numbers |
| width_m | double | |
| height_m | double | |
| created_by | text fk users.id | |
| created_at | timestamp | |

### `room_worldmaps`

| column | type | notes |
| --- | --- | --- |
| id | text pk | |
| room_id | text fk rooms.id | |
| asset_id | text fk assets.id | worldmap asset |
| version | integer | increment per room |
| created_by | text fk users.id | |
| created_at | timestamp | |

## Authorization Rules

- A user can list only rooms where they are a member.
- A user can create invites only for rooms where they are a member.
- A user can list/create placements only in rooms where they are a member.
- A placement `image_asset_id` must reference an uploaded image asset owned by the user or otherwise permitted by the room policy.
- A worldmap `asset_id` must reference an uploaded `worldmap` asset owned by the user.
- Download URLs must only be issued when the caller can access the asset through ownership or room membership.

## Frontend Contract Checklist

The Swift frontend expects:

- `POST /auth/signup` and `POST /auth/login` return `access_token`, `refresh_token`, `user_id`, `email`.
- Protected endpoints accept `Authorization: Bearer <access_token>`.
- `GET /rooms` returns an array, not an object wrapper.
- `POST /rooms/join` returns `{ "room_id": "..." }`.
- `GET /rooms/{room_id}/placements` returns `image_download_url` for each placement when available.
- `GET /rooms/{room_id}/worldmap` returns `404` when there is no map yet.
- `POST /assets/upload-url` returns `asset_id` and `upload_url`.
- `GET /assets/{asset_id}/download-url` returns `download_url`.
- WebSocket sends `placement_created` and `worldmap_updated` events.

## Supabase-Free Implementation Notes

- Replace Supabase Auth with backend-owned users, password hashing, JWT access tokens, and refresh token rotation.
- Replace Supabase Storage with local filesystem in development and S3-compatible object storage in production.
- Replace Supabase Realtime with an in-process WebSocket room hub. If running multiple backend instances, back the hub with Redis pub/sub or another message bus.
- Replace Supabase RLS with explicit authorization checks in service methods.

## Open Questions

- Should invite codes be single-use or reusable until expiry?
- Should room owners be able to remove members and delete placements?
- Should uploaded assets be garbage-collected when not referenced by any room?
- Should WorldMap versions be kept forever or compacted to the latest N versions?

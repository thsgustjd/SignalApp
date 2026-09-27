# Group chat (max 5 per room)

## Required: Supabase SQL

Run **`RoomMembersSetup.sql`** once in the SQL Editor.

It creates `room_members` with:

| Column | Purpose |
|--------|---------|
| `room_id` | → `rooms.id` |
| `user_id` | Device id (same as `profiles.id`) |
| `display_name` | Nickname in that room |

Existing `rooms.user1` / `user2` rows are copied into `room_members`.  
`rooms` stays as-is (creator + optional 2nd slot mirror); **3rd–5th members live only in `room_members`**.

## App behavior

- Home card: **`1/5명` … `5/5명`**
- Join: insert into `room_members` until full
- Delete waiting room: creator + **1 member only**
- Push: all members except sender

Without `RoomMembersSetup.sql`, the app falls back to **2-person** logic via `user1` / `user2` only.

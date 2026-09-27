# messages INSERT → APNs (서버 트리거 보장)

클라이언트 Edge Function 호출이 실패해도 푸시가 가도록 **Database Webhook**을 권장합니다.

## Supabase Dashboard

1. **Database → Webhooks → Create**
2. Table: `messages`, Events: **Insert**
3. URL: `https://<project-ref>.supabase.co/functions/v1/send-message-push`
4. HTTP Headers: `Authorization: Bearer <SERVICE_ROLE_KEY>`, `Content-Type: application/json`
5. Payload template (예시 — 실제 필드명에 맞게 매핑):

```json
{
  "recipient_id": "{{ compute partner user id from room }}",
  "message_id": "{{ record.id }}",
  "room_id": "{{ record.room_id }}",
  "sender_id": "{{ record.sender_id }}",
  "sender_nickname": "{{ record.sender_nickname }}",
  "message_type": "{{ record.type }}",
  "content": "{{ record.content }}"
}
```

`recipient_id`는 `rooms`에서 `sender_id`가 user1이면 user2_id, 반대면 user1_id로 Edge Function 내부에서 조회하는 편이 안전합니다.  
→ **`send-message-push`에 `message_id`만 넘기고 함수가 messages+rooms join** 하도록 확장할 수 있습니다.

## Edge Function 배포

```bash
supabase secrets set APNS_KEY_ID=... APNS_TEAM_ID=... APNS_BUNDLE_ID=com.hyunseong.SignalApp APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----..." APNS_USE_SANDBOX=true
supabase functions deploy send-message-push
```

TestFlight/Production 빌드는 `APNS_USE_SANDBOX=false`.

// supabase functions deploy send-message-push
// Secrets: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY, APNS_USE_SANDBOX

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { buildSignalApnsPayload, sendApnsAlert } from "../_shared/apns.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface MessagePushBody {
  recipient_id: string;
  message_id: string;
  room_id: string;
  sender_id: string;
  sender_nickname?: string;
  message_type: string;
  content?: string;
  image_url?: string;
  room_display_title?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as MessagePushBody;
    for (const key of ["message_id", "room_id", "sender_id", "message_type"] as const) {
      if (!body[key]) {
        return json({ error: `missing ${key}` }, 400);
      }
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let recipientId = body.recipient_id?.trim();

    if (!recipientId) {
      const { data: members, error: membersError } = await supabase
        .from("room_members")
        .select("user_id")
        .eq("room_id", body.room_id);
      if (!membersError && members?.length) {
        const others = members
          .map((m: { user_id: string }) => m.user_id)
          .filter((id: string) => id && id !== body.sender_id);
        recipientId = others[0];
      }

      if (!recipientId) {
        const { data: room, error: roomError } = await supabase
          .from("rooms")
          .select("user1_id, user2_id")
          .eq("id", body.room_id)
          .maybeSingle();
        if (roomError) throw roomError;
        if (room) {
          if (room.user1_id === body.sender_id) recipientId = room.user2_id ?? undefined;
          else if (room.user2_id === body.sender_id) recipientId = room.user1_id ?? undefined;
          else recipientId = room.user2_id ?? room.user1_id ?? undefined;
        }
      }
    }

    if (!recipientId) {
      return json({ ok: false, reason: "no_recipient_id" }, 200);
    }

    const tokenLookup = await fetchProfileApnsToken(supabase, recipientId);

    if (!tokenLookup.deviceToken) {
      console.warn("no_apns_token", {
        recipient_id: recipientId,
        profile_row_found: tokenLookup.profileRowFound,
        matched_profile_id: tokenLookup.matchedProfileId,
        variants: profileIdVariants(recipientId),
      });
      return json(
        {
          ok: false,
          reason: "no_apns_token",
          recipient_id: recipientId,
          profiles_lookup_column: "id",
          profiles_lookup_variants: profileIdVariants(recipientId),
          profile_row_found: tokenLookup.profileRowFound,
          matched_profile_id: tokenLookup.matchedProfileId,
          apns_token_present: false,
          hint:
            "클라이언트 profiles.id = device UserDefaults id (rooms.user1_id/user2_id). 수신 기기에서 didRegister 후 저장 필요.",
        },
        200,
      );
    }

    const deviceToken = tokenLookup.deviceToken;

    const nickname = body.sender_nickname?.trim() || "상대방";
    const type = body.message_type;
    const imageUrl = body.image_url?.trim();
    const roomLabel =
      body.room_display_title?.trim() ||
      "채팅방";
    const pushTitle = `${roomLabel}-${nickname}`;

    const rich = (type === "drawing" || type === "photo") && !!imageUrl;

    let title = pushTitle;
    let alertBody = `${nickname} 님이 메시지를 보냈어요`;

    switch (type) {
      case "drawing":
        alertBody = `${nickname} 님이 방금 그림을 보냈어요!`;
        break;
      case "photo":
        alertBody = `${nickname} 님이 사진을 보냈어요`;
        break;
      case "emoji":
        alertBody = body.content?.trim()
          ? body.content.trim()
          : `${nickname} 님이 이모지를 보냈어요`;
        break;
      case "nudge": {
        const display =
          (body.content?.trim() ?? "").replace(/^[^|]+\|/, "") || body.content?.trim() || "…";
        alertBody = display;
        break;
      }
      case "emergency":
        alertBody = `${nickname} — 비상 연락`;
        break;
    }

    const apnsPayload = buildSignalApnsPayload({
      alert: { title, body: alertBody },
      roomId: body.room_id,
      messageId: body.message_id,
      messageType: type,
      senderId: body.sender_id,
      senderNickname: nickname,
      richMedia: rich,
      content: body.content,
      imageUrl,
      hostBundleId: Deno.env.get("APNS_BUNDLE_ID") ?? undefined,
    });

    const apnsResult = await sendApnsAlert(deviceToken, apnsPayload);
    if (!apnsResult.ok) {
      console.error("apns_failed", {
        recipientId,
        message_type: type,
        ...apnsResult,
      });
      return json(
        {
          ok: false,
          sent: false,
          reason: "apns_failed",
          apns_status: apnsResult.apns_status,
          apns_reason: apnsResult.apns_reason,
          apns_detail: apnsResult.apns_detail,
        },
        502,
      );
    }

    console.log("apns_sent", {
      recipientId,
      message_type: type,
      apns_status: apnsResult.apns_status,
      apns_id: apnsResult.apns_id,
    });
    return json(
      {
        ok: true,
        sent: true,
        apns_status: apnsResult.apns_status,
        apns_id: apnsResult.apns_id,
      },
      200,
    );
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    const apnsSecrets = message.includes("APNS secrets missing");
    return json(
      {
        ok: false,
        sent: false,
        error: message,
        reason: apnsSecrets ? "apns_secrets_missing" : "internal_error",
      },
      500,
    );
  }
});

function profileIdVariants(id: string): string[] {
  const trimmed = id.trim();
  if (!trimmed) return [];
  return [...new Set([trimmed, trimmed.toLowerCase(), trimmed.toUpperCase()])];
}

async function fetchProfileApnsToken(
  supabase: ReturnType<typeof createClient>,
  recipientId: string,
): Promise<{
  deviceToken: string | null;
  profileRowFound: boolean;
  matchedProfileId: string | null;
}> {
  for (const id of profileIdVariants(recipientId)) {
    const { data, error } = await supabase
      .from("profiles")
      .select("id, apns_token")
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    if (!data) continue;
    const token = data.apns_token?.trim();
    return {
      deviceToken: token || null,
      profileRowFound: true,
      matchedProfileId: data.id ?? id,
    };
  }
  return { deviceToken: null, profileRowFound: false, matchedProfileId: null };
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

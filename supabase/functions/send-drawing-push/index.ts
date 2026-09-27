// Supabase Edge Function: send-drawing-push
// Deploy: supabase functions deploy send-drawing-push
// Secrets: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY (p8 contents), APNS_USE_SANDBOX=true|false

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { buildSignalApnsPayload, sendApnsAlert } from "../_shared/apns.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface DrawingPushBody {
  recipient_id: string;
  message_id: string;
  room_id: string;
  sender_id: string;
  sender_nickname: string;
  image_url: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as DrawingPushBody;
    const required = ["recipient_id", "message_id", "room_id", "sender_id", "image_url"] as const;
    for (const key of required) {
      if (!body[key]) {
        return new Response(JSON.stringify({ error: `missing ${key}` }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("apns_token")
      .eq("id", body.recipient_id)
      .maybeSingle();

    if (profileError) throw profileError;
    const deviceToken = profile?.apns_token;
    if (!deviceToken) {
      return new Response(JSON.stringify({ ok: false, reason: "no_apns_token" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const nickname = body.sender_nickname?.trim() || "상대방";
    const apnsPayload = buildSignalApnsPayload({
      alert: {
        title: "💌 손그림",
        body: `${nickname} 님이 방금 그림을 보냈어요!`,
      },
      roomId: body.room_id,
      messageId: body.message_id,
      messageType: "drawing",
      senderId: body.sender_id,
      senderNickname: nickname,
      richMedia: true,
      imageUrl: body.image_url,
      hostBundleId: Deno.env.get("APNS_BUNDLE_ID") ?? undefined,
    });

    const apnsResult = await sendApnsAlert(deviceToken, apnsPayload);
    if (!apnsResult.ok) {
      return new Response(
        JSON.stringify({
          ok: false,
          reason: "apns_failed",
          apns_status: apnsResult.apns_status,
          apns_reason: apnsResult.apns_reason,
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

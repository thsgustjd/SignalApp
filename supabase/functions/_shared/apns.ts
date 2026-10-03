/**
 * SignalApp APNs payload + HTTP/2 send helpers.
 *
 * iOS 알림 배너 왼쪽 아이콘 = **메인 앱 AppIcon** (페이로드로 이미지 URL 불가).
 * `aps.alert.subtitle` 은 iOS가 커뮤니케이션 알림(발신자 아바타)로 분류해 **회색 placeholder** 를
 * 보여줄 수 있어 — 닉네임은 body에만 넣습니다.
 */

export const APNS_CATEGORY_MESSAGE = "SIGNAL_MESSAGE";
export const APNS_CATEGORY_RICH_MEDIA = "SIGNAL_RICH_MEDIA";

export const DEFAULT_HOST_BUNDLE_ID = "com.hyunseong.SignalApp";
export const DEFAULT_APP_GROUP_ID = "group.com.hs.SignalApp";
export const DEFAULT_ICON_ASSET_NAME = "AppIcon";

export type SignalApnsAlert = {
  title: string;
  body: string;
};

export type BuildSignalApnsPayloadInput = {
  alert: SignalApnsAlert;
  roomId: string;
  messageId: string;
  messageType: string;
  senderId: string;
  senderNickname: string;
  richMedia: boolean;
  content?: string;
  imageUrl?: string;
  hostBundleId?: string;
};

function nonEmpty(value: string | undefined, fallback: string): string {
  const trimmed = value?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : fallback;
}

export function buildSignalApnsPayload(input: BuildSignalApnsPayloadInput): Record<string, unknown> {
  const category = input.richMedia ? APNS_CATEGORY_RICH_MEDIA : APNS_CATEGORY_MESSAGE;
  const hostBundleId = nonEmpty(input.hostBundleId, DEFAULT_HOST_BUNDLE_ID);

  const title = nonEmpty(input.alert.title, "새 메시지");
  const body = nonEmpty(input.alert.body, "메시지가 도착했어요");
  const isEmergency = input.messageType === "emergency";
  const trimmedContent = input.content?.trim() ?? "";
  const isBipbiNudge =
    input.messageType === "nudge" && trimmedContent.startsWith("bipbi|");

  const payload: Record<string, unknown> = {
    aps: {
      alert: { title, body },
      sound: isBipbiNudge ? "bippibippisound.wav" : "default",
      "thread-id": input.roomId,
      category,
      ...(isEmergency ? { "interruption-level": "time-sensitive" } : {}),
      "mutable-content": 1,
    },
    category,
    bundle_id: hostBundleId,
    host_bundle_id: hostBundleId,
    notification_id: input.messageId,
    message_type: input.messageType,
    message_id: input.messageId,
    room_id: input.roomId,
    sender_id: input.senderId,
    sender_nickname: input.senderNickname,
    app_group_id: DEFAULT_APP_GROUP_ID,
    icon_asset_name: DEFAULT_ICON_ASSET_NAME,
    "target-content-id": input.messageId,
  };

  if (input.content?.trim()) payload.content = input.content.trim();
  if (input.imageUrl?.trim()) {
    payload.image_url = input.imageUrl.trim();
    payload.media_url = input.imageUrl.trim();
  }

  return payload;
}

export type ApnsSendResult = {
  ok: boolean;
  apns_status?: number;
  apns_reason?: string;
  apns_detail?: string;
  apns_id?: string;
  apns_topic?: string;
  apns_collapse_id?: string;
};

function parseApnsErrorBody(text: string): { reason?: string; detail: string } {
  const detail = text.trim();
  try {
    const parsed = JSON.parse(text) as { reason?: string };
    if (typeof parsed.reason === "string") {
      return { reason: parsed.reason, detail };
    }
  } catch {
    /* plain text */
  }
  return { detail };
}

export async function sendApnsAlert(
  deviceToken: string,
  payload: Record<string, unknown>,
): Promise<ApnsSendResult> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const bundleId = (Deno.env.get("APNS_BUNDLE_ID") ?? DEFAULT_HOST_BUNDLE_ID).trim();
  const privateKeyPem = Deno.env.get("APNS_PRIVATE_KEY");
  const useSandbox = (Deno.env.get("APNS_USE_SANDBOX") ?? "true") === "true";

  if (!keyId || !teamId || !privateKeyPem) {
    throw new Error("APNS secrets missing (APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY)");
  }

  payload.bundle_id = bundleId;
  payload.host_bundle_id = bundleId;

  const messageId = String(payload.message_id ?? payload.notification_id ?? "").trim();
  const collapseId = messageId.length > 0 ? messageId : undefined;

  const payloadHost = (payload.host_bundle_id as string | undefined)?.trim();
  if (payloadHost && payloadHost !== bundleId) {
    console.warn("apns_bundle_mismatch", { apns_topic: bundleId, payload_host_bundle_id: payloadHost });
  }

  const { SignJWT, importPKCS8 } = await import("https://esm.sh/jose@4.15.9");
  const privateKey = await importPKCS8(privateKeyPem.replace(/\\n/g, "\n"), "ES256");
  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(privateKey);

  const host = useSandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const headers: Record<string, string> = {
    authorization: `bearer ${jwt}`,
    "apns-topic": bundleId,
    "apns-push-type": "alert",
    "apns-priority": "10",
    "apns-expiration": "0",
    "content-type": "application/json",
  };
  if (collapseId) {
    headers["apns-collapse-id"] = collapseId;
  }

  const response = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
  });

  const apnsId = response.headers.get("apns-id") ?? undefined;

  if (!response.ok) {
    const text = await response.text();
    const { reason, detail } = parseApnsErrorBody(text);
    return {
      ok: false,
      apns_status: response.status,
      apns_reason: reason,
      apns_detail: detail,
      apns_id: apnsId,
      apns_topic: bundleId,
      apns_collapse_id: collapseId,
    };
  }

  return {
    ok: true,
    apns_status: response.status,
    apns_id: apnsId,
    apns_topic: bundleId,
    apns_collapse_id: collapseId,
  };
}

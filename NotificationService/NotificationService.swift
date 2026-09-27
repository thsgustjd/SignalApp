//
//  NotificationService.swift
//  NotificationService
//

import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    private let downloadTimeout: TimeInterval = 20

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        guard let mutable = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        bestAttemptContent = mutable
        Self.applyPayloadMetadata(to: mutable)
        RoomPushTitleFormatter.apply(to: mutable)

        if mutable.categoryIdentifier.isEmpty {
            if let category = mutable.userInfo["category"] as? String, !category.isEmpty {
                mutable.categoryIdentifier = category
            } else if let aps = mutable.userInfo["aps"] as? [String: Any],
                      let category = aps["category"] as? String, !category.isEmpty {
                mutable.categoryIdentifier = category
            }
        }

        guard let imageURL = Self.imageURL(from: mutable.userInfo) else {
            deliver(mutable)
            return
        }

        downloadAttachment(from: imageURL) { [weak self] attachment in
            guard let self, let content = self.bestAttemptContent else { return }
            if let attachment {
                content.attachments = [attachment]
            }
            self.deliver(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func deliver(_ content: UNMutableNotificationContent) {
        contentHandler?(content)
        contentHandler = nil
    }

    /// Edge 페이로드의 host bundle / notification id → Content Extension·스레드 매핑.
    private static func applyPayloadMetadata(to content: UNMutableNotificationContent) {
        let info = content.userInfo
        if let target = info["target-content-id"] as? String, !target.isEmpty {
            content.targetContentIdentifier = target
        }
        if content.threadIdentifier.isEmpty,
           let roomId = info["room_id"] as? String, !roomId.isEmpty {
            content.threadIdentifier = roomId
        }
        if let host = info["host_bundle_id"] as? String, !host.isEmpty {
            print("🔔 [NotificationService] host_bundle_id=\(host) ext=\(Bundle.main.bundleIdentifier ?? "?")")
        }
    }

    private static func imageURL(from userInfo: [AnyHashable: Any]) -> URL? {
        let keys = ["image_url", "imageUrl", "media_url", "mediaUrl"]
        for key in keys {
            if let raw = userInfo[key] as? String, let url = URL(string: raw), !raw.isEmpty {
                return url
            }
        }
        if let data = userInfo["data"] as? [String: Any] {
            for key in keys {
                if let raw = data[key] as? String, let url = URL(string: raw), !raw.isEmpty {
                    return url
                }
            }
        }
        return nil
    }

    private func downloadAttachment(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = downloadTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = URLSession.shared.downloadTask(with: request) { tempURL, response, error in
            if let error {
                print("⚠️ [NotificationService] download failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let tempURL else {
                completion(nil)
                return
            }

            if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                print("⚠️ [NotificationService] HTTP \(http.statusCode)")
                completion(nil)
                return
            }

            let fileManager = FileManager.default
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let destination = fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.moveItem(at: tempURL, to: destination)

                let attachment = try UNNotificationAttachment(
                    identifier: "drawing-thumbnail",
                    url: destination,
                    options: [
                        UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg",
                        UNNotificationAttachmentOptionsThumbnailHiddenKey: false
                    ]
                )
                completion(attachment)
            } catch {
                print("⚠️ [NotificationService] attachment error: \(error.localizedDescription)")
                completion(nil)
            }
        }
        task.resume()
    }
}

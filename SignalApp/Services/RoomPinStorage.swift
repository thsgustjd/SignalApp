//
//  RoomPinStorage.swift
//  SignalApp
//

import Foundation

/// 채팅방 목록 상단 고정 — 이 기기 UserDefaults에만 저장.
enum RoomPinStorage {
    private static let orderedIdsKey = "pinnedRoomIdsOrdered"

    static func orderedPinnedIds() -> [UUID] {
        guard let raw = UserDefaults.standard.stringArray(forKey: orderedIdsKey) else { return [] }
        return raw.compactMap { UUID(uuidString: $0) }
    }

    static func isPinned(_ roomId: UUID) -> Bool {
        orderedPinnedIds().contains(roomId)
    }

    static func setPinned(_ roomId: UUID, pinned: Bool) {
        var ids = orderedPinnedIds()
        ids.removeAll { $0 == roomId }
        if pinned {
            ids.insert(roomId, at: 0)
        }
        persist(ids)
    }

    static func togglePinned(_ roomId: UUID) {
        setPinned(roomId, pinned: !isPinned(roomId))
    }

    static func removePin(for roomId: UUID) {
        var ids = orderedPinnedIds()
        ids.removeAll { $0 == roomId }
        persist(ids)
    }

    static func sortRooms(_ rooms: [Room]) -> [Room] {
        let pinnedOrder = orderedPinnedIds()
        let pinnedSet = Set(pinnedOrder)
        var pinnedRooms: [Room] = []
        for id in pinnedOrder {
            if let room = rooms.first(where: { $0.id == id }) {
                pinnedRooms.append(room)
            }
        }
        let unpinned = rooms.filter { !pinnedSet.contains($0.id) }
        return pinnedRooms + unpinned
    }

    private static func persist(_ ids: [UUID]) {
        if ids.isEmpty {
            UserDefaults.standard.removeObject(forKey: orderedIdsKey)
        } else {
            UserDefaults.standard.set(ids.map(\.uuidString), forKey: orderedIdsKey)
        }
    }
}

//
//  LockScreenWidgetSnapshot.swift
//  SignalApp
//

import WidgetKit

struct LockScreenWidgetPresence: Equatable {
    var nudgeTypes: Set<String> = []
    var hasDNDWidget: Bool = false
    var hasEmergencyWidget: Bool = false

    var hasAnyLockScreenKeycap: Bool {
        !nudgeTypes.isEmpty || hasDNDWidget || hasEmergencyWidget
    }
}

enum LockScreenWidgetSnapshot {
    private static let lockScreenFamilies: Set<WidgetFamily> = [
        .accessoryCircular,
        .accessoryRectangular,
        .accessoryInline,
    ]

    static func fetch(completion: @escaping (LockScreenWidgetPresence) -> Void) {
        WidgetCenter.shared.getCurrentConfigurations { result in
            let presence: LockScreenWidgetPresence
            switch result {
            case .success(let infos):
                presence = parseLockScreenWidgets(from: infos)
            case .failure:
                presence = LockScreenWidgetPresence()
            }
            DispatchQueue.main.async {
                completion(presence)
            }
        }
    }

    static func parseLockScreenWidgets(from infos: [WidgetInfo]) -> LockScreenWidgetPresence {
        var nudgeTypes = Set<String>()
        var hasDND = false
        var hasEmergency = false

        for info in infos where lockScreenFamilies.contains(info.family) {
            switch info.kind {
            case KeycapWidgetKindMap.dndWidgetKind:
                hasDND = true
            case KeycapWidgetKindMap.emergencyWidgetKind:
                hasEmergency = true
            default:
                if let type = KeycapWidgetKindMap.nudgeType(forWidgetKind: info.kind) {
                    nudgeTypes.insert(type)
                }
            }
        }

        return LockScreenWidgetPresence(
            nudgeTypes: nudgeTypes,
            hasDNDWidget: hasDND,
            hasEmergencyWidget: hasEmergency
        )
    }
}

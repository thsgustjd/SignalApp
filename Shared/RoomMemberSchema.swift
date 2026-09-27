//
//  RoomMemberSchema.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

enum RoomMemberSchema {
    static let table = "room_members"
    static let selectList = "id,room_id,user_id,display_name,joined_at"
}

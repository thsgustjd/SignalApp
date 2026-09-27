//
//  CalendarArchiveView.swift
//  SignalApp
//

import SwiftUI

struct CalendarArchiveView: View {
    let roomId: UUID
    let myUserId: String
    let myDisplayName: String
    let partnerDisplayName: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: CalendarArchiveViewModel
    @State private var selectedSegment = 0
    @State private var lightboxURL: URL?

    init(
        roomId: UUID,
        myUserId: String,
        myDisplayName: String,
        partnerDisplayName: String,
        statMemberColumns: [CalendarArchiveViewModel.KeycapStatMemberColumn] = []
    ) {
        self.roomId = roomId
        self.myUserId = myUserId
        self.myDisplayName = myDisplayName
        self.partnerDisplayName = partnerDisplayName
        _model = StateObject(
            wrappedValue: CalendarArchiveViewModel(
                roomId: roomId,
                myUserId: myUserId,
                myDisplayName: myDisplayName,
                partnerDisplayName: partnerDisplayName,
                statMemberColumns: statMemberColumns
            )
        )
    }

    /// 방 멤버(최대 5명) → 키캡 표 열.
    static func statMemberColumns(
        room: Room,
        myUserId: String,
        myDisplayName: String,
        partnerDisplayName: String
    ) -> [CalendarArchiveViewModel.KeycapStatMemberColumn] {
        if !room.members.isEmpty {
            return room.members.prefix(5).map {
                CalendarArchiveViewModel.KeycapStatMemberColumn(userId: $0.userId, displayName: $0.displayName)
            }
        }
        var columns = [
            CalendarArchiveViewModel.KeycapStatMemberColumn(userId: myUserId, displayName: myDisplayName)
        ]
        if let partnerId = room.user2Id, !partnerId.isEmpty {
            let partnerName = room.user2Name.flatMap { $0.isEmpty ? nil : $0 } ?? partnerDisplayName
            columns.append(
                CalendarArchiveViewModel.KeycapStatMemberColumn(userId: partnerId, displayName: partnerName)
            )
        }
        return columns
    }

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                calendarHeader
                weekdayHeader
                calendarGrid
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                Divider()

                Picker("", selection: $selectedSegment) {
                    Text("키캡 횟수").tag(0)
                    Text("채팅 기록").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                detailSection
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("다이어리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task(id: model.displayedMonth) {
                await model.loadMonth()
            }
            .fullScreenCover(isPresented: lightboxPresented) {
                if let lightboxURL {
                    ImageDetailView(imageURL: lightboxURL)
                }
            }
        }
    }

    private var lightboxPresented: Binding<Bool> {
        Binding(
            get: { lightboxURL != nil },
            set: { isPresented in
                if !isPresented { lightboxURL = nil }
            }
        )
    }

    private var calendarHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    model.shiftMonth(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(model.monthTitle)
                .font(.headline)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    model.shiftMonth(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(index == 0 ? Color.red : Color.primary.opacity(0.55))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(model.gridDays) { day in
                Button {
                    model.select(day: day.date)
                } label: {
                    CalendarDayCellView(
                        day: day,
                        isSelected: model.isSameDay(day.date, model.selectedDate),
                        isToday: model.isSameDay(day.date, Date()),
                        hasActivity: model.hasActivity(on: day.date)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!day.isCurrentMonth)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    let dx = value.translation.width
                    if dx < -50 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            model.shiftMonth(by: 1)
                        }
                    } else if dx > 50 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            model.shiftMonth(by: -1)
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private var detailSection: some View {
        if model.isLoading && model.monthMessages.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if selectedSegment == 0 {
            keycapStatsSection
        } else {
            chatHistorySection
        }
    }

    private var keycapStatsSection: some View {
        let matrix = model.keycapStatsMatrix(on: model.selectedDate)
        return ScrollView {
            ScrollView(.horizontal, showsIndicators: false) {
                KeycapStatsMatrixTable(matrix: matrix)
            }
            .padding(16)
        }
    }

    private var chatHistorySection: some View {
        let messages = model.chatMessages(on: model.selectedDate)
        return ScrollView {
            if messages.isEmpty {
                emptyState(text: "이날 주고받은 대화가 없어요")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ArchiveChatRow(
                            message: message,
                            isMine: message.senderId == myUserId,
                            onMediaTap: { url in
                                lightboxURL = url
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private func emptyState(text: String) -> some View {
        VStack {
            Spacer(minLength: 40)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day cell

private struct CalendarDayCellView: View {
    let day: CalendarGridDay
    let isSelected: Bool
    let isToday: Bool
    let hasActivity: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.primary.opacity(0.88))
                        .frame(width: 34, height: 34)
                } else if isToday {
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 2)
                        .frame(width: 34, height: 34)
                }
                Text("\(day.dayNumber)")
                    .font(.subheadline.weight(isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(textColor)
            }
            Circle()
                .fill(hasActivity ? Color.accentColor : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(height: 48)
        .opacity(day.isCurrentMonth ? 1 : 0.28)
    }

    private var textColor: Color {
        if isSelected { return Color(.systemBackground) }
        if isToday { return .red }
        if day.weekdayIndex == 0 { return .red.opacity(day.isCurrentMonth ? 0.85 : 1) }
        return .primary
    }
}

private struct KeycapStatsMatrixTable: View {
    let matrix: CalendarArchiveViewModel.KeycapStatsMatrix

    private let emojiColumnWidth: CGFloat = 44
    private let memberColumnWidth: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: emojiColumnWidth, height: 1)
                ForEach(matrix.columns) { column in
                    Text(column.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: memberColumnWidth)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))

            Divider()

            ForEach(Array(matrix.rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 0) {
                    Text(row.emoji)
                        .font(.title3)
                        .frame(width: emojiColumnWidth)
                    ForEach(row.counts, id: \.memberId) { cell in
                        Text(cell.count > 0 ? "\(cell.count)" : "")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(cell.count > 0 ? Color.accentColor : Color.clear)
                            .frame(width: memberColumnWidth)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                if index < matrix.rows.count - 1 {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct ArchiveChatRow: View {
    let message: MediaMessage
    let isMine: Bool
    var onMediaTap: ((URL) -> Void)? = nil

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            ChatMessageBubble(message: message, isMine: isMine, onMediaTap: onMediaTap)
            Text(Self.timeFormatter.string(from: message.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}

// MARK: - View model

struct CalendarGridDay: Identifiable {
    let id: Date
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let weekdayIndex: Int
}

@MainActor
final class CalendarArchiveViewModel: ObservableObject {
    struct SenderKeycapStats {
        let senderId: String
        let displayName: String
        let counts: [(key: String, count: Int)]
    }

    struct KeycapStatMemberColumn: Identifiable, Equatable {
        let userId: String
        let displayName: String

        var id: String { userId }
    }

    struct KeycapStatsMatrix {
        let columns: [KeycapStatMemberColumn]
        let rows: [KeycapStatsMatrixRow]
    }

    struct KeycapStatsMatrixRow: Identifiable {
        let keycapKey: String
        let emoji: String
        let counts: [(memberId: String, count: Int)]

        var id: String { keycapKey }
    }

    let roomId: UUID
    let myUserId: String
    let myDisplayName: String
    let partnerDisplayName: String
    let statMemberColumns: [KeycapStatMemberColumn]

    @Published var displayedMonth: Date
    @Published var selectedDate: Date
    @Published var monthMessages: [MediaMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let calendar = Calendar.current
    private let manager = SupabaseManager.shared

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter
    }()

    init(
        roomId: UUID,
        myUserId: String,
        myDisplayName: String,
        partnerDisplayName: String,
        statMemberColumns: [KeycapStatMemberColumn] = []
    ) {
        self.roomId = roomId
        self.myUserId = myUserId
        self.myDisplayName = myDisplayName
        self.partnerDisplayName = partnerDisplayName
        if statMemberColumns.isEmpty {
            self.statMemberColumns = [
                KeycapStatMemberColumn(userId: myUserId, displayName: myDisplayName)
            ]
        } else {
            self.statMemberColumns = Array(statMemberColumns.prefix(5))
        }
        let today = Calendar.current.startOfDay(for: Date())
        self.displayedMonth = today
        self.selectedDate = today
    }

    var monthTitle: String {
        Self.monthTitleFormatter.string(from: displayedMonth)
    }

    var gridDays: [CalendarGridDay] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        var days: [CalendarGridDay] = []

        if firstWeekday > 0,
           let previousMonth = calendar.date(byAdding: .month, value: -1, to: monthStart),
           let previousRange = calendar.range(of: .day, in: .month, for: previousMonth) {
            let startDay = previousRange.count - firstWeekday + 1
            for day in startDay ... previousRange.count {
                if let date = calendar.date(byAdding: .day, value: day - 1, to: previousMonth) {
                    days.append(makeGridDay(date: date, isCurrentMonth: false))
                }
            }
        }

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(makeGridDay(date: date, isCurrentMonth: true))
            }
        }

        var trailing = (7 - (days.count % 7)) % 7
        if trailing > 0,
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) {
            for offset in 0 ..< trailing {
                if let date = calendar.date(byAdding: .day, value: offset, to: nextMonth) {
                    days.append(makeGridDay(date: date, isCurrentMonth: false))
                }
            }
        }

        return days
    }

    func shiftMonth(by value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = next
        }
    }

    func select(day: Date) {
        selectedDate = calendar.startOfDay(for: day)
    }

    func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    func hasActivity(on day: Date) -> Bool {
        !messages(on: day).isEmpty
    }

    func messages(on day: Date) -> [MediaMessage] {
        monthMessages.filter { isSameDay($0.createdAt, day) }
    }

    func chatMessages(on day: Date) -> [MediaMessage] {
        messages(on: day).filter { SupabaseManager.isChatVisibleMessage($0) }
    }

    func keycapStats(on day: Date) -> [SenderKeycapStats] {
        let nudges = messages(on: day).filter { $0.type == "nudge" }
        guard !nudges.isEmpty else { return [] }

        var bySender: [String: [String: Int]] = [:]
        for nudge in nudges {
            guard let key = AppGroupStorage.keycapSymbolKey(fromNudgeContent: nudge.content),
                  AppGroupStorage.isActiveKeycapType(key) else {
                continue
            }
            var bucket = bySender[nudge.senderId, default: [:]]
            bucket[key, default: 0] += 1
            bySender[nudge.senderId] = bucket
        }

        return bySender.map { senderId, counts in
            let sorted = counts.sorted { $0.value > $1.value }
            return SenderKeycapStats(
                senderId: senderId,
                displayName: displayName(for: senderId, messageNickname: nudges.first(where: { $0.senderId == senderId })?.senderNickname),
                counts: sorted.map { (key: $0.key, count: $0.value) }
            )
        }
        .sorted { $0.displayName < $1.displayName }
    }

    /// 표 UI — 행: 키캡 순서, 열: 멤버(최대 5명).
    func keycapStatsMatrix(on day: Date) -> KeycapStatsMatrix {
        let nudges = messages(on: day).filter { $0.type == "nudge" }
        var bySender: [String: [String: Int]] = [:]
        for nudge in nudges {
            guard let key = AppGroupStorage.keycapSymbolKey(fromNudgeContent: nudge.content),
                  AppGroupStorage.isActiveKeycapType(key) else {
                continue
            }
            var bucket = bySender[nudge.senderId, default: [:]]
            bucket[key, default: 0] += 1
            bySender[nudge.senderId] = bucket
        }

        let columns = resolvedStatColumns(from: nudges)
        let rows = AppGroupStorage.keycapNudgeTypeOrder.map { key in
            let emoji = AppGroupStorage.keycapSymbolPresentation(for: key).emoji
            let counts = columns.map { column in
                (
                    memberId: column.userId,
                    count: nudgeCount(for: column.userId, keycapKey: key, in: bySender)
                )
            }
            return KeycapStatsMatrixRow(keycapKey: key, emoji: emoji, counts: counts)
        }

        return KeycapStatsMatrix(columns: columns, rows: rows)
    }

    func loadMonth() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            monthMessages = try await manager.fetchMessagesForMonth(roomId: roomId, month: displayedMonth)
        } catch {
            errorMessage = error.localizedDescription
            monthMessages = []
        }
    }

    private func makeGridDay(date: Date, isCurrentMonth: Bool) -> CalendarGridDay {
        CalendarGridDay(
            id: calendar.startOfDay(for: date),
            date: date,
            dayNumber: calendar.component(.day, from: date),
            isCurrentMonth: isCurrentMonth,
            weekdayIndex: calendar.component(.weekday, from: date) - 1
        )
    }

    private func displayName(for senderId: String, messageNickname: String?) -> String {
        if DeviceUserId.matches(senderId, myUserId) {
            return myDisplayName
        }
        if let messageNickname, !messageNickname.isEmpty {
            return messageNickname
        }
        return partnerDisplayName
    }

    private func resolvedStatColumns(from nudges: [MediaMessage]) -> [KeycapStatMemberColumn] {
        guard statMemberColumns.isEmpty else { return statMemberColumns }
        var seen = Set<String>()
        var columns: [KeycapStatMemberColumn] = []
        for nudge in nudges {
            guard !seen.contains(nudge.senderId) else { continue }
            seen.insert(nudge.senderId)
            columns.append(
                KeycapStatMemberColumn(
                    userId: nudge.senderId,
                    displayName: displayName(for: nudge.senderId, messageNickname: nudge.senderNickname)
                )
            )
            if columns.count >= 5 { break }
        }
        return columns
    }

    private func nudgeCount(for userId: String, keycapKey: String, in bySender: [String: [String: Int]]) -> Int {
        guard let bucket = bySender.first(where: { DeviceUserId.matches($0.key, userId) })?.value else {
            return 0
        }
        return bucket[keycapKey] ?? 0
    }
}

#Preview {
    CalendarArchiveView(
        roomId: UUID(),
        myUserId: "me",
        myDisplayName: "나",
        partnerDisplayName: "상대"
    )
}

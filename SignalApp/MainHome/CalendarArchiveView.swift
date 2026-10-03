//
//  CalendarArchiveView.swift
//  SignalApp
//

import SwiftUI

extension Notification.Name {
    /// 키캡 전송 후 다이어리 `monthMessages` 갱신용.
    static let keycapDiaryShouldReload = Notification.Name("KeycapDiaryShouldReload")
}

enum KeycapDiaryReloadKeys {
    static let message = "KeycapDiaryReloadKeys.message"
}

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
            .task {
                model.focusOnToday()
                await model.loadMonth()
            }
            .onAppear {
                model.focusOnToday()
                Task { await model.loadMonth() }
            }
            .onChange(of: model.displayedMonth) { _, _ in
                Task { await model.loadMonth() }
            }
            .onChange(of: selectedSegment) { _, segment in
                if segment == 0 {
                    Task { await model.loadMonth() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .keycapDiaryShouldReload)) { note in
                guard let postedRoomId = note.object as? UUID, postedRoomId == roomId else { return }
                let sent = note.userInfo?[KeycapDiaryReloadKeys.message] as? MediaMessage
                if let sent {
                    model.applyKeycapSentForDiary(sent)
                }
                Task { await model.reloadMonth(merging: sent) }
            }
            .task(id: roomId) {
                await model.runDiaryRealtimeMerge(roomId: roomId)
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
                    .id("\(model.selectedDate.timeIntervalSince1970)-\(model.monthMessages.count)")
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
                    ForEach(row.counts, id: \.cellId) { cell in
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
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
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
        /// `cellId` — 행×열 ForEach identity (`memberId`만 쓰면 SwiftUI가 행 간 셀을 재사용해 숫자가 안 보일 수 있음).
        let counts: [(cellId: String, count: Int)]

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

    private var keycapDiaryDebugFingerprint: String?

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
        self.myUserId = DeviceUserId.canonical(myUserId)
        self.myDisplayName = myDisplayName
        self.partnerDisplayName = partnerDisplayName
        if statMemberColumns.isEmpty {
            self.statMemberColumns = [
                KeycapStatMemberColumn(userId: self.myUserId, displayName: myDisplayName)
            ]
        } else {
            self.statMemberColumns = Array(statMemberColumns.prefix(5)).map {
                KeycapStatMemberColumn(
                    userId: DeviceUserId.canonical($0.userId),
                    displayName: $0.displayName
                )
            }
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
            if !calendar.isDate(selectedDate, equalTo: next, toGranularity: .month) {
                let today = calendar.startOfDay(for: Date())
                if calendar.isDate(today, equalTo: next, toGranularity: .month) {
                    selectedDate = today
                } else if let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: next)) {
                    selectedDate = monthStart
                }
            }
            keycapDiaryDebugFingerprint = nil
        }
    }

    func select(day: Date) {
        selectedDate = calendar.startOfDay(for: day)
        keycapDiaryDebugFingerprint = nil
    }

    /// 다이어리를 열 때 **항상 당일** + 당일이 속한 달 (자동으로 다른 날로 옮기지 않음).
    func focusOnToday() {
        let today = calendar.startOfDay(for: Date())
        selectedDate = today
        displayedMonth = today
        keycapDiaryDebugFingerprint = nil
    }

    /// 키캡 전송 직후 — fetch 전에 `monthMessages`·선택일을 먼저 맞춤 (다이어리 켜 둔 상태).
    func applyKeycapSentForDiary(_ message: MediaMessage) {
        let monthInterval = SupabaseManager.localCalendarMonthInterval(containing: displayedMonth, calendar: calendar)
        upsertMonthMessage(message, monthInterval: monthInterval)
        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(message.createdAt, inSameDayAs: today) {
            selectedDate = today
            if !calendar.isDate(displayedMonth, equalTo: today, toGranularity: .month) {
                displayedMonth = today
            }
        }
    }

    func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    /// 캘린더 점 — **키캡 다이어리 집계 대상**이 있는 날만 (채팅만 있는 날과 구분).
    func hasActivity(on day: Date) -> Bool {
        !keycapDiaryMessages(on: day).isEmpty
    }

    func messages(on day: Date) -> [MediaMessage] {
        let interval = Self.localDayInterval(for: calendar.startOfDay(for: day), calendar: calendar)
        return monthMessages.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
    }

    /// 키캡 다이어리 집계 — `nudge` + 레거시 `emoji`(❤️ 등) 포함.
    private func keycapDiaryMessages(on day: Date) -> [MediaMessage] {
        messages(on: day).filter {
            AppGroupStorage.isKeycapDiaryCountableMessage(type: $0.type, content: $0.content)
        }
    }

    /// 로컬 타임존 기준 하루 [00:00, 다음날 00:00).
    private static func localDayInterval(for day: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    func chatMessages(on day: Date) -> [MediaMessage] {
        messages(on: day).filter { SupabaseManager.isChatVisibleMessage($0) }
    }

    func keycapStats(on day: Date) -> [SenderKeycapStats] {
        let nudges = keycapDiaryMessages(on: day)
        guard !nudges.isEmpty else { return [] }

        var bySender: [String: [String: Int]] = [:]
        for nudge in nudges {
            guard let key = AppGroupStorage.keycapDiarySymbolKey(fromNudgeContent: nudge.content) else {
                continue
            }
            let senderKey = DeviceUserId.canonical(nudge.senderId)
            var bucket = bySender[senderKey, default: [:]]
            bucket[key, default: 0] += 1
            bySender[senderKey] = bucket
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
        let nudges = keycapDiaryMessages(on: day)
        var bySender: [String: [String: Int]] = [:]
        for nudge in nudges {
            guard let key = AppGroupStorage.keycapDiarySymbolKey(fromNudgeContent: nudge.content) else {
                continue
            }
            let senderKey = DeviceUserId.canonical(nudge.senderId)
            var bucket = bySender[senderKey, default: [:]]
            bucket[key, default: 0] += 1
            bySender[senderKey] = bucket
        }

        let columns = resolvedStatColumns(bySender: bySender, nudges: nudges)
        let rows = AppGroupStorage.keycapNudgeTypeOrder.map { key in
            let emoji = AppGroupStorage.keycapSymbolPresentation(for: key).emoji
            let counts = columns.enumerated().map { columnIndex, column in
                (
                    cellId: "\(key)-\(columnIndex)-\(column.userId)",
                    count: countInSenderBucket(
                        bySender: bySender,
                        senderKeyHint: column.userId,
                        keycapKey: key
                    )
                )
            }
            return KeycapStatsMatrixRow(keycapKey: key, emoji: emoji, counts: counts)
        }

        let matrix = KeycapStatsMatrix(columns: columns, rows: rows)
        let senderSig = bySender.keys.sorted().joined(separator: ",")
        let fingerprint = "\(day.timeIntervalSince1970)-\(monthMessages.count)-\(nudges.count)-\(senderSig)"
        if keycapDiaryDebugFingerprint != fingerprint {
            keycapDiaryDebugFingerprint = fingerprint
            emitKeycapDiaryDebug(
                day: day,
                nudges: nudges,
                bySender: bySender,
                columns: columns,
                rows: rows
            )
        }
        return matrix
    }

    func loadMonth() async {
        await reloadMonth(merging: nil)
    }

    /// 다이어리 표시 중 Realtime INSERT → `monthMessages`에 즉시 반영 (오늘·상대 키캡).
    func runDiaryRealtimeMerge(roomId: UUID) async {
        for await message in manager.watchChatMessageInserts(roomId: roomId) {
            guard !Task.isCancelled else { break }
            mergeRealtimeMessageIfNeeded(message)
        }
    }

    func mergeRealtimeMessageIfNeeded(_ message: MediaMessage) {
        guard message.roomId == roomId else { return }
        let monthInterval = SupabaseManager.localCalendarMonthInterval(containing: displayedMonth, calendar: calendar)
        guard message.createdAt >= monthInterval.start, message.createdAt < monthInterval.end else { return }
        upsertMonthMessage(message, monthInterval: monthInterval)
    }

    /// 월 재조회 + 방금 INSERT한 넛지를 즉시 반영 (fetch 지연·다이어리 선오픈 대비).
    func reloadMonth(merging sentMessage: MediaMessage?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let monthInterval = SupabaseManager.localCalendarMonthInterval(containing: displayedMonth, calendar: calendar)
        let rangeStart = monthInterval.start
        let rangeEnd = monthInterval.end

        do {
            monthMessages = try await manager.fetchMessagesForMonth(roomId: roomId, month: displayedMonth)
            if let sentMessage {
                upsertMonthMessage(sentMessage, monthInterval: monthInterval)
            }
            keycapDiaryDebugFingerprint = nil
            KeycapDiaryDebug.logMonthFetch(
                roomId: roomId,
                month: displayedMonth,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                myUserId: myUserId,
                statColumns: statMemberColumns.map { ($0.userId, $0.displayName) },
                messages: monthMessages.map(KeycapDiaryDebug.MessageRow.init(mediaMessage:))
            )
            if let sentMessage {
                KeycapDiaryDebug.log(
                    "reloadMonth merged sent id=\(sentMessage.id) created=\(sentMessage.createdAt) diaryEligible=\(AppGroupStorage.isKeycapDiaryCountableMessage(type: sentMessage.type, content: sentMessage.content))"
                )
            }
            await supplementSelectedDayIfKeycapRowsMissing(monthInterval: monthInterval)
        } catch {
            errorMessage = UserFacingErrorMessage.loadMessage(from: error)
            monthMessages = []
            if let sentMessage {
                upsertMonthMessage(sentMessage, monthInterval: monthInterval)
            }
            KeycapDiaryDebug.log("loadMonth FAILED: \(error.localizedDescription)")
        }
    }

    /// 월 fetch 후에도 선택일 키캡 row가 없으면 해당 **로컬 하루**만 재조회 (1000행 잘림·INSERT 지연 보정).
    private func supplementSelectedDayIfKeycapRowsMissing(monthInterval: (start: Date, end: Date)) async {
        let day = calendar.startOfDay(for: selectedDate)
        guard keycapDiaryMessages(on: day).isEmpty else { return }

        do {
            let dayRows = try await manager.fetchMessagesForLocalDay(roomId: roomId, day: day, calendar: calendar)
            guard !dayRows.isEmpty else { return }
            for row in dayRows {
                upsertMonthMessage(row, monthInterval: monthInterval)
            }
            keycapDiaryDebugFingerprint = nil
            KeycapDiaryDebug.log(
                """
                supplementSelectedDay day=\(KeycapDiaryDebug.dayLabelForLog(day)) \
                addedRows=\(dayRows.count) diaryEligible=\(dayRows.filter { AppGroupStorage.isKeycapDiaryCountableMessage(type: $0.type, content: $0.content) }.count)
                """
            )
        } catch {
            KeycapDiaryDebug.log("supplementSelectedDay FAILED: \(error.localizedDescription)")
        }
    }

    private func upsertMonthMessage(_ message: MediaMessage, monthInterval: (start: Date, end: Date)) {
        guard message.roomId == roomId else { return }
        guard message.createdAt >= monthInterval.start, message.createdAt < monthInterval.end else { return }
        if let index = monthMessages.firstIndex(where: { $0.id == message.id }) {
            monthMessages[index] = message
        } else {
            monthMessages.append(message)
            monthMessages.sort { $0.createdAt < $1.createdAt }
        }
        keycapDiaryDebugFingerprint = nil
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

    private func resolvedStatColumns(
        bySender: [String: [String: Int]],
        nudges: [MediaMessage]
    ) -> [KeycapStatMemberColumn] {
        if !statMemberColumns.isEmpty {
            return statMemberColumns.map { column in
                let matched = resolveSenderId(
                    for: column,
                    bySender: bySender,
                    nudges: nudges,
                    logResolution: !bySender.isEmpty
                )
                if matched == nil, !bySender.isEmpty {
                    KeycapDiaryDebug.log(
                        """
                        column «\(column.displayName)» memberUserId=\(column.userId) \
                        could not map to bySender keys — counts may show 0 (fallback userId=\(column.userId))
                        """
                    )
                }
                return KeycapStatMemberColumn(
                    userId: matched ?? column.userId,
                    displayName: column.displayName
                )
            }
        }

        var seen = Set<String>()
        var columns: [KeycapStatMemberColumn] = []
        for senderId in bySender.keys.sorted() {
            let canonical = DeviceUserId.canonical(senderId)
            guard !seen.contains(canonical) else { continue }
            seen.insert(canonical)
            columns.append(
                KeycapStatMemberColumn(
                    userId: senderId,
                    displayName: displayName(
                        for: senderId,
                        messageNickname: nudges.first(where: { DeviceUserId.matches($0.senderId, senderId) })?.senderNickname
                    )
                )
            )
            if columns.count >= 5 { break }
        }
        return columns
    }

    /// `room_members.user_id`와 `messages.sender_id` 불일치 시 닉네임·매칭으로 집계 키 보정.
    private func resolveSenderId(
        for column: KeycapStatMemberColumn,
        bySender: [String: [String: Int]],
        nudges: [MediaMessage],
        logResolution: Bool = false
    ) -> String? {
        if let key = bySender.keys.first(where: { DeviceUserId.matches($0, column.userId) }) {
            if logResolution {
            KeycapDiaryDebug.logResolveSender(
                columnDisplayName: column.displayName,
                columnUserId: column.userId,
                outcome: "matched memberUserId",
                matchedSenderId: key
            )
            }
            return key
        }
        for senderId in bySender.keys {
            let name = displayName(
                for: senderId,
                messageNickname: nudges.first(where: { DeviceUserId.matches($0.senderId, senderId) })?.senderNickname
            )
            if namesMatch(name, column.displayName) {
                if logResolution {
                KeycapDiaryDebug.logResolveSender(
                    columnDisplayName: column.displayName,
                    columnUserId: column.userId,
                    outcome: "matched displayName «\(name)»",
                    matchedSenderId: senderId
                )
                }
                return senderId
            }
        }
        for nudge in nudges {
            let senderKey = DeviceUserId.canonical(nudge.senderId)
            guard bySender[senderKey] != nil else { continue }
            if namesMatch(nudge.senderNickname, column.displayName) {
                if logResolution {
                KeycapDiaryDebug.logResolveSender(
                    columnDisplayName: column.displayName,
                    columnUserId: column.userId,
                    outcome: "matched nudge senderNickname",
                    matchedSenderId: senderKey
                )
                }
                return senderKey
            }
        }
        if logResolution {
        KeycapDiaryDebug.logResolveSender(
            columnDisplayName: column.displayName,
            columnUserId: column.userId,
            outcome: "no match",
            matchedSenderId: nil
        )
        }
        return nil
    }

    /// `bySender` 버킷 조회 — `resolvedStatColumns`가 넣은 `sender_id` 키·canonical·퍼지 매칭.
    private func countInSenderBucket(
        bySender: [String: [String: Int]],
        senderKeyHint: String,
        keycapKey: String
    ) -> Int {
        if let bucket = bySender[senderKeyHint], let count = bucket[keycapKey] {
            return count
        }
        let canonicalHint = DeviceUserId.canonical(senderKeyHint)
        if canonicalHint != senderKeyHint,
           let bucket = bySender[canonicalHint],
           let count = bucket[keycapKey] {
            return count
        }
        if let matchedKey = bySender.keys.first(where: { DeviceUserId.matches($0, senderKeyHint) }),
           let count = bySender[matchedKey]?[keycapKey] {
            return count
        }
        return 0
    }

    private func keycapCount(
        for member: KeycapStatMemberColumn,
        keycapKey: String,
        bySender: [String: [String: Int]],
        nudges: [MediaMessage]
    ) -> Int {
        guard let senderKey = aggregationSenderKey(for: member, bySender: bySender, nudges: nudges) else {
            return 0
        }
        return countInSenderBucket(bySender: bySender, senderKeyHint: senderKey, keycapKey: keycapKey)
    }

    /// `room_members.user_id` ≠ `messages.sender_id` 여도 a/c 열에 합산되도록.
    private func aggregationSenderKey(
        for member: KeycapStatMemberColumn,
        bySender: [String: [String: Int]],
        nudges: [MediaMessage]
    ) -> String? {
        if let resolved = resolveSenderId(for: member, bySender: bySender, nudges: nudges) {
            return resolved
        }
        if let direct = bySender.keys.first(where: { DeviceUserId.matches($0, member.userId) }) {
            return direct
        }
        if DeviceUserId.matches(member.userId, myUserId) {
            return bySender.keys.first(where: { DeviceUserId.matches($0, myUserId) })
        }
        let otherKeys = bySender.keys.filter { !DeviceUserId.matches($0, myUserId) }
        if otherKeys.count == 1 {
            return otherKeys[0]
        }
        return nil
    }

    private func namesMatch(_ lhs: String?, _ rhs: String) -> Bool {
        let a = lhs?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let b = rhs.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a.compare(b, options: .caseInsensitive) == .orderedSame
    }

    private func emitKeycapDiaryDebug(
        day: Date,
        nudges: [MediaMessage],
        bySender: [String: [String: Int]],
        columns: [KeycapStatMemberColumn],
        rows: [KeycapStatsMatrixRow]
    ) {
        let resolvedTrace: [(userId: String, displayName: String, resolvedFrom: String)] = {
            if statMemberColumns.isEmpty {
                return columns.map { ($0.userId, $0.displayName, $0.userId) }
            }
            return zip(statMemberColumns, columns).map { member, column in
                (member.userId, member.displayName, column.userId)
            }
        }()
        let preview = rows.prefix(8).map { row in
            (emoji: row.emoji, key: row.keycapKey, counts: row.counts.map(\.count))
        }
        KeycapDiaryDebug.logDayAggregation(
            day: day,
            myUserId: myUserId,
            myDisplayName: myDisplayName,
            partnerDisplayName: partnerDisplayName,
            statColumns: statMemberColumns.map { ($0.userId, $0.displayName) },
            nudges: nudges.map(KeycapDiaryDebug.MessageRow.init(mediaMessage:)),
            bySender: bySender,
            resolvedColumns: resolvedTrace,
            matrixPreview: Array(preview)
        )
    }
}

private extension KeycapDiaryDebug.MessageRow {
    init(mediaMessage message: MediaMessage) {
        self.init(
            type: message.type,
            senderId: message.senderId,
            senderNickname: message.senderNickname,
            content: message.content,
            createdAt: message.createdAt
        )
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

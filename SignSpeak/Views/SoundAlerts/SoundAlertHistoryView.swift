import SwiftUI

/// History view displaying logged sound detections (`64-sound-alert-history`).
public struct SoundAlertHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SoundAlertsViewModel

    @State private var selectedFilter: HistoryFilter = .all
    @State private var showingClearConfirmation: Bool = false

    enum HistoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case emergencies = "Emergencies"
        case household = "Household"

        var id: String { rawValue }
    }

    public init(viewModel: SoundAlertsViewModel) {
        self.viewModel = viewModel
    }

    private var filteredRecords: [SoundAlertRecord] {
        switch selectedFilter {
        case .all:
            return viewModel.history
        case .emergencies:
            return viewModel.history.filter { $0.isEmergency }
        case .household:
            return viewModel.history.filter { !$0.isEmergency }
        }
    }

    private var groupedRecords: [(key: String, records: [SoundAlertRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecords) { record -> String in
            if calendar.isDateInToday(record.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(record.timestamp) {
                return "Yesterday"
            } else {
                return record.timestamp.formatted(date: .abbreviated, time: .omitted)
            }
        }

        let order = ["Today", "Yesterday"]
        return grouped.sorted { (item1, item2) -> Bool in
            let idx1 = order.firstIndex(of: item1.key) ?? Int.max
            let idx2 = order.firstIndex(of: item2.key) ?? Int.max
            if idx1 != idx2 {
                return idx1 < idx2
            }
            return item1.key > item2.key
        }.map { (key: $0.key, records: $0.value) }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Segmented Bar
                HStack(spacing: 8) {
                    ForEach(HistoryFilter.allCases) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 14, weight: selectedFilter == filter ? .bold : .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedFilter == filter ? Color.brandTurquoise : Color.cardBackground,
                                    in: Capsule()
                                )
                                .foregroundStyle(
                                    selectedFilter == filter ? Color.brandNavy : Color.textPrimary
                                )
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)

                if filteredRecords.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(groupedRecords, id: \.key) { section in
                            Section {
                                ForEach(section.records) { record in
                                    historyRow(record)
                                }
                            } header: {
                                Text(section.key)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.textSecondary)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Alert History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.history.isEmpty {
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.danger)
                        }
                    }
                }
            }
            .confirmationDialog("Clear Alert History?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
                Button("Clear All History", role: .destructive) {
                    viewModel.clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all recorded sound detection logs. This action cannot be undone.")
            }
        }
    }

    private func historyRow(_ record: SoundAlertRecord) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(record.isEmergency ? Color.danger.opacity(0.15) : Color.brandYellow.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: record.type.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(record.isEmergency ? Color.danger : Color.brandYellow)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.type.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    if record.isEmergency {
                        Text("EMERGENCY")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.danger, in: Capsule())
                    }
                }

                Text(record.type.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)

                Text("\(Int(record.confidence * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.brandTurquoise)
            }

            Text("No Alerts Logged Yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("When SignSpeak detects environmental sounds like doorbells, knocks, or alarms, they will appear here.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }
}

import SwiftUI

struct ItemRowView: View {
    let item: Item
    var showArea = true
    var projectName: String?
    var onToggle: (() -> Void)?
    var onEdit: (() -> Void)?

    private var done: Bool { item.status == .done }
    private var overdue: Bool { !done && (item.dueDate.map { $0 < BerlinTime.today() } ?? false) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if item.type == .todo {
                Button {
                    onToggle?()
                } label: {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(done ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(done ? "\(item.title) wieder öffnen" : "\(item.title) erledigt")
            } else {
                Image(systemName: item.type.symbol)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(item.type.label)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .strikethrough(done)
                        .foregroundStyle(done ? .secondary : .primary)
                    if item.priority == .high {
                        Circle().fill(.red).frame(width: 6, height: 6)
                            .accessibilityLabel("Hohe Priorität")
                    }
                }
                meta
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit?() }
    }

    @ViewBuilder private var meta: some View {
        if showArea || projectName != nil || item.dueDate != nil {
            HStack(spacing: 10) {
                if showArea { Text(item.area.name) }
                if let projectName { Label(projectName, systemImage: "folder") }
                if let due = item.dueDate {
                    Label("fällig \(BerlinTime.formatDay(due))", systemImage: "calendar")
                        .foregroundStyle(overdue ? Color.red : Color.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
    }
}

struct OccurrenceRowView: View {
    let occurrence: Occurrence

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(CalendarGrouping.timeLabel(occurrence))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(occurrence.title)
                    if occurrence.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Wiederholung")
                    }
                    if occurrence.source == .icsImport {
                        Text("importiert")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4)))
                    }
                }
                if let location = occurrence.location {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

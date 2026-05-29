import SwiftUI

struct WeekReportView: View {
    let goals: [String]
    let days: [DayAggregate]
    let weekStart: Date
    let weekEnd: Date
    let onClose: () -> Void

    enum State: Equatable {
        case loading
        case loaded(WeekReport)
        case failed(String)
    }

    @EnvironmentObject private var auth: AuthService
    @SwiftUI.State private var state: State = .loading
    @SwiftUI.State private var runID: Int = 0
    @SwiftUI.State private var didSave = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(rangeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Palette.ink)
                    }
                }
            }
        }
        .task(id: runID) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            VStack(spacing: Spacing.md) {
                ProgressView()
                Text("Generating your weekly report…")
                    .font(.cwCaption)
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let report):
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if !report.goalAnalyses.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            ForEach(report.goalAnalyses) { analysis in
                                goalCard(analysis)
                            }
                        }
                    }

                    if !report.ideas.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("\(report.ideas.count) IDEAS TO BETTER USE YOUR TIME")
                                .font(.cwCaption)
                                .tracking(1.2)
                                .foregroundStyle(Palette.muted)

                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                ForEach(Array(report.ideas.enumerated()), id: \.offset) { index, idea in
                                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                                        Text("\(index + 1).")
                                            .font(.cwBody.weight(.semibold))
                                            .foregroundStyle(Palette.muted)
                                            .frame(width: 24, alignment: .leading)
                                        Text(idea)
                                            .font(.cwBody)
                                            .foregroundStyle(Palette.ink)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.white)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(Palette.border, lineWidth: 1)
                            )
                        }
                    }

                    Button(action: { runID += 1 }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "arrow.clockwise")
                            Text("Regenerate")
                        }
                        .font(.cwBody.weight(.semibold))
                        .foregroundColor(Palette.amber)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.sm)
                }
                .padding(Spacing.md)
            }

        case .failed(let message):
            VStack(spacing: Spacing.md) {
                Text("Couldn’t generate the report")
                    .font(.cwBody.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(.cwCaption)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                Button(action: { runID += 1 }) {
                    Text("Try again")
                        .font(.cwBody.weight(.semibold))
                        .foregroundColor(Palette.amber)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func goalCard(_ analysis: GoalAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(analysis.goal)
                .font(.cwBody.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text(analysis.summary)
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    private var rangeTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Week of \(f.string(from: weekStart)) – \(f.string(from: weekEnd))"
    }

    private func load() async {
        state = .loading
        do {
            let report = try await WeekReportService.generate(
                goals: goals,
                weekStart: weekStart,
                weekEnd: weekEnd,
                days: days
            )
            state = .loaded(report)
            if !didSave {
                didSave = true
                await persistReport(report)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func persistReport(_ report: WeekReport) async {
        guard let uid = auth.currentUser?.uid else { return }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let title = "Week of \(f.string(from: weekStart)) – \(f.string(from: weekEnd))"
        let profileReport = ProfileReport(
            id: ProfileReportsService.newReportId(),
            title: title,
            html: makeHTML(report),
            rangeStart: weekStart,
            rangeEnd: weekEnd,
            customPrompt: nil,
            createdAt: Date()
        )
        try? await ProfileReportsService.shared.save(uid: uid, report: profileReport)
    }

    private func makeHTML(_ report: WeekReport) -> String {
        var html = "<html><body style=\"font-family: -apple-system, Helvetica; padding: 16px; color: #111;\">"
        for analysis in report.goalAnalyses {
            html += "<div style=\"margin-bottom: 16px; padding: 16px; background: #fff; border: 1px solid #e5e5e5; border-radius: 12px;\">"
            html += "<strong style=\"font-size: 15px;\">\(analysis.goal)</strong>"
            html += "<p style=\"margin-top: 8px; font-size: 15px; line-height: 1.5;\">\(analysis.summary)</p></div>"
        }
        if !report.ideas.isEmpty {
            html += "<p style=\"font-size: 11px; color: #999; letter-spacing: 1px; text-transform: uppercase; margin-bottom: 8px;\">\(report.ideas.count) IDEAS TO BETTER USE YOUR TIME</p>"
            html += "<div style=\"padding: 16px; background: #fff; border: 1px solid #e5e5e5; border-radius: 12px;\"><ol style=\"margin: 0; padding-left: 20px;\">"
            for idea in report.ideas {
                html += "<li style=\"margin-bottom: 8px; font-size: 15px; line-height: 1.5;\">\(idea)</li>"
            }
            html += "</ol></div>"
        }
        html += "</body></html>"
        return html
    }
}

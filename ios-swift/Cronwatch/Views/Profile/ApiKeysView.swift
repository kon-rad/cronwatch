import SwiftUI

struct ApiKeysView: View {
    let uid: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let docsURL = URL(string: "https://cronwatch.xyz/docs")!
    private let skillURL = URL(string: "https://cronwatch.xyz/skill.md")!

    @State private var keys: [ApiKey] = []
    @State private var isLoading = true
    @State private var loadError: String?

    @State private var showCreateSheet = false
    @State private var revealedKey: RevealedKey?

    @State private var pendingDeleteKey: ApiKey?
    @State private var pendingRefreshKey: ApiKey?
    @State private var isWorking = false
    @State private var workError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Palette.amber)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Palette.amber)
                    }
                }
            }
        }
        .task { await loadKeys() }
        .sheet(isPresented: $showCreateSheet) {
            CreateApiKeySheet(uid: uid) { key, rawKey in
                keys.insert(key, at: 0)
                revealedKey = RevealedKey(key: key, rawKey: rawKey)
            }
        }
        .sheet(item: $revealedKey) { revealed in
            RevealKeySheet(key: revealed.key, rawKey: revealed.rawKey)
        }
        .alert("Delete key?", isPresented: Binding(
            get: { pendingDeleteKey != nil },
            set: { if !$0 { pendingDeleteKey = nil } }
        ), presenting: pendingDeleteKey) { key in
            Button("Cancel", role: .cancel) { pendingDeleteKey = nil }
            Button("Delete", role: .destructive) {
                Task { await onDelete(key) }
            }
        } message: { key in
            Text("\"\(key.name)\" (\(key.prefix)…) will stop working immediately.")
        }
        .alert("Refresh key?", isPresented: Binding(
            get: { pendingRefreshKey != nil },
            set: { if !$0 { pendingRefreshKey = nil } }
        ), presenting: pendingRefreshKey) { key in
            Button("Cancel", role: .cancel) { pendingRefreshKey = nil }
            Button("Refresh", role: .destructive) {
                Task { await onRefresh(key) }
            }
        } message: { key in
            Text("A new key will be generated. The old key (\(key.prefix)…) stops working immediately.")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack { Spacer(); ProgressView(); Spacer() }
        } else if let err = loadError {
            VStack(spacing: Spacing.sm) {
                Spacer()
                Text(err).font(.cwCaption).foregroundColor(Palette.muted).multilineTextAlignment(.center)
                Button("Retry") { Task { await loadKeys() } }
                    .font(.cwBody).foregroundColor(Palette.amber)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
        } else if keys.isEmpty {
            emptyState
        } else {
            keyList
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Image(systemName: "key")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Palette.muted)
                    .padding(.top, Spacing.xl)
                Text("No API keys yet.")
                    .font(.cwBody)
                    .foregroundColor(Palette.muted)
                Text("Create a key to give agents read access to your time entries.")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                Button("Create API Key") { showCreateSheet = true }
                    .font(.cwBody.weight(.semibold))
                    .foregroundColor(Palette.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 12)
                    .background(Palette.amber)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                resourcesSection
                    .padding(.top, Spacing.xl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }

    private var keyList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(spacing: 0) {
                    if let err = workError {
                        Text(err)
                            .font(.cwCaption)
                            .foregroundColor(Palette.danger)
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(Array(keys.enumerated()), id: \.element.id) { index, key in
                        keyRow(key: key, isFirst: index == 0)
                    }
                }
                .background(Palette.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Palette.border, lineWidth: 1)
                )

                resourcesSection
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - Resources (docs + agent skill)

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("LEARN MORE")
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundColor(Palette.muted)

            VStack(spacing: 0) {
                resourceRow(
                    title: "API documentation",
                    subtitle: "cronwatch.xyz/docs",
                    url: docsURL,
                    isFirst: true
                )
                resourceRow(
                    title: "Agent skill file",
                    subtitle: "skill.md — drop into Claude & other agents",
                    url: skillURL,
                    isFirst: false
                )
            }
            .background(Palette.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )

            Text("Hand the docs or skill file to any agent so it can read your time entries using a key above.")
                .font(.cwCaption)
                .foregroundColor(Palette.muted)
        }
    }

    private func resourceRow(title: String, subtitle: String, url: URL, isFirst: Bool) -> some View {
        Button {
            openURL(url)
        } label: {
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle().fill(Palette.border).frame(height: 0.5)
                }
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.cwBody)
                            .foregroundColor(Palette.ink)
                        Text(subtitle)
                            .font(.cwCaption)
                            .foregroundColor(Palette.muted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Palette.muted)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func keyRow(key: ApiKey, isFirst: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFirst {
                Rectangle().fill(Palette.border).frame(height: 0.5)
            }
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(key.name)
                        .font(.cwBody.weight(.semibold))
                        .foregroundColor(Palette.ink)
                    Text("\(key.prefix)…")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Palette.muted)
                    Text(key.createdAt, style: .date)
                        .font(.cwCaption)
                        .foregroundColor(Palette.muted)
                }
                Spacer()
                Menu {
                    Button {
                        pendingRefreshKey = key
                    } label: {
                        Label("Refresh key", systemImage: "arrow.clockwise")
                    }
                    Button(role: .destructive) {
                        pendingDeleteKey = key
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Palette.muted)
                        .frame(width: 36, height: 36)
                        .background(Palette.borderSoft)
                        .clipShape(Circle())
                }
                .disabled(isWorking)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Actions

    private func loadKeys() async {
        isLoading = true
        loadError = nil
        do {
            keys = try await ApiKeyService.shared.list(uid: uid)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func onDelete(_ key: ApiKey) async {
        pendingDeleteKey = nil
        isWorking = true
        workError = nil
        do {
            try await ApiKeyService.shared.delete(uid: uid, keyId: key.id)
            keys.removeAll { $0.id == key.id }
        } catch {
            workError = error.localizedDescription
        }
        isWorking = false
    }

    private func onRefresh(_ key: ApiKey) async {
        pendingRefreshKey = nil
        isWorking = true
        workError = nil
        do {
            let (newKey, rawKey) = try await ApiKeyService.shared.refresh(uid: uid, keyId: key.id, name: key.name)
            keys.removeAll { $0.id == key.id }
            keys.insert(newKey, at: 0)
            revealedKey = RevealedKey(key: newKey, rawKey: rawKey)
        } catch {
            workError = error.localizedDescription
        }
        isWorking = false
    }
}

// MARK: - Create sheet

private struct CreateApiKeySheet: View {
    let uid: String
    let onCreated: (ApiKey, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var isCreating = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("KEY NAME")
                        .font(.cwCaption)
                        .tracking(1.2)
                        .foregroundColor(Palette.muted)
                    TextField("e.g. My Agent", text: $name)
                        .font(.cwBody)
                        .foregroundColor(Palette.ink)
                        .padding(Spacing.md)
                        .background(Palette.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(focused ? Palette.amber : Palette.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { Task { await onCreate() } }
                }

                if let error {
                    Text(error)
                        .font(.cwCaption)
                        .foregroundColor(Palette.danger)
                }

                Text("The key will be shown once. Store it somewhere safe — it cannot be recovered.")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)

                Spacer()
            }
            .padding(Spacing.md)
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("New API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Palette.muted)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") { Task { await onCreate() } }
                            .foregroundColor(canCreate ? Palette.amber : Palette.muted)
                            .disabled(!canCreate)
                    }
                }
            }
        }
        .onAppear { focused = true }
    }

    private func onCreate() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isCreating = true
        error = nil
        do {
            let (key, rawKey) = try await ApiKeyService.shared.create(uid: uid, name: trimmed)
            dismiss()
            onCreated(key, rawKey)
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }
}

// MARK: - Reveal sheet (shown once after creation or refresh)

private struct RevealKeySheet: View {
    let key: ApiKey
    let rawKey: String

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Palette.amber)
                        Text("Copy this key now — it won't be shown again.")
                            .font(.cwCaption.weight(.semibold))
                            .foregroundColor(Palette.ink)
                    }
                    Text("If you lose it, delete and create a new one.")
                        .font(.cwCaption)
                        .foregroundColor(Palette.muted)
                }
                .padding(Spacing.md)
                .background(Palette.amberSoft)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Palette.amber.opacity(0.3), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("KEY NAME")
                        .font(.cwCaption).tracking(1.2).foregroundColor(Palette.muted)
                    Text(key.name)
                        .font(.cwBody.weight(.semibold))
                        .foregroundColor(Palette.ink)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("API KEY")
                        .font(.cwCaption).tracking(1.2).foregroundColor(Palette.muted)
                    HStack(spacing: Spacing.sm) {
                        Text(rawKey)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = rawKey
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copied = false }
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16))
                                .foregroundColor(copied ? Palette.amber : Palette.muted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Spacing.md)
                    .background(Palette.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Palette.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("API Key Created")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Palette.amber)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Helpers

private struct RevealedKey: Identifiable {
    let key: ApiKey
    let rawKey: String
    var id: String { key.id }
}

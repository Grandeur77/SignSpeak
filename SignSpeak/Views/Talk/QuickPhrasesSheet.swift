import SwiftUI

/// Quick Phrases shortcut sheet (`38-communicator-start`, `39c-quick-phrases`).
/// Allows users to browse, search (with voice dictation), preview signs, speak aloud, and manage quick phrases by category.
public struct QuickPhrasesSheet: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: QuickPhrasesViewModel?
    @State private var isShowingAddModal: Bool = false
    @State private var newPhraseText: String = ""
    @State private var newPhraseCategory: String = "Essentials"
    @State private var newPhraseIsEmergency: Bool = false
    @State private var newPhraseNote: String = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if let vm = viewModel {
                    VStack(spacing: 0) {
                        // Search & Dictation Bar
                        searchAndDictationBar(vm)

                        // Category Filter Pills
                        categoryPillsBar(vm)

                        // Main Scrollable Content
                        ScrollView {
                            VStack(spacing: Theme.Spacing.m) {
                                // Featured / Priority Key Card (when showing All or Essentials, or if keyCard matches filter)
                                if let keyCard = vm.keyCardPhrase, vm.searchQuery.isEmpty && (vm.selectedCategory == "All" || vm.selectedCategory == "Essentials") {
                                    keyCardView(keyCard, vm: vm)
                                }

                                // Phrases Grid / List
                                phrasesListView(vm)
                            }
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.top, Theme.Spacing.s)
                            .padding(.bottom, 100) // Padding for floating Add Phrase button
                        }
                    }

                    // Floating Toast Notification
                    if let toast = vm.toastMessage {
                        VStack {
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.brandYellow)

                                Text(toast)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(red: 11/255, green: 42/255, blue: 74/255), in: Capsule())
                            .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 8)

                            Spacer()
                        }
                        .zIndex(100)
                        .onAppear {
                            Task {
                                try? await Task.sleep(nanoseconds: 2_200_000_000)
                                withAnimation {
                                    vm.toastMessage = nil
                                }
                            }
                        }
                    }

                    // Anchored Action Bar: Add Phrase
                    VStack {
                        Spacer()
                        Button {
                            newPhraseText = ""
                            newPhraseCategory = vm.selectedCategory == "All" ? "Essentials" : vm.selectedCategory
                            newPhraseIsEmergency = vm.selectedCategory == "Emergency"
                            newPhraseNote = ""
                            isShowingAddModal = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.brandYellow)

                                Text("Add phrase")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(red: 11/255, green: 42/255, blue: 74/255), in: RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.bottom, Theme.Spacing.m)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Quick Phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
                }
            }
            .task {
                if viewModel == nil {
                    let vm = QuickPhrasesViewModel(
                        repository: dependencies.quickPhraseRepository,
                        speechSynthesisService: dependencies.speechSynthesisService,
                        speechRecognitionService: dependencies.speechRecognitionService,
                        userId: dependencies.authService.currentUserId ?? "guest"
                    )
                    viewModel = vm
                    await vm.loadPhrases()
                }
            }
            .sheet(item: Binding(
                get: { viewModel?.selectedSignPhrase },
                set: { viewModel?.selectedSignPhrase = $0 }
            )) { phrase in
                PhraseSignVideoSheet(phrase: phrase) { toSpeak in
                    viewModel?.speak(phrase: toSpeak)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isShowingAddModal) {
                addPhraseSheet
            }
        }
    }

    // MARK: - Search & Dictation Bar

    private func searchAndDictationBar(_ vm: QuickPhrasesViewModel) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)

                TextField("Search saved phrases…", text: Binding(
                    get: { vm.searchQuery },
                    set: { vm.searchQuery = $0 }
                ))
                .font(.system(size: 15))
                .foregroundStyle(Color.textPrimary)

                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Voice Dictation Mic Button
                Button {
                    vm.toggleDictationSearch()
                } label: {
                    ZStack {
                        if vm.isDictatingSearch {
                            Circle()
                                .fill(Color.danger.opacity(0.2))
                                .frame(width: 30, height: 30)
                                .scaleEffect(1.2)
                        }

                        Image(systemName: vm.isDictatingSearch ? "mic.fill" : "mic")
                            .font(.system(size: 16))
                            .foregroundStyle(vm.isDictatingSearch ? Color.danger : Color.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.xs)
    }

    // MARK: - Category Filter Pills

    private func categoryPillsBar(_ vm: QuickPhrasesViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QuickPhrasesViewModel.categories, id: \.self) { cat in
                    let isSelected = vm.selectedCategory == cat
                    let isEmergencyCat = cat == "Emergency"

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            vm.selectedCategory = cat
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if cat == "Essentials" {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? Color.brandYellow : Color.brandTurquoise)
                            } else if isEmergencyCat {
                                Image(systemName: "cross.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(isSelected ? Color.white : Color.danger)
                            }

                            Text(cat)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            isSelected
                                ? (isEmergencyCat ? Color.danger : Color(red: 11/255, green: 42/255, blue: 74/255))
                                : (isEmergencyCat ? Color.danger.opacity(0.12) : Color.cardBackground),
                            in: Capsule()
                        )
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : (isEmergencyCat ? Color.danger : Color.textPrimary)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
        }
    }

    // MARK: - Featured Key Card

    private func keyCardView(_ phrase: QuickPhrase, vm: QuickPhrasesViewModel) -> some View {
        Button {
            vm.speak(phrase: phrase)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                // Subtle cyan glow ribbon
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                    .offset(x: 30, y: 30)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 12))
                            Text("Key Card")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.brandTurquoise, in: Capsule())

                        Spacer()

                        HStack(spacing: 8) {
                            // Sign demonstration preview
                            Button {
                                vm.selectedSignPhrase = phrase
                            } label: {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.brandTurquoise)
                                    .frame(width: 34, height: 34)
                                    .background(Color.white.opacity(0.15), in: Circle())
                            }
                            .buttonStyle(.plain)

                            // Speaker
                            Image(systemName: vm.spokenPhraseId == phrase.id ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                                .frame(width: 34, height: 34)
                                .background(Color.brandTurquoise, in: Circle())
                        }
                    }

                    Text("\"\(phrase.text)\"")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)

                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 11))
                        Text("Tap card to speak aloud at full volume")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.white.opacity(0.8))
                }
                .padding(Theme.Spacing.l)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 11/255, green: 42/255, blue: 74/255), in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.12), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Phrases List

    private func phrasesListView(_ vm: QuickPhrasesViewModel) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(vm.filteredPhrases) { phrase in
                phraseRowCard(phrase, vm: vm)
            }
        }
    }

    private func phraseRowCard(_ phrase: QuickPhrase, vm: QuickPhrasesViewModel) -> some View {
        Button {
            vm.speak(phrase: phrase)
        } label: {
            HStack(spacing: 12) {
                // Emergency SOS Badge or Category Icon
                if phrase.isEmergency {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.danger)
                            .frame(width: 42, height: 42)

                        Image(systemName: "sos")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Color.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(phrase.text)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(phrase.isEmergency ? Color.danger : Color.textPrimary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(phrase.category)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(phrase.isEmergency ? Color.danger : Color.brandTurquoise)

                        if let note = phrase.note {
                            Text("• \(note)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                        }

                        if phrase.playCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("+\(phrase.playCount) plays")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(Color.brandYellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.brandYellow.opacity(0.12), in: Capsule())
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    // Sign demonstration button
                    Button {
                        vm.selectedSignPhrase = phrase
                    } label: {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.textSecondary.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)

                    // Speaker Playback Icon
                    Image(systemName: vm.spokenPhraseId == phrase.id ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.system(size: 16))
                        .foregroundStyle(phrase.isEmergency ? Color.danger : Color.brandTurquoise)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(Theme.Spacing.m)
            .background(
                phrase.isEmergency
                    ? Color.danger.opacity(0.08)
                    : Color.cardBackground,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        phrase.isEmergency ? Color.danger.opacity(0.35) : Color.textSecondary.opacity(0.15),
                        lineWidth: phrase.isEmergency ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                vm.speak(phrase: phrase)
            } label: {
                Label("Speak Aloud", systemImage: "speaker.wave.2")
            }

            Button {
                vm.selectedSignPhrase = phrase
            } label: {
                Label("Preview Sign Demo", systemImage: "hand.raised")
            }

            Button(role: .destructive) {
                Task {
                    await vm.deletePhrase(id: phrase.id)
                }
            } label: {
                Label("Delete Phrase", systemImage: "trash")
            }
        }
    }

    // MARK: - Add Phrase Modal Sheet

    private var addPhraseSheet: some View {
        NavigationStack {
            Form {
                Section("Phrase Text") {
                    TextField("e.g., Where is the exit?", text: $newPhraseText)
                        .font(.system(size: 16))
                }

                Section("Category") {
                    Picker("Category", selection: $newPhraseCategory) {
                        ForEach(QuickPhrasesViewModel.categories.filter { $0 != "All" }, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Settings") {
                    Toggle("Emergency SOS Phrase", isOn: $newPhraseIsEmergency)
                        .tint(Color.danger)

                    TextField("Short Note (e.g. Navigation, Polite)", text: $newPhraseNote)
                        .font(.system(size: 14))
                }
            }
            .navigationTitle("New Quick Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isShowingAddModal = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let text = newPhraseText
                        let category = newPhraseCategory
                        let isEmergency = newPhraseIsEmergency
                        let note = newPhraseNote.isEmpty ? nil : newPhraseNote
                        Task {
                            await viewModel?.addPhrase(
                                text: text,
                                category: category,
                                isEmergency: isEmergency,
                                signId: nil,
                                note: note
                            )
                        }
                        isShowingAddModal = false
                    }
                    .disabled(newPhraseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

import SwiftUI

struct MainView: View {
    @EnvironmentObject var vm: GameViewModel
    @EnvironmentObject var voices: VoiceStore

    // ── وضع العرض ──────────────────────────────────────────────────────────
    @State private var isSimpleMode = true
    @State private var showSettingsSheet = false

    // ── حالة الإدخال التفصيلي ──────────────────────────────────────────────
    @State private var gameType     : GameType = .hokm
    @State private var buyerIsTeam1 : Bool     = true
    @State private var buyerRawText : String   = ""
    @State private var isKaboot     : Bool     = false
    @State private var isDobble     : Bool     = false
    @State private var team1Dec     = Declarations()
    @State private var team2Dec     = Declarations()

    // ── حالة الإدخال المبسط ────────────────────────────────────────────────
    @State private var simpleGameType:     GameType = .hokm
    @State private var simpleBuyerIsTeam1: Bool     = true
    @State private var simpleT1Text:       String   = ""
    @State private var simpleT2Text:       String   = ""
    @State private var simpleIsKaboot:     Bool     = false
    @State private var simpleIsDobble:     Bool     = false

    @FocusState private var rawFocused: Bool

    // ── صوت ───────────────────────────────────────────────────────────────
    @StateObject private var speech      = SpeechManager()
    @State private var isProcessing      = false
    @State private var voiceError:         String?
    @State private var showAPIKeySheet   = false
    @State private var autoStopTask:       Task<Void, Never>?
    @State private var lastTranscript:     String = ""

    // ── تعديل الجولة ────────────────────────────────────────────────────
    @State private var editingRound:       Round?
    @State private var editT1Text:         String = ""
    @State private var editT2Text:         String = ""
    @State private var showEditSheet       = false

    // ── تتبع آخر جولة شغّلنا لها صوت ─────────────────────────────────────
    @State private var lastPlayedRoundID:  UUID?

    // ── تأكيد لعبة جديدة ────────────────────────────────────────────────
    @State private var showNewGameConfirm = false

    // ── مساعدات ──────────────────────────────────────────────────────────
    private var buyerRaw: Int { Int(buyerRawText) ?? 0 }
    private var team1RawDisplay: Int { buyerIsTeam1 ? buyerRaw : max(0, gameType.rawTotal - buyerRaw) }
    private var team2RawDisplay: Int { buyerIsTeam1 ? max(0, gameType.rawTotal - buyerRaw) : buyerRaw }

    private var buyerRawValid: Bool {
        guard let r = Int(buyerRawText) else { return false }
        return r >= 0 && r <= gameType.rawTotal
    }
    private var canSave: Bool { isKaboot || buyerRawValid }

    private var simpleCanSave: Bool {
        Int(simpleT1Text) != nil && Int(simpleT2Text) != nil
    }

    private var liveResult: RoundResult? {
        guard canSave else { return nil }
        let bDec = buyerIsTeam1 ? team1Dec : team2Dec
        let oDec = buyerIsTeam1 ? team2Dec : team1Dec
        return vm.calculateRound(gameType: gameType, buyerRaw: buyerRaw,
                                 isKaboot: isKaboot, isDobble: isDobble,
                                 buyerDec: bDec, otherDec: oDec)
    }

    // ──────────────────────────────────────────────────────────────────────
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    // ── بطاقات النقاط — نحن يمين، هم يسار ──────────
                    HStack(spacing: Theme.Space.md) {
                        ScoreCard(name: $vm.team1Name, score: vm.team1Total, color: Theme.Color.team1)
                        ScoreCard(name: $vm.team2Name, score: vm.team2Total, color: Theme.Color.team2)
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.lg)

                    ProgressBar(t1: vm.team1Total, t2: vm.team2Total, goal: vm.winningScore)
                        .padding(.horizontal, Theme.Space.lg)
                        .padding(.top, Theme.Space.md)

                    // ── إدخال الجولة ──────────────────────────────────
                    if isSimpleMode {
                        simpleEntrySection
                            .padding(.horizontal, Theme.Space.lg)
                            .padding(.top, Theme.Space.md)
                    } else {
                        roundEntrySection
                            .padding(.horizontal, Theme.Space.lg)
                            .padding(.top, Theme.Space.md)
                    }

                    // ── سجل الجولات ───────────────────────────────────
                    if !vm.rounds.isEmpty {
                        RoundHistory(onEdit: { round in startEditRound(round) })
                            .padding(.horizontal, Theme.Space.lg)
                            .padding(.top, Theme.Space.xl)
                    }

                    // ── زر لعبة جديدة (يظهر فقط إذا فيه جولات مسجّلة) ──
                    if !vm.rounds.isEmpty {
                        Button {
                            Theme.Haptic.warning()
                            showNewGameConfirm = true
                        } label: {
                            HStack(spacing: Theme.Space.sm) {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                Text("لعبة جديدة — تصفير العدّاد")
                            }
                            .font(Theme.Font.title)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Space.md + 2)
                            .foregroundColor(Theme.Color.warning)
                            .background(Theme.Color.surface)
                            .cornerRadius(Theme.Radius.md)
                            .themeHairline(Theme.Color.warning.opacity(0.4), cornerRadius: Theme.Radius.md)
                        }
                        .padding(.horizontal, Theme.Space.lg)
                        .padding(.top, Theme.Space.lg)
                    }

                    Spacer(minLength: Theme.Space.xxl + Theme.Space.sm)
                }
            }
            .background(Theme.Color.canvas.ignoresSafeArea())
            .navigationTitle("البلوت")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: Theme.Space.sm) {
                        Button {
                            Theme.Haptic.light()
                            vm.undoLastRound()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(Theme.Color.ink)
                        }
                        .disabled(vm.rounds.isEmpty)

                        Button {
                            Theme.Haptic.medium()
                            vm.fullReset(); resetEntry(); resetSimple()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(Theme.Color.ink)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    modeSwitcher
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showSettingsSheet = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Theme.Color.ink)
                    }
                    if !isSimpleMode {
                        Button { showAPIKeySheet = true } label: {
                            Image(systemName: "brain")
                                .foregroundColor(Theme.Color.ink)
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onChange(of: speech.autoStoppedText) { text in
            guard let text = text, !text.isEmpty, isSimpleMode else { return }
            speech.autoStoppedText = nil
            processSimpleVoice(text)
        }
        .sheet(isPresented: $showAPIKeySheet) { APIKeyView() }
        .sheet(isPresented: $showEditSheet) { editRoundSheet }
        .sheet(isPresented: $showSettingsSheet) { AdminSettingsView() }
        .onChange(of: vm.rounds.count) { _ in playVoiceForLastRound() }
        .confirmationDialog("لعبة جديدة",
                            isPresented: $showNewGameConfirm,
                            titleVisibility: .visible) {
            Button("نفس الفرق — تصفير النقاط", role: .destructive) {
                vm.restartSameTeams()
                resetEntry(); resetSimple()
                lastPlayedRoundID = nil
                voices.play(.gameStart)
            }
            Button("تغيير الفرق", role: .destructive) {
                vm.fullReset()
                resetEntry(); resetSimple()
                lastPlayedRoundID = nil
                voices.play(.gameStart)
            }
            Button("إلغاء", role: .cancel) { }
        } message: {
            Text("هل تبي تصفّر العدّاد وتبدأ لعبة جديدة؟")
        }
    }

    // MARK: ── تشغيل صوت حسب نتيجة الجولة ───────────────────────────────
    private func playVoiceForLastRound() {
        guard let last = vm.rounds.last else {
            lastPlayedRoundID = nil
            return
        }
        // لا نعيد تشغيل نفس الجولة (حماية من onChange في الحذف/التعديل)
        guard last.id != lastPlayedRoundID else { return }
        lastPlayedRoundID = last.id
        if let state = VoiceStore.detect(
            round: last,
            team1Total: vm.team1Total,
            team2Total: vm.team2Total,
            winningScore: vm.winningScore
        ) {
            voices.play(state)
        }
    }

    // MARK: ── تبديل الوضع ───────────────────────────────────────────────
    @ViewBuilder
    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            smallModeBtn(label: "مبسط",   active: isSimpleMode)  {
                Theme.Haptic.light()
                isSimpleMode = true
            }
            smallModeBtn(label: "تفصيلي", active: !isSimpleMode) {
                Theme.Haptic.light()
                isSimpleMode = false
            }
        }
        .padding(2)
        .background(Theme.Color.canvas)
        .cornerRadius(Theme.Radius.sm)
        .themeHairline(cornerRadius: Theme.Radius.sm)
    }

    @ViewBuilder
    private func smallModeBtn(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Font.label)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.xs + 2)
                .background(active ? Theme.Color.ink : Color.clear)
                .foregroundColor(active ? Theme.Color.surface : Theme.Color.muted)
                .cornerRadius(Theme.Radius.xs + 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: ══════════════════════════════════════════════════════════════════
    // MARK: ── الوضع المبسط ─────────────────────────────────────────────────
    // MARK: ══════════════════════════════════════════════════════════════════
    @ViewBuilder
    private var simpleEntrySection: some View {
        VStack(spacing: Theme.Space.lg) {

            // حقول النقاط — نحن يمين، هم يسار
            HStack(spacing: Theme.Space.md) {
                simpleScoreField(label: vm.team1Name, text: $simpleT1Text, color: Theme.Color.team1)
                simpleScoreField(label: vm.team2Name, text: $simpleT2Text, color: Theme.Color.team2)
            }

            // زر الميكروفون — كبير، دائري. عَنبَر للإدلة، أحمر للتسجيل.
            Button { handleSimpleMic() } label: {
                ZStack {
                    Circle()
                        .fill(micFillColor)
                        .frame(width: 84, height: 84)
                        .shadow(color: micFillColor.opacity(0.35), radius: 12, y: 4)

                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.Color.onAccent))
                            .scaleEffect(1.5)
                    } else if speech.isListening {
                        RoundedRectangle(cornerRadius: Theme.Radius.xs)
                            .fill(Theme.Color.onAccent)
                            .frame(width: 26, height: 26)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Color.onAccent)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            // نص التسجيل الصوتي المباشر أو آخر نص مسموع
            if speech.isListening && !speech.transcript.isEmpty {
                transcriptBubble(speech.transcript, icon: nil)
            } else if !lastTranscript.isEmpty && simpleCanSave {
                transcriptBubble("سمعت: \(lastTranscript)", icon: "ear.fill")
            }

            // خطأ الصوت
            if let err = voiceError {
                HStack(spacing: Theme.Space.xs + 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.Color.warning)
                    Text(err)
                        .font(Theme.Font.caption)
                        .foregroundColor(Theme.Color.warning)
                }
                .frame(maxWidth: .infinity)
            }

            // زر التسجيل اليدوي
            primarySaveButton(enabled: simpleCanSave) {
                Theme.Haptic.success()
                saveSimpleRound()
            }
        }
    }

    private var micFillColor: Color {
        if isProcessing      { return Theme.Color.warning    }
        if speech.isListening { return Theme.Color.micActive }
        return Theme.Color.accent
    }

    @ViewBuilder
    private func transcriptBubble(_ text: String, icon: String?) -> some View {
        HStack(spacing: Theme.Space.xs + 2) {
            if let icon {
                Image(systemName: icon)
                    .font(Theme.Font.micro)
                    .foregroundColor(Theme.Color.muted)
            }
            Text(text)
                .font(Theme.Font.caption)
                .foregroundColor(Theme.Color.muted)
        }
        .padding(Theme.Space.sm)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(Theme.Color.canvas)
        .cornerRadius(Theme.Radius.sm)
        .themeHairline(cornerRadius: Theme.Radius.sm)
    }

    @ViewBuilder
    private func primarySaveButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("تسجيل")
                .font(Theme.Font.title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.md + 2)
                .background(enabled ? Theme.Color.accent : Theme.Color.canvas)
                .foregroundColor(enabled ? Theme.Color.onAccent : Theme.Color.muted)
                .cornerRadius(Theme.Radius.md)
                .themeHairline(enabled ? Color.clear : Theme.Color.border,
                               cornerRadius: Theme.Radius.md)
        }
        .disabled(!enabled)
    }

    @ViewBuilder
    private func simpleScoreField(label: String, text: Binding<String>, color: Color) -> some View {
        VStack(spacing: Theme.Space.xs) {
            Text(label)
                .font(Theme.Font.caption)
                .foregroundColor(color)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .font(Theme.Font.displayLG)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .frame(height: 52)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.sm)
        .background(Theme.Color.surface)
        .cornerRadius(Theme.Radius.md)
        .themeHairline(cornerRadius: Theme.Radius.md)
    }

    // MARK: ── حفظ الوضع المبسط ──────────────────────────────────────────
    private func saveSimpleRound() {
        guard let t1 = Int(simpleT1Text), let t2 = Int(simpleT2Text) else { return }
        vm.addRoundDirect(t1: t1, t2: t2, gameType: simpleGameType, buyerIsTeam1: simpleBuyerIsTeam1)
        resetSimple()
    }

    private func resetSimple() {
        simpleT1Text   = ""
        simpleT2Text   = ""
        lastTranscript = ""
    }

    // MARK: ── المفتاح ──────────────────────────────────────────────────────
    private var activeAPIKey: String {
        let stored = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
        return stored.isEmpty ? kBuiltInAPIKey : stored
    }

    // MARK: ── ميكروفون الوضع المبسط ──────────────────────────────────────
    private func handleSimpleMic() {
        voiceError = nil
        Theme.Haptic.light()

        if speech.isListening {
            let text = speech.stop()
            processSimpleVoice(text)
        } else {
            lastTranscript = ""
            simpleT1Text = ""
            simpleT2Text = ""
            speech.start()
        }
    }

    /// يعالج النص الصوتي — يُستدعى من التوقف اليدوي أو التلقائي
    private func processSimpleVoice(_ text: String) {
        lastTranscript = text
        guard !text.isEmpty else { return }

        isProcessing = true
        Task {
            do {
                let result = try await GameParser.parseSimple(text: text, apiKey: activeAPIKey)
                await MainActor.run {
                    simpleT1Text = String(format: "%d", result.t1)
                    simpleT2Text = String(format: "%d", result.t2)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    voiceError = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func fillSimpleFromParsed(_ p: SimpleRoundResult) {
        if let gt = p.gameType      { simpleGameType = gt }
        if let b  = p.buyerIsTeam1  { simpleBuyerIsTeam1 = b }
        if let s1 = p.t1Score       { simpleT1Text = String(format: "%d", s1) }
        if let s2 = p.t2Score       { simpleT2Text = String(format: "%d", s2) }
        simpleIsKaboot = p.isKaboot
        simpleIsDobble = p.isDobble
        voiceError = nil
    }

    // MARK: ══════════════════════════════════════════════════════════════════
    // MARK: ── الوضع التفصيلي ───────────────────────────────────────────────
    // MARK: ══════════════════════════════════════════════════════════════════
    @ViewBuilder
    private var roundEntrySection: some View {
        VStack(spacing: Theme.Space.md) {

            // نوع اللعبة + الفريق المشتري
            HStack(spacing: Theme.Space.md) {
                toggleCard(title: "نوع اللعبة") {
                    HStack(spacing: Theme.Space.xs + 2) {
                        ForEach(GameType.allCases, id: \.self) { gt in
                            toggleBtn(label: gt.rawValue, active: gameType == gt) {
                                Theme.Haptic.light()
                                gameType = gt
                                team1Dec.reset(); team2Dec.reset()
                            }
                        }
                    }
                }
                toggleCard(title: "المشتري") {
                    HStack(spacing: Theme.Space.xs + 2) {
                        toggleBtn(label: vm.team1Name, active: buyerIsTeam1,  activeColor: Theme.Color.team1)  {
                            Theme.Haptic.light()
                            buyerIsTeam1 = true
                        }
                        toggleBtn(label: vm.team2Name, active: !buyerIsTeam1, activeColor: Theme.Color.team2) {
                            Theme.Haptic.light()
                            buyerIsTeam1 = false
                        }
                    }
                }
            }

            // كبوت / دبل + حقل الأوراق
            VStack(spacing: Theme.Space.md) {
                HStack(spacing: Theme.Space.sm) {
                    toggleBtn(label: "كبوت", active: isKaboot, activeColor: Theme.Color.warning) {
                        Theme.Haptic.light()
                        isKaboot.toggle()
                        if isKaboot { isDobble = false; buyerRawText = "" }
                    }
                    toggleBtn(label: "دبل x2", active: isDobble, activeColor: Theme.Color.dobble) {
                        Theme.Haptic.light()
                        isDobble.toggle()
                        if isDobble { isKaboot = false }
                    }
                }
                .padding(.horizontal, Theme.Space.md)

                if !isKaboot {
                    // نحن دائما يمين، هم دائما يسار
                    HStack(spacing: Theme.Space.md) {
                        rawInputCard(
                            label: "\(vm.team1Name) — أوراق",
                            text: buyerIsTeam1 ? $buyerRawText
                                              : .constant(buyerRawValid ? String(format: "%d", team1RawDisplay) : "—"),
                            color: buyerIsTeam1 ? Theme.Color.team1 : Theme.Color.team1.opacity(0.5),
                            isEditable: buyerIsTeam1
                        )
                        rawInputCard(
                            label: "\(vm.team2Name) — أوراق",
                            text: buyerIsTeam1 ? .constant(buyerRawValid ? String(format: "%d", team2RawDisplay) : "—")
                                              : $buyerRawText,
                            color: buyerIsTeam1 ? Theme.Color.team2.opacity(0.5) : Theme.Color.team2,
                            isEditable: !buyerIsTeam1
                        )
                    }
                    .padding(.horizontal, Theme.Space.md)

                    if let raw = Int(buyerRawText), raw > gameType.rawTotal {
                        Text("الحد الاقصى في \(gameType.rawValue): \(String(format: "%d", gameType.rawTotal))")
                            .font(Theme.Font.caption)
                            .foregroundColor(Theme.Color.warning)
                            .padding(.horizontal, Theme.Space.md)
                    }
                }
            }
            .padding(.vertical, Theme.Space.md)
            .background(Theme.Color.surface)
            .cornerRadius(Theme.Radius.md)
            .themeHairline(cornerRadius: Theme.Radius.md)

            // مشاريع
            declarationsCard(title: "مشاريع \(vm.team1Name)", dec: $team1Dec, color: Theme.Color.team1)
            declarationsCard(title: "مشاريع \(vm.team2Name)", dec: $team2Dec, color: Theme.Color.team2)

            // نتيجة الجولة (live)
            if let r = liveResult {
                resultPreview(r)
            }

            // خطأ الصوت
            if let err = voiceError {
                HStack(spacing: Theme.Space.xs + 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.Color.warning)
                    Text(err)
                        .font(Theme.Font.caption)
                        .foregroundColor(Theme.Color.warning)
                }
                .frame(maxWidth: .infinity)
            }

            // أزرار التسجيل + الميكروفون
            HStack(spacing: Theme.Space.md) {
                Button { handleMicButton() } label: {
                    ZStack {
                        Circle()
                            .fill(speech.isListening ? Theme.Color.micActive : Theme.Color.canvas)
                            .frame(width: 52, height: 52)
                            .themeHairline(speech.isListening ? Color.clear : Theme.Color.border,
                                           cornerRadius: Theme.Radius.pill)
                        if isProcessing {
                            ProgressView().tint(Theme.Color.onAccent)
                        } else {
                            Image(systemName: speech.isListening ? "stop.fill" : "mic.fill")
                                .font(.title3)
                                .foregroundColor(speech.isListening ? Theme.Color.onAccent : Theme.Color.muted)
                        }
                    }
                }
                .disabled(isProcessing)

                primarySaveButton(enabled: canSave) {
                    Theme.Haptic.success()
                    saveRound()
                }
            }

            // نص التسجيل الصوتي المباشر
            if speech.isListening && !speech.transcript.isEmpty {
                transcriptBubble(speech.transcript, icon: nil)
            }
        }
    }

    // MARK: ── أزرار التبديل ─────────────────────────────────────────────
    @ViewBuilder
    private func toggleCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Theme.Space.xs + 2) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundColor(Theme.Color.muted)
                .frame(maxWidth: .infinity, alignment: .center)
            content()
        }
        .padding(Theme.Space.md)
        .background(Theme.Color.surface)
        .cornerRadius(Theme.Radius.md)
        .themeHairline(cornerRadius: Theme.Radius.md)
    }

    @ViewBuilder
    private func toggleBtn(label: String, active: Bool,
                           activeColor: Color = Theme.Color.ink,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Font.label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.sm)
                .background(active ? activeColor : Theme.Color.canvas)
                .foregroundColor(active ? Theme.Color.onAccent : Theme.Color.muted)
                .cornerRadius(Theme.Radius.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: ── حقل الإدخال الخام ─────────────────────────────────────────
    @ViewBuilder
    private func rawInputCard(label: String, text: Binding<String>, color: Color, isEditable: Bool) -> some View {
        VStack(spacing: Theme.Space.xs) {
            Text(label)
                .font(Theme.Font.caption)
                .foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            if isEditable {
                TextField("0", text: text)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(Theme.Font.displayLG)
                    .foregroundColor(color)
                    .multilineTextAlignment(.center)
                    .frame(height: 52)
                    .focused($rawFocused)
            } else {
                Text(text.wrappedValue)
                    .font(Theme.Font.displayLG)
                    .foregroundColor(color)
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.sm)
        .background(Theme.Color.canvas)
        .cornerRadius(Theme.Radius.sm)
    }

    // MARK: ── بطاقة المشاريع ────────────────────────────────────────────
    @ViewBuilder
    private func declarationsCard(title: String, dec: Binding<Declarations>, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: Theme.Space.sm) {
            Text(title)
                .font(Theme.Font.label)
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .trailing)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Space.sm) {
                DecStepper(label: "سرا",    value: dec.sara,    color: color)
                DecStepper(label: "خمسين",  value: dec.fifty,   color: color)
                DecStepper(label: "مية",    value: dec.hundred, color: color)
                if gameType == .sun {
                    DecStepper(label: "أربع مية", value: dec.fourHundred, color: color)
                } else {
                    DecStepper(label: "بلوت",    value: dec.bloot,       color: color)
                }
            }
        }
        .padding(Theme.Space.md)
        .background(Theme.Color.surface)
        .cornerRadius(Theme.Radius.md)
        .themeHairline(cornerRadius: Theme.Radius.md)
    }

    // MARK: ── معاينة النتيجة ────────────────────────────────────────────
    @ViewBuilder
    private func resultPreview(_ r: RoundResult) -> some View {
        let t1 = buyerIsTeam1 ? r.buyerFinal : r.otherFinal
        let t2 = buyerIsTeam1 ? r.otherFinal : r.buyerFinal
        let accentColor: Color = r.buyerWon ? Theme.Color.success : Theme.Color.team2

        VStack(spacing: Theme.Space.md) {
            HStack(spacing: Theme.Space.xs + 2) {
                Image(systemName: r.buyerWon ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(accentColor)
                let bName = buyerIsTeam1 ? vm.team1Name : vm.team2Name
                let oName = buyerIsTeam1 ? vm.team2Name : vm.team1Name
                if r.isKaboot {
                    Text("كبوت — \(bName) يأخذ كل النقاط")
                } else if r.buyerWon {
                    Text("المشتري نجح")
                } else {
                    Text("المشتري خسر — كل النقاط لـ \(oName)")
                }
                if r.isDobble {
                    Text("x2")
                        .font(Theme.Font.micro)
                        .padding(.horizontal, Theme.Space.xs + 2)
                        .padding(.vertical, Theme.Space.xxs)
                        .background(Theme.Color.dobble.opacity(0.12))
                        .foregroundColor(Theme.Color.dobble)
                        .cornerRadius(Theme.Radius.xs)
                }
            }
            .font(Theme.Font.label)
            .foregroundColor(accentColor)
            .frame(maxWidth: .infinity)

            if !r.isKaboot && r.buyerWon {
                HStack(spacing: Theme.Space.xs) {
                    Text("أوراق: \(String(format: "%d", r.buyerCardPts))")
                    if r.buyerDecPts > 0 { Text("+ مشاريع: \(String(format: "%d", r.buyerDecPts))") }
                }
                .font(Theme.Font.caption)
                .foregroundColor(Theme.Color.muted)
            }

            Rectangle()
                .fill(Theme.Color.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                VStack(spacing: Theme.Space.xxs) {
                    Text(vm.team1Name).font(Theme.Font.caption).foregroundColor(Theme.Color.muted)
                    Text(String(format: "%d", t1)).font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Color.team1)
                    Text("بنط").font(Theme.Font.micro).foregroundColor(Theme.Color.team1.opacity(0.5))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Theme.Color.border)
                    .frame(width: 1, height: 44)

                VStack(spacing: Theme.Space.xxs) {
                    Text(vm.team2Name).font(Theme.Font.caption).foregroundColor(Theme.Color.muted)
                    Text(String(format: "%d", t2)).font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Color.team2)
                    Text("بنط").font(Theme.Font.micro).foregroundColor(Theme.Color.team2.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: Theme.Space.xs) {
                Text("المجموع:")
                    .font(Theme.Font.caption).foregroundColor(Theme.Color.muted)
                Text(String(format: "%d", vm.team1Total + t1))
                    .font(Theme.Font.label).foregroundColor(Theme.Color.team1)
                Text("—")
                    .font(Theme.Font.caption).foregroundColor(Theme.Color.muted)
                Text(String(format: "%d", vm.team2Total + t2))
                    .font(Theme.Font.label).foregroundColor(Theme.Color.team2)
            }
        }
        .padding(Theme.Space.md + 2)
        .background(Theme.Color.surface)
        .cornerRadius(Theme.Radius.md)
        .themeHairline(accentColor.opacity(0.3), cornerRadius: Theme.Radius.md)
    }

    // MARK: ── الحفظ التفصيلي ────────────────────────────────────────────
    private func saveRound() {
        let raw: Int
        if isKaboot { raw = 0 }
        else {
            guard buyerRawValid, let r = Int(buyerRawText) else { return }
            raw = r
        }
        let bDec = buyerIsTeam1 ? team1Dec : team2Dec
        let oDec = buyerIsTeam1 ? team2Dec : team1Dec
        vm.addRound(gameType: gameType, buyerIsTeam1: buyerIsTeam1,
                    buyerRaw: raw, isKaboot: isKaboot, isDobble: isDobble,
                    buyerDec: bDec, otherDec: oDec)
        resetEntry()
    }

    private func resetEntry() {
        buyerRawText = ""
        isKaboot     = false
        isDobble     = false
        team1Dec.reset()
        team2Dec.reset()
        rawFocused   = false
    }

    // MARK: ── ميكروفون التفصيلي (API) ──────────────────────────────────
    private func handleMicButton() {
        voiceError = nil
        Theme.Haptic.light()

        if speech.isListening {
            let text = speech.stop()
            guard !text.isEmpty else { return }
            processVoice(text: text)
        } else {
            speech.start()
        }
    }

    private func processVoice(text: String) {
        isProcessing = true

        Task {
            do {
                let parsed = try await GameParser.parse(
                    text:      text,
                    team1Name: vm.team1Name,
                    team2Name: vm.team2Name,
                    apiKey:    activeAPIKey
                )
                await MainActor.run { fillFromParsed(parsed) }
            } catch {
                await MainActor.run {
                    voiceError = error.localizedDescription
                }
            }
            await MainActor.run { isProcessing = false }
        }
    }

    private func fillFromParsed(_ p: ParsedRound) {
        if let gt = p.gameType     { gameType = gt }
        if let b  = p.buyerIsTeam1 { buyerIsTeam1 = b }
        if let r  = p.buyerRaw     { buyerRawText = String(format: "%d", r) }
        isKaboot = p.isKaboot
        isDobble = p.isDobble
        team1Dec = p.team1Dec
        team2Dec = p.team2Dec
        voiceError = nil
    }

    // MARK: ── تعديل الجولة ──────────────────────────────────────────────
    @ViewBuilder
    private var editRoundSheet: some View {
        NavigationView {
            VStack(spacing: Theme.Space.xl) {
                if let round = editingRound {
                    Text("تعديل الجولة \(String(format: "%d", round.number))")
                        .font(Theme.Font.title)
                        .foregroundColor(Theme.Color.ink)
                        .padding(.top, Theme.Space.xl)

                    HStack(spacing: Theme.Space.md) {
                        editRoundField(label: vm.team1Name, text: $editT1Text, color: Theme.Color.team1)
                        editRoundField(label: vm.team2Name, text: $editT2Text, color: Theme.Color.team2)
                    }
                    .padding(.horizontal, Theme.Space.lg)

                    Button {
                        if let t1 = Int(editT1Text), let t2 = Int(editT2Text) {
                            Theme.Haptic.success()
                            vm.updateRound(id: round.id, t1: t1, t2: t2)
                            showEditSheet = false
                        }
                    } label: {
                        Text("حفظ التعديل")
                            .font(Theme.Font.title)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Space.md + 2)
                            .background(Theme.Color.accent)
                            .foregroundColor(Theme.Color.onAccent)
                            .cornerRadius(Theme.Radius.md)
                    }
                    .padding(.horizontal, Theme.Space.lg)

                    Button(role: .destructive) {
                        Theme.Haptic.warning()
                        vm.deleteRound(id: round.id)
                        showEditSheet = false
                    } label: {
                        Text("حذف الجولة")
                            .font(Theme.Font.body)
                            .foregroundColor(Theme.Color.team2)
                    }

                    Spacer()
                }
            }
            .background(Theme.Color.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { showEditSheet = false }
                        .foregroundColor(Theme.Color.ink)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private func editRoundField(label: String, text: Binding<String>, color: Color) -> some View {
        VStack(spacing: Theme.Space.xs) {
            Text(label).font(Theme.Font.caption).foregroundColor(color)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .font(Theme.Font.displayLG)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .frame(height: 52)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.sm)
        .background(Theme.Color.surface)
        .cornerRadius(Theme.Radius.md)
        .themeHairline(cornerRadius: Theme.Radius.md)
    }

    private func startEditRound(_ round: Round) {
        editingRound = round
        editT1Text = String(format: "%d", round.team1Score)
        editT2Text = String(format: "%d", round.team2Score)
        showEditSheet = true
    }
}

// MARK: ── DecStepper ──────────────────────────────────────────────────────
struct DecStepper: View {
    let label: String
    @Binding var value: Int
    var color: Color = Theme.Color.ink

    var body: some View {
        Group {
            if value == 0 {
                Button {
                    Theme.Haptic.light()
                    value = 1
                } label: {
                    Text(label)
                        .font(Theme.Font.label)
                        .foregroundColor(Theme.Color.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.sm + 1)
                        .background(Theme.Color.canvas)
                        .cornerRadius(Theme.Radius.sm)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 5) {
                    Text(label)
                        .font(Theme.Font.label)
                        .foregroundColor(color)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(1).minimumScaleFactor(0.7)

                    Button {
                        Theme.Haptic.light()
                        value = max(0, value - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                    .buttonStyle(.plain)

                    Text(String(format: "%d", value))
                        .font(Theme.Font.label)
                        .frame(width: 22)

                    Button {
                        Theme.Haptic.light()
                        value += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(color)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, Theme.Space.sm - 2)
                .background(color.opacity(0.08))
                .cornerRadius(Theme.Radius.sm)
            }
        }
    }
}

// MARK: ── ScoreCard ──────────────────────────────────────────────────────
struct ScoreCard: View {
    @Binding var name: String
    let score: Int
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Space.xxs) {
            TextField("الاسم", text: $name)
                .font(Theme.Font.label)
                .foregroundColor(Theme.Color.muted)
                .multilineTextAlignment(.center)

            Text(String(format: "%d", score))
                .font(Theme.Font.displayXL)
                .foregroundColor(color)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Text("بنط")
                .font(Theme.Font.micro)
                .foregroundColor(color.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg + 2)
        .padding(.horizontal, Theme.Space.sm)
        .background(Theme.Color.surface)
        .cornerRadius(Theme.Radius.lg)
        .themeCardShadow()
    }
}

// MARK: ── ProgressBar ────────────────────────────────────────────────────
struct ProgressBar: View {
    let t1: Int, t2: Int, goal: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Color.border)
                HStack(spacing: 0) {
                    Spacer()
                    Capsule().fill(Theme.Color.team2)
                        .frame(width: bw(geo.size.width, score: t2))
                }
                Capsule().fill(Theme.Color.team1)
                    .frame(width: bw(geo.size.width, score: t1))
            }
        }
        .frame(height: 6)
        .padding(.vertical, Theme.Space.xs)
    }

    private func bw(_ total: CGFloat, score: Int) -> CGFloat {
        min(total, total * CGFloat(score) / CGFloat(goal))
    }
}

// MARK: ── RoundHistory ────────────────────────────────────────────────────
struct RoundHistory: View {
    @EnvironmentObject var vm: GameViewModel
    var onEdit: ((Round) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vm.team1Name).frame(maxWidth: .infinity, alignment: .trailing)
                Text("ج").frame(width: 54, alignment: .center)
                Text(vm.team2Name).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(Theme.Font.label)
            .foregroundColor(Theme.Color.muted)
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, Theme.Space.md)

            Rectangle().fill(Theme.Color.border).frame(height: 1)

            ForEach(Array(vm.rounds.reversed().enumerated()), id: \.element.id) { idx, round in
                VStack(spacing: 0) {
                    HStack {
                        Text(String(format: "%d", round.team1Score))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Color.team1)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        VStack(spacing: 1) {
                            Text(String(format: "%d", round.number))
                                .font(Theme.Font.caption).foregroundColor(Theme.Color.muted)
                            HStack(spacing: 3) {
                                if round.isDobble {
                                    Text("x2").font(Theme.Font.micro).foregroundColor(Theme.Color.dobble)
                                }
                                Image(systemName: round.buyerWon ? "checkmark" : "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(round.buyerWon ? Theme.Color.success : Theme.Color.team2)
                            }
                        }
                        .frame(width: 54)

                        Text(String(format: "%d", round.team2Score))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Color.team2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.md)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Theme.Haptic.light()
                        onEdit?(round)
                    }

                    if idx < vm.rounds.count - 1 {
                        Rectangle().fill(Theme.Color.border).frame(height: 1)
                    }
                }
            }
        }
        .background(Theme.Color.surface)
        .cornerRadius(Theme.Radius.md)
        .themeHairline(cornerRadius: Theme.Radius.md)
    }
}

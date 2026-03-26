import SwiftUI

struct MainView: View {
    @EnvironmentObject var vm: GameViewModel

    // ── وضع العرض ──────────────────────────────────────────────────────────
    @State private var isSimpleMode = true

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

    private let c1 = Color.blue
    private let c2 = Color.red

    // ──────────────────────────────────────────────────────────────────────
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    // ── بطاقات النقاط — نحن يمين، هم يسار ──────────
                    HStack(spacing: 12) {
                        ScoreCard(name: $vm.team1Name, score: vm.team1Total, color: c1)
                        ScoreCard(name: $vm.team2Name, score: vm.team2Total, color: c2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    ProgressBar(t1: vm.team1Total, t2: vm.team2Total, goal: vm.winningScore)
                        .padding(.horizontal)
                        .padding(.top, 10)

                    // ── إدخال الجولة ──────────────────────────────────
                    if isSimpleMode {
                        simpleEntrySection
                            .padding(.horizontal)
                            .padding(.top, 12)
                    } else {
                        roundEntrySection
                            .padding(.horizontal)
                            .padding(.top, 12)
                    }

                    // ── سجل الجولات ───────────────────────────────────
                    if !vm.rounds.isEmpty {
                        RoundHistory()
                            .padding(.horizontal)
                            .padding(.top, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("البلوت")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        Button { vm.undoLastRound() } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(vm.rounds.isEmpty)

                        Button { vm.fullReset(); resetEntry(); resetSimple() } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    modeSwitcher
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !isSimpleMode {
                        Button { showAPIKeySheet = true } label: {
                            Image(systemName: "brain")
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onTapGesture { rawFocused = false }
        .onChange(of: speech.autoStoppedText) { text in
            guard let text = text, !text.isEmpty, isSimpleMode else { return }
            speech.autoStoppedText = nil
            processSimpleVoice(text)
        }
        .sheet(isPresented: $showAPIKeySheet) { APIKeyView() }
    }

    // MARK: ── تبديل الوضع ───────────────────────────────────────────────
    @ViewBuilder
    private var modeSwitcher: some View {
        HStack(spacing: 4) {
            smallModeBtn(label: "مبسط", active: isSimpleMode) { isSimpleMode = true }
            smallModeBtn(label: "تفصيلي", active: !isSimpleMode) { isSimpleMode = false }
        }
    }

    @ViewBuilder
    private func smallModeBtn(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(active ? Color.blue : Color(.systemGray5))
                .foregroundColor(active ? .white : .secondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: ══════════════════════════════════════════════════════════════════
    // MARK: ── الوضع المبسط ─────────────────────────────────────────────────
    // MARK: ══════════════════════════════════════════════════════════════════
    @ViewBuilder
    private var simpleEntrySection: some View {
        VStack(spacing: 14) {

            // حقول النقاط — نحن يمين، هم يسار
            HStack(spacing: 10) {
                simpleScoreField(label: vm.team1Name, text: $simpleT1Text, color: c1)
                simpleScoreField(label: vm.team2Name, text: $simpleT2Text, color: c2)
            }

            // زر الميكروفون — كبير ودائري وأحمر
            Button { handleSimpleMic() } label: {
                ZStack {
                    Circle()
                        .fill(isProcessing ? Color.orange : (speech.isListening ? Color.red.opacity(0.2) : Color.red))
                        .frame(width: 80, height: 80)
                        .shadow(color: speech.isListening ? .red.opacity(0.4) : .red.opacity(0.25), radius: 10, y: 4)
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    } else if speech.isListening {
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 80, height: 80)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red)
                            .frame(width: 26, height: 26)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            // نص التسجيل الصوتي المباشر أو آخر نص مسموع
            if speech.isListening && !speech.transcript.isEmpty {
                Text(speech.transcript)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else if !lastTranscript.isEmpty && simpleCanSave {
                HStack(spacing: 4) {
                    Image(systemName: "ear.fill").font(.caption2).foregroundColor(.secondary)
                    Text("سمعت: \(lastTranscript)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // خطأ الصوت
            if let err = voiceError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(err).font(.caption).foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
            }

            // زر التسجيل اليدوي
            Button { saveSimpleRound() } label: {
                Text("تسجيل")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(simpleCanSave ? Color.blue : Color(.systemGray5))
                    .foregroundColor(simpleCanSave ? .white : Color(.systemGray))
                    .cornerRadius(12)
            }
            .disabled(!simpleCanSave)
        }
    }

    @ViewBuilder
    private func simpleScoreField(label: String, text: Binding<String>, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption).foregroundColor(color)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .frame(height: 52)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .cornerRadius(10)
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

    // MARK: ── ميكروفون الوضع المبسط ──────────────────────────────────────
    private func handleSimpleMic() {
        voiceError = nil

        if speech.isListening {
            // وقف يدوي
            let text = speech.stop()
            processSimpleVoice(text)
        } else {
            let key = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
            if key.isEmpty {
                showAPIKeySheet = true
                return
            }
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

        let key = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
        if key.isEmpty {
            showAPIKeySheet = true
            return
        }
        isProcessing = true
        Task {
            do {
                let result = try await GameParser.parseSimple(text: text, apiKey: key)
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
        VStack(spacing: 10) {

            // نوع اللعبة + الفريق المشتري
            HStack(spacing: 10) {
                toggleCard(title: "نوع اللعبة") {
                    HStack(spacing: 6) {
                        ForEach(GameType.allCases, id: \.self) { gt in
                            toggleBtn(label: gt.rawValue, active: gameType == gt) {
                                gameType = gt
                                team1Dec.reset(); team2Dec.reset()
                            }
                        }
                    }
                }
                toggleCard(title: "المشتري") {
                    HStack(spacing: 6) {
                        toggleBtn(label: vm.team1Name, active: buyerIsTeam1)  { buyerIsTeam1 = true  }
                        toggleBtn(label: vm.team2Name, active: !buyerIsTeam1) { buyerIsTeam1 = false }
                    }
                }
            }

            // كبوت / دبل + حقل الأوراق
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    toggleBtn(label: "كبوت", active: isKaboot, activeColor: .orange) {
                        isKaboot.toggle()
                        if isKaboot { isDobble = false; buyerRawText = "" }
                    }
                    toggleBtn(label: "دبل x2", active: isDobble, activeColor: .purple) {
                        isDobble.toggle()
                        if isDobble { isKaboot = false }
                    }
                }
                .padding(.horizontal)

                if !isKaboot {
                    // نحن دائما يمين، هم دائما يسار
                    HStack(spacing: 10) {
                        rawInputCard(
                            label: "\(vm.team1Name) — أوراق",
                            text: buyerIsTeam1 ? $buyerRawText
                                              : .constant(buyerRawValid ? String(format: "%d", team1RawDisplay) : "—"),
                            color: buyerIsTeam1 ? c1 : c1.opacity(0.5),
                            isEditable: buyerIsTeam1
                        )
                        rawInputCard(
                            label: "\(vm.team2Name) — أوراق",
                            text: buyerIsTeam1 ? .constant(buyerRawValid ? String(format: "%d", team2RawDisplay) : "—")
                                              : $buyerRawText,
                            color: buyerIsTeam1 ? c2.opacity(0.5) : c2,
                            isEditable: !buyerIsTeam1
                        )
                    }
                    .padding(.horizontal)

                    if let raw = Int(buyerRawText), raw > gameType.rawTotal {
                        Text("الحد الاقصى في \(gameType.rawValue): \(String(format: "%d", gameType.rawTotal))")
                            .font(.caption).foregroundColor(.orange)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // مشاريع
            declarationsCard(title: "مشاريع \(vm.team1Name)", dec: $team1Dec, color: c1)
            declarationsCard(title: "مشاريع \(vm.team2Name)", dec: $team2Dec, color: c2)

            // نتيجة الجولة (live)
            if let r = liveResult {
                resultPreview(r)
            }

            // خطأ الصوت
            if let err = voiceError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(err).font(.caption).foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
            }

            // أزرار التسجيل + الميكروفون
            HStack(spacing: 10) {
                Button { handleMicButton() } label: {
                    ZStack {
                        Circle()
                            .fill(speech.isListening ? Color.red : Color(.systemGray5))
                            .frame(width: 52, height: 52)
                        if isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: speech.isListening ? "stop.fill" : "mic.fill")
                                .font(.title3)
                                .foregroundColor(speech.isListening ? .white : .secondary)
                        }
                    }
                }
                .disabled(isProcessing)

                Button { saveRound() } label: {
                    Text("تسجيل")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? Color.blue : Color(.systemGray5))
                        .foregroundColor(canSave ? .white : Color(.systemGray))
                        .cornerRadius(12)
                }
                .disabled(!canSave)
            }

            // نص التسجيل الصوتي المباشر
            if speech.isListening && !speech.transcript.isEmpty {
                Text(speech.transcript)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: ── أزرار التبديل ─────────────────────────────────────────────
    @ViewBuilder
    private func toggleCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            content()
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func toggleBtn(label: String, active: Bool,
                           activeColor: Color = .blue,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(active ? activeColor : Color(.systemGray5))
                .foregroundColor(active ? .white : Color(.label).opacity(0.35))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: ── حقل الإدخال الخام ─────────────────────────────────────────
    @ViewBuilder
    private func rawInputCard(label: String, text: Binding<String>, color: Color, isEditable: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            if isEditable {
                TextField("0", text: text)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .multilineTextAlignment(.center)
                    .frame(height: 52)
                    .focused($rawFocused)
            } else {
                Text(text.wrappedValue)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: ── بطاقة المشاريع ────────────────────────────────────────────
    @ViewBuilder
    private func declarationsCard(title: String, dec: Binding<Declarations>, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .trailing)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                DecStepper(label: "سرا", value: dec.sara)
                DecStepper(label: "خمسين", value: dec.fifty)
                DecStepper(label: "مية", value: dec.hundred)
                if gameType == .sun {
                    DecStepper(label: "أربع مية", value: dec.fourHundred)
                } else {
                    DecStepper(label: "بلوت", value: dec.bloot)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: ── معاينة النتيجة ────────────────────────────────────────────
    @ViewBuilder
    private func resultPreview(_ r: RoundResult) -> some View {
        let t1 = buyerIsTeam1 ? r.buyerFinal : r.otherFinal
        let t2 = buyerIsTeam1 ? r.otherFinal : r.buyerFinal

        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: r.buyerWon ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(r.buyerWon ? .green : .red)
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
                        .font(.caption.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }
            }
            .font(.subheadline.bold())
            .foregroundColor(r.buyerWon ? .green : .red)
            .frame(maxWidth: .infinity)

            if !r.isKaboot && r.buyerWon {
                HStack(spacing: 4) {
                    Text("أوراق: \(String(format: "%d", r.buyerCardPts))")
                    if r.buyerDecPts > 0 { Text("+ مشاريع: \(String(format: "%d", r.buyerDecPts))") }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(vm.team1Name).font(.caption).foregroundColor(.secondary)
                    Text(String(format: "%d", t1)).font(.title2.bold()).foregroundColor(c1)
                    Text("بنط").font(.caption2).foregroundColor(c1.opacity(0.5))
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 44)

                VStack(spacing: 2) {
                    Text(vm.team2Name).font(.caption).foregroundColor(.secondary)
                    Text(String(format: "%d", t2)).font(.title2.bold()).foregroundColor(c2)
                    Text("بنط").font(.caption2).foregroundColor(c2.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 4) {
                Text("المجموع:")
                    .font(.caption).foregroundColor(.secondary)
                Text(String(format: "%d", vm.team1Total + t1))
                    .font(.caption.bold()).foregroundColor(c1)
                Text("—")
                    .font(.caption).foregroundColor(.secondary)
                Text(String(format: "%d", vm.team2Total + t2))
                    .font(.caption.bold()).foregroundColor(c2)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(r.buyerWon ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1.5)
        )
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

        if speech.isListening {
            let text = speech.stop()
            guard !text.isEmpty else { return }
            processVoice(text: text)
        } else {
            let key = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
            if key.isEmpty {
                showAPIKeySheet = true
                return
            }
            speech.start()
        }
    }

    private func processVoice(text: String) {
        let key = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
        isProcessing = true

        Task {
            do {
                let parsed = try await GameParser.parse(
                    text:      text,
                    team1Name: vm.team1Name,
                    team2Name: vm.team2Name,
                    apiKey:    key
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
}

// MARK: ── DecStepper ──────────────────────────────────────────────────────
struct DecStepper: View {
    let label: String
    @Binding var value: Int

    var body: some View {
        Group {
            if value == 0 {
                Button { value = 1 } label: {
                    Text(label)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 5) {
                    Text(label)
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(1).minimumScaleFactor(0.7)

                    Button { value = max(0, value - 1) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    Text(String(format: "%d", value))
                        .font(.subheadline.bold())
                        .frame(width: 22)

                    Button { value += 1 } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(8)
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
        VStack(spacing: 2) {
            TextField("الاسم", text: $name)
                .font(.footnote.bold())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text(String(format: "%d", score))
                .font(.system(size: 64, weight: .heavy))
                .foregroundColor(color)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Text("بنط")
                .font(.caption2)
                .foregroundColor(color.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18).padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: ── ProgressBar ────────────────────────────────────────────────────
struct ProgressBar: View {
    let t1: Int, t2: Int, goal: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                HStack(spacing: 0) {
                    Spacer()
                    Capsule().fill(Color.red)
                        .frame(width: bw(geo.size.width, score: t2))
                }
                Capsule().fill(Color.blue)
                    .frame(width: bw(geo.size.width, score: t1))
            }
        }
        .frame(height: 6).padding(.vertical, 4)
    }

    private func bw(_ total: CGFloat, score: Int) -> CGFloat {
        min(total, total * CGFloat(score) / CGFloat(goal))
    }
}

// MARK: ── RoundHistory ────────────────────────────────────────────────────
struct RoundHistory: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vm.team1Name).frame(maxWidth: .infinity, alignment: .trailing)
                Text("ج").frame(width: 54, alignment: .center).foregroundColor(.secondary)
                Text(vm.team2Name).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.bold()).foregroundColor(.secondary)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(12, corners: [.topLeft, .topRight])

            Divider()

            ForEach(Array(vm.rounds.reversed().enumerated()), id: \.element.id) { idx, round in
                VStack(spacing: 0) {
                    HStack {
                        Text(String(format: "%d", round.team1Score))
                            .font(.body.bold()).foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        VStack(spacing: 1) {
                            Text(String(format: "%d", round.number))
                                .font(.caption).foregroundColor(.secondary)
                            HStack(spacing: 3) {
                                Text(round.gameType.rawValue)
                                    .font(.caption2).foregroundColor(.secondary)
                                if round.isDobble {
                                    Text("x2").font(.caption2).foregroundColor(.purple)
                                }
                                Image(systemName: round.buyerWon ? "checkmark" : "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(round.buyerWon ? .green : .red)
                            }
                        }
                        .frame(width: 54)

                        Text(String(format: "%d", round.team2Score))
                            .font(.body.bold()).foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(.systemBackground))

                    if idx < vm.rounds.count - 1 { Divider() }
                }
            }
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: ── Helpers ─────────────────────────────────────────────────────────
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat; var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

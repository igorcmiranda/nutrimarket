import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct ChallengeView: View {
    @EnvironmentObject var challengeManager: ChallengeManager
    @EnvironmentObject var healthKit: HealthKitManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var trophyManager: TrophyManager
    @EnvironmentObject var profile: UserProfile
    @Binding var showSubscription: Bool

    @State private var selectedTab = 0
    @State private var showNewChallenge = false
    @State private var leaderboardFilter: ChallengeManager.LeaderboardFilter = .global

    var dailyCalorieBurnGoal: Double {
        let bmr: Double
        if profile.sex == "Masculino" {
            bmr = 88.36 + (13.4 * profile.weight) + (4.8 * profile.height) - (5.7 * Double(profile.age))
        } else {
            bmr = 447.6 + (9.2 * profile.weight) + (3.1 * profile.height) - (4.3 * Double(profile.age))
        }
        switch profile.goal {
        case "Perder peso":  return bmr * 0.3
        case "Ganhar massa": return bmr * 0.2
        default:             return bmr * 0.25
        }
    }

    var todayProgress: Double {
        guard dailyCalorieBurnGoal > 0 else { return 0 }
        return min(healthKit.todayCaloriesBurned / dailyCalorieBurnGoal, 1.0)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Meu progresso").tag(0)
                    Text("Desafios").tag(1)
                    Text("Placar").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0: progressTab
                        case 1: challengesTab
                        default: leaderboardTab
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Desafio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewChallenge = true } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showNewChallenge) {
            NewChallengeView()
                .environmentObject(challengeManager)
                .environmentObject(authManager)
                .environmentObject(feedManager)
        }
        .fullScreenCover(isPresented: $trophyManager.showTrophyAnimation) {
            if let trophy = trophyManager.pendingTrophy {
                TrophyAnimationView(trophy: trophy) {
                    trophyManager.showTrophyAnimation = false
                    trophyManager.pendingTrophy = nil
                }
            }
        }
        .sheet(item: $trophyManager.completedChallengeToShare) { result in
            ShareChallengeResultView(
                result: result,
                onDismiss: {
                    trophyManager.completedChallengeToShare = nil
                }
            )
            .environmentObject(feedManager)
            .environmentObject(authManager)
        }
        .onAppear {
            Task {
                challengeManager.startChallengesListener()
                await healthKit.requestAuthorization()
                await trophyManager.loadTrophies()
                await trophyManager.checkExpiredChallenges()
                await challengeManager.loadLeaderboard(filter: .global)
                await challengeManager.loadLeaderboardPreference(uid: Auth.auth().currentUser?.uid ?? "")
                for challenge in challengeManager.activeChallenges {
                    await challengeManager.updateDailyProgress(
                        challengeID: challenge.id,
                        caloriesBurned: healthKit.todayCaloriesBurned,
                        dailyGoal: dailyCalorieBurnGoal
                    )
                }
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await trophyManager.checkExpiredChallenges()
                if let uid = Auth.auth().currentUser?.uid {
                    await challengeManager.loadChallenges(uid: uid)
                }
            }
        }
    }

    // MARK: - Compartilhar no feed

    

    // MARK: - Tab Progresso

    var progressTab: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meta de gasto calórico").font(.headline)
                        Text("Baseada no seu perfil e objetivo")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(healthKit.todayCaloriesBurned))")
                            .font(.title2).fontWeight(.black).foregroundStyle(.orange)
                        Text("de \(Int(dailyCalorieBurnGoal)) kcal")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5)).frame(height: 16)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: todayProgress >= 1 ? [.green, .mint] : [.orange, .yellow],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * todayProgress, height: 16)
                            .animation(.spring(), value: todayProgress)
                    }
                }
                .frame(height: 16)

                HStack {
                    Text("\(Int(todayProgress * 100))% da meta")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if todayProgress >= 1 {
                        Label("Meta atingida!", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    } else {
                        Text("Faltam \(Int(dailyCalorieBurnGoal - healthKit.todayCaloriesBurned)) kcal")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

            HStack(spacing: 12) {
                ActivityStat(icon: "flame.fill",
                             value: "\(Int(healthKit.todayCaloriesBurned))",
                             label: "kcal gastas", color: .orange)
                ActivityStat(icon: "figure.walk",
                             value: "\(healthKit.todaySteps)",
                             label: "passos", color: .blue)
                ActivityStat(icon: "mappin.and.ellipse",
                             value: "\(healthKit.todayDistanceKm)km",
                             label: "distância", color: .green)
            }

            VStack(spacing: 8) {
                Text("\(Int(PointsCalculator.calculate(caloriesBurned: healthKit.todayCaloriesBurned, dailyGoal: dailyCalorieBurnGoal)))")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                    startPoint: .top, endPoint: .bottom))
                Text("pontos hoje").font(.subheadline).foregroundStyle(.secondary)
                Text("Máximo 100 pontos por dia").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

            if !healthKit.isAuthorized {
                Button {
                    Task { await healthKit.requestAuthorization() }
                } label: {
                    Label("Conectar ao Apple Saúde", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.red.opacity(0.12)).foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tab Desafios

    var challengesTab: some View {
        VStack(spacing: 16) {
            if !challengeManager.pendingChallenges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Pendentes", systemImage: "bell.fill")
                        .font(.headline).foregroundStyle(.orange)
                    ForEach(challengeManager.pendingChallenges) { challenge in
                        PendingChallengeCard(challenge: challenge)
                            .environmentObject(challengeManager)
                            .environmentObject(profile)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button { showNewChallenge = true } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Novo desafio ou competição").fontWeight(.medium)
                }
                .frame(maxWidth: .infinity).padding()
                .background(LinearGradient(colors: [.purple, .blue],
                                           startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            if challengeManager.activeChallenges.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy").font(.system(size: 44)).foregroundStyle(.secondary)
                    Text("Nenhum desafio ativo").font(.headline)
                    Text("Desafie alguém que você segue!").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(32)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(challengeManager.activeChallenges) { challenge in
                    ActiveChallengeCard(
                        challenge: challenge,
                        myCaloriesBurned: healthKit.todayCaloriesBurned,
                        myDailyGoal: dailyCalorieBurnGoal
                    )
                    .environmentObject(challengeManager)
                    .environmentObject(authManager)
                }
            }
        }
    }

    // MARK: - Tab Placar

    var leaderboardTab: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aparecer no placar público")
                        .font(.subheadline).fontWeight(.medium)
                    Text("Sua pontuação ficará visível para todos")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { challengeManager.showOnLeaderboard },
                    set: { newValue in
                        Task {
                            guard let uid = Auth.auth().currentUser?.uid,
                                  let user = authManager.currentUser else { return }
                            challengeManager.showOnLeaderboard = newValue
                            let ref = Firestore.firestore().collection("leaderboard").document(uid)
                            if newValue {
                                try? await ref.setData([
                                    "userName": user.name,
                                    "avatarURL": user.avatarURL,
                                    "isVerified": user.isVerified,
                                    "totalPoints": 0,
                                    "city": "",
                                    "region": "",
                                    "country": "Brasil",
                                    "showOnLeaderboard": true
                                ])
                            } else {
                                try? await ref.updateData(["showOnLeaderboard": false])
                            }
                            try? await Firestore.firestore().collection("users").document(uid)
                                .updateData(["showOnLeaderboard": newValue])
                            await challengeManager.loadLeaderboard(filter: leaderboardFilter)
                        }
                    }
                ))
                .tint(.green)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

            HStack(spacing: 8) {
                ForEach([
                    ("Global", ChallengeManager.LeaderboardFilter.global),
                    ("País", .country),
                    ("Estado", .region),
                    ("Cidade", .city)
                ], id: \.0) { label, filter in
                    Button {
                        leaderboardFilter = filter
                        Task { await challengeManager.loadLeaderboard(filter: filter) }
                    } label: {
                        Text(label).font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(leaderboardFilter == filter ? Color.green : Color(.systemGray5))
                            .foregroundStyle(leaderboardFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if challengeManager.leaderboard.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.number").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("Nenhum participante ainda").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(32)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(challengeManager.leaderboard) { entry in
                        LeaderboardRow(entry: entry)
                        if entry.id != challengeManager.leaderboard.last?.id {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
        }
    }
}

// MARK: - Sub-components

struct ActivityStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(value).font(.subheadline).fontWeight(.bold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PendingChallengeCard: View {
    let challenge: Challenge
    @EnvironmentObject var challengeManager: ChallengeManager
    @EnvironmentObject var profile: UserProfile

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                AvatarView(url: challenge.challengerAvatarURL, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.isGroup
                         ? "\(challenge.challengerName) te convidou para uma competição!"
                         : "\(challenge.challengerName) te desafiou!")
                        .font(.subheadline).fontWeight(.medium)
                    Text("Duração: 1 mês · até \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                    if challenge.isGroup {
                        Text("\(challenge.acceptedIDs.count) pessoa(s) já aceitaram")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
            }
            HStack(spacing: 10) {
                Button {
                    Task { await challengeManager.acceptChallenge(challenge, userProfile: profile) }
                } label: {
                    Text("Aceitar").fontWeight(.medium)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.green).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await challengeManager.declineChallenge(challenge) }
                } label: {
                    Text("Recusar").fontWeight(.medium)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color(.systemGray5)).foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

struct ActiveChallengeCard: View {
    let challenge: Challenge
    let myCaloriesBurned: Double
    let myDailyGoal: Double
    @EnvironmentObject var challengeManager: ChallengeManager
    @EnvironmentObject var authManager: AuthManager
    @State private var participants: [(id: String, name: String, avatar: String, points: Double)] = []
    @State private var myPoints: Double = 0

    var myProgress: Double {
        PointsCalculator.calculate(caloriesBurned: myCaloriesBurned, dailyGoal: myDailyGoal) / 100
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: challenge.endDate).day ?? 0)
    }

    var uid: String { authManager.currentUser?.uid ?? "" }

    var sortedParticipants: [(id: String, name: String, avatar: String, points: Double)] {
        participants.sorted { $0.points > $1.points }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label(challenge.isGroup ? "Competição em grupo" : "Desafio ativo",
                      systemImage: challenge.isGroup ? "person.3.fill" : "flame.fill")
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(challenge.isGroup ? .purple : .orange)
                Spacer()
                Text("Termina em \(daysRemaining) dias")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if challenge.isGroup {
                groupScoreboard
            } else {
                duoScoreboard
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .onAppear { setupListeners() }
    }

    var duoScoreboard: some View {
        let opponent = sortedParticipants.first { $0.id != uid }
        return HStack(spacing: 0) {
            VStack(spacing: 6) {
                AvatarView(url: authManager.currentUser?.avatarURL ?? "", size: 44)
                Text("Eu").font(.caption).fontWeight(.medium)
                Text("\(Int(myPoints)) pts")
                    .font(.title3).fontWeight(.black).foregroundStyle(.green)
                ProgressView(value: myProgress).tint(.green).frame(width: 80)
                Text("\(Int(myCaloriesBurned)) kcal").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("VS").font(.title2).fontWeight(.black).foregroundStyle(.secondary)
                Text("hoje").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 44)

            VStack(spacing: 6) {
                AvatarView(url: opponent?.avatar ?? "", size: 44)
                Text(opponent?.name ?? "...").font(.caption).fontWeight(.medium).lineLimit(1)
                Text("\(Int(opponent?.points ?? 0)) pts")
                    .font(.title3).fontWeight(.black).foregroundStyle(.orange)
                ProgressView(value: min((opponent?.points ?? 0) / 100, 1.0))
                    .tint(.orange).frame(width: 80)
                Text("- kcal").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var groupScoreboard: some View {
        VStack(spacing: 8) {
            Text("\(participants.count) participantes")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(Array(sortedParticipants.enumerated()), id: \.element.id) { index, p in
                HStack(spacing: 10) {
                    Text("#\(index + 1)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(
                            index == 0 ? Color(hex: "FFD700") :
                            index == 1 ? Color(hex: "C0C0C0") :
                            index == 2 ? Color(hex: "CD7F32") : .secondary
                        )
                        .frame(width: 28)
                    AvatarView(url: p.avatar, size: 34)
                    Text(p.id == uid ? "Eu" : p.name)
                        .font(.subheadline)
                        .fontWeight(p.id == uid ? .bold : .regular)
                        .foregroundStyle(p.id == uid ? .green : .primary)
                    Spacer()
                    Text("\(Int(p.points)) pts")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(index == 0 ? Color(hex: "FFD700") : .primary)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(p.id == uid ? Color.green.opacity(0.06) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func setupListeners() {
        let db = Firestore.firestore()

        // Fetch imediato
        Task {
            let uid = self.uid
            if let doc = try? await db.collection("challenges").document(challenge.id)
                .collection("participants").document(uid).getDocument(),
               let data = doc.data() {
                await MainActor.run {
                    self.myPoints = data["totalPoints"] as? Double ?? 0
                }
            }
            let allDocs = try? await db.collection("challenges").document(challenge.id)
                .collection("participants").getDocuments()
            if let docs = allDocs?.documents {
                await MainActor.run {
                    self.participants = docs.map { doc in
                        (
                            id: doc.documentID,
                            name: doc.data()["userName"] as? String ?? "",
                            avatar: doc.data()["avatarURL"] as? String ?? "",
                            points: doc.data()["totalPoints"] as? Double ?? 0
                        )
                    }
                    self.myPoints = self.participants.first { $0.id == uid }?.points ?? 0
                }
            }
        }

        // Listener em tempo real
        db.collection("challenges").document(challenge.id)
            .collection("participants")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self.participants = docs.map { doc in
                        (
                            id: doc.documentID,
                            name: doc.data()["userName"] as? String ?? "",
                            avatar: doc.data()["avatarURL"] as? String ?? "",
                            points: doc.data()["totalPoints"] as? Double ?? 0
                        )
                    }
                    self.myPoints = self.participants.first { $0.id == self.uid }?.points ?? 0
                }
            }
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    var rankColor: Color {
        switch entry.rank {
        case 1: return Color(hex: "FFD700")
        case 2: return Color(hex: "C0C0C0")
        case 3: return Color(hex: "CD7F32")
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(rankColor).frame(width: 36)
            AvatarView(url: entry.avatarURL, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.userName).font(.subheadline).fontWeight(.medium)
                    if entry.isVerified { VerifiedBadge(size: 12) }
                }
                Text(entry.city.isEmpty ? "Localização desconhecida" : "\(entry.city), \(entry.region)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.totalPoints))")
                    .font(.subheadline).fontWeight(.black).foregroundStyle(rankColor)
                Text("pontos").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

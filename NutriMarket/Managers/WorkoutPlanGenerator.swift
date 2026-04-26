import Foundation

class WorkoutPlanGenerator {
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    func generate(bodyResult: BodyAnalysisResult, profile: UserProfile) async throws -> WorkoutPlan {

        let muscles = bodyResult.muscleGroups
            .map { "\($0.name) (prioridade: \($0.priority))" }
            .joined(separator: ", ")

        // ── Exercise-type specific instructions ──────────────────────
        let modalityInstructions = modalityGuide(for: profile.exerciseType, profile: profile)

        let prompt = """
        Você é um personal trainer experiente especializado em diversas modalidades esportivas.
        
        Perfil do usuário:
        - Sexo: \(profile.sex), Idade: \(profile.age) anos
        - Peso: \(profile.weight)kg, Altura: \(profile.height)cm
        - Objetivo: \(profile.goal)
        - Gordura corporal estimada: \(bodyResult.fatPercentageLow)-\(bodyResult.fatPercentageHigh)%
        - Categoria: \(bodyResult.fatCategory)
        - Modalidade praticada: \(profile.exerciseSummaryForAI)
        
        Músculos que precisam de mais atenção:
        \(muscles)
        
        \(modalityInstructions)
        
        Crie um plano de treino semanal e retorne APENAS JSON válido:
        {
          "targetMuscles": ["músculo1", "músculo2"],
          "summary": "resumo do plano em 2 frases explicando a estratégia e a modalidade",
          "estimatedDuration": "duração estimada por sessão (ex: 45-60 minutos)",
          "difficulty": "Iniciante" ou "Intermediário" ou "Avançado",
          "weeklySchedule": [
            {
              "dayName": "Segunda-feira",
              "focus": "descrição do foco do dia (ex: Corrida intervalada, Yoga restaurativa)",
              "restDay": false,
              "exercises": [
                {
                  "name": "nome do exercício",
                  "muscleGroup": "músculo ou sistema trabalhado",
                  "sets": número de séries (ou número de repetições do circuito),
                  "reps": "repetições ou tempo (ex: '8-12', '30s', '400m')",
                  "rest": "tempo de descanso (ex: '60s', '2min', 'sem descanso')",
                  "tips": "dica de execução ou segurança curta (máx 15 palavras)"
                }
              ]
            }
          ],
          "generalTips": ["dica geral 1", "dica geral 2", "dica geral 3"]
        }
        
        Regras gerais:
        - Crie 7 dias (Segunda a Domingo)
        - Inclua pelo menos 1-2 dias de descanso (restDay: true, exercises: [])
        - Para dias de descanso, focus deve ser "Descanso e recuperação"
        - Entre 4-7 exercícios/atividades por dia de treino ativo
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 3000,
            "messages": [["role": "user", "content": prompt]]
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw GeneratorError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = bodyData

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw GeneratorError.parseFailed
        }

        let cleanText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let cleanData = cleanText.data(using: .utf8),
              let result = try? JSONDecoder().decode(WorkoutPlan.self, from: cleanData) else {
            throw GeneratorError.parseFailed
        }

        return result
    }

    // MARK: - Modality-specific prompt guide

    private func modalityGuide(for type: ExerciseType, profile: UserProfile) -> String {
        switch type {
        case .musculacao:
            return """
            ⚠️ MODALIDADE: Musculação (academia)
            - Exercícios com pesos, barras, halteres e máquinas
            - Inclua aquecimento, exercícios principais e alongamento
            - Para ganho de massa: 3-5 séries, 6-12 reps, descanso 90-120s
            - Para perda de peso: 3 séries, 12-15 reps, descanso 45-60s
            - Para manter: equilíbrio entre força e resistência
            - Priorize os músculos identificados na análise corporal
            """
        case .pilates:
            return """
            ⚠️ MODALIDADE: Pilates
            - Exercícios de solo (mat pilates) ou aparelhos (reformer, cadillac)
            - Foco em core, estabilização, flexibilidade e postura
            - Séries no formato "repetições lentas e controladas"
            - Inclua exercícios como: hundred, roll-up, leg circles, plank, bridge
            - Adapte para o objetivo: modelagem (mais reps), força (mais resistência)
            """
        case .corrida:
            return """
            ⚠️ MODALIDADE: Corrida
            - Crie uma planilha de corrida semanal
            - Inclua: corrida leve, intervalados, tempo run, corrida longa
            - Use distâncias (km) ou tempos (min) como "reps"
            - Inclua aquecimento com caminhada e resfriamento com alongamento
            - Para perda de peso: maior volume e treinos contínuos
            - Para manter: equilíbrio entre velocidade e resistência
            - Adicione 1 dia de fortalecimento muscular para prevenir lesões
            """
        case .cardio:
            return """
            ⚠️ MODALIDADE: Cardio
            - Exercícios aeróbicos variados (esteira, elíptico, bike, corda)
            - Alterne entre exercícios de baixa, média e alta intensidade
            - Inclua duração (min) e intensidade (% FCmáx ou percepção de esforço)
            - Para perda de peso: zonas de queima de gordura (60-70% FCmáx)
            - Para condicionamento: zonas aeróbicas-anaeróbicas (70-85% FCmáx)
            """
        case .hiit:
            return """
            ⚠️ MODALIDADE: HIIT (Treino Intervalado de Alta Intensidade)
            - Circuitos com intervalos de esforço máximo e recuperação
            - Formato: "20s esforço / 10s descanso" ou "40s esforço / 20s descanso"
            - Exercícios: burpees, mountain climbers, jumping jacks, sprints, kettlebell
            - Sessões mais curtas (20-40 min) mas intensas
            - Máximo 4 sessões HIIT por semana para recuperação adequada
            - Inclua pelo menos 1 dia de mobilidade/recuperação ativa
            """
        case .crossfit:
            return """
            ⚠️ MODALIDADE: CrossFit / Treino Funcional
            - WODs (Workout of the Day) com movimentos funcionais
            - Inclua levantamentos olímpicos, ginástica e metcons
            - Exercícios: clean, snatch, pull-ups, box jump, thrusters, double-unders
            - Formato: AMRAP, For Time, EMOM (explique no campo "reps")
            - Escale para o nível de experiência do usuário
            - Inclua mobilidade e aquecimento específico
            """
        case .natacao:
            return """
            ⚠️ MODALIDADE: Natação
            - Séries de nado por distância (metros) ou tempo
            - Inclua diferentes estilos: crawl, costas, peito, borboleta
            - Séries de: aquecimento, técnica, principal, desaquecimento
            - Exemplo de reps: "4x50m crawl descanso 30s", "200m contínuo"
            - Inclua kicking board, pull buoy para trabalho isolado
            - 1 dia de treino em seco (core, mobilidade) para complementar
            """
        case .ciclismo:
            return """
            ⚠️ MODALIDADE: Ciclismo / Spinning
            - Treinos por tempo ou distância no pedal
            - Inclua: warm-up, subidas (cadência baixa/carga alta), sprints, cool-down
            - Para spinning: RPM e nível de resistência como "reps"
            - Varie entre endurance (longa duração, ritmo moderado) e potência (sprints)
            - 1 dia de fortalecimento de quadríceps, isquiotibiais e core
            """
        case .yoga:
            return """
            ⚠️ MODALIDADE: Yoga
            - Sequências de poses (asanas) adaptadas ao objetivo
            - Para emagrecer: yoga dinâmico (vinyasa, power yoga)
            - Para flexibilidade/recuperação: hatha, yin yoga, restaurativo
            - Nomeie as poses em português e sânscrito: ex. "Guerreiro I (Virabhadrasana I)"
            - Inclua pranayama (respiração) em cada sessão
            - Duração em minutos ou número de respirações por pose
            """
        case .futebol:
            return """
            ⚠️ MODALIDADE: Futebol e Esportes Coletivos
            - Combine treino técnico, condicionamento e força
            - Inclua: corrida, sprints, agilidade (ladder, cones), força funcional
            - Adicione exercícios de prevenção de lesões (tornozelo, joelho)
            - Treinos de força focados em membros inferiores e core
            - Simule movimentos do esporte: arranques, mudanças de direção
            """
        case .artesMarciais:
            return """
            ⚠️ MODALIDADE: Artes Marciais (boxe, jiu-jitsu, muay thai, etc.)
            - Combine treino técnico, condicionamento e força
            - Inclua: shadowboxing, saco de pancadas, rolar no chão (grappling)
            - Exercícios de força funcional: pull-ups, dips, core, flexões
            - Treino cardiovascular: pular corda, sprints curtos
            - Exercícios de flexibilidade e prevenção de lesões
            - Organize por grupos musculares e demandas do esporte
            """
        case .misto:
            let schedule = profile.exerciseSummaryForAI
            return """
            ⚠️ MODALIDADE: Misto
            Agenda do usuário: \(schedule)
            - Crie exercícios DIFERENTES para cada dia conforme a modalidade indicada
            - Respeite rigorosamente a agenda semanal acima
            - Para cada dia, aplique as mesmas regras da modalidade correspondente
            - Nos dias não especificados, sugira descanso ou recuperação ativa
            """
        case .nenhum:
            return """
            ⚠️ MODALIDADE: Sedentário / Nenhuma atividade regular
            - Comece com exercícios de baixa intensidade e alto volume de adaptação
            - Foco em: caminhada, mobilidade, exercícios funcionais simples
            - Progressão gradual: sem sobrecarregar nas primeiras semanas
            - Exercícios acessíveis: agachamento, flexão de parede, caminhada
            - Evite impacto alto e levantamentos pesados inicialmente
            - Priorize a criação de hábito e prevenção de lesões
            """
        }
    }

    enum GeneratorError: Error {
        case requestFailed, parseFailed
    }
}

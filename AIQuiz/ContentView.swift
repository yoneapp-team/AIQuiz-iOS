import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import AVFoundation

struct LoadingView: View {
    var body: some View {
        ProgressView("読み込み中...")
    }
}

struct CorrectAnswerPopupView: View {
    let explanation: String?
    let correctAnswer: String
    let onNext: () -> Void
    let isLastQuestion: Bool
    let onFinish: () -> Void
    @State private var audioPlayer: AVPlayerWrapper?
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        VStack(spacing: 24) {
            Text("正解")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Text(correctAnswer)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.bottom, 8)
            
            if let explanation = explanation {
                Text(explanation)
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal)
            }
            
            if isLastQuestion {
                Button(action: {
                    audioPlayer?.stop()
                    onFinish()
                }) {
                    Text("クイズを終了")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            } else {
                Button(action: {
                    audioPlayer?.stop()
                    onNext()
                }) {
                    Text("次の問題へ")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(radius: 12)
        .padding()
        .opacity(opacity)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
                scale = 1
            }
        }
    }
}

struct QuizSettingsView: View {
    @State private var quizTopic = ""
    @State private var questionsCount = 5
    @State private var isGenerating = false
    @State private var isLoading = true
    @Binding var showingQuizSettings: Bool
    @Binding var quizId: String?
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundColor(.blue)
                    Text("クイズを作成してみましょう")
                        .font(.headline)
                    Spacer()
                }
                HStack {
                    Text("テーマを入力して問題数を選んでください。\nAIがクイズを生成します。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(6)
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.vertical)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Text("クイズのテーマ")
                    .font(.headline)
                TextEditor(text: $quizTopic)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.bottom)
                    .disabled(isLoading)
                
                Text("問題数")
                    .font(.headline)
                Stepper("\(questionsCount)問", value: $questionsCount, in: 1...10)
                    .sensoryFeedback(.selection, trigger: questionsCount)
                    .disabled(isLoading)
            }
            .padding()
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isGenerating = true
                Task {
                    guard let userId = Auth.auth().currentUser?.uid else { return }
                    
                    let db = Firestore.firestore()

                    let quizData: [String: Any] = [
                        "topic": quizTopic,
                        "questionsCount": questionsCount,
                        "status": "generating",
                        "createdAt": FieldValue.serverTimestamp()
                    ]
                    
                    do {
                        let docRef = try await db.collection("users").document(userId).collection("quizzes").addDocument(data: quizData)
                        quizId = docRef.documentID
                        showingQuizSettings = false
                    } catch {
                        print("Error saving quiz: \(error)")
                        isGenerating = false
                    }
                }
            }) {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("クイズを生成")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(quizTopic.isEmpty || isGenerating || isLoading)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical)
        .task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            
            do {
                let querySnapshot = try await db.collection("users").document(userId)
                    .collection("quizzes")
                    .order(by: "createdAt", descending: true)
                    .limit(to: 1)
                    .getDocuments()
                
                if let lastQuiz = querySnapshot.documents.first {
                    quizTopic = lastQuiz.get("topic") as? String ?? ""
                    questionsCount = lastQuiz.get("questionsCount") as? Int ?? 5
                }
                isLoading = false
            } catch {
                print("Error fetching last quiz: \(error)")
                isLoading = false
            }
        }
    }
}

struct Question: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    let text: String
    let answers: [String]
    let correctAnswer: Int
    let questionAudioUrl: String?
    let explanationAudioUrl: String?
    let questionAudioScript: String?
    let explanationAudioScript: String?
    let answerAudioUrls: [String]?
    let explanation: String?
    let index: Int
    let combinedAudioUrl: String?
    
    static func == (lhs: Question, rhs: Question) -> Bool {
        return lhs.id == rhs.id &&
               lhs.text == rhs.text &&
               lhs.answers == rhs.answers &&
               lhs.correctAnswer == rhs.correctAnswer &&
               lhs.questionAudioUrl == rhs.questionAudioUrl &&
               lhs.explanationAudioUrl == rhs.explanationAudioUrl &&
               lhs.questionAudioScript == rhs.questionAudioScript &&
               lhs.explanationAudioScript == rhs.explanationAudioScript &&
               lhs.answerAudioUrls == rhs.answerAudioUrls &&
               lhs.explanation == rhs.explanation &&
               lhs.combinedAudioUrl == rhs.combinedAudioUrl &&
               lhs.index == rhs.index
    }
}

struct QuizView: View {
    let quizId: String
    @State private var currentQuestionIndex = 0
    @State private var score = 0
    @State private var questionsListener: ListenerRegistration?
    @State private var quizListener: ListenerRegistration?
    @State private var selectedAnswerIndex: Int?
    @State private var isLoading = true
    @State private var audioPlayer: AVPlayerWrapper?
    @State private var previousQuestionAudioUrl: String?
    @State private var correctAnswerAudioUrl: String?
    @State private var wrongAnswerAudioUrl: String?
    @Binding var questions: [Question]
    @Binding var showCorrectPopup: Bool
    @Binding var currentQuestion: Question?
    @Binding var isLastQuestion: Bool
    @State private var shouldPlayNextQuestionAudio = true
    
    private func playAudio(urls: [String]) {
        let validUrls = urls.compactMap { URL(string: $0) }
        guard !validUrls.isEmpty else {
            print("No valid URLs provided")
            return
        }
        
        audioPlayer?.stop()
        audioPlayer = AVPlayerWrapper(urls: validUrls)
        audioPlayer?.play()
    }
    
    private func handleAnswerSelection(index: Int) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        selectedAnswerIndex = index
        let isCorrect = index == questions[currentQuestionIndex].correctAnswer
        
        var audioUrls: [String] = []
        
        if let answerAudioUrls = questions[currentQuestionIndex].answerAudioUrls,
           index < answerAudioUrls.count {
            audioUrls.append(answerAudioUrls[index])
        }
        
        if isCorrect {
            score += 1
            if let correctAnswerAudioUrl = correctAnswerAudioUrl {
                audioUrls.append(correctAnswerAudioUrl)
            }
            if let explanationAudioUrl = questions[currentQuestionIndex].explanationAudioUrl {
                audioUrls.append(explanationAudioUrl)
            }
            currentQuestion = questions[currentQuestionIndex]
            isLastQuestion = currentQuestionIndex == questions.count - 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCorrectPopup = true
            }
        } else {
            if let wrongAnswerAudioUrl = wrongAnswerAudioUrl {
                audioUrls.append(wrongAnswerAudioUrl)
            }
        }
        
        if !audioUrls.isEmpty {
            playAudio(urls: audioUrls)
        }
    }
    
    var body: some View {
        ZStack {
            if isLoading || questions.isEmpty {
                LoadingView()
            } else {
                VStack(spacing: 30) {
                    Spacer()

                    Text(questions[currentQuestionIndex].text)
                        .font(.largeTitle)
                        .minimumScaleFactor(0.5)
                        .lineLimit(5)
                        .padding()
                    
                    ZStack {
                        if questions[currentQuestionIndex].combinedAudioUrl != nil {
                            Button(action: {
                                if let combinedAudioUrl = questions[currentQuestionIndex].combinedAudioUrl {
                                    playAudio(urls: [combinedAudioUrl])
                                }
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.borderless)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(width: 44, height: 44)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 25) {
                        ForEach(Array(questions[currentQuestionIndex].answers.enumerated()), id: \.element) { index, answer in
                            Button(action: {
                                handleAnswerSelection(index: index)
                            }) {
                                ZStack {
                                    Text(answer)
                                        .frame(maxWidth: .infinity)
                                        .foregroundColor(selectedAnswerIndex == index ? .white : .black)
                                        .animation(.none)
                                    HStack {
                                        Image(systemName: "\(index + 1).circle")
                                            .frame(width: 40, alignment: .leading)
                                            .foregroundColor(selectedAnswerIndex == index ? .white : .black)
                                            .animation(.none)
                                        Spacer()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }
                            .buttonStyle(.bordered)
                            .font(.title2)
                            .background(getButtonBackground(for: index))
                            .cornerRadius(8)
                            .animation(.none)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .onAppear {
            setupListener()
        }
        .onDisappear {
            questionsListener?.remove()
            quizListener?.remove()
            audioPlayer?.stop()
        }
        .onChange(of: questions) { oldValue, newValue in
            if !newValue.isEmpty && shouldPlayNextQuestionAudio {
                if let combinedAudioUrl = questions[currentQuestionIndex].combinedAudioUrl,
                   previousQuestionAudioUrl != combinedAudioUrl {
                    previousQuestionAudioUrl = combinedAudioUrl
                    playAudio(urls: [combinedAudioUrl])
                }
            }
        }
        .onChange(of: showCorrectPopup) { oldValue, newValue in
            if !newValue && !isLastQuestion {
                currentQuestionIndex += 1
                selectedAnswerIndex = nil
                shouldPlayNextQuestionAudio = true
                previousQuestionAudioUrl = nil
            }
        }
    }
    
    private func getButtonBackground(for index: Int) -> Color? {
        guard let selectedIndex = selectedAnswerIndex else { return nil }
        
        if index == selectedIndex {
            return index == questions[currentQuestionIndex].correctAnswer ? .green : .red
        }
        return nil
    }
    
    private func setupListener() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: No user ID found")
            return
        }
        let db = Firestore.firestore()
        
        let quizRef = db.collection("users").document(userId)
            .collection("quizzes").document(quizId)
            
        quizListener = quizRef.addSnapshotListener { document, error in
            if let document = document, document.exists {
                correctAnswerAudioUrl = document.get("correctAnswerAudioUrl") as? String
                wrongAnswerAudioUrl = document.get("wrongAnswerAudioUrl") as? String
            }
        }
        
        questionsListener = quizRef.collection("questions")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("Error listening to questions: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No documents found in snapshot")
                    return
                }
                
                let updatedQuestions = documents.compactMap { queryDocumentSnapshot -> Question? in
                    let result = Result { try queryDocumentSnapshot.data(as: Question.self) }
                    switch result {
                    case .success(let question):
                        return question
                    case .failure(let error):
                        print("Error decoding question: \(error)")
                        return nil
                    }
                }
                .sorted { $0.index < $1.index }
                
                if !updatedQuestions.isEmpty {
                    questions = updatedQuestions
                    isLoading = false
                }
            }
    }
}

struct ContentView: View {
    @State private var isLoading = true
    @State private var showingQuizSettings = true
    @State private var questions: [Question] = []
    @State private var quizId: String?
    @State private var showCorrectPopup = false
    @State private var currentQuestion: Question?
    @State private var isLastQuestion = false
    
    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if isLoading {
                        LoadingView()
                    } else if showingQuizSettings {
                        QuizSettingsView(showingQuizSettings: $showingQuizSettings, quizId: $quizId)
                    } else if let id = quizId {
                        QuizView(quizId: id, 
                                questions: $questions, 
                                showCorrectPopup: $showCorrectPopup,
                                currentQuestion: $currentQuestion,
                                isLastQuestion: $isLastQuestion)
                    } else {
                        EmptyView()
                    }
                }
                .navigationTitle("AIクイズメーカー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            }
            
            if showCorrectPopup, let question = currentQuestion {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        CorrectAnswerPopupView(
                            explanation: question.explanation,
                            correctAnswer: question.answers[question.correctAnswer],
                            onNext: {
                                showCorrectPopup = false
                                currentQuestion = nil
                            },
                            isLastQuestion: isLastQuestion,
                            onFinish: {
                                showCorrectPopup = false
                                currentQuestion = nil
                                showingQuizSettings = true
                                questions = []
                            }
                        )
                    }
            }
        }
        .task {
            if Auth.auth().currentUser == nil {
                do {
                    try await Auth.auth().signInAnonymously()
                    isLoading = false
                } catch {
                    print("Anonymous auth error: \(error)")
                }
            } else {
                isLoading = false
            }
        }
    }
}

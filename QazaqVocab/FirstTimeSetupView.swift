import SwiftUI

/// First-time setup journey presenting two concise Russian onboarding steps in a neutral voice.
/// Explains the one-featured-word-per-day promise, lets the learner choose a local reminder time,
/// requests notification authorization contextually, and lands directly on the featured daily word.
struct FirstTimeSetupView: View {
    let onComplete: () -> Void
    
    @State private var currentStep: Int = 1
    @State private var reminderDate: Date = {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = ExperienceEngine.defaultReminderHour
        components.minute = ExperienceEngine.defaultReminderMinute
        return calendar.date(from: components) ?? Date()
    }()
    @State private var isProcessing: Bool = false
    
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 16
    @ScaledMetric(relativeTo: .footnote) private var footnoteSize: CGFloat = 14
    
    var body: some View {
        ZStack {
            QazaqTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header / Step indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(currentStep == 1 ? QazaqTheme.Colors.steppeGold : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(currentStep == 2 ? QazaqTheme.Colors.steppeGold : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
                .padding(.top, 32)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Шаг \(currentStep) из 2")
                
                Spacer()
                
                if currentStep == 1 {
                    stepOneView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                } else {
                    stepTwoView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                }
                
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Step 1: Discovery Promise
    private var stepOneView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(QazaqTheme.Colors.pillSurface)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                QazaqLogoMark(size: 46, accentColor: QazaqTheme.Colors.steppeGold)
            }
            .padding(.bottom, 8)
            .accessibilityHidden(true)
            
            Text("Одно слово каждый день")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                Text("Каждый день в QazaqVocab открывается одно главное казахское слово с переводом на русский язык, примерами и контекстом употребления.")
                    .font(.system(size: bodySize))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.85))
                
                Text("Исследуйте коллекцию в комфортном темпе — без таймеров и принудительных ограничений.")
                    .font(.system(size: footnoteSize))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(.horizontal, 8)
            
            Button {
                HapticManager.impact(style: .medium)
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = 2
                }
            } label: {
                Text("Продолжить")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(QazaqTheme.Colors.steppeGold)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Продолжить переход ко второму шагу")
            .padding(.top, 20)
        }
    }
    
    // MARK: - Step 2: Reminder Time & Contextual Permission
    private var stepTwoView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(QazaqTheme.Colors.pillSurface)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                Image(systemName: "bell.badge")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(QazaqTheme.Colors.steppeGold)
            }
            .padding(.bottom, 4)
            .accessibilityHidden(true)
            
            Text("Ежедневное напоминание")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            
            Text("Выберите удобное время, чтобы вовремя увидеть главное слово сегодняшнего дня:")
                .font(.system(size: footnoteSize))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.8))
                .padding(.horizontal, 12)
            
            // Time selection before permission prompt
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(QazaqTheme.Colors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                DatePicker("Время напоминания", selection: $reminderDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(height: 120)
                    .clipped()
            }
            .frame(height: 130)
            .padding(.vertical, 8)
            
            VStack(spacing: 12) {
                Button {
                    handleEnableReminders()
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.black)
                                .padding(.trailing, 4)
                        }
                        Text("Включить напоминания")
                            .font(.headline)
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(QazaqTheme.Colors.steppeGold)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                .accessibilityLabel("Включить ежедневные напоминания")
                
                Button {
                    handleSkipReminders()
                } label: {
                    Text("Не сейчас")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                .accessibilityLabel("Пропустить настройку напоминаний")
            }
            .padding(.top, 8)
        }
    }
    
    private func handleEnableReminders() {
        guard !isProcessing else { return }
        isProcessing = true
        HapticManager.impact(style: .medium)
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderDate)
        let minute = calendar.component(.minute, from: reminderDate)
        
        Task {
            _ = try? await DailyReminderManager.shared.scheduleReminder(hour: hour, minute: minute)
            
            await MainActor.run {
                ExperienceEngine.setFirstTimeSetupCompleted(true)
                isProcessing = false
                onComplete()
            }
        }
    }
    
    private func handleSkipReminders() {
        guard !isProcessing else { return }
        isProcessing = true
        HapticManager.impact(style: .light)
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderDate)
        let minute = calendar.component(.minute, from: reminderDate)
        
        ExperienceEngine.saveReminderTime(hour: hour, minute: minute)
        ExperienceEngine.setReminderEnabled(false)
        ExperienceEngine.setFirstTimeSetupCompleted(true)
        
        isProcessing = false
        onComplete()
    }
}

#Preview {
    FirstTimeSetupView(onComplete: {})
}

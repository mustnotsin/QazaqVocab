import SwiftUI
import Combine
import UserNotifications
import UIKit

/// ViewModel managing state, permission checks, and reminder scheduling for the Settings surface.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isReminderEnabled: Bool = false
    @Published var reminderDate: Date = Date()
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isCollectionCompleted: Bool = false
    
    let reminderManager: DailyReminderManager
    let defaults: UserDefaults
    let openSettingsHandler: (URL) -> Void
    let allWordsCount: Int
    let seenWordsCount: Int
    let savedWordsCount: Int
    
    @MainActor
    init(
        reminderManager: DailyReminderManager? = nil,
        defaults: UserDefaults? = nil,
        openSettingsHandler: ((URL) -> Void)? = nil,
        allWordsCount: Int = 30,
        seenWordsCount: Int = 0,
        savedWordsCount: Int = 0
    ) {
        let resolvedManager = reminderManager ?? .shared
        let resolvedDefaults = defaults ?? (UserDefaults(suiteName: ExperienceEngine.appGroupID) ?? .standard)
        let resolvedHandler: (URL) -> Void = openSettingsHandler ?? { url in
            UIApplication.shared.open(url)
        }
        
        self.reminderManager = resolvedManager
        self.defaults = resolvedDefaults
        self.openSettingsHandler = resolvedHandler
        self.allWordsCount = allWordsCount
        self.seenWordsCount = seenWordsCount
        self.savedWordsCount = savedWordsCount
        
        self.isReminderEnabled = ExperienceEngine.isReminderEnabled(in: defaults)
        self.isCollectionCompleted = ExperienceEngine.isCollectionCompleted(in: defaults)
        
        let (hour, minute) = ExperienceEngine.getReminderTime(from: defaults)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        self.reminderDate = calendar.date(from: components) ?? Date()
    }
    
    func load() async {
        self.authorizationStatus = await reminderManager.authorizationStatus()
        self.isReminderEnabled = ExperienceEngine.isReminderEnabled(in: defaults)
        self.isCollectionCompleted = ExperienceEngine.isCollectionCompleted(in: defaults)
        
        let (hour, minute) = ExperienceEngine.getReminderTime(from: defaults)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        self.reminderDate = calendar.date(from: components) ?? Date()
    }
    
    func setReminderEnabled(_ enabled: Bool) async {
        if enabled {
            guard !isCollectionCompleted else {
                self.isReminderEnabled = false
                return
            }
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: reminderDate)
            let minute = calendar.component(.minute, from: reminderDate)
            do {
                let scheduled = try await reminderManager.scheduleReminder(hour: hour, minute: minute)
                self.isReminderEnabled = scheduled
            } catch {
                self.isReminderEnabled = false
            }
        } else {
            reminderManager.cancelReminders()
            self.isReminderEnabled = false
        }
        self.authorizationStatus = await reminderManager.authorizationStatus()
    }
    
    func updateReminderTime(_ newDate: Date) async {
        self.reminderDate = newDate
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: newDate)
        let minute = calendar.component(.minute, from: newDate)
        ExperienceEngine.saveReminderTime(hour: hour, minute: minute, in: defaults)
        
        if isReminderEnabled && !isCollectionCompleted {
            _ = try? await reminderManager.scheduleReminder(hour: hour, minute: minute)
        }
    }
    
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openSettingsHandler(url)
        }
    }
    
    var permissionStatusText: String {
        switch authorizationStatus {
        case .authorized, .provisional:
            return "Разрешено"
        case .denied:
            return "Отключено в iOS"
        case .notDetermined:
            return "Не запрошено"
        case .ephemeral:
            return "Временно разрешено"
        @unknown default:
            return "Неизвестно"
        }
    }
    
    var isPermissionDenied: Bool {
        authorizationStatus == .denied
    }
}

/// Focused Settings surface for the TestFlight experience.
/// Lets learners understand and control daily reminders, inspect notification permission status,
/// open system settings when denied, and read neutral Russian information about QazaqVocab
/// and the finite 30-entry test collection.
@MainActor
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: SettingsViewModel
    
    @ScaledMetric(relativeTo: .title3) private var headerSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var footnoteSize: CGFloat = 13
    
    init(
        viewModel: @autoclosure @escaping () -> SettingsViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }
    
    init() {
        _viewModel = StateObject(wrappedValue: SettingsViewModel())
    }
    
    init(
        allWordsCount: Int,
        seenWordsCount: Int,
        savedWordsCount: Int
    ) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            allWordsCount: allWordsCount,
            seenWordsCount: seenWordsCount,
            savedWordsCount: savedWordsCount
        ))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    remindersSection
                    testFlightCollectionSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(QazaqTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        HapticManager.impact(style: .light)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(QazaqTheme.Colors.steppeGold)
                    .accessibilityLabel("Закрыть настройки")
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.load()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.load()
                }
            }
        }
    }
    
    // MARK: - Reminders Section
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ежедневные напоминания")
                .font(.footnote)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(QazaqTheme.Colors.textTertiary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 14) {
                // Reminder Toggle
                Toggle(isOn: Binding(
                    get: { viewModel.isReminderEnabled },
                    set: { newValue in
                        HapticManager.impact(style: .medium)
                        Task {
                            await viewModel.setReminderEnabled(newValue)
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Напоминание каждый день")
                            .font(.system(size: bodySize, weight: .medium))
                            .foregroundStyle(QazaqTheme.Colors.textPrimary)
                        Text("Приглашение открыть главное слово дня")
                            .font(.system(size: footnoteSize))
                            .foregroundStyle(QazaqTheme.Colors.textSecondary)
                    }
                }
                .tint(QazaqTheme.Colors.steppeGold)
                .disabled(viewModel.isCollectionCompleted)
                .accessibilityLabel("Включить или выключить ежедневное напоминание")
                
                if viewModel.isCollectionCompleted {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(QazaqTheme.Colors.steppeGold)
                            .font(.system(size: 16))
                        Text("Коллекция первой версии завершена. Напоминания остановлены.")
                            .font(.system(size: footnoteSize))
                            .foregroundStyle(QazaqTheme.Colors.textSecondary)
                    }
                    .padding(.top, 4)
                } else if viewModel.isReminderEnabled {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Time Picker
                    HStack {
                        Text("Время")
                            .font(.system(size: bodySize, weight: .medium))
                            .foregroundStyle(QazaqTheme.Colors.textPrimary)
                        Spacer()
                        DatePicker(
                            "Время напоминания",
                            selection: Binding(
                                get: { viewModel.reminderDate },
                                set: { newDate in
                                    Task {
                                        await viewModel.updateReminderTime(newDate)
                                    }
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .accessibilityLabel("Выбор времени ежедневного напоминания")
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Permission Status Row
                HStack {
                    Text("Статус уведомлений в iOS")
                        .font(.system(size: footnoteSize))
                        .foregroundStyle(QazaqTheme.Colors.textSecondary)
                    Spacer()
                    Text(viewModel.permissionStatusText)
                        .font(.system(size: footnoteSize, weight: .semibold))
                        .foregroundStyle(
                            viewModel.isPermissionDenied
                                ? Color.orange
                                : (viewModel.authorizationStatus == .authorized ? QazaqTheme.Colors.steppeGold : QazaqTheme.Colors.textTertiary)
                        )
                }
                .accessibilityElement(children: .combine)
                
                // Route to System Settings when permission is unavailable
                if viewModel.isPermissionDenied {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 15))
                            Text("Уведомления отключены в настройках устройства. Чтобы получать напоминания, разрешите их для QazaqVocab.")
                                .font(.system(size: footnoteSize))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .lineSpacing(3)
                        }
                        
                        Button {
                            HapticManager.impact(style: .light)
                            viewModel.openSystemSettings()
                        } label: {
                            HStack {
                                Text("Открыть настройки iOS")
                                    .font(.system(size: footnoteSize, weight: .semibold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(QazaqTheme.Colors.steppeGold)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Открыть настройки iOS для включения уведомлений")
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.25), lineWidth: 0.8)
                            )
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(QazaqTheme.Colors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(QazaqTheme.Colors.cardBorder, lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - TestFlight Collection Section
    private var testFlightCollectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Тестовая коллекция")
                .font(.footnote)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(QazaqTheme.Colors.textTertiary)
                .padding(.horizontal, 4)
            
            VStack(alignment: .leading, spacing: 14) {
                Text("В этой версии QazaqVocab доступно 30 проверенных слов (повседневные, разговорные и культурно значимые). Это тестовая коллекция для первого закрытого тестирования в TestFlight, а не ограничение будущего публичного каталога.")
                    .font(.system(size: bodySize))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineSpacing(4)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Слов в тесте")
                            .font(.system(size: footnoteSize))
                            .foregroundStyle(QazaqTheme.Colors.textSecondary)
                        Text("\(viewModel.allWordsCount)")
                            .font(.system(size: bodySize, weight: .semibold, design: .rounded))
                            .foregroundStyle(QazaqTheme.Colors.steppeGold)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Просмотрено")
                            .font(.system(size: footnoteSize))
                            .foregroundStyle(QazaqTheme.Colors.textSecondary)
                        Text("\(viewModel.seenWordsCount) из \(viewModel.allWordsCount)")
                            .font(.system(size: bodySize, weight: .semibold, design: .rounded))
                            .foregroundStyle(QazaqTheme.Colors.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Сохранено")
                            .font(.system(size: footnoteSize))
                            .foregroundStyle(QazaqTheme.Colors.textSecondary)
                        Text("\(viewModel.savedWordsCount)")
                            .font(.system(size: bodySize, weight: .semibold, design: .rounded))
                            .foregroundStyle(QazaqTheme.Colors.textPrimary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(QazaqTheme.Colors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(QazaqTheme.Colors.cardBorder, lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - About QazaqVocab Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("О приложении")
                .font(.footnote)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(QazaqTheme.Colors.textTertiary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    QazaqLogoMark(size: 42, accentColor: QazaqTheme.Colors.steppeGold)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("QazaqVocab")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(QazaqTheme.Colors.textPrimary)
                        Text("Версия 1.0 (TestFlight)")
                            .font(.system(size: footnoteSize))
                            .foregroundStyle(QazaqTheme.Colors.textSecondary)
                    }
                    Spacer()
                }
                
                KazakhOrnamentDivider(width: 64, accentColor: QazaqTheme.Colors.steppeGold)
                    .padding(.vertical, 2)
                
                Text("QazaqVocab — приложение для ежедневного знакомства с казахскими словами. Создано для русскоязычных людей, изучающих казахский язык. Здесь нет спешки, таймеров и оценок — только одно главное слово каждый день и удобный темп исследования.")
                    .font(.system(size: bodySize))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineSpacing(4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(QazaqTheme.Colors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(QazaqTheme.Colors.cardBorder, lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    SettingsView(
        allWordsCount: 30,
        seenWordsCount: 12,
        savedWordsCount: 5
    )
}

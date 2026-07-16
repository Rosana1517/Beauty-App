import Foundation

struct BeautyDiaryState: Codable {
    var profile: UserProfileRecord
    var checklistItems: [ChecklistItem]
    var routine: SkincareRoutine
    var products: [Product]
    var skinRecords: [SkinRecord]
    var bodyMetricRecords: [BodyMetricRecord]
    var mealRecords: [MealRecord]
    var appointments: [Appointment]
    var resourceItems: [ResourceItem]
    var bookRecords: [BookRecord]
    var tutorialLinks: [TutorialLink]
    var punchRecords: [PunchRecord]
    /// 各功能區的預期目標（區域名 -> 目標文字），有預設值故不需進 memberwise init
    var areaGoals: [String: String] = [:]
    /// AI 建議的自訂常用問題（topic rawValue -> 問題清單），加入後跨啟動保存
    var customAdviceConcerns: [String: [String]] = [:]
    /// 每日熱量目標的身體參數（TDEE 計算用）
    var tdeeProfile: TDEEProfile = TDEEProfile()
    /// 各習慣的獨立提醒時間（習慣 key -> "HH:mm"，空字串代表關閉）
    var habitReminderTimes: [String: String] = [:]
    var achievements: [AchievementBadge]
    var exportHistory: [ExportRecord]
    var resourceFilter: ResourceCategory
    var resourceImportHistory: [ResourceImportHistoryEntry]
    var pendingImportDraft: ResourceImportDraft?
    var resourceSyncQueue: [ResourceSyncQueueItem]
    var aiProviderSettings: AIProviderSettings?
    var hairCareRecords: [HairCareRecord]
    var bodySkinRecords: [BodySkinRecord]
    var faceLiftActions: [FaceLiftAction]
    var faceLiftPunches: [FaceLiftPunchRecord]
    var faceLiftRatings: [FaceLiftRatingRecord]
    var bodyProducts: [Product]
    var hairProducts: [Product]
    var hairAppointments: [Appointment]
    var washFrequencyDays: Int
    var careFrequencyDays: Int
    var whiteningProductUsages: [WhiteningProductUsage]
    var shadeTrackingRecords: [ShadeTrackingRecord]
    var beforeAfterPhotos: [BeforeAfterPhotoPair]
    var favoriteRecipes: [TutorialLink]
    var faceShape: String?
    var savedHairstyles: [TutorialLink]
    var makeupInspirations: [TutorialLink]
    var exercisePunches: [ExercisePunchRecord]
    var customExercises: [CustomExercise]
    var targetWeight: Double?
    var targetBodyFat: Double?
    var trainingSchedule: [TrainingScheduleItem]
    var symptomRecords: [SymptomRecord]
    var bodyAlbumPhotos: [BodyAlbumPhoto]
    var courses: [Course]
    var knowledgeNotes: [KnowledgeNote]
    var videoLearningRecords: [VideoLearningRecord]
    var selfAffirmations: [SelfAffirmation]
    var visionBoardItems: [VisionBoardItem]
    var gratitudeEntries: [GratitudeEntry]
    var moodEntries: [MoodEntry]
    var transactions: [Transaction]
    var budgetCategories: [BudgetCategory]
    var beautyFundTransactions: [BeautyFundTransaction]
    var wishes: [Wish]
    var shoppingItems: [ShoppingItem]
    var checklistCompletions: [ChecklistCompletionEntry]
    var menstrualRecords: [MenstrualRecord]
    var nourishmentRecipes: [TutorialLink]
    var bodyConstitution: String?

    private enum CodingKeys: String, CodingKey {
        case profile
        case checklistItems
        case routine
        case products
        case skinRecords
        case bodyMetricRecords
        case mealRecords
        case appointments
        case resourceItems
        case bookRecords
        case tutorialLinks
        case punchRecords
        case areaGoals
        case customAdviceConcerns
        case tdeeProfile
        case habitReminderTimes
        case achievements
        case exportHistory
        case resourceFilter
        case resourceImportHistory
        case pendingImportDraft
        case resourceSyncQueue
        case aiProviderSettings
        case hairCareRecords
        case bodySkinRecords
        case faceLiftActions
        case faceLiftPunches
        case faceLiftRatings
        case bodyProducts
        case hairProducts
        case hairAppointments
        case washFrequencyDays
        case careFrequencyDays
        case whiteningProductUsages
        case shadeTrackingRecords
        case beforeAfterPhotos
        case favoriteRecipes
        case faceShape
        case savedHairstyles
        case makeupInspirations
        case exercisePunches
        case customExercises
        case targetWeight
        case targetBodyFat
        case trainingSchedule
        case symptomRecords
        case bodyAlbumPhotos
        case courses
        case knowledgeNotes
        case videoLearningRecords
        case selfAffirmations
        case visionBoardItems
        case gratitudeEntries
        case moodEntries
        case transactions
        case budgetCategories
        case beautyFundTransactions
        case wishes
        case shoppingItems
        case checklistCompletions
        case menstrualRecords
        case nourishmentRecipes
        case bodyConstitution
    }

    init(
        profile: UserProfileRecord,
        checklistItems: [ChecklistItem],
        routine: SkincareRoutine,
        products: [Product],
        skinRecords: [SkinRecord],
        bodyMetricRecords: [BodyMetricRecord],
        mealRecords: [MealRecord],
        appointments: [Appointment],
        resourceItems: [ResourceItem],
        bookRecords: [BookRecord],
        tutorialLinks: [TutorialLink],
        punchRecords: [PunchRecord],
        achievements: [AchievementBadge],
        exportHistory: [ExportRecord],
        resourceFilter: ResourceCategory,
        resourceImportHistory: [ResourceImportHistoryEntry],
        pendingImportDraft: ResourceImportDraft?,
        resourceSyncQueue: [ResourceSyncQueueItem],
        aiProviderSettings: AIProviderSettings? = nil,
        hairCareRecords: [HairCareRecord] = [],
        bodySkinRecords: [BodySkinRecord] = [],
        faceLiftActions: [FaceLiftAction] = [],
        faceLiftPunches: [FaceLiftPunchRecord] = [],
        faceLiftRatings: [FaceLiftRatingRecord] = [],
        bodyProducts: [Product] = [],
        hairProducts: [Product] = [],
        hairAppointments: [Appointment] = [],
        washFrequencyDays: Int = 2,
        careFrequencyDays: Int = 7,
        whiteningProductUsages: [WhiteningProductUsage] = [],
        shadeTrackingRecords: [ShadeTrackingRecord] = [],
        beforeAfterPhotos: [BeforeAfterPhotoPair] = [],
        favoriteRecipes: [TutorialLink] = [],
        faceShape: String? = nil,
        savedHairstyles: [TutorialLink] = [],
        makeupInspirations: [TutorialLink] = [],
        exercisePunches: [ExercisePunchRecord] = [],
        customExercises: [CustomExercise] = [],
        targetWeight: Double? = nil,
        targetBodyFat: Double? = nil,
        trainingSchedule: [TrainingScheduleItem] = [],
        symptomRecords: [SymptomRecord] = [],
        bodyAlbumPhotos: [BodyAlbumPhoto] = [],
        courses: [Course] = [],
        knowledgeNotes: [KnowledgeNote] = [],
        videoLearningRecords: [VideoLearningRecord] = [],
        selfAffirmations: [SelfAffirmation] = [],
        visionBoardItems: [VisionBoardItem] = [],
        gratitudeEntries: [GratitudeEntry] = [],
        moodEntries: [MoodEntry] = [],
        transactions: [Transaction] = [],
        budgetCategories: [BudgetCategory] = [],
        beautyFundTransactions: [BeautyFundTransaction] = [],
        wishes: [Wish] = [],
        shoppingItems: [ShoppingItem] = [],
        checklistCompletions: [ChecklistCompletionEntry] = [],
        menstrualRecords: [MenstrualRecord] = [],
        nourishmentRecipes: [TutorialLink] = [],
        bodyConstitution: String? = nil
    ) {
        self.profile = profile
        self.checklistItems = checklistItems
        self.routine = routine
        self.products = products
        self.skinRecords = skinRecords
        self.bodyMetricRecords = bodyMetricRecords
        self.mealRecords = mealRecords
        self.appointments = appointments
        self.resourceItems = resourceItems
        self.bookRecords = bookRecords
        self.tutorialLinks = tutorialLinks
        self.punchRecords = punchRecords
        self.achievements = achievements
        self.exportHistory = exportHistory
        self.resourceFilter = resourceFilter
        self.resourceImportHistory = resourceImportHistory
        self.pendingImportDraft = pendingImportDraft
        self.resourceSyncQueue = resourceSyncQueue
        self.aiProviderSettings = aiProviderSettings
        self.hairCareRecords = hairCareRecords
        self.bodySkinRecords = bodySkinRecords
        self.faceLiftActions = faceLiftActions
        self.faceLiftPunches = faceLiftPunches
        self.faceLiftRatings = faceLiftRatings
        self.bodyProducts = bodyProducts
        self.hairProducts = hairProducts
        self.hairAppointments = hairAppointments
        self.washFrequencyDays = washFrequencyDays
        self.careFrequencyDays = careFrequencyDays
        self.whiteningProductUsages = whiteningProductUsages
        self.shadeTrackingRecords = shadeTrackingRecords
        self.beforeAfterPhotos = beforeAfterPhotos
        self.favoriteRecipes = favoriteRecipes
        self.faceShape = faceShape
        self.savedHairstyles = savedHairstyles
        self.makeupInspirations = makeupInspirations
        self.exercisePunches = exercisePunches
        self.customExercises = customExercises
        self.targetWeight = targetWeight
        self.targetBodyFat = targetBodyFat
        self.trainingSchedule = trainingSchedule
        self.symptomRecords = symptomRecords
        self.bodyAlbumPhotos = bodyAlbumPhotos
        self.courses = courses
        self.knowledgeNotes = knowledgeNotes
        self.videoLearningRecords = videoLearningRecords
        self.selfAffirmations = selfAffirmations
        self.visionBoardItems = visionBoardItems
        self.gratitudeEntries = gratitudeEntries
        self.moodEntries = moodEntries
        self.transactions = transactions
        self.budgetCategories = budgetCategories
        self.beautyFundTransactions = beautyFundTransactions
        self.wishes = wishes
        self.shoppingItems = shoppingItems
        self.checklistCompletions = checklistCompletions
        self.menstrualRecords = menstrualRecords
        self.nourishmentRecipes = nourishmentRecipes
        self.bodyConstitution = bodyConstitution
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(UserProfileRecord.self, forKey: .profile)
        checklistItems = try container.decode([ChecklistItem].self, forKey: .checklistItems)
        routine = try container.decode(SkincareRoutine.self, forKey: .routine)
        products = try container.decodeIfPresent([Product].self, forKey: .products) ?? []
        skinRecords = try container.decodeIfPresent([SkinRecord].self, forKey: .skinRecords) ?? []
        bodyMetricRecords = try container.decodeIfPresent([BodyMetricRecord].self, forKey: .bodyMetricRecords) ?? []
        mealRecords = try container.decodeIfPresent([MealRecord].self, forKey: .mealRecords) ?? []
        appointments = try container.decodeIfPresent([Appointment].self, forKey: .appointments) ?? []
        resourceItems = try container.decodeIfPresent([ResourceItem].self, forKey: .resourceItems) ?? []
        bookRecords = try container.decodeIfPresent([BookRecord].self, forKey: .bookRecords) ?? []
        tutorialLinks = try container.decodeIfPresent([TutorialLink].self, forKey: .tutorialLinks) ?? []
        punchRecords = try container.decodeIfPresent([PunchRecord].self, forKey: .punchRecords) ?? []
        areaGoals = try container.decodeIfPresent([String: String].self, forKey: .areaGoals) ?? [:]
        customAdviceConcerns = try container.decodeIfPresent([String: [String]].self, forKey: .customAdviceConcerns) ?? [:]
        tdeeProfile = try container.decodeIfPresent(TDEEProfile.self, forKey: .tdeeProfile) ?? TDEEProfile()
        habitReminderTimes = try container.decodeIfPresent([String: String].self, forKey: .habitReminderTimes) ?? [:]
        achievements = try container.decodeIfPresent([AchievementBadge].self, forKey: .achievements) ?? []
        exportHistory = try container.decodeIfPresent([ExportRecord].self, forKey: .exportHistory) ?? []
        resourceFilter = try container.decodeIfPresent(ResourceCategory.self, forKey: .resourceFilter) ?? .all
        resourceImportHistory = try container.decodeIfPresent([ResourceImportHistoryEntry].self, forKey: .resourceImportHistory) ?? []
        pendingImportDraft = try container.decodeIfPresent(ResourceImportDraft.self, forKey: .pendingImportDraft)
        resourceSyncQueue = try container.decodeIfPresent([ResourceSyncQueueItem].self, forKey: .resourceSyncQueue) ?? []
        aiProviderSettings = try container.decodeIfPresent(AIProviderSettings.self, forKey: .aiProviderSettings)
        hairCareRecords = try container.decodeIfPresent([HairCareRecord].self, forKey: .hairCareRecords) ?? []
        bodySkinRecords = try container.decodeIfPresent([BodySkinRecord].self, forKey: .bodySkinRecords) ?? []
        faceLiftActions = try container.decodeIfPresent([FaceLiftAction].self, forKey: .faceLiftActions) ?? []
        faceLiftPunches = try container.decodeIfPresent([FaceLiftPunchRecord].self, forKey: .faceLiftPunches) ?? []
        faceLiftRatings = try container.decodeIfPresent([FaceLiftRatingRecord].self, forKey: .faceLiftRatings) ?? []
        bodyProducts = try container.decodeIfPresent([Product].self, forKey: .bodyProducts) ?? []
        hairProducts = try container.decodeIfPresent([Product].self, forKey: .hairProducts) ?? []
        hairAppointments = try container.decodeIfPresent([Appointment].self, forKey: .hairAppointments) ?? []
        washFrequencyDays = try container.decodeIfPresent(Int.self, forKey: .washFrequencyDays) ?? 2
        careFrequencyDays = try container.decodeIfPresent(Int.self, forKey: .careFrequencyDays) ?? 7
        whiteningProductUsages = try container.decodeIfPresent([WhiteningProductUsage].self, forKey: .whiteningProductUsages) ?? []
        shadeTrackingRecords = try container.decodeIfPresent([ShadeTrackingRecord].self, forKey: .shadeTrackingRecords) ?? []
        beforeAfterPhotos = try container.decodeIfPresent([BeforeAfterPhotoPair].self, forKey: .beforeAfterPhotos) ?? []
        favoriteRecipes = try container.decodeIfPresent([TutorialLink].self, forKey: .favoriteRecipes) ?? []
        faceShape = try container.decodeIfPresent(String.self, forKey: .faceShape)
        savedHairstyles = try container.decodeIfPresent([TutorialLink].self, forKey: .savedHairstyles) ?? []
        makeupInspirations = try container.decodeIfPresent([TutorialLink].self, forKey: .makeupInspirations) ?? []
        exercisePunches = try container.decodeIfPresent([ExercisePunchRecord].self, forKey: .exercisePunches) ?? []
        customExercises = try container.decodeIfPresent([CustomExercise].self, forKey: .customExercises) ?? []
        targetWeight = try container.decodeIfPresent(Double.self, forKey: .targetWeight)
        targetBodyFat = try container.decodeIfPresent(Double.self, forKey: .targetBodyFat)
        trainingSchedule = try container.decodeIfPresent([TrainingScheduleItem].self, forKey: .trainingSchedule) ?? []
        symptomRecords = try container.decodeIfPresent([SymptomRecord].self, forKey: .symptomRecords) ?? []
        bodyAlbumPhotos = try container.decodeIfPresent([BodyAlbumPhoto].self, forKey: .bodyAlbumPhotos) ?? []
        courses = try container.decodeIfPresent([Course].self, forKey: .courses) ?? []
        knowledgeNotes = try container.decodeIfPresent([KnowledgeNote].self, forKey: .knowledgeNotes) ?? []
        videoLearningRecords = try container.decodeIfPresent([VideoLearningRecord].self, forKey: .videoLearningRecords) ?? []
        selfAffirmations = try container.decodeIfPresent([SelfAffirmation].self, forKey: .selfAffirmations) ?? []
        visionBoardItems = try container.decodeIfPresent([VisionBoardItem].self, forKey: .visionBoardItems) ?? []
        gratitudeEntries = try container.decodeIfPresent([GratitudeEntry].self, forKey: .gratitudeEntries) ?? []
        moodEntries = try container.decodeIfPresent([MoodEntry].self, forKey: .moodEntries) ?? []
        transactions = try container.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
        budgetCategories = try container.decodeIfPresent([BudgetCategory].self, forKey: .budgetCategories) ?? []
        beautyFundTransactions = try container.decodeIfPresent([BeautyFundTransaction].self, forKey: .beautyFundTransactions) ?? []
        wishes = try container.decodeIfPresent([Wish].self, forKey: .wishes) ?? []
        shoppingItems = try container.decodeIfPresent([ShoppingItem].self, forKey: .shoppingItems) ?? []
        checklistCompletions = try container.decodeIfPresent([ChecklistCompletionEntry].self, forKey: .checklistCompletions) ?? []
        menstrualRecords = try container.decodeIfPresent([MenstrualRecord].self, forKey: .menstrualRecords) ?? []
        nourishmentRecipes = try container.decodeIfPresent([TutorialLink].self, forKey: .nourishmentRecipes) ?? []
        bodyConstitution = try container.decodeIfPresent(String.self, forKey: .bodyConstitution)
    }
}

extension BeautyDiaryState {
    static let seed = BeautyDiaryState(
        profile: UserProfileRecord(
            nickname: "精緻女孩",
            streakDays: 1,
            signature: "設定、成就、資源、數據管理",
            bodyFocus: "全身 / 局部訓練追蹤",
            skincareFocus: "混合肌保養與膚況記錄",
            themeName: "暖米白",
            notificationTime: "21:00"
        ),
        checklistItems: [
            ChecklistItem(id: UUID(), title: "護膚打卡", category: "變美"),
            ChecklistItem(id: UUID(), title: "頭髮保養", category: "變美"),
            ChecklistItem(id: UUID(), title: "美白計畫", category: "變美"),
            ChecklistItem(id: UUID(), title: "面部拉提/瑜珈", category: "變美"),
            ChecklistItem(id: UUID(), title: "運動打卡", category: "體態"),
            ChecklistItem(id: UUID(), title: "養生茶飲", category: "體態"),
            ChecklistItem(id: UUID(), title: "飲食記錄", category: "體態"),
            ChecklistItem(id: UUID(), title: "健康狀況", category: "體態"),
            ChecklistItem(id: UUID(), title: "閱讀打卡", category: "成長"),
            ChecklistItem(id: UUID(), title: "情緒記錄", category: "成長")
        ],
        routine: SkincareRoutine(
            steps: [
                RoutineStep(id: UUID(), period: .morning, name: "清潔", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "化妝水", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "精華液", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "眼霜", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "乳液/面霜", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .morning, name: "防曬", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "卸妝", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "清潔", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "化妝水", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "精華液", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "眼霜", productName: nil, isChecked: false),
                RoutineStep(id: UUID(), period: .evening, name: "乳液/面霜", productName: nil, isChecked: false)
            ]
        ),
        products: [],
        skinRecords: [],
        bodyMetricRecords: [],
        mealRecords: [],
        appointments: [],
        resourceItems: [],
        bookRecords: [],
        tutorialLinks: [
            TutorialLink(id: UUID(), title: "敏感肌晚間修護流程", url: "https://example.com/skincare-night"),
            TutorialLink(id: UUID(), title: "新手保養品疊擦順序", url: "https://example.com/product-order")
        ],
        punchRecords: [],
        achievements: [
            AchievementBadge(id: UUID(), title: "連續打卡王", detail: "連續打卡 7 天", unlocked: false),
            AchievementBadge(id: UUID(), title: "資源收藏家", detail: "新增 10 筆資源", unlocked: false),
            AchievementBadge(id: UUID(), title: "護膚紀錄員", detail: "完成 5 次膚況紀錄", unlocked: false)
        ],
        exportHistory: [],
        resourceFilter: .all,
        resourceImportHistory: [],
        pendingImportDraft: nil,
        resourceSyncQueue: [],
        hairCareRecords: [],
        bodySkinRecords: [],
        faceLiftActions: [],
        faceLiftPunches: [],
        faceLiftRatings: [],
        bodyProducts: [],
        hairProducts: [],
        hairAppointments: [],
        washFrequencyDays: 2,
        careFrequencyDays: 7,
        whiteningProductUsages: [],
        shadeTrackingRecords: [],
        beforeAfterPhotos: [],
        favoriteRecipes: [],
        faceShape: nil,
        savedHairstyles: [],
        makeupInspirations: [],
        exercisePunches: [],
        customExercises: [],
        targetWeight: nil,
        targetBodyFat: nil,
        trainingSchedule: [],
        symptomRecords: [],
        bodyAlbumPhotos: [],
        courses: [],
        knowledgeNotes: [],
        videoLearningRecords: [],
        selfAffirmations: [],
        visionBoardItems: [],
        gratitudeEntries: [],
        moodEntries: [],
        transactions: [],
        budgetCategories: [],
        beautyFundTransactions: [],
        wishes: [],
        shoppingItems: [],
        checklistCompletions: [],
        menstrualRecords: [],
        nourishmentRecipes: [],
        bodyConstitution: nil
    )
}

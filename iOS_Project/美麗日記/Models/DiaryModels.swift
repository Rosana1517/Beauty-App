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
    /// 美妝知識問答的對話紀錄，跨啟動保存（與 Keychain 的 sessionID 搭配）
    var notionQAMessages: [NotionQAChatMessage] = []

    enum CodingKeys: String, CodingKey {
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
        case notionQAMessages
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

}

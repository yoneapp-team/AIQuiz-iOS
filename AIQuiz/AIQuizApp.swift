import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {
    var authStateListener: AuthStateDidChangeListenerHandle?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        FirebaseApp.configure()
        
        Messaging.messaging().delegate = self
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        authStateListener = Auth.auth().addStateDidChangeListener { (auth, user) in
            if let token = fcmToken, let userId = user?.uid {
                let db = Firestore.firestore()
                db.collection("fcmTokens").document(userId).setData([
                    "token": token,
                    "updatedAt": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        print("Error saving FCM token to Firestore: \(error)")
                    } else {
                        print("FCM token successfully saved to Firestore for user: \(userId)")
                    }
                }
            } else {
                print("User ID or FCM token not available, FCM token not saved")
            }
        }
    }
}

@main
struct AIQuizApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

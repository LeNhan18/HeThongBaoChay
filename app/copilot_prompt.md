Bộ Prompt Kỹ Thuật cho AI Copilot (Xây Dựng App Flutter Báo Cháy)// Ghi chú: Bạn nên đưa các prompt này vào theo thứ tự, file-by-file,// vì các file sau sẽ phụ thuộc vào các file được tạo trước.PHẦN 1: DATA MODELS (Cấu trúc dữ liệu)File: lib/models/camera.dart// Prompt cho Copilot:
Create a Dart class `Camera`.
This class must be immutable (all fields should be final).
It needs the following fields:
- `id` (String)
- `name` (String)
- `status` (String)
- `thumbnailUrl` (String)

Also, create a `factory Camera.fromJson(Map<String, dynamic> json)` constructor. This factory constructor must parse a JSON map and return a new `Camera` instance.
File: lib/models/alert.dart// Prompt cho Copilot:
Create a Dart class `Alert`.
This class must be immutable (all fields final).
It needs the following fields:
- `id` (String)
- `cameraName` (String)
- `type` (String, e.g., 'fire' or 'smoke')
- `timestamp` (String)
- `snapshotUrl` (String)

Create a `factory Alert.fromJson(Map<String, dynamic> json)` constructor to parse data from a JSON map.
PHẦN 2: CẤU HÌNH & DỊCH VỤ (Configuration & Services)File: lib/constants.dart// Prompt cho Copilot:
Create a `constants.dart` file. This file must NOT import 'package:flutter/material.dart'.
It should define:
1.  A `const String` named `apiBaseUrl` set to '[http://10.0.2.2:8000](http://10.0.2.2:8000)'.
2.  Logic to read the global environment variables `__firebase_config` and `__app_id` using `String.fromEnvironment`.
3.  A final `FirebaseOptions` variable named `firebaseOptions` that is built using these config variables (apiKey, authDomain, projectId, etc.).
File: lib/services/mock_api_service.dart// Prompt cho Copilot:
Create a `MockApiService` class. This class will simulate our backend API.
It needs to:
1.  Import `lib/models/camera.dart` and `lib/models/alert.dart`.
2.  Contain a private final List `_mockCameras` holding 3 sample `Map<String, dynamic>` objects for cameras (keys: id, name, status, thumbnailUrl).
3.  Contain a private final List `_mockAlerts` holding 2 sample `Map<String, dynamic>` objects for alerts (keys: id, camera_name, type, timestamp, snapshot_url).
4.  Create a method `Future<List<Camera>> fetchCameras()`. This method must simulate a 1-second network delay using `Future.delayed` and return the `_mockCameras` list, converting each map to a `Camera` object using `Camera.fromJson`.
5.  Create a method `Future<List<Alert>> fetchAlerts()`. This method must simulate a 500ms delay and return the `_mockAlerts` list, converting maps to `Alert` objects.
File: lib/services/auth_service.dart// Prompt cho Copilot:
Create an `AuthService` class for managing Firebase Authentication.
It needs:
1.  Instances of `FirebaseAuth` and `FirebaseFirestore`.
2.  A stream `Stream<User?> get authStateChanges` that returns `_auth.authStateChanges()`.
3.  A method `Future<User?> signInWithEmail(String email, String password)`.
4.  A method `Future<User?> signUpWithEmail(String email, String password)`. When signing up, this method must also create a new document in Firestore at the path `artifacts/$appId/users/{userId}/profile` containing the user's email and a server timestamp. (Import `appId` from `constants.dart`).
5.  A method `Future<void> signOut()`.
File: lib/services/notification_service.dart// Prompt cho Copilot:
Create a `NotificationService` class for Firebase Cloud Messaging (FCM).
It needs:
1.  An `init()` method that requests user permission for notifications (`_fcm.requestPermission`).
2.  If permission is granted, it must get the FCM token (`_fcm.getToken()`).
3.  It needs a private helper method `_saveTokenToDatabase(String token)` that updates the user's profile in Firestore (at `artifacts/$appId/users/{userId}/profile`) with the new FCM token. This method must handle the case where the profile document might not exist yet (using `SetOptions(merge: true)` or checking for 'not-found' exception).
4.  Set up listeners for `onTokenRefresh`, `onMessage` (for foreground alerts), and `onMessageOpenedApp` (for background/terminated alerts).
PHẦN 3: CÁC MÀN HÌNH (Screens)File: lib/screens/live_view_screen.dart// Prompt cho Copilot:
Create a `StatelessWidget` named `LiveViewScreen`.
1.  It must accept a `Camera` object in its constructor.
2.  The `Scaffold` `appBar` should show the `camera.name`.
3.  The `body` should show the `camera.thumbnailUrl` (from the `camera` object) using an `Image.network` widget.
4.  Place the `Image.network` inside an `AspectRatio` widget with a 16/9 ratio.
5.  Add a `// TODO:` comment explaining that this `Image.network` will later be replaced by a real video streaming widget.
File: lib/screens/alerts_screen.dart// Prompt cho Copilot:
Create a `StatefulWidget` named `AlertsScreen`.
1.  It must use a `FutureBuilder<List<Alert>>` to call `MockApiService().fetchAlerts()`.
2.  Handle `ConnectionState.waiting` by showing a `CircularProgressIndicator`.
3.  Handle `snapshot.hasError` and `snapshot.data!.isEmpty` states.
4.  If data is available, show a `ListView.builder`.
5.  Each item in the list should be a `Card` inside a `ListTile`.
6.  The `ListTile` `leading` icon should be `Icons.local_fire_department` (if type is 'fire') or `Icons.smoke_free` (if type is 'smoke').
7.  The `ListTile` `title` should show 'PHÁT HIỆN LỬA!' or 'Phát Hiện Khói'.
8.  The `ListTile` `subtitle` should show the `cameraName` and the `timestamp`. Format the timestamp using the `intl` package (e.g., 'HH:mm, dd/MM/yyyy').
9.  When the `ListTile` is tapped, show an `AlertDialog` that displays the `alert.snapshotUrl` using an `Image.network`.
File: lib/screens/dashboard_screen.dart// Prompt cho Copilot:
Create a `StatefulWidget` named `DashboardScreen`.
1.  It must use a `FutureBuilder<List<Camera>>` to call `MockApiService().fetchCameras()`.
2.  Handle loading, error, and empty states.
3.  Render a `ListView.builder` for the list of `Camera` objects.
4.  Each item should be a `Card` with a `ListTile`. The `leading` icon should be `Icons.videocam` (green color) if `camera.status` is 'online', or `Icons.videocam_off` (grey color) if 'offline'.
5.  The `ListTile` `title` should show `camera.name` and `subtitle` should show `camera.status`.
6.  When the `ListTile` is tapped (`onTap`), it must navigate (`Navigator.push`) to the `LiveViewScreen`, passing the selected `camera` object.
File: lib/screens/auth_screen.dart// Prompt cho Copilot:
Create a `StatefulWidget` named `AuthScreen`.
1.  It must contain a `Form` (with a `GlobalKey<FormState>`) with two `TextFormField` (for email and password) and a submit `ElevatedButton`.
2.  Use `AuthService` from `lib/services/auth_service.dart`.
3.  Maintain a boolean state `_isLogin` to switch between 'Đăng Nhập' and 'Đăng Ký' modes.
4.  Maintain an `_isLoading` state to show a `CircularProgressIndicator` on the button when pressed.
5.  The submit button's `onPressed` must call a `_handleAuth` method.
6.  `_handleAuth` validates the form, sets loading to true, and calls `_authService.signInWithEmail` or `_authService.signUpWithEmail` based on the `_isLogin` state.
7.  Display any errors in a `Text` widget.
8.  Include a `TextButton` to toggle the `_isLogin` state.
File: lib/screens/main_home_page.dart// Prompt cho Copilot:
Create a `StatefulWidget` named `MainHomePage`. This widget will be the main UI after login.
1.  It must use a `Scaffold` with a `BottomNavigationBar`.
2.  The `BottomNavigationBar` must have two tabs: 
    - Tab 0: 'Giám Sát' (Icon: `Icons.video_camera_front`)
    - Tab 1: 'Cảnh Báo' (Icon: `Icons.notifications_active`)
3.  Maintain a state `_selectedIndex` to manage the active tab.
4.  The `body` of the `Scaffold` should display either `DashboardScreen` (from `dashboard_screen.dart`) or `AlertsScreen` (from `alerts_screen.dart`) based on `_selectedIndex`.
5.  The `appBar` should have a title that changes based on the selected tab ('Giám Sát Camera' or 'Lịch Sử Cảnh Báo').
6.  The `appBar` must have a logout `IconButton` that calls `AuthService().signOut()`.
File: lib/screens/wrapper.dart// Prompt cho Copilot:
Create a `StatelessWidget` named `Wrapper`. This widget's only job is to check the auth state.
1.  It must use a `StreamBuilder<User?>` to listen to `FirebaseAuth.instance.authStateChanges()`.
2.  If `snapshot.connectionState` is `waiting`, show a `CircularProgressIndicator`.
3.  If `snapshot.hasData` (user is logged in), return `MainHomePage` (from `main_home_page.dart`).
4.  If `snapshot.hasNoData` (user is logged out), return `AuthScreen` (from `auth_screen.dart`).
File: lib/main.dart// Prompt cho Copilot:
Create the main `main.dart` file.
1.  The `main()` function must be `async` and call `WidgetsFlutterBinding.ensureInitialized()`.
2.  It must initialize Firebase: `await Firebase.initializeApp(options: firebaseOptions)` (using `firebaseOptions` from `constants.dart`).
3.  It must initialize the notification service: `await NotificationService().init()` (using `NotificationService` from `services/notification_service.dart`).
4.  It must run the app `runApp(const FireAlertApp())`.
5.  The `FireAlertApp` (StatelessWidget) returns a `MaterialApp`.
6.  The `home` of the `MaterialApp` must be the `Wrapper` widget (from `screens/wrapper.dart`).
7.  Set the `debugShowCheckedModeBanner` to false.
8.  Define a `ThemeData` with `primarySwatch` set to `Colors.deepOrange`.

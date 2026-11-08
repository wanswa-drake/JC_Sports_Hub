<div align="center">

<p align="center">
  <img src="https://api.dicebear.com/7.x/adventurer/png?seed=JC&backgroundColor=1B5E20&size=256" width="110" height="110" alt="JC Sports Hub logo"/>
</p>

#  JC Sports Hub

### Sports Management & Community App for Makerere University **Jinja Campus**

> Predict matches · Place bets · Manage your wallet · Run Inter-Tribe tournaments · Join school teams

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Messaging-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-4CAF50?style=for-the-badge&logo=android&logoColor=white)]()

<br/>

**[ Features](#-features)** · **[ Tech Stack](#-tech-stack)** · **[ Project Structure](#-project-structure)** · **[ Getting Started](#-getting-started)** · **[ Data Model](#-firestore-data-model)** · **[ Configuration](#-configuration)** · **[ Contributing](#-contributing)**

</div>

---

##  About

**JC Sports Hub** is a complete sports-management and social platform built for **Makerere University Jinja Campus**. Students can follow match schedules, place bets with virtual credits, deposit and withdraw from a mobile-money wallet, register for university teams, and follow the campus **Inter-Tribe Games** tournament, all from one app.

The app is **admin-driven**: the admin publishes tournaments, schedules matches, sets odds, verifies team registrations, and manually confirms wallet deposits/withdrawals through a dedicated admin panel.

---

##  Features

###  Authentication & Profiles
- Email + password sign-up with **OTP email verification** (SMTP)
- Login, anonymous **guest browsing**, and a full **Forgot Password** flow (Firebase reset link)
- Profile with **avatar picker**, badges, wallet balance, and **Change Password** (re-authentication protected)

###  Matches & Bets
- **Upcoming / Live  / Completed** match tabs streaming live from Firestore
- Admin **Match Scheduler**  setup sport, teams, venue, odds (1.5×, 2.0×), date & notes
- **Place a Bet** against live odds with stake amounts from your wallet
- Vote on predictions, view potential winnings, and track settled results

###  Wallet (Mobile Money)
- **Deposit workflow**  get the admin's MoMo number + reference code, then the admin confirms receipt
- **Withdrawal workflow**  request a payout with a **confirmation dialog**, 12% charge applied, funds held in `pendingWithdrawal`
- Live balance & transaction history, atomic Firestore transactions (no drift between balance & request)

###  Tournaments (Inter-Tribe Games 2026)
- Dynamic user screen name, campus, season, status (UPCOMING / LIVE / DONE), reg dates, league dates & the Fixtures / Register / Standings / Fairness tabs all driven by Firestore
- Admin management  create, edit, **publish fixtures to Matches**, reseed, change status, delete
- Verified workbook fixtures, results entry, automatic **points table** recalculation
- Squad registration + fairness view for match-day scheduling

###  Teams
- Register as a player for **Football, Basketball, Volleyball, Athletics, Netball, Chess, and Dart**
- View verified rosters; **only the admin** can approve or remove pending players
- Guests are restricted from the Teams area

### Admin Panel
- Moderate **pending posts**, publish **announcements**, reply to **suggestions**
- **Manage Matches** schedule, edit odds, update live scores/status, delete
- **Wallet** confirm/reject deposits & withdrawals
- **Tournaments** one-tap Inter-Tribe 2026 creation, fixture seeding, publish-to-matches

---

##  Screenshots

> Add screenshots of your app here when ready (Android `adb exec-out screencap -p > screen.png` or an emulator snapshot).






<div align="center">

| Login | Matches | Tournament | Teams |
|:-----:|:-------:|:-----------:|:-----:|
| ![Login](screenshots/Login.png) | ![Matches](screenshots/matches.png) | ![Tournaments](screenshots/tournaments.png) | ![Teams](screenshots/teams.png) | 

| Wallet | Betting | Admin Panel | 
|:-----:|:-------:|:-----------:|
| ![Wallet](screenshots/wallet.png) | ![Betting](screenshots/betting.png) | ![Admin](screenshots/admin_pannel.png) |

| Profile | Home |
|:-------:|:-------:|
| ![Profile](screenshots/profile.png) | ![Home](screenshots/Home.png) |

</div>

---

##  Tech Stack

| Layer | Technologies |
|-------|--------------|
| **Framework** | Flutter · Dart |
| **Backend** | Firebase (Auth, Cloud Firestore, Cloud Storage, Cloud Messaging, App Check) |
| **State Management** | Provider |
| **Email (OTP)** | `mailer` package → Gmail/App password SMTP |
| **Other Packages** | `http` · `intl` · `uuid` · `image_picker` · `cached_network_image` · `cupertino_icons` |

**Key packages** (`pubspec.yaml`):

```
firebase_core        ^3.6.0    firebase_auth       ^5.3.1
cloud_firestore      ^5.4.4    firebase_messaging  ^15.1.3
firebase_storage     ^12.3.2   firebase_app_check  ^0.3.2+10
provider             ^6.1.2    http                ^1.6.0
mailer               ^6.1.2    intl                ^0.19.0
uuid                 ^4.5.1    image_picker        ^1.1.2
cached_network_image ^3.4.1    cupertino_icons     ^1.0.8
```

---

##  Project Structure

```
lib/
├── main.dart                        # App entry, routes, push notifications
├── firebase_options.dart            #  generated by flutterfire (gitignored)
├── data/
│   ├── inter_clan_fixture_seed.dart # Verified 2026 fixture workbook data
│   └── inter_clan_games_constants.dart
├── models/
│   ├── match_model.dart             # MatchModel · MatchStatus
│   ├── tournament_model.dart        # TournamentModel · fixtures · squads · points
│   ├── wallet_model.dart            # WalletTransactionModel
│   └── ...                          # posts, bets, notifications, etc.
├── screens/
│   ├── auth/                        # Splash, Onboarding, Signup, Login, OTP
│   ├── home/                        # Home feed, posts, comments, announcements
│   ├── matches/                     # Matches tabs + match detail + betting
│   ├── tournaments/                 # User tournament view + admin tools
│   ├── teams/                       # Team registration + admin verification
│   ├── wallet/                      # Deposit, Withdraw screens
│   ├── bets/                        # My bets / accountability
│   ├── profile/                     # Profile, avatar, change password
│   └── admin/                       # Admin panel + widgets (matches, wallet, etc.)
├── services/                        # Auth, OTP, Match, Betting, Wallet, Tournament, Post
└── utils/
    ├── constants.dart               # Colors, strings, sizes
    ├── secrets.dart                 #  SMTP creds (gitignored)
    └── tournament_result_parser.dart
```

---

##  Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>= 3.24`
- [Dart SDK](https://dart.dev/get-dart) `>= 3.0`
- A Firebase project ([console.firebase.google.com](https://console.firebase.google.com))
- Android Studio / Xcode toolchain for building to a device

### 1. Clone & install dependencies

```bash
git clone https://github.com/<your-username>/jc_sports_hub.git
cd jc_sports_hub
flutter pub get
```

### 2. Connect Firebase

```bash
# Install the FlutterFire CLI
dart pub global activate flutterfire_cli

# Generates lib/firebase_options.dart for your project
flutterfire configure --project=<your-firebase-project-id>
```

Or drop your existing `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)
into the respective platform folders and keep a hand-written `firebase_options.dart`.

### 3. Enable Firebase services

In the **Firebase Console → your project**:

| Service | What to do |
|---------|-----------|
| **Authentication → Sign-in method** | Enable **Email/Password** |
| **Authentication → Templates** | Enable **Password reset** & **Email verification** templates and keep the default action URL `https://<project-id>.firebaseapp.com/__/auth/action` |
| **Firestore Database** | Create the database, then deploy the security rules (Step 4) |
| **Cloud Storage** | Enable for profile images/media |
| **Cloud Messaging** | Enabled automatically for push notifications |

### 4. Deploy Firestore security rules

```bash
firebase login
firebase deploy --only firestore:rules
```

> The rules in [`firestore.rules`](firestore.rules) enforce ownership checks
> (`request.auth.uid == userId`), admin-only writes (`isAdmin == true`),
> guest blocking on team registration, and the wallet balance fields.

### 5. Configure secrets

Create `lib/utils/secrets.dart` (gitignored) with your SMTP/app-password for sending OTP emails:

```dart
/// SMTP credentials used by the mailer package to send OTP emails.
/// NEVER commit this file — it is gitignored.
class AppSecrets {
  static const String senderEmail = 'youraccount@gmail.com';
  static const String smtpServer = 'smtp://youraccount@gmail.com:your-app-password@smtp.gmail.com:587';
}
```

> **Gmail tip:** enable **2-Step Verification** and create an
> [App Password](https://support.google.com/accounts/answer/185833) the normal
> account password will not work with SMTP.

### 6. Run the app

```bash
flutter run
```

---

## 🗄 Firestore Data Model

```
users/{uid}                     # profile, isAdmin, isVerified, walletBalance, avatar…
otps/{resetId}                  # emailed 6-digit codes (open by design, 10-min expiry)
posts/{id}                      # feed posts & announcements
posts/{id}/comments/{id}        # post comments
matches/{id}                    # schedule: teams, odds, scores, pool, tournamentId…
bets/{id}                       # user bets placed against a match
transactions/{id}               # deposit/withdrawal requests (pending → confirmed/rejected)
tournaments/{id}                # name, campus, season, status, dates, tribes, games
tournaments/{id}/fixtures/{id}  # fixture: game, round, date, clans, timeSlot, result
tournaments/{id}/points/{id}    # live points table per tribe
tournaments/{id}/squads/{id}    # student squad registrations
tournaments/{id}/tribe_registrations/{id}
teams/{id}                      # team player registrations (isVerified by admin)
notifications/{id}              # per-user push notifications
suggestions/{id}                # user suggestions + admin replies
```
---

## ⚙️ Configuration

Almost everything in the app is configurable from two small files — no rebuild-hunting required.

### 🔑 `lib/utils/constants.dart` — app-wide constants

| Constant | Purpose |
|----------|---------|
| `AppStrings.adminEmail` | The **only** email granted admin access across the app |
| `AppStrings.adminMomoNumber` / `adminMomoName` | Mobile-money number shown to users when depositing |
| `AppStrings.bachelorDomain` | Restricts sign-up to official Makerere student webmails |
| `AppColors.primary` | Brand green (`#1B5E20`) used across the UI |

> ⚠️ Change `adminEmail` to your real webmail before going live, and replace
> `adminMomoNumber` with the MoMo line you actually collect deposits on.

### 🔐 `lib/utils/secrets.dart` — SMTP credentials (gitignored)

This file is **never committed**. Create it locally with your email app-password:

```dart
class AppSecrets {
  static const String senderEmail = 'youraccount@gmail.com';
  static const String smtpServer = 'smtp://youraccount@gmail.com:your-app-password@smtp.gmail.com:587';
}
```

### ☁️ Firebase Console settings

| Setting | Where | Requirement |
|---------|-------|-------------|
| **Email/Password** provider | Authentication → Sign-in method | Must be **enabled** |
| **Password reset** template | Authentication → Templates | Enable + keep default action URL `https://<project-id>.firebaseapp.com/__/auth/action` |
| **Email verification** template | Authentication → Templates | Enable so sign-up OTPs are deliverable |
| **Security rules** | Firestore → Rules | Deploy the repo's [`firestore.rules`](firestore.rules) |
| **App Check** | App Check | Enabled via Play Integrity (falls back to debug builds) |

---

## 🤝 Contributing

Contributions make the JC Sports Hub community stronger. Please follow these steps:

1. **Fork** the repository on GitHub.
2. **Create a feature branch:**

   ```bash
   git checkout -b feat/my-awesome-feature
   ```

3. **Commit your changes** with a clear message:

   ```bash
   git commit -am "feat: add live match commentary"
   ```

4. **Run the analyzer** before pushing — the project must stay at **0 errors / 0 warnings**:

   ```bash
   flutter analyze
   ```

5. **Push and open a Pull Request:**

   ```bash
   git push origin feat/my-awesome-feature
   ```

### ✅ Code style guidelines

- Keep screens in `lib/screens/<feature>/` and business logic in `lib/services/`.
- Pull data through **Firestore streams** (`StreamBuilder`) for live UI updates.
- Prefer `AppColors` / `AppSizes` constants over hard-coded values.
- Never commit `secrets.dart`, `google-services.json`, or `GoogleService-Info.plist` — they are gitignored.

---

## 📄 License

This project is developed for **Makerere University Jinja Campus** as an internal community project.



---

<div align="center">

**JC Sports Hub** — Built with Love by **[Drake Wanswa](https://github.com/)** · For the students of Makerere University Jinja Campus

[↑ Back to top](#-jc-sports-hub)

</div>

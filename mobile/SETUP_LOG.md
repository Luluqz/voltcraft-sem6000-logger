# Journal des actions — portage mobile Flutter

Ce fichier trace toutes les actions effectuées pour créer et faire
fonctionner la version mobile de `sem6000.py`, avec la raison de chacune.
Mis à jour au fur et à mesure.

## 2026-09-01

1. **Création du squelette Flutter** (`mobile/pubspec.yaml`, `mobile/lib/*.dart`, `mobile/README.md`)
   Pourquoi : porter la logique du script Python (protocole SEM6000, BLE,
   export CSV) vers une app mobile Android/iOS, à la demande de l'utilisateur.
   - `lib/protocol.dart` : port direct de `checksum`, `build_frame`,
     `build_auth_frame`, `build_measure_frame`, `parse_measurement` depuis
     `sem6000.py`.
   - `lib/ble/sem6000_ble.dart` : scan/connexion/auth/lecture BLE via le
     package `flutter_blue_plus` (équivalent mobile de `bleak`).
   - `lib/csv_logger.dart` : export CSV dans le dossier documents de l'app.
   - `lib/screens/scan_screen.dart`, `logger_screen.dart` : UI (scan →
     PIN → mesures live → start/stop → partage du CSV).

2. **Vérification de l'environnement** (`flutter --version`, recherche de
   SDK Android/JDK existants, `df`, connectivité réseau)
   Pourquoi : savoir ce qu'il fallait installer avant de pouvoir compiler
   l'app. Résultat : ni Flutter, ni Android SDK, ni JDK présents sur la
   machine.

3. **Clonage du SDK Flutter (branche `stable`, shallow clone)** vers
   `C:\Users\dumon\dev\flutter` via `git clone --depth 1`
   Pourquoi : obtenir la CLI `flutter`/`dart` nécessaire pour scaffolder et
   compiler le projet. Clone superficiel (`--depth 1`) pour limiter la
   taille téléchargée, l'historique complet n'étant pas utile ici.

4. **Installation de Microsoft OpenJDK 17** via
   `winget install --id Microsoft.OpenJDK.17 --silent`
   Pourquoi : la chaîne de build Android (Gradle) exige un JDK ; Microsoft
   OpenJDK est un choix standard, gratuit et silencieux à installer via
   winget, sans passer par l'installeur complet d'Android Studio.
   Résultat : installé avec succès dans
   `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot`.

5. **Téléchargement des Android command-line tools** (sans passer par
   Android Studio complet, pour rester scriptable et léger)
   - 1ère tentative avec l'URL `edgedl.me.gvt1.com` récupérée via une page
     web : **échec (404)** — cette URL est un lien de CDN dynamique non
     stable hors contexte navigateur.
   - Pourquoi la 2e tentative a fonctionné : relecture du HTML brut de la
     page `developer.android.com/studio` pour extraire l'URL canonique
     `dl.google.com/android/repository/commandlinetools-win-*.zip`, stable
     et documentée.
   - Téléchargement en cours vers
     `C:\Users\dumon\dev\android-sdk\cmdline-tools.zip`, puis extraction
     dans `cmdline-tools\latest`.

5bis. **Extraction confirmée** de `cmdline-tools.zip` vers
   `C:\Users\dumon\dev\android-sdk\cmdline-tools\latest\bin` (sdkmanager,
   avdmanager, etc. présents).

6. **Installation des composants Android SDK** via `sdkmanager` :
   `platform-tools`, `platforms;android-34`, `build-tools;34.0.0`, puis
   acceptation automatique des licences (`sdkmanager --licenses`, réponses
   "y" envoyées en pipe).
   Pourquoi : `platform-tools` fournit `adb` (déploiement/debug), la
   plateforme 34 et les build-tools sont nécessaires pour compiler un APK
   avec `flutter build apk`. `JAVA_HOME` pointé vers le JDK 17 installé à
   l'étape 4, requis par `sdkmanager` et Gradle.
   - 1er essai : échec silencieux — le prompt d'acceptation de licence
     Android SDK n'a reçu aucune réponse (le pipe "y" n'était fourni qu'à
     la commande `--licenses`, pas à la commande d'installation elle-même),
     donc rien n'a été installé (`platforms/`, `platform-tools/`,
     `build-tools/` absents après coup).
   - 2e essai : correction en envoyant "y" à chaque invite, pour les deux
     commandes — toujours bloqué sur le même prompt de licence malgré le
     pipe.
   - 3e essai (solution) : le pipe stdin PowerShell → .bat → process Java
     imbriqué ne transmettait pas correctement l'entrée interactive dans
     cet environnement (l'outil shell tourne en `-NonInteractive`, stdin
     rattaché à NUL). Contournement standard utilisé dans les pipelines CI
     Android : pré-écrire directement les fichiers de hash de licence
     acceptée dans `android-sdk\licenses\` (`android-sdk-license`,
     `android-sdk-preview-license`, avec les hash SHA1 publics et
     documentés du texte de licence officiel Google). Cela équivaut à
     accepter la licence, sans dépendre d'un prompt interactif défaillant.
     Relance de l'installation des packages ensuite, sans blocage.

7bis. **Confirmation** : `platform-tools/`, `platforms/android-34/`,
   `build-tools/34.0.0/` bien présents dans
   `C:\Users\dumon\dev\android-sdk` — installation réussie.

8. **Ajout du disclaimer légal dans l'app** (`scan_screen.dart`,
   `main.dart`, `README.md`)
   Pourquoi : suite à la question de l'utilisateur sur le droit de publier
   une app tierce compatible avec un appareil Voltcraft (marque déposée) —
   voir échange précédent. Ajout : bandeau visible en permanence sur
   l'écran de scan, dialogue "À propos" (icône ⓘ) avec le texte complet,
   nom de l'app changé de "SEM6000 Logger" à "Power Logger for SEM6000"
   pour éviter de laisser croire à une app officielle, et suggestion de
   description pour la fiche store dans le README.

9. **Premier `flutter doctor -v`** : Flutter/Dart OK, mais signale deux
   soucis : (a) il exige Android SDK 36 + Build Tools 28.0.3 (on n'avait
   installé que la 34), (b) licences encore incomplètes pour ces nouveaux
   composants.
   Correction : ajout des hash de licence supplémentaires connus
   (`android-sdk-preview-license` complété, `android-googletv-license`,
   `google-gdk-license`, `intel-android-extra-license`,
   `mips-android-sysimage-license`, `android-sdk-arm-dbt-license` — mêmes
   valeurs SHA1 publiques standard utilisées dans les CI Android), puis
   installation de `platforms;android-36` et `build-tools;28.0.3` via
   `sdkmanager`.

10. **2e `flutter doctor -v`** : l'exigence de version SDK est résolue
   (Android 36 détecté, plus d'erreur bloquante sur la version), mais il
   reste "Some Android licenses not accepted" malgré les fichiers de hash
   ajoutés à l'étape 9 (`sdkmanager --licenses` confirmait "2 of 7" encore
   refusées, correspondant à des licences liées aux nouveaux packages
   android-36/build-tools 28.0.3 non couvertes par les hash pré-écrits).

11. **Résolution finale des licences** : le pipe interactif via
   PowerShell (`"y`n..." | & sdkmanager.bat`) ne transmettait toujours pas
   correctement le flux stdin au process Java imbriqué. Contournement :
   lancer `sdkmanager --licenses` directement depuis Bash (git-bash) avec
   `yes | sdkmanager.bat --licenses`, qui gère correctement les pipes
   Unix vers un process Windows lancé depuis ce shell.
   Résultat : "All SDK package licenses accepted".

12. **3e `flutter doctor -v`** : Android toolchain entièrement vert
   ("All Android licenses accepted"). Seul point restant : Visual Studio
   absent, non pertinent (nécessaire uniquement pour cibler Windows
   desktop, pas Android/mobile) — ignoré volontairement.

13. **`flutter create --org com.sem6000 --project-name sem6000_app .`**
   dans `mobile/` : génère `android/`, `ios/`, `linux/`, `macos/`, `web/`,
   `windows/`, `test/widget_test.dart`. Confirmé : n'a pas écrasé les
   fichiers `lib/*.dart` ni `pubspec.yaml` déjà écrits — comportement
   attendu de `flutter create` sur un projet existant.
   Note : `test/widget_test.dart` est le test générique par défaut
   (référence l'app compteur template) — à remplacer plus tard, sans
   impact sur la compilation de l'APK.
   Warning observé (non bloquant pour Android) : "Building with plugins
   requires symlink support" — concerne les cibles desktop Windows (mode
   développeur Windows requis pour les symlinks), pas la cible Android.

14. **`flutter pub get`** : dépendances résolues avec succès (versions
   fixées légèrement en retrait des dernières disponibles, sans
   incompatibilité bloquante).

15. **1er `flutter build apk --debug`** : échec après 4m29s.
   Erreur : `share_plus:checkDebugAarMetadata` — les dépendances
   AndroidX de `share_plus` (fragment, window, lifecycle, core-ktx...)
   exigent un `compileSdk` ≥ 34, alors que le projet compilait contre
   android-33 (`compileSdk = flutter.compileSdkVersion` pointait vers une
   valeur par défaut trop basse dans cette version du plugin Gradle
   Flutter).
   Correction : `android/app/build.gradle.kts` — remplacement de
   `compileSdk = flutter.compileSdkVersion` par `compileSdk = 36` (la
   plateforme 36 est déjà installée sur la machine).
   Au passage, le build a lui-même installé automatiquement
   `build-tools;36.0.0`, `platforms;android-35`, `platforms;android-33`
   et `cmake;3.22.1` (dépendances transitives des plugins Gradle utilisés,
   licences déjà acceptées donc pas de blocage).

16. **2e `flutter build apk --debug`** : échoue toujours avec la même
   erreur, malgré `compileSdk = 36` dans notre `app/build.gradle.kts`.
   Cause réelle trouvée en inspectant le cache pub
   (`~/AppData/Local/Pub/Cache/hosted/pub.dev/share_plus-7.2.2/android/build.gradle`) :
   le plugin `share_plus` en version 7.2.2 code en dur
   `compileSdkVersion 33` dans son propre module Android, indépendamment
   de la config de l'app — c'est ce module-là qui échouait, pas le nôtre.
   Correction : montée de version dans `pubspec.yaml`,
   `share_plus: ^7.2.1` → `^11.0.0` (versions récentes du plugin
   compilent contre un SDK plus haut). Relance de `flutter pub get` puis
   nouveau build.

17. **3e `flutter build apk --debug` : SUCCÈS**
   `√ Built build\app\outputs\flutter-apk\app-debug.apk` (exit code 0).
   APK confirmé sur disque : `mobile\build\app\outputs\flutter-apk\app-debug.apk`
   (~180 Mo — taille normale pour un debug APK Flutter multi-ABI non
   optimisé ; un `flutter build apk --release --split-per-abi` donnerait
   des APK bien plus légers pour une vraie distribution).
   → Le portage Dart de `sem6000.py` (protocole, BLE, CSV, UI, disclaimer)
   compile et s'assemble correctement en application Android installable.
   Warning restant, non bloquant : "Your app uses plugins that apply
   Kotlin Gradle Plugin (KGP): share_plus" — avertissement de dépréciation
   Flutter, pas une erreur ; à surveiller lors d'une future montée de
   version Flutter.

18. **Installation de l'émulateur Android** (`emulator` +
   `system-images;android-34;google_apis;x86_64`) via `sdkmanager`
   Pourquoi : à la demande de l'utilisateur, pour visualiser l'UI de
   l'app dans un émulateur. Limite connue : le BLE ne fonctionnera pas
   depuis l'émulateur (pas d'accès Bluetooth matériel réel), donc ce test
   valide seulement l'interface, pas la communication avec la prise
   SEM6000 physique.

19. **Création de l'AVD `sem6000_avd`** (Android 14, google_apis,
   x86_64) via `avdmanager`. 1er essai avec `--device "pixel_5"` a
   échoué (erreur de chargement de `devices.xml`, bug/incompatibilité de
   cette combinaison cmdline-tools/profil) ; recréé avec `--force` sans
   profil matériel spécifique (profil par défaut) → succès.

20. **Lancement de l'émulateur** (`emulator.exe -avd sem6000_avd`, process
   détaché via `Start-Process`) : ouvre une fenêtre graphique visible sur
   l'écran de l'utilisateur.

21. **Boot émulateur confirmé** (`adb devices` → `emulator-5554 device`),
   **installation** de l'APK debug (`adb install -r ...` → Success) et
   **lancement** de l'app (`adb shell am start -n
   com.sem6000.sem6000_app/.MainActivity`) : succès, écran de scan avec
   bandeau disclaimer affiché dans l'émulateur.
   Limite rappelée : le scan BLE ne trouvera aucun appareil dans
   l'émulateur (pas de matériel Bluetooth réel) — validation UI
   uniquement, pas de test de communication avec la prise SEM6000.

22. **Extinction de l'émulateur** (`adb emu kill`), à la demande de
   l'utilisateur. Confirmé arrêté (`adb devices` ne liste plus rien).

23. **Correction de `test/widget_test.dart`** avant commit : le fichier
   généré par `flutter create` référençait encore l'app compteur template
   (`MyApp`, recherche du texte "0"/"1") qui n'existe pas dans notre code
   → remplacé par un test de fumée qui vérifie que l'écran de scan
   affiche bien le bandeau disclaimer.

(Section "Étapes suivantes prévues" retirée le 2026-09-04 : toutes les
étapes qu'elle listait — configuration ANDROID_HOME, installation SDK,
PATH, `flutter doctor`, `flutter create`, `flutter build apk` — avaient
déjà été réalisées et documentées ci-dessus aux points 6 à 17.)

## 2026-09-04 — Test sur appareil Android réel

1. **Réactivation de l'environnement de la session** (`ANDROID_HOME`,
   `ANDROID_SDK_ROOT`, ajout de `flutter\bin` et `platform-tools` au
   `PATH`) via variables d'environnement Bash, puis `flutter --version`
   pour confirmer.
   Pourquoi : ces variables ne persistent pas entre les sessions du
   terminal ; nécessaire pour pouvoir relancer `adb`/`flutter` après
   avoir rouvert une nouvelle session de travail.

2. **`adb devices -l`** : aucun appareil listé au premier essai, puis
   après demande à l'utilisateur de brancher son téléphone en USB et
   d'activer le débogage USB.
   Pourquoi : première étape de diagnostic avant de lancer
   `flutter run` sur un vrai appareil (test BLE réel, impossible en
   émulateur — voir points 18 et 21).

3. **`adb kill-server` / `adb start-server`** puis nouveau
   `adb devices -l` : toujours aucun appareil détecté côté ADB.
   Pourquoi : élimine l'hypothèse d'un démon adb bloqué avant de
   creuser côté pilote USB Windows.

4. **Diagnostic côté Windows** via `Get-PnpDevice` (PowerShell) :
   trouvé un périphérique nommé "Mobile" (`VID_12D1` — Huawei),
   `Status = Unknown`, `Problem = CM_PROB_PHANTOM`.
   Pourquoi : si `adb` ne voit rien, vérifier si le problème est côté
   ADB (autorisation refusée/pilote) ou côté connexion physique
   (câble, port). `CM_PROB_PHANTOM` indique que Windows garde le
   souvenir d'une connexion USB passée mais que l'appareil n'est pas
   actuellement branché/reconnu — donc le problème est en amont d'ADB.
   → Utilisateur invité à vérifier le câble (data, pas charge seule),
   le déverrouillage de l'écran (nécessaire pour voir le popup
   d'autorisation de débogage USB), et le mode de connexion USB choisi
   sur le téléphone (Transfert de fichiers/MTP plutôt que Charge
   seule).

5. **Résolu** : après vérification côté utilisateur (câble/écran/mode
   USB), `adb devices -l` détecte l'appareil : `b971b523` — OnePlus 6
   (`ONEPLUS_A6003`), état `device` (autorisé). Passage à
   `flutter run` sur cet appareil pour un test réel avec BLE matériel.

6. **Bug réel #1 trouvé et corrigé : permissions Bluetooth manquantes
   dans `android/app/src/main/AndroidManifest.xml`**.
   Symptôme : l'app se lance mais crashe dès le premier scan avec
   `PlatformException(androidException, java.lang.SecurityException:
   Need BLUETOOTH permission...)`, malgré des demandes de permission
   runtime correctes côté Dart (`scan_screen.dart` utilise déjà
   `permission_handler` pour `bluetoothScan`/`bluetoothConnect`/
   `locationWhenInUse`).
   Cause : ces demandes runtime sont sans effet si les permissions ne
   sont pas déclarées dans le manifest — jamais détecté avant car les
   tests précédents (émulateur, étape 21) ne validaient que l'UI, pas
   un vrai scan BLE.
   Correction : ajout de `BLUETOOTH`/`BLUETOOTH_ADMIN`/
   `ACCESS_FINE_LOCATION` (maxSdkVersion 30, pour Android ≤11) et
   `BLUETOOTH_SCAN` (avec `neverForLocation`)/`BLUETOOTH_CONNECT`
   (Android 12+), plus `<uses-feature android:name=
   "android.hardware.bluetooth_le" android:required="true">`, suivant
   la doc officielle du plugin `flutter_blue_plus`.
   Rebuild complet nécessaire (changement de manifest natif, pas
   rechargeable à chaud) : `flutter run` relancé après `pkill -f
   "flutter run"` + `adb shell am force-stop` pour libérer proprement
   la session précédente.
   Résultat : le scan fonctionne, l'appareil réel `Voltcraft
   B3:00:00:00:87:07` est bien détecté.

7. **Bug réel #2 trouvé et corrigé : comparaison d'UUID de
   caractéristiques toujours fausse dans `lib/ble/sem6000_ble.dart`**.
   Symptôme : après le scan, la connexion à l'appareil réel échoue
   systématiquement avec `StateError("SEM6000 characteristics not
   found (device may not be a SEM6000, or PIN screen not paired)")`,
   alors que l'appareil est bien un SEM6000 reconnu.
   Cause trouvée en inspectant le code source du plugin
   `flutter_blue_plus_platform_interface` (`lib/src/guid.dart`) dans
   le cache pub : `Guid.toString()` renvoie la forme *courte* d'un
   UUID standard 16 bits (ex. `"fff3"`), pas la forme 128 bits complète
   (`"0000fff3-0000-1000-8000-00805f9b34fb"`) utilisée dans
   `protocol.dart` (`uuidWrite`, `uuidNotify`). La comparaison
   `char.uuid.toString().toLowerCase() == uuidWrite` échouait donc
   toujours, silencieusement, quel que soit l'appareil.
   Correction : `char.uuid.toString()` → `char.uuid.str128` (getter du
   plugin qui renvoie explicitement la forme 128 bits) dans
   `sem6000_ble.dart`.
   Test en cours après ce correctif (hot reload suffisant, changement
   Dart pur, pas de rebuild natif nécessaire).

8. **Bug réel #3 trouvé et corrigé : connexion GATT non nettoyée en
   cas d'échec, provoquant `FlutterBluePlusException` code Android 133
   ("GATT error") au réessai**.
   Symptôme : après le correctif du point 7, nouvelle tentative de
   connexion → erreur générique Android 133, un code d'erreur GATT
   fourre-tout connu pour survenir quand une connexion précédente est
   restée à moitié ouverte côté pile Bluetooth Android.
   Cause : dans `sem6000_ble.dart`, `connect()` appelait déjà
   `device.connect()` (connexion GATT établie) *avant* de vérifier la
   présence des caractéristiques ; si elles manquaient (cas du bug #2,
   juste avant le fix), une `StateError` était levée sans jamais
   appeler `device.disconnect()`. Côté UI, `logger_screen.dart`
   (`_connect()`) attrapait l'erreur pour l'afficher mais ne
   déconnectait pas non plus. Résultat : une connexion GATT fantôme
   restait ouverte sur l'appareil, perturbant les tentatives
   suivantes.
   Correction : `sem6000_ble.dart` déconnecte (`await
   device.disconnect()`) avant de lever la `StateError` si les
   caractéristiques ne sont pas trouvées ; `logger_screen.dart`
   déconnecte aussi (`await _ble.disconnect()`) dans le bloc `catch`
   de `_connect()`, pour ne jamais laisser une connexion à moitié
   établie après un échec, quelle qu'en soit la cause.
   Remédiation immédiate en plus du fix : `adb shell am force-stop`
   sur l'app pour forcer la fermeture du client GATT existant côté
   process avant de relancer (le simple hot-reload ne suffit pas à
   nettoyer un état de connexion déjà corrompu côté OS).

   → Ces trois correctifs confirmés fonctionnels sur l'appareil réel
   (scan, connexion, authentification PIN, mesures live). Commit
   `7ca3aac`.

9. **Test export CSV + partage** : validé de bout en bout sur
   l'appareil réel (enregistrement → arrêt → export → partage via
   WhatsApp, instantané). Une confusion initiale sur Gmail (un seul
   mail visible dans "Envoyés" après deux partages) a été
   diagnostiquée comme un simple regroupement en fil de discussion
   Gmail (sujet vide + même destinataire) après vérification, via
   `adb shell run-as com.sem6000.sem6000_app` (build debug), que
   6 fichiers CSV distincts avec des données réelles (2 à 26 lignes)
   existaient bien dans `app_flutter/` — donc pas de bug côté app.
   Au passage, confirmation que `getApplicationDocumentsDirectory()`
   pointe vers le stockage interne privé de l'app
   (`app_flutter/`), invisible sans `adb`/root pour un utilisateur
   normal.

10. **Nouvelle fonctionnalité : historique des enregistrements CSV**
    (`lib/screens/history_screen.dart`), à la demande de
    l'utilisateur suite au test précédent.
    Pourquoi : les CSV générés à chaque session n'étaient accessibles
    que via le bouton "Exporter" de la session en cours ; les
    enregistrements précédents restaient invisibles et non
    supprimables depuis l'app.
    - `CsvLogger.listFiles()` (`lib/csv_logger.dart`) : liste les CSV
      du dossier documents de l'app, triés du plus récent au plus
      ancien.
    - `CsvLogger.deleteFile()` : suppression d'un fichier.
    - Écran `HistoryScreen` : liste avec date/heure, taille, bouton
      partager (réutilise `share_plus`) et bouton supprimer (avec
      confirmation).
    - Accès ajouté dans `scan_screen.dart` (icône historique dans
      l'AppBar, à côté du bouton "À propos"), car cet écran est
      atteignable sans connexion active à un appareil.
    Choix technique : le tri et l'affichage de la date utilisent la
    date de modification du fichier (`FileStat.modified` via
    `file.stat()`/`file.lastModified()`), pas un parsing du nom de
    fichier — pour rester correct indépendamment du format de nom
    choisi (voir point 11 juste après, qui change justement ce
    format).
    Testé et confirmé fonctionnel par l'utilisateur (liste, partage
    d'un ancien fichier, suppression).

11. **Format du nom de fichier CSV changé en ordre français
    (jj-mm-aaaa)**, à la demande de l'utilisateur.
    Avant : `sem6000_<ISO8601 avec ':' remplacés par '-'>.csv`
    (ex. `sem6000_2026-09-04T10-34-00.338146.csv`), lisible mais en
    ordre année-mois-jour anglosaxon, visible tel quel par le
    destinataire lors d'un partage (email, WhatsApp...).
    Après : `sem6000_jj-mm-aaaa_hh-mm-ss.csv`
    (ex. `sem6000_04-09-2026_10-34-00.csv`).
    Point d'attention traité : le tri de `listFiles()` reposait
    jusqu'ici sur l'ordre lexicographique du nom de fichier
    (valable seulement parce que le format ISO trie
    naturellement par date) ; ce n'est plus vrai avec l'ordre
    jour-mois-année. Corrigé en triant par date de modification du
    fichier (`file.lastModified()`) plutôt que par nom — cf. point 10,
    ce choix avait été anticipé.
    Rebuild + test sur l'appareil réel demandé après ce changement.

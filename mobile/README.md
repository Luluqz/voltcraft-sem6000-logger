# sem6000_app — version mobile (Flutter)

Portage du script `sem6000.py` en application mobile Android/iOS. Même
protocole BLE (checksum, frames, parsing — voir `lib/protocol.dart`), mais
connexion, scan et logging pilotés depuis l'app au lieu de la ligne de
commande.

## Ce qui est fait

- `lib/protocol.dart` — port direct des fonctions Python (`checksum`,
  `build_frame`, `build_auth_frame`, `build_measure_frame`, `parse_measurement`).
- `lib/ble/sem6000_ble.dart` — connexion BLE, authentification PIN, lecture
  périodique (via `flutter_blue_plus`).
- `lib/csv_logger.dart` — écriture CSV dans le dossier documents de l'app.
- `lib/screens/scan_screen.dart` — scan et sélection de l'appareil.
- `lib/screens/logger_screen.dart` — saisie du PIN, connexion, affichage
  live des mesures, start/stop logging, export/partage du CSV.

## Ce qui manque (Flutter SDK non installé dans cet environnement)

Le dossier ne contient que le code Dart : il manque les projets natifs
`android/` et `ios/` que `flutter create` génère normalement. À faire une
fois Flutter installé sur votre machine :

```bash
cd mobile
flutter create --org com.sem6000 .   # ajoute android/, ios/, etc. sans écraser lib/ ni pubspec.yaml existants
flutter pub get
flutter run                          # avec un appareil/émulateur connecté
```

## Permissions à vérifier après `flutter create`

**Android** (`android/app/src/main/AndroidManifest.xml`) — ajouter avant
`<application>` :

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

**iOS** (`ios/Runner/Info.plist`) — ajouter :

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Cette app utilise le Bluetooth pour lire les mesures de la prise SEM6000.</string>
```

## Mentions légales / disclaimer

Application non officielle, indépendante, non affiliée à Voltcraft ni à
Conrad Electronic. "Voltcraft" et "SEM6000" sont des marques de leurs
propriétaires respectifs, mentionnées uniquement à titre descriptif pour
indiquer la compatibilité de l'application. Le disclaimer est affiché dans
l'app (bandeau sur l'écran de scan + dialogue "À propos", icône ⓘ dans la
barre d'app).

Suggestion de description pour la fiche App Store / Play Store :

> Enregistreur de consommation électrique compatible avec la prise
> connectée Voltcraft SEM6000 (Bluetooth LE). Application indépendante,
> non affiliée à Voltcraft/Conrad Electronic.

## Limites connues

- Pas de reconnexion automatique si le lien BLE tombe pendant le logging.
- Pas de persistance de l'historique en base (juste le fichier CSV courant).
- Sur iOS, le scan/logging en arrière-plan prolongé est plus contraint
  qu'Android — à tester en conditions réelles avant usage longue durée.

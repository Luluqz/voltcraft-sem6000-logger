# Power Logger for SEM6000 — version mobile (Flutter)

Application mobile Flutter qui reproduit `sem6000.py` (le script Python à la
racine du dépôt) : elle se connecte en Bluetooth Low Energy à une prise
connectée Voltcraft SEM6000, affiche les mesures en direct et permet
d'enregistrer une session dans un fichier CSV.

Testée et fonctionnelle sur Android (OnePlus 6, Android 11) contre une prise
SEM6000 physique — voir `SETUP_LOG.md` pour le détail de la mise en place et
des bugs corrigés. iOS n'a pas été testé sur appareil réel.

## Fonctionnalités

- Scan BLE et détection des appareils SEM6000/Voltcraft à proximité
- Connexion et authentification par PIN (4 chiffres)
- Mesures en direct (puissance, tension, courant, fréquence, état
  marche/arrêt), rafraîchies chaque seconde dès la connexion
- Graphique de puissance (W) sur toute la durée de la session
- Enregistrement optionnel dans un fichier CSV, à démarrer/arrêter à la
  demande indépendamment de l'affichage live
- Export/partage du CSV (email, messagerie, Drive, etc.)
- Historique des enregistrements précédents : liste, partage, suppression
- Bandeau et dialogue "À propos" rappelant qu'il s'agit d'une app non
  officielle

## Prérequis

- Flutter SDK (stable)
- Android SDK (platform 34+, build-tools) pour la cible Android
- Un appareil Android avec Bluetooth activé (le BLE ne fonctionne pas dans
  un émulateur — utile uniquement pour visualiser l'UI)
- Une prise Voltcraft SEM6000

## Lancer l'app

```bash
cd mobile
flutter pub get
flutter devices        # repérer l'ID de l'appareil connecté en USB
flutter run -d <device_id>
```

Build d'un APK debug :

```bash
flutter build apk --debug
```

## Structure du code

- `lib/protocol.dart` — port direct du protocole SEM6000 (checksum, frames,
  parsing) depuis `sem6000.py`
- `lib/ble/sem6000_ble.dart` — connexion, authentification PIN, lecture
  périodique via `flutter_blue_plus`
- `lib/csv_logger.dart` — création, listing et suppression des fichiers CSV
  (stockage privé de l'app)
- `lib/screens/scan_screen.dart` — scan et sélection de l'appareil
- `lib/screens/logger_screen.dart` — connexion, mesures live, graphique,
  démarrage/arrêt de l'enregistrement, export
- `lib/screens/history_screen.dart` — liste des enregistrements CSV passés

## Permissions Android

Déjà déclarées dans `android/app/src/main/AndroidManifest.xml` :
`BLUETOOTH`/`BLUETOOTH_ADMIN`/`ACCESS_FINE_LOCATION` (Android ≤ 11) et
`BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` (Android 12+), plus la déclaration de la
fonctionnalité `bluetooth_le`. Rien à ajouter manuellement.

## iOS

Projet natif `ios/` généré mais non testé sur appareil réel. Avant de
pouvoir scanner en Bluetooth sur iOS, ajouter dans `ios/Runner/Info.plist` :

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Cette app utilise le Bluetooth pour lire les mesures de la prise SEM6000.</string>
```

## Où sont stockés les CSV ?

Dans le stockage privé de l'app (non visible depuis un gestionnaire de
fichiers classique, ni depuis un PC connecté en USB sans root/débogage).
Utiliser le bouton "Exporter" (écran de mesure ou historique) pour partager
un fichier ou l'enregistrer ailleurs (Drive, Fichiers, email...).

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

- Pas de reconnexion automatique si le lien BLE tombe pendant une session.
- iOS non testé sur appareil réel.
- Testée avec une seule prise SEM6000 physique ; d'autres versions
  matérielles du SEM6000 peuvent renvoyer un format de trame légèrement
  différent (voir le commentaire dans `parseMeasurement`, `protocol.dart`).
- Pas de vue "toutes les mesures détaillées" au-delà du graphique de
  puissance (tension/courant/fréquence ne sont affichés qu'en instantané,
  pas graphés dans le temps).

## Protocole

Basé sur la documentation communautaire reverse-engineered :
[Heckie75/voltcraft-sem-6000](https://github.com/Heckie75/voltcraft-sem-6000/blob/master/API.md)

Journal détaillé de la mise en place de l'environnement et des bugs
rencontrés/corrigés lors des tests sur appareil réel : voir `SETUP_LOG.md`.

# Angličtina – verze 1

Foto slovníček (paměťový palác), zkoušení nahlas a opakování v rozestupech.

## Co umí verze 1

- **Moje místnosti:** vyfotíš místnost a AI k věcem na fotce napíše anglické názvy, výslovnost a větu.
- **Detail fotky:** ťukni na štítek a uslyšíš výslovnost. Štítek můžeš táhnout, opravit nebo smazat. Dlouhým podržením na fotce přidáš vlastní slovo. Ikonou oka skryješ názvy a zkoušíš se.
- **Zkoušení:** na fotce bliká místo, ty řekneš anglicky, co tam je, a appka tě poslouchá. Pak ohodnotíš, jak to šlo.
- **Opakování v rozestupech:** co jde, přijde za delší dobu, co zapomeneš, přijde za 10 minut. Nejvýš 15 nových slov denně.
- **Dnes:** kolik slov je na řadě, série dnů a kolik slov už umíš dlouhodobě.

## První spuštění na Macu

1. Rozbal ZIP a otevři Terminál ve složce `anglictina-app`.
2. Nahraj kód na GitHub (repozitář je zatím prázdný):
   ```
   git remote add origin https://github.com/ludek-vymetal/anglictina-app.git
   git push -u origin main
   ```
3. Nech Flutter vytvořit složky pro iPhone a Android:
   ```
   flutter create --org cz.spal --project-name anglictina_app --platforms ios,android .
   flutter pub get
   ```
4. Otevři `ios/Runner/Info.plist` a před poslední `</dict>` vlož:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Fotíš místnosti, ze kterých se učíš slovíčka.</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Můžeš vybrat fotku místnosti z galerie.</string>
   <key>NSMicrophoneUsageDescription</key>
   <string>Odpovídáš nahlas anglicky.</string>
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>Appka pozná, co jsi řekl anglicky.</string>
   ```
5. Pro Android otevři `android/app/src/main/AndroidManifest.xml`. Nad `<application` vlož:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
   <queries>
       <intent>
           <action android:name="android.speech.RecognitionService" />
       </intent>
   </queries>
   ```
6. API klíč si vytvoř na https://console.anthropic.com (sekce API Keys). Platí se zvlášť podle použití, jedna fotka stojí řádově jednotky Kč.
7. Připoj iPhone kabelem a spusť:
   ```
   flutter run --dart-define=ANTHROPIC_API_KEY=sem-vloz-svuj-klic
   ```
8. Ulož změny na GitHub:
   ```
   git add .
   git commit -m "Složky pro iPhone a Android"
   git push
   ```

## Důležité

- API klíč nikdy nedávej do kódu ani na GitHub. Předává se jen při spuštění (krok 7).
- Než appku dostane někdo další, přesune se volání AI na malý server.
- Všechna data jsou jen v telefonu (SQLite).

## Struktura

| Soubor | Co dělá |
| --- | --- |
| `lib/main.dart` | Start appky, barvy |
| `lib/models.dart` | Místnost a slovo |
| `lib/db.dart` | Databáze v telefonu, fronta k opakování, série dnů |
| `lib/srs.dart` | Algoritmus opakování |
| `lib/ai.dart` | Claude API: pozná věci na fotce |
| `lib/voice.dart` | Výslovnost (TTS) a poslech tvé odpovědi |
| `lib/screens/home_screen.dart` | Obrazovka Dnes |
| `lib/screens/rooms_screen.dart` | Seznam místností, focení |
| `lib/screens/photo_screen.dart` | Fotka se štítky |
| `lib/screens/review_screen.dart` | Zkoušení nahlas |

## Další verze

2. Režim do auta: fráze hlasem a procházka palácem
3. Hlasový rozhovor s AI lektorem
4. Vstupní test, testy každé 2 týdny, obrazovka pokroku
5. Pomůcky na těžká slova, večerní opakování, upozornění, algoritmus FSRS

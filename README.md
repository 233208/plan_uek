# Plan Zajęć UEK (Nieoficjalny Klient Mobilny)

Projekt stanowi natywną aplikację mobilną zrealizowaną w technologii Flutter, służącą jako alternatywny interfejs dostępowy do systemu harmonogramowania zajęć Uniwersytetu Ekonomicznego w Krakowie (UEK). Aplikacja eliminuje konieczność interakcji z przeglądarkowym interfejsem użytkownika, oferując bezpośredni dostęp do danych poprzez analizę struktury DOM serwisu uczelnianego.

## Specyfikacja Techniczna

### 1. Architektura i Stos Technologiczny
Aplikacja została zaimplementowana w języku **Dart** przy użyciu frameworka **Flutter** (SDK >=3.2.3). Architektura projektu opiera się na wzorcu `Provider` do zarządzania stanem aplikacji oraz separacji warstwy logiki biznesowej od warstwy prezentacji.

Kluczowe biblioteki:
* **Klient HTTP:** `http` – obsługa żądań sieciowych z niestandardową implementacją `HttpOverrides`.
* **Parser HTML:** `html` – analiza struktury DOM i ekstrakcja danych o zajęciach.
* **Bezpieczeństwo danych:** `flutter_secure_storage` – szyfrowany magazyn poświadczeń (KeyStore na Androidzie).
* **Interfejs:** `table_calendar` – obsługa widoków kalendarzowych.

### 2. Warstwa Sieciowa i Bezpieczeństwo (SSL Pinning)
Ze względu na specyfikę infrastruktury docelowej oraz konieczność zapewnienia integralności połączenia, w aplikacji zaimplementowano rygorystyczny mechanizm **Certificate Pinningu**.

* **Weryfikacja Odcisku Certyfikatu:** Klasa `UEKHttpOverrides` nadpisuje domyślny `HttpClient`. Aplikacja nie polega na systemowym magazynie zaufanych certyfikatów (Trusted Roots), lecz weryfikuje certyfikat serwera bezpośrednio poprzez porównanie jego skrótu SHA-256 ze statyczną białą listą (`_allowedHashes`).
* **Ochrona przed atakami MITM:** Mechanizm ten skutecznie uniemożliwia ataki typu *Man-in-the-Middle*, odrzucając każde połączenie, które nie legitymuje się oczekiwanym podpisem kryptograficznym, nawet jeśli certyfikat zostałby wystawiony przez zaufany urząd certyfikacji.
* **Weryfikacja Hosta:** Zaimplementowano blokadę połączeń do domen innych niż `*.uek.krakow.pl`.

### 3. Przetwarzanie Danych (Scraping)
Aplikacja działa w modelu *client-side scraping*. Nie wykorzystuje publicznego API (z powodu jego braku), lecz symuluje zapytania przeglądarki:
1.  **Uwierzytelnianie:** Wykorzystanie nagłówka `Authorization: Basic` (Base64) do autoryzacji sesji.
2.  **Ekstrakcja Danych:** Pobieranie surowego kodu HTML z endpointu `/index.php` i parsowanie tabel wynikowych w celu budowy obiektów `ClassItem`.
3.  **Wykrywanie Zmian:** Algorytmiczna analiza atrybutów CSS (np. klasa `.czerwony`) w celu identyfikacji zajęć odwołanych lub przeniesionych.

### 4. Przechowywanie Danych
Dane logowania (login, hasło) przechowywane są **wyłącznie lokalnie** na urządzeniu użytkownika w bezpiecznym kontenerze (`FlutterSecureStorage`). Aplikacja nie przesyła poświadczeń do żadnych zewnętrznych serwerów analitycznych ani pośredniczących.

---

## Zrzeczenie się Odpowiedzialności (Disclaimer)

Projekt ma charakter **nieoficjalny** i jest inicjatywą typu Open Source.

1.  **Brak Afiliacji:** Aplikacja nie jest autoryzowana, wspierana, ani w żaden sposób powiązana z Uniwersytetem Ekonomicznym w Krakowie (UEK).
2.  **Gwarancja:** Oprogramowanie jest dostarczane na zasadzie "TAKIM, JAKIM JEST" (*AS IS*), bez jakiejkolwiek gwarancji, wyraźnej lub dorozumianej. Autor nie ponosi odpowiedzialności za błędy w wyświetlaniu harmonogramu, przerwy w działaniu wynikające ze zmian w strukturze strony uczelnianej, ani za ewentualne konsekwencje wynikające z polegania wyłącznie na danych prezentowanych w aplikacji.
3.  **Zgodność z Regulaminem:** Użytkownik końcowy zobowiązany jest do korzystania z aplikacji w sposób zgodny z obowiązującym prawem oraz wewnętrznymi regulaminami korzystania z infrastruktury informatycznej UEK.

---

## Kompilacja i Uruchomienie

Wymagane środowisko Flutter SDK.

```bash
# Pobranie zależności
flutter pub get

# Uruchomienie w trybie debug
flutter run

# Budowanie wersji release (APK)
flutter build apk --release

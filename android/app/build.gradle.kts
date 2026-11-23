import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de envio para o Google Play (upload key). Fica FORA do repositório:
// android/key.properties aponta para o arquivo .jks (ambos no .gitignore).
// Sem a chave a versão release sai com a chave de depuração, que o Play recusa.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.appcoleta"
    // Android 16 (API 36): o Play Protect bloqueia a instalação de apps com
    // targetSdk abaixo do exigido pela versão do sistema ("app criado para
    // uma versão mais antiga do Android"). compileSdk acompanha o targetSdk.
    compileSdk = 36
    // Versão exigida pelos plugins (sqflite_android, wakelock_plus e outros);
    // maior que a default do Flutter e retrocompatível.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Identificação única no Google Play. Depois da primeira publicação
        // não pode mais mudar ("com.example" é recusado pela loja).
        applicationId = "br.com.institutoalveslima.coleta"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        // Fixado em 36 em vez de flutter.targetSdkVersion (que nesta versão
        // do Flutter ainda é 35) para não ser bloqueado no Android 16.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("upload") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("upload")
            else
                signingConfigs.getByName("debug")   // só para teste local
        }
    }
}

flutter {
    source = "../.."
}

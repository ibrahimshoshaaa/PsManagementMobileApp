import os

open('android/settings.gradle','w').write(
'pluginManagement {\n'
'    def flutterSdkPath = {\n'
'        def properties = new Properties()\n'
'        file("local.properties").withInputStream { properties.load(it) }\n'
'        def flutterSdkPath = properties.getProperty("flutter.sdk")\n'
'        assert flutterSdkPath != null\n'
'        return flutterSdkPath\n'
'    }()\n'
'    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")\n'
'    repositories { google(); mavenCentral(); gradlePluginPortal() }\n'
'}\n'
'plugins {\n'
'    id "dev.flutter.flutter-plugin-loader" version "1.0.0"\n'
'    id "com.android.application" version "8.1.0" apply false\n'
'    id "org.jetbrains.kotlin.android" version "1.9.25" apply false\n'
'    id "com.google.gms.google-services" version "4.4.0" apply false\n'
'}\n'
'include ":app"\n'
)

open('android/app/build.gradle','w').write(
'plugins {\n'
'    id "com.android.application"\n'
'    id "kotlin-android"\n'
'    id "dev.flutter.flutter-gradle-plugin"\n'
'    id "com.google.gms.google-services"\n'
'}\n'
'android {\n'
'    namespace = "com.shosha.alharifa"\n'
'    compileSdk = 34\n'
'    compileOptions {\n'
'        sourceCompatibility = JavaVersion.VERSION_1_8\n'
'        targetCompatibility = JavaVersion.VERSION_1_8\n'
'    }\n'
'    kotlinOptions { jvmTarget = "1.8" }\n'
'    defaultConfig {\n'
'        applicationId = "com.shosha.alharifa"\n'
'        minSdk = 21\n'
'        targetSdk = 34\n'
'        versionCode = 6\n'
'        versionName = "2.1.0"\n'
'    }\n'
'    buildTypes {\n'
'        release {\n'
'            signingConfig = signingConfigs.debug\n'
'            minifyEnabled = false\n'
'            shrinkResources = false\n'
'        }\n'
'    }\n'
'}\n'
'flutter { source = "../.." }\n'
'dependencies {\n'
'    implementation platform("com.google.firebase:firebase-bom:33.1.0")\n'
'    implementation "com.google.firebase:firebase-analytics"\n'
'    implementation "com.google.firebase:firebase-database"\n'
'}\n'
)

open('android/build.gradle','w').write(
'allprojects {\n'
'    repositories { google(); mavenCentral() }\n'
'}\n'
'rootProject.buildDir = "../build"\n'
'subprojects { project.buildDir = "${rootProject.buildDir}/${project.name}" }\n'
'subprojects { project.evaluationDependsOn(":app") }\n'
'tasks.register("clean", Delete) { delete rootProject.buildDir }\n'
)

os.makedirs('android/app/src/main/res/values', exist_ok=True)
open('android/app/src/main/res/values/styles.xml','w').write(
'<?xml version="1.0" encoding="utf-8"?>\n'
'<resources>\n'
'    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">\n'
'        <item name="android:windowBackground">@android:color/black</item>\n'
'    </style>\n'
'    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">\n'
'        <item name="android:windowBackground">@android:color/black</item>\n'
'    </style>\n'
'</resources>\n'
)

open('android/gradle.properties','w').write(
'android.useAndroidX=true\n'
'android.enableJetifier=true\n'
'org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m\n'
)

print('Done!')

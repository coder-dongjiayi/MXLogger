
# MXLogger for Flutter Change Log
# v1.2.14/2024-10-31
* Fix Fixed a bug where files were overwritten。 native lib v1.2.14.
# v1.2.13+2/2024-07-10
* Change the folder permission to 0777 for local export.
# v1.2.13+1/2024-05-27
* Fix bug. 
* Annotation flatDir。In order to fix the android side of the compilation error
# v1.2.13/2024-05-21
* Add `flutter_mxlogger_web.dart`. Only the method name is not implemented.
* Compatible with web side compilation
# v1.2.12/2024-04-26
* Keep up with MXLogger  native lib v1.2.12 on Android.
* Fix jin error.
# v1.2.11+1/2024-04-08
* Add `writeFail` method.
* You can write fail info when `log` return value not 0.
* `mxlogger.diskcacheErrorPath` is error path. You can use this path to manipulate file information
# v1.2.11/2024-3-27
* Log write Add return value。0 success,otherwise field.
* Add `errorDesc` get log error.
* Keep up with MXLogger  native lib v1.2.11.
# v1.2.10+3/2024-02-18
* Compatible Gradle 8.0 on Android. AndroidManifest.xml add package. fix package is com.coderdjy.mxlogger.
* 
# v1.2.10+2/2024-02-18
* Compatible Gradle 8.0 on Android. AndroidManifest.xml add package.
# v1.2.10+1/2024-02-18
* Compatible Gradle 8.0 on Android.
# v1.2.10/2023-12-02
* Keep up with MXLogger  native lib v1.2.10.
* Remove logger_key field in console
# v1.2.9/2023-11-13
* Keep up with MXLogger  native lib v1.2.9.
* Fix memory leak When setting setConsoleEnable is ture.
# v1.2.8/2023-08-14
*  Keep up with MXLogger  native lib v1.2.8.
* Remove shouldRemoveExpiredDataWhenTerminate on ios native.
* Replace fileLevel with the level field.
# v1.2.7+1/2023-06-21
* Fix bug
# v1.2.7/2023-06-20
* Adapter armv7 on Android. Add  annotation on iOS. Keep up with MXLogger  native lib v1.2.7
# v1.2.6/2023-06-03
* fix bug. maybe crash when Clean up expired files . Keep up with MXLogger  native lib v1.2.6
# v1.2.5+6/2023-05-06
* Update Flutter dependencies, set Flutter >=3.3.0 and Dart to >=2.18.0 <4.0.0
# v1.2.5+5/2023-05-05
* Format
# v1.2.5+4/2023-05-05
* Resolve the problem of using class methods in plug-ins that are not valid on Android
# v1.2.5+3/2023-05-05
* Keep up with MXLogger native lib v1.2.5.3 on Android
* Fix crash on native Android.
# v1.2.5/2023-03-06
* Keep up with MXLogger native lib v1.2.5.
* Add removeBeforeAllData() method.
# v1.2.4/2023-02-10
* Keep up with MXLogger native lib v1.2.4.
* Use "🟩","🟦","🟨","🟥","❌ emoji for 'DEBUG','INFO','WARN','ERROR','FATAL' on console.
# v1.2.3/2023-01-31
* Keep up with MXLogger native lib v1.2.3.
* fix bug
* formatting console json
# v1.2.2/2023-01-16
* Keep up with MXLogger native lib v1.2.2.
* Add logFiles method.
* Use `2023-01-02w_filename.mx` named file when storagePolicy is yyyy_ww.
* Change default name is log
# v1.2.1/2023-01-12
* Keep up with MXLogger native lib v1.2.1
* StoragePolicy arg use enum
* Fix bugs

# v1.2.0+1/2023-01-03
* Fixed bugs on android

# v1.2.0/2022-12-28
* Keep up with MXLogger native lib v1.2.0
* Add fileHeader

# v1.1.3/2022-10-13

* Keep up with MXLogger native lib v1.1.2
* Android remove unnecessary dependencies

# v1.1.2/ 2022-10-10

* fix bug

## v1.1.1 / 2022-10-09

* Android Change the package name.

## v1.1.0 / 2022-10-09
* Keep up with MXLogger native lib v1.1.0
* Logs can be written using loggerKey




@echo off
REM Sign entry-default-unsigned.hap -> entry-default-signed.hap (bypass DevEco SignHap)
setlocal
set ROOT=D:\oh-ai-car-ros-app
set JAR=D:\OpenHarmonySDK\12\toolchains\lib\hap-sign-tool.jar
set IN=%ROOT%\entry\build\default\outputs\default\entry-default-unsigned.hap
set OUT=%ROOT%\entry\build\default\outputs\default\entry-default-signed.hap
set /p PWD=<"%ROOT%\signing\PASSWORD.txt"
if not exist "%IN%" (
  echo Missing unsigned HAP: %IN%
  echo Build the project once in DevEco first.
  exit /b 1
)
java -jar "%JAR%" sign-app -mode localSign -keyAlias debugKey -signAlg SHA256withECDSA -appCertFile "%ROOT%\signing\app.cer" -profileFile "%ROOT%\signing\app.p7b" -inFile "%IN%" -keystoreFile "%ROOT%\signing\app.p12" -outFile "%OUT%" -keyPwd %PWD% -keystorePwd %PWD% -compatibleVersion 12
if errorlevel 1 exit /b 1
echo Signed: %OUT%
dir "%OUT%"

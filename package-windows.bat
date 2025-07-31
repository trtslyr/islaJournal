@echo off
echo 📦 Creating user-friendly Windows package...

rem Create clean package directory
if exist "IslaJournal-Windows" rmdir /s /q "IslaJournal-Windows"
mkdir "IslaJournal-Windows"

rem Copy main executable to root
copy "build\windows\runner\Release\isla_journal.exe" "IslaJournal-Windows\Isla Journal.exe"

rem Copy DLLs to root
copy "build\windows\runner\Release\*.dll" "IslaJournal-Windows\"

rem Copy data folder
xcopy "build\windows\runner\Release\data" "IslaJournal-Windows\data" /E /I /Q

rem Create simple launcher
echo @echo off > "IslaJournal-Windows\Isla Journal.bat"
echo start "" "Isla Journal.exe" >> "IslaJournal-Windows\Isla Journal.bat"

rem Create README for users
echo Welcome to Isla Journal! > "IslaJournal-Windows\README.txt"
echo. >> "IslaJournal-Windows\README.txt"
echo Double-click "Isla Journal.bat" to start the app >> "IslaJournal-Windows\README.txt"
echo or double-click "Isla Journal.exe" directly >> "IslaJournal-Windows\README.txt"

echo ✅ Package created in IslaJournal-Windows folder
echo 📁 Users just need to double-click "Isla Journal.bat"
pause 
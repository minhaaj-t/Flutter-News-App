@echo off
REM 🚀 NewsAI Pro Deployment Script for Windows
REM This script automates deployment to multiple free platforms

echo 🚀 Starting NewsAI Pro Deployment...

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter is not installed. Please install Flutter first.
    pause
    exit /b 1
)

REM Check if Git is installed
git --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git is not installed. Please install Git first.
    pause
    exit /b 1
)

echo [INFO] Building Flutter web app...

REM Clean and get dependencies
flutter clean
flutter pub get

REM Build for web
flutter build web --release

if errorlevel 1 (
    echo [ERROR] Web build failed!
    pause
    exit /b 1
)

echo [SUCCESS] Web build completed successfully!

REM Check if build/web directory exists
if not exist "build\web" (
    echo [ERROR] build\web directory not found!
    pause
    exit /b 1
)

echo [INFO] Build files are ready in build\web\

REM Git deployment
echo [INFO] Setting up Git deployment...

REM Check if this is a Git repository
if not exist ".git" (
    echo [WARNING] Not a Git repository. Initializing...
    git init
    git add .
    git commit -m "Initial commit - NewsAI Pro"
    echo [WARNING] Please add a remote repository and push your code.
    echo [WARNING] Example: git remote add origin https://github.com/yourusername/your-repo.git
    echo [WARNING] Then: git push -u origin main
) else (
    echo [INFO] Git repository found. Adding changes...
    git add .
    git commit -m "Deploy NewsAI Pro - %date% %time%"
    echo [SUCCESS] Changes committed to Git!
)

REM Create deployment instructions
echo [INFO] Creating deployment instructions...

(
echo # 🚀 Quick Deployment Instructions
echo.
echo ## Your NewsAI Pro app is ready for deployment!
echo.
echo ### Option 1: GitHub Pages ^(Recommended^)
echo 1. Push your code to GitHub:
echo    ```bash
echo    git push origin main
echo    ```
echo 2. Go to your repository Settings → Pages
echo 3. Select "GitHub Actions" as source
echo 4. Your app will be live at: `https://yourusername.github.io/your-repo-name`
echo.
echo ### Option 2: Netlify
echo 1. Go to [netlify.com](https://netlify.com^)
echo 2. Drag and drop the `build/web` folder
echo 3. Your app will be live instantly!
echo.
echo ### Option 3: Vercel
echo 1. Go to [vercel.com](https://vercel.com^)
echo 2. Import your GitHub repository
echo 3. Deploy automatically!
echo.
echo ### Option 4: Firebase
echo 1. Install Firebase CLI: `npm install -g firebase-tools`
echo 2. Login: `firebase login`
echo 3. Initialize: `firebase init hosting`
echo 4. Deploy: `firebase deploy`
echo.
echo ## Build Files Location
echo - Web build: `build/web/`
echo - Android APK: Run `flutter build apk --release`
echo - iOS app: Run `flutter build ios --release`
echo.
echo ## Next Steps
echo 1. Choose your preferred platform
echo 2. Follow the deployment steps
echo 3. Share your live app URL!
) > DEPLOYMENT_INSTRUCTIONS.md

echo [SUCCESS] Deployment instructions created in DEPLOYMENT_INSTRUCTIONS.md

REM Show file sizes
echo [INFO] Build file sizes:
for %%f in (build\web\*.*) do (
    echo   %%~nxf: %%~zf bytes
)

REM Show next steps
echo.
echo [SUCCESS] 🎉 Deployment preparation completed!
echo.
echo 📋 Next steps:
echo 1. Push your code to GitHub: git push origin main
echo 2. Choose a deployment platform from DEPLOYMENT_INSTRUCTIONS.md
echo 3. Follow the platform-specific instructions
echo 4. Share your live app URL!
echo.
echo 📁 Your web build is ready in: build\web\
echo 📖 See DEPLOYMENT_INSTRUCTIONS.md for detailed steps
echo.

echo [SUCCESS] Happy deploying! 🚀
pause 
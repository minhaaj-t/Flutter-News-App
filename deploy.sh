#!/bin/bash

# 🚀 NewsAI Pro Deployment Script
# This script automates deployment to multiple free platforms

echo "🚀 Starting NewsAI Pro Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Check if Git is installed
if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Please install Git first."
    exit 1
fi

print_status "Building Flutter web app..."

# Clean and get dependencies
flutter clean
flutter pub get

# Build for web
flutter build web --release

if [ $? -eq 0 ]; then
    print_success "Web build completed successfully!"
else
    print_error "Web build failed!"
    exit 1
fi

# Check if build/web directory exists
if [ ! -d "build/web" ]; then
    print_error "build/web directory not found!"
    exit 1
fi

print_status "Build files are ready in build/web/"

# Git deployment
print_status "Setting up Git deployment..."

# Check if this is a Git repository
if [ ! -d ".git" ]; then
    print_warning "Not a Git repository. Initializing..."
    git init
    git add .
    git commit -m "Initial commit - NewsAI Pro"
    print_warning "Please add a remote repository and push your code."
    print_warning "Example: git remote add origin https://github.com/yourusername/your-repo.git"
    print_warning "Then: git push -u origin main"
else
    print_status "Git repository found. Adding changes..."
    git add .
    git commit -m "Deploy NewsAI Pro - $(date)"
    print_success "Changes committed to Git!"
fi

# Create deployment instructions
print_status "Creating deployment instructions..."

cat > DEPLOYMENT_INSTRUCTIONS.md << 'EOF'
# 🚀 Quick Deployment Instructions

## Your NewsAI Pro app is ready for deployment!

### Option 1: GitHub Pages (Recommended)
1. Push your code to GitHub:
   ```bash
   git push origin main
   ```
2. Go to your repository Settings → Pages
3. Select "GitHub Actions" as source
4. Your app will be live at: `https://yourusername.github.io/your-repo-name`

### Option 2: Netlify
1. Go to [netlify.com](https://netlify.com)
2. Drag and drop the `build/web` folder
3. Your app will be live instantly!

### Option 3: Vercel
1. Go to [vercel.com](https://vercel.com)
2. Import your GitHub repository
3. Deploy automatically!

### Option 4: Firebase
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Initialize: `firebase init hosting`
4. Deploy: `firebase deploy`

## Build Files Location
- Web build: `build/web/`
- Android APK: Run `flutter build apk --release`
- iOS app: Run `flutter build ios --release`

## Next Steps
1. Choose your preferred platform
2. Follow the deployment steps
3. Share your live app URL!
EOF

print_success "Deployment instructions created in DEPLOYMENT_INSTRUCTIONS.md"

# Show file sizes
print_status "Build file sizes:"
du -sh build/web/* | while read size file; do
    echo "  $file: $size"
done

# Show next steps
echo ""
print_success "🎉 Deployment preparation completed!"
echo ""
echo "📋 Next steps:"
echo "1. Push your code to GitHub: git push origin main"
echo "2. Choose a deployment platform from DEPLOYMENT_INSTRUCTIONS.md"
echo "3. Follow the platform-specific instructions"
echo "4. Share your live app URL!"
echo ""
echo "📁 Your web build is ready in: build/web/"
echo "📖 See DEPLOYMENT_INSTRUCTIONS.md for detailed steps"
echo ""

print_success "Happy deploying! 🚀" 
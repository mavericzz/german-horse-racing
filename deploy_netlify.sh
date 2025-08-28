#!/bin/bash

echo "🌐 Deploying Indian Racing Frontend to Netlify..."

# Check if Netlify CLI is installed
if ! command -v netlify &> /dev/null; then
    echo "❌ Netlify CLI not found. Installing..."
    npm install -g netlify-cli
fi

# Check if user is logged in
if ! netlify status &> /dev/null; then
    echo "🔐 Please log in to Netlify..."
    netlify login
fi

# Navigate to netlify-site directory
cd netlify-site

# Deploy to Netlify
echo "📦 Deploying to Netlify..."
netlify deploy --prod

echo "✅ Deployment complete!"
echo "🌐 Your frontend should be available at the URL shown above"
echo "📝 Make sure your Railway backend is running and update the API URL if needed"

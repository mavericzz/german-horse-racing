# 🚀 Deployment Guide: Indian Racing Benter Model

This guide will walk you through deploying the Indian Racing Benter Model to production using **Netlify** (frontend) + **Railway** (backend).

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Netlify       │    │   Railway       │    │   Your Data     │
│   (Frontend)    │◄──►│   (Backend)     │◄──►│   (PDFs/JSON)   │
│                 │    │                 │    │                 │
│ • Static HTML   │    │ • Flask API     │    │ • Race Cards    │
│ • Bootstrap     │    │ • Data Pipeline │    │ • Odds Data     │
│ • Plotly.js     │    │ • Benter Model  │    │ • Results      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🎯 **Quick Start (5 minutes)**

### 1. Deploy Backend to Railway

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Deploy backend
./deploy_railway.sh
```

### 2. Deploy Frontend to Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login to Netlify
netlify login

# Deploy frontend
./deploy_netlify.sh
```

### 3. Update API URL

Update the API URL in your Netlify frontend with your Railway backend URL.

## 🔧 **Detailed Setup**

### **Prerequisites**

- GitHub account
- Railway account (free tier)
- Netlify account (free tier)
- Node.js installed
- Python 3.10+ installed

### **Step 1: Prepare Your Repository**

```bash
# Clone your repository
git clone https://github.com/yourusername/german-horse-racing.git
cd german-horse-racing

# Ensure you have the latest changes
git pull origin main
```

### **Step 2: Deploy Backend to Railway**

#### **A. Install Railway CLI**
```bash
npm install -g @railway/cli
```

#### **B. Login to Railway**
```bash
railway login
```

#### **C. Initialize Railway Project**
```bash
# This will create a new Railway project
railway init

# Select "Create new project"
# Give it a name like "indiaracing-backend"
```

#### **D. Deploy**
```bash
# Deploy your app
railway up

# Your app will get a URL like:
# https://indiaracing-backend-production.up.railway.app
```

#### **E. Set Environment Variables (Optional)**
```bash
railway variables set FLASK_ENV=production
railway variables set SECRET_KEY=your-secret-key-here
```

### **Step 3: Deploy Frontend to Netlify**

#### **A. Install Netlify CLI**
```bash
npm install -g netlify-cli
```

#### **B. Login to Netlify**
```bash
netlify login
```

#### **C. Deploy**
```bash
# Navigate to netlify-site directory
cd netlify-site

# Deploy to Netlify
netlify deploy --prod

# Follow the prompts to create a new site
```

#### **D. Update API URL**
After deployment, update the API URL in your Netlify site:

1. Go to your Netlify dashboard
2. Find your site
3. Go to "Site settings" → "Build & deploy" → "Post processing"
4. Add a redirect rule to update the API URL

Or manually edit `netlify-site/index.html` and redeploy.

### **Step 4: Connect Frontend to Backend**

1. **Get your Railway URL** from the Railway dashboard
2. **Update the API URL** in your Netlify frontend
3. **Test the connection** by refreshing your Netlify site

## 🔄 **Automated Deployment with GitHub Actions**

### **Setup GitHub Secrets**

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

```
RAILWAY_TOKEN=your_railway_token
RAILWAY_SERVICE=your_railway_service_id
NETLIFY_AUTH_TOKEN=your_netlify_token
NETLIFY_SITE_ID=your_netlify_site_id
```

### **Get Railway Token**
```bash
railway login
railway whoami
# Copy the token from ~/.railway/config.json
```

### **Get Netlify Token**
```bash
netlify status
# Copy the token from ~/.netlify/config.json
```

### **Get Netlify Site ID**
```bash
netlify sites:list
# Copy the Site ID for your site
```

## 📊 **Data Pipeline Setup**

### **Local Development**
```bash
# Process new racing data
python3 india/run_pipeline.py

# Test the web interface locally
python3 india/web/app.py
```

### **Production Updates**
The GitHub Actions workflow will automatically:
- Process new data every 6 hours
- Deploy updates when you push to main
- Keep your production app up-to-date

## 🌐 **Custom Domain Setup**

### **Netlify Custom Domain**
1. Go to your Netlify dashboard
2. Site settings → Domain management
3. Add custom domain
4. Update DNS records as instructed

### **Railway Custom Domain**
1. Go to your Railway dashboard
2. Select your service
3. Settings → Domains
4. Add custom domain

## 📱 **Mobile Optimization**

The frontend is already mobile-optimized with:
- Responsive Bootstrap design
- Touch-friendly interface
- Progressive Web App features
- Fast loading on mobile networks

## 🔍 **Monitoring & Analytics**

### **Railway Monitoring**
- Built-in metrics dashboard
- Logs and error tracking
- Performance monitoring
- Auto-scaling

### **Netlify Analytics**
- Page views and visitors
- Performance metrics
- Form submissions
- Error tracking

## 🚨 **Troubleshooting**

### **Common Issues**

#### **Backend Not Responding**
```bash
# Check Railway logs
railway logs

# Check if app is running
railway status
```

#### **Frontend Can't Connect to Backend**
1. Verify Railway URL is correct
2. Check CORS settings
3. Test API endpoints directly
4. Check browser console for errors

#### **Data Not Loading**
1. Verify data files exist
2. Check file permissions
3. Test data processing pipeline
4. Check API response format

### **Debug Commands**
```bash
# Test backend locally
python3 india/web/app.py

# Test data processing
python3 india/test_setup.py

# Check Railway status
railway status

# Check Netlify status
netlify status
```

## 📈 **Scaling & Performance**

### **Railway Scaling**
- Auto-scales based on traffic
- Free tier: 500 hours/month
- Paid plans: Unlimited scaling
- Global CDN included

### **Netlify Performance**
- Global CDN (200+ locations)
- Automatic builds and deployments
- Form handling and serverless functions
- Edge computing capabilities

## 💰 **Costs**

### **Free Tier**
- **Railway**: 500 hours/month
- **Netlify**: 100GB bandwidth/month
- **GitHub**: Unlimited public repos

### **Paid Plans**
- **Railway**: $5/month for unlimited hours
- **Netlify**: $19/month for team features
- **Custom domains**: $10-15/year

## 🔐 **Security Best Practices**

1. **Environment Variables**: Never commit secrets
2. **HTTPS Only**: Both platforms enforce HTTPS
3. **CORS**: Properly configured for production
4. **Input Validation**: All API inputs validated
5. **Rate Limiting**: Consider adding rate limits

## 📚 **Additional Resources**

- [Railway Documentation](https://docs.railway.app/)
- [Netlify Documentation](https://docs.netlify.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flask Production Deployment](https://flask.palletsprojects.com/en/2.3.x/deploying/)

## 🎉 **Success!**

After following this guide, you'll have:
- ✅ **Production backend** running on Railway
- ✅ **Beautiful frontend** deployed on Netlify
- ✅ **Automated deployments** via GitHub Actions
- ✅ **Real-time data updates** every 6 hours
- ✅ **Mobile-optimized** racing analytics platform

Your Indian Racing Benter Model is now live and ready to analyze racing data! 🏇

---

**Need help?** Check the troubleshooting section or open an issue on GitHub.

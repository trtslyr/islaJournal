# 🚀 Railway Deployment Instructions

## Quick Deploy (5 minutes)

### 1. Create Railway Account
- Go to [railway.app](https://railway.app)
- Sign up with GitHub

### 2. Deploy Backend
1. Click "New Project" → "Deploy from GitHub repo"
2. Connect your GitHub account 
3. Select your backend repository (upload this /backend folder)
4. Railway will auto-detect Node.js and deploy

### 3. Set Environment Variables
In Railway dashboard → Your Project → Variables tab:

```
STRIPE_SECRET_KEY=sk_live_YOUR_ACTUAL_KEY_HERE
STRIPE_WEBHOOK_SECRET=whsec_xxx  (get from Stripe dashboard)
FRONTEND_URL=https://islajournal.app
https://islajournal.appPORT=3000
```

### 4. Get Your Backend URL
Railway will give you a URL like: `https://your-app-name.railway.app`

### 5. Update Flutter App
In `lib/services/license_service.dart`, change:
```dart
static const String baseUrl = 'https://your-app-name.railway.app';
```

### 6. Setup Stripe Webhook
1. Go to Stripe Dashboard → Developers → Webhooks
2. Add endpoint: `https://your-app-name.railway.app/stripe/webhook`
3. Select events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`
4. Copy webhook secret and add to Railway environment variables

## Your Lifetime Customer Keys

Once deployed, visit: `https://your-app-name.railway.app/admin/lifetime-licenses`

This will show you all 10 lifetime keys to send to your customers:

- mickyrathod@gmail.com: ij_life_xxx...
- akb965@proton.me: ij_life_xxx...
- dev@dvin.me: ij_life_xxx...
- piercermcbride@gmail.com: ij_life_xxx...
- joshuakeay@gmail.com: ij_life_xxx...
- codyobrien124@gmail.com: ij_life_xxx...
- Kejoin@gmail.com: ij_life_xxx...
- smithmichael.agent@gmail.com: ij_life_xxx...
- taylorwall214@gmail.com: ij_life_xxx...
- 4alowry@gmail.com: ij_life_xxx...

## Testing

1. **Test lifetime key**: Enter a key from admin endpoint
2. **Test subscription**: Try monthly/annual checkout
3. **Test trial**: Fresh install should show 24h trial

## Customer Portal

Your customers can manage subscriptions at:
`https://customer-portal.stripe.com` (accessed via app's "Manage Subscription" button)

## That's it! 🎉

Your licensing system is now live and ready for launch! 
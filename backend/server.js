require('dotenv').config();
const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());

// For Stripe webhooks - MUST be before express.json()
app.use('/stripe/webhook', express.raw({type: 'application/json'}));

// For all other routes
app.use(express.json());

// Initialize Database
const db = new sqlite3.Database('./licenses.db');

// Create tables
db.serialize(() => {
  // Lifetime licenses table
  db.run(`CREATE TABLE IF NOT EXISTS lifetime_licenses (
    id TEXT PRIMARY KEY,
    license_key TEXT UNIQUE NOT NULL,
    customer_email TEXT NOT NULL,
    customer_name TEXT,
    granted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'active'
  )`);

  // Device licenses table (subscriptions)
  db.run(`CREATE TABLE IF NOT EXISTS device_licenses (
    id TEXT PRIMARY KEY,
    device_id TEXT UNIQUE NOT NULL,
    stripe_customer_id TEXT NOT NULL,
    stripe_subscription_id TEXT NOT NULL,
    plan_type TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME
  )`);

  // Insert lifetime customers
  const lifetimeCustomers = [
    { email: 'mickyrathod@gmail.com', name: 'Micky Rathod' },
    { email: 'akb965@proton.me', name: 'Customer' },
    { email: 'dev@dvin.me', name: 'Dev' },
    { email: 'piercermcbride@gmail.com', name: 'Pierce McBride' },
    { email: 'joshuakeay@gmail.com', name: 'Joshua Keay' },
    { email: 'codyobrien124@gmail.com', name: 'Cody OBrien' },
    { email: 'Kejoin@gmail.com', name: 'Ke Join' },
    { email: 'smithmichael.agent@gmail.com', name: 'Michael Smith' },
    { email: 'taylorwall214@gmail.com', name: 'Taylor Wall' },
    { email: '4alowry@gmail.com', name: 'A Lowry' }
  ];

  lifetimeCustomers.forEach(customer => {
    const licenseKey = `ij_life_${crypto.randomBytes(16).toString('hex')}`;
    db.run(
      `INSERT OR IGNORE INTO lifetime_licenses (id, license_key, customer_email, customer_name) 
       VALUES (?, ?, ?, ?)`,
      [uuidv4(), licenseKey, customer.email, customer.name],
      function(err) {
        if (!err && this.changes > 0) {
          console.log(`✅ Generated lifetime key for ${customer.email}: ${licenseKey}`);
        }
      }
    );
  });
});

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'Isla Journal Backend Running', timestamp: new Date().toISOString() });
});

// Get all lifetime licenses (for sending to customers)
app.get('/admin/lifetime-licenses', (req, res) => {
  db.all('SELECT customer_email, license_key, customer_name FROM lifetime_licenses ORDER BY customer_email', (err, rows) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

// Get all device licenses (for debugging subscriptions)
app.get('/admin/device-licenses', (req, res) => {
  db.all('SELECT * FROM device_licenses ORDER BY created_at DESC', (err, rows) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

// Validate lifetime license
app.post('/validate-lifetime-key', (req, res) => {
  const { license_key } = req.body;
  
  if (!license_key) {
    return res.json({ valid: false, reason: 'missing_key' });
  }
  
  db.get(
    'SELECT * FROM lifetime_licenses WHERE license_key = ? AND status = ?',
    [license_key, 'active'],
    (err, row) => {
      if (err) {
        console.error('Database error:', err);
        return res.status(500).json({ valid: false, reason: 'database_error' });
      }
      
      if (!row) {
        return res.json({ valid: false, reason: 'invalid_key' });
      }
      
      res.json({
        valid: true,
        license_type: 'lifetime',
        customer_name: row.customer_name,
        never_expires: true,
        granted_at: row.granted_at
      });
    }
  );
});

// Check device license
app.post('/check-device-license', async (req, res) => {
  const { device_id } = req.body;
  
  if (!device_id) {
    return res.json({ licensed: false, reason: 'missing_device_id' });
  }
  
  db.get(
    'SELECT * FROM device_licenses WHERE device_id = ? AND status = ?',
    [device_id, 'active'],
    async (err, row) => {
      if (err) {
        console.error('Database error:', err);
        return res.status(500).json({ licensed: false, reason: 'database_error' });
      }
      
      if (!row) {
        return res.json({ licensed: false, reason: 'no_license' });
      }
      
      try {
        // Check Stripe subscription status
        const subscription = await stripe.subscriptions.retrieve(row.stripe_subscription_id);
        
        const isActive = subscription.status === 'active';
        
        res.json({
          licensed: isActive,
          license_type: 'subscription',
          plan_type: row.plan_type,
          expires_at: row.expires_at,
          stripe_customer_id: row.stripe_customer_id,
          subscription_status: subscription.status
        });
      } catch (stripeError) {
        console.error('Stripe error:', stripeError);
        res.json({ licensed: false, reason: 'stripe_error' });
      }
    }
  );
});

// Create Stripe checkout session
app.post('/create-checkout-session', async (req, res) => {
  const { plan_type, device_id } = req.body;
  
  if (!plan_type || !device_id) {
    return res.status(400).json({ error: 'Missing plan_type or device_id' });
  }
  
  const prices = {
    monthly: 'price_1RqLWxBxQUfu73U6spCvwWRJ',
    annual: 'price_1RqLd7BxQUfu73U6WNMSqg0e',
    lifetime: 'price_1RqLaKBxQUfu73U6aDaJvVKH'
  };
  
  if (!prices[plan_type]) {
    return res.status(400).json({ error: 'Invalid plan_type' });
  }
  
  try {
    const sessionConfig = {
      payment_method_types: ['card'],
      line_items: [{
        price: prices[plan_type],
        quantity: 1,
      }],
      mode: plan_type === 'lifetime' ? 'payment' : 'subscription',
      success_url: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/cancel`,
      metadata: {
        device_id: device_id,
        plan_type: plan_type
      }
    };

    const session = await stripe.checkout.sessions.create(sessionConfig);
    
    res.json({ 
      checkout_url: session.url, 
      session_id: session.id 
    });
  } catch (error) {
    console.error('Stripe checkout error:', error);
    res.status(400).json({ error: error.message });
  }
});

// Stripe webhook
app.post('/stripe/webhook', (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;
  
  try {
    event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }
  
  console.log('Received webhook event:', event.type);
  
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    
    console.log('Processing checkout completion for session:', session.id);
    
    // Create device license for subscriptions
    if (session.mode === 'subscription' && session.metadata.device_id) {
      const expiryDate = session.metadata.plan_type === 'annual' 
        ? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
        : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      
      db.run(
        `INSERT OR REPLACE INTO device_licenses (id, device_id, stripe_customer_id, stripe_subscription_id, plan_type, expires_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          uuidv4(),
          session.metadata.device_id,
          session.customer,
          session.subscription,
          session.metadata.plan_type,
          expiryDate.toISOString()
        ],
        function(err) {
          if (err) {
            console.error('Error creating device license:', err);
          } else {
            console.log('✅ Created device license for:', session.metadata.device_id);
          }
        }
      );
    }
    
    // Handle lifetime payments
    if (session.mode === 'payment' && session.metadata.plan_type === 'lifetime') {
      // For lifetime, we could create a special device license or handle differently
      console.log('✅ Lifetime payment completed for device:', session.metadata.device_id);
    }
  }
  
  // Handle subscription updates
  if (event.type === 'customer.subscription.updated' || event.type === 'customer.subscription.deleted') {
    const subscription = event.data.object;
    
    const newStatus = subscription.status === 'active' ? 'active' : 'inactive';
    
    db.run(
      'UPDATE device_licenses SET status = ? WHERE stripe_subscription_id = ?',
      [newStatus, subscription.id],
      function(err) {
        if (err) {
          console.error('Error updating subscription status:', err);
        } else {
          console.log(`✅ Updated subscription ${subscription.id} status to ${newStatus}`);
        }
      }
    );
  }
  
  res.json({received: true});
});

// Customer portal
app.post('/customer-portal', async (req, res) => {
  const { device_id } = req.body;
  
  if (!device_id) {
    return res.status(400).json({ error: 'Missing device_id' });
  }
  
  db.get(
    'SELECT stripe_customer_id FROM device_licenses WHERE device_id = ?',
    [device_id],
    async (err, row) => {
      if (err) {
        console.error('Database error:', err);
        return res.status(500).json({ error: 'Database error' });
      }
      
      if (!row) {
        return res.status(404).json({ error: 'No subscription found for this device' });
      }
      
      try {
        const portalSession = await stripe.billingPortal.sessions.create({
          customer: row.stripe_customer_id,
          return_url: process.env.FRONTEND_URL || 'http://localhost:3000',
        });
        
        res.json({ portal_url: portalSession.url });
      } catch (error) {
        console.error('Customer portal error:', error);
        res.status(400).json({ error: error.message });
      }
    }
  );
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Isla Journal Backend running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/`);
  console.log(`🔑 Admin endpoint: http://localhost:${PORT}/admin/lifetime-licenses`);
});

module.exports = app; // Force deployment trigger

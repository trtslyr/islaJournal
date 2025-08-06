require('dotenv').config();
const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());

// CRITICAL: Raw body parsing for webhooks BEFORE json parsing
app.use('/stripe/webhook', express.raw({type: 'application/json'}));
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

  // Subscription licenses table (key-based like lifetime)
  db.run(`CREATE TABLE IF NOT EXISTS subscription_licenses (
    id TEXT PRIMARY KEY,
    license_key TEXT UNIQUE NOT NULL,
    stripe_customer_id TEXT NOT NULL,
    stripe_subscription_id TEXT NOT NULL,
    customer_email TEXT,
    customer_name TEXT,
    plan_type TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME
  )`);
  
  // Add email and name columns for existing databases
  db.run(`ALTER TABLE subscription_licenses ADD COLUMN customer_email TEXT`, (err) => {});
  db.run(`ALTER TABLE subscription_licenses ADD COLUMN customer_name TEXT`, (err) => {});

  // Insert lifetime customers with FIXED KEYS (never change)
  const lifetimeCustomers = [
    { email: 'mickyrathod@gmail.com', name: 'Micky Rathod', key: 'ij_life_mickyrathod_permanent_key' },
    { email: 'akb965@proton.me', name: 'Customer', key: 'ij_life_akb965_permanent_key' },
    { email: 'dev@dvin.me', name: 'Dev', key: 'ij_life_dev_permanent_key' },
    { email: 'piercermcbride@gmail.com', name: 'Pierce McBride', key: 'ij_life_pierce_permanent_key' },
    { email: 'joshuakeay@gmail.com', name: 'Joshua Keay', key: 'ij_life_joshua_permanent_key' },
    { email: 'codyobrien124@gmail.com', name: 'Cody OBrien', key: 'ij_life_cody_permanent_key' },
    { email: 'Kejoin@gmail.com', name: 'Ke Join', key: 'ij_life_kejoin_permanent_key' },
    { email: 'smithmichael.agent@gmail.com', name: 'Michael Smith', key: 'ij_life_michael_permanent_key' },
    { email: 'taylorwall214@gmail.com', name: 'Taylor Wall', key: 'ij_life_taylor_permanent_key' },
    { email: '4alowry@gmail.com', name: 'A Lowry', key: 'ij_life_alowry_permanent_key' }
  ];

  lifetimeCustomers.forEach(customer => {
    db.run(
      `INSERT OR IGNORE INTO lifetime_licenses (id, license_key, customer_email, customer_name) 
       VALUES (?, ?, ?, ?)`,
      [uuidv4(), customer.key, customer.email, customer.name],
      function(err) {
        if (!err && this.changes > 0) {
          console.log(`✅ Added lifetime customer: ${customer.email} with permanent key`);
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

// Get all subscription licenses (for customer support)
app.get('/admin/subscription-licenses', (req, res) => {
  db.all('SELECT license_key, stripe_customer_id, customer_email, plan_type, status, created_at, expires_at FROM subscription_licenses ORDER BY created_at DESC', (err, rows) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

// ADMIN EDITING ENDPOINTS - Added for full license management

// Update lifetime license
app.put('/admin/lifetime-license/:email', (req, res) => {
  const { email } = req.params;
  const { customer_name, license_key, status } = req.body;
  
  const updates = [];
  const values = [];
  
  if (customer_name !== undefined) {
    updates.push('customer_name = ?');
    values.push(customer_name);
  }
  
  if (license_key !== undefined) {
    updates.push('license_key = ?');
    values.push(license_key);
  }
  
  if (status !== undefined) {
    updates.push('status = ?');
    values.push(status);
  }
  
  if (updates.length === 0) {
    return res.status(400).json({ error: 'No fields to update' });
  }
  
  values.push(email);
  
  db.run(
    `UPDATE lifetime_licenses SET ${updates.join(', ')} WHERE customer_email = ?`,
    values,
    function(err) {
      if (err) {
        console.error('Error updating lifetime license:', err);
        return res.status(500).json({ error: 'Failed to update license' });
      }
      
      if (this.changes === 0) {
        return res.status(404).json({ error: 'License not found' });
      }
      
      console.log(`✅ Updated lifetime license for ${email}`);
      res.json({ 
        success: true, 
        message: 'License updated successfully',
        changes: this.changes 
      });
    }
  );
});

// Delete lifetime license
app.delete('/admin/lifetime-license/:email', (req, res) => {
  const { email } = req.params;
  
  db.run(
    'DELETE FROM lifetime_licenses WHERE customer_email = ?',
    [email],
    function(err) {
      if (err) {
        console.error('Error deleting lifetime license:', err);
        return res.status(500).json({ error: 'Failed to delete license' });
      }
      
      if (this.changes === 0) {
        return res.status(404).json({ error: 'License not found' });
      }
      
      console.log(`✅ Deleted lifetime license for ${email}`);
      res.json({ 
        success: true, 
        message: 'License deleted successfully',
        changes: this.changes 
      });
    }
  );
});

// Deactivate/reactivate lifetime license
app.post('/admin/lifetime-license/:email/toggle-status', (req, res) => {
  const { email } = req.params;
  
  // First get current status
  db.get(
    'SELECT status FROM lifetime_licenses WHERE customer_email = ?',
    [email],
    (err, row) => {
      if (err) {
        console.error('Error fetching license status:', err);
        return res.status(500).json({ error: 'Database error' });
      }
      
      if (!row) {
        return res.status(404).json({ error: 'License not found' });
      }
      
      const newStatus = row.status === 'active' ? 'inactive' : 'active';
      
      db.run(
        'UPDATE lifetime_licenses SET status = ? WHERE customer_email = ?',
        [newStatus, email],
        function(err) {
          if (err) {
            console.error('Error updating license status:', err);
            return res.status(500).json({ error: 'Failed to update status' });
          }
          
          console.log(`✅ ${newStatus === 'active' ? 'Activated' : 'Deactivated'} lifetime license for ${email}`);
          res.json({ 
            success: true, 
            message: `License ${newStatus === 'active' ? 'activated' : 'deactivated'} successfully`,
            new_status: newStatus
          });
        }
      );
    }
  );
});

// Toggle subscription license status
app.post('/admin/subscription-license/:license_key/toggle-status', (req, res) => {
  const { license_key } = req.params;
  
  // First get current status
  db.get(
    'SELECT status FROM subscription_licenses WHERE license_key = ?',
    [license_key],
    (err, row) => {
      if (err) {
        console.error('Error fetching subscription license status:', err);
        return res.status(500).json({ error: 'Database error' });
      }
      
      if (!row) {
        return res.status(404).json({ error: 'License not found' });
      }
      
      const newStatus = row.status === 'active' ? 'inactive' : 'active';
      
      db.run(
        'UPDATE subscription_licenses SET status = ? WHERE license_key = ?',
        [newStatus, license_key],
        function(err) {
          if (err) {
            console.error('Error updating subscription license status:', err);
            return res.status(500).json({ error: 'Failed to update status' });
          }
          
          console.log(`✅ ${newStatus === 'active' ? 'Activated' : 'Deactivated'} subscription license ${license_key}`);
          res.json({ 
            success: true, 
            message: `License ${newStatus === 'active' ? 'activated' : 'deactivated'} successfully`,
            new_status: newStatus
          });
        }
      );
    }
  );
});

// Update subscription license
app.put('/admin/subscription-license/:license_key', (req, res) => {
  const { license_key } = req.params;
  const { customer_name, license_key: new_license_key, plan_type, status } = req.body;
  
  const updates = [];
  const values = [];
  
  if (customer_name !== undefined) {
    updates.push('customer_name = ?');
    values.push(customer_name);
  }
  
  if (new_license_key !== undefined) {
    updates.push('license_key = ?');
    values.push(new_license_key);
  }
  
  if (plan_type !== undefined) {
    updates.push('plan_type = ?');
    values.push(plan_type);
  }
  
  if (status !== undefined) {
    updates.push('status = ?');
    values.push(status);
  }
  
  if (updates.length === 0) {
    return res.status(400).json({ error: 'No fields to update' });
  }
  
  values.push(license_key);
  
  db.run(
    `UPDATE subscription_licenses SET ${updates.join(', ')} WHERE license_key = ?`,
    values,
    function(err) {
      if (err) {
        console.error('Error updating subscription license:', err);
        return res.status(500).json({ error: 'Failed to update license' });
      }
      
      if (this.changes === 0) {
        return res.status(404).json({ error: 'License not found' });
      }
      
      console.log(`✅ Updated subscription license ${license_key}`);
      res.json({ 
        success: true, 
        message: 'License updated successfully',
        changes: this.changes 
      });
    }
  );
});

// Delete subscription license
app.delete('/admin/subscription-license/:license_key', (req, res) => {
  const { license_key } = req.params;
  
  db.run(
    'DELETE FROM subscription_licenses WHERE license_key = ?',
    [license_key],
    function(err) {
      if (err) {
        console.error('Error deleting subscription license:', err);
        return res.status(500).json({ error: 'Failed to delete license' });
      }
      
      if (this.changes === 0) {
        return res.status(404).json({ error: 'License not found' });
      }
      
      console.log(`✅ Deleted subscription license ${license_key}`);
      res.json({ 
        success: true, 
        message: 'License deleted successfully',
        changes: this.changes 
      });
    }
  );
});

// Get detailed info for a specific lifetime license
app.get('/admin/lifetime-license/:email', (req, res) => {
  const { email } = req.params;
  
  db.get(
    'SELECT * FROM lifetime_licenses WHERE customer_email = ?',
    [email],
    (err, row) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }
      
      if (!row) {
        return res.status(404).json({ error: 'License not found' });
      }
      
      res.json(row);
    }
  );
});

// Get detailed info for a specific subscription license
app.get('/admin/subscription-license/:license_key', (req, res) => {
  const { license_key } = req.params;
  
  db.get(
    'SELECT * FROM subscription_licenses WHERE license_key = ?',
    [license_key],
    (err, row) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }
      
      if (!row) {
        return res.status(404).json({ error: 'License not found' });
      }
      
      res.json(row);
    }
  );
});

// Admin stats endpoint
app.get('/admin/stats', (req, res) => {
  const stats = {};
  
  // Get lifetime license stats
  db.get('SELECT COUNT(*) as total, COUNT(CASE WHEN status = "active" THEN 1 END) as active FROM lifetime_licenses', (err, lifetimeStats) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    
    stats.lifetime = lifetimeStats;
    
    // Get subscription license stats
    db.get('SELECT COUNT(*) as total, COUNT(CASE WHEN status = "active" THEN 1 END) as active FROM subscription_licenses', (err, subStats) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }
      
      stats.subscription = subStats;
      stats.total_customers = lifetimeStats.total + subStats.total;
      stats.active_customers = lifetimeStats.active + subStats.active;
      
      res.json(stats);
    });
  });
});

// Validate lifetime license
app.post('/validate-lifetime-key', (req, res) => {
  const { license_key } = req.body;
  
  console.log(`🔍 Lifetime license validation request:`);
  console.log(`   Key: ${license_key ? license_key.substring(0, 10) + '...' : 'MISSING'}`);
  console.log(`   User-Agent: ${req.headers['user-agent']}`);
  console.log(`   Origin: ${req.headers.origin || 'N/A'}`);
  
  if (!license_key) {
    console.log(`❌ Missing license key`);
    return res.json({ valid: false, reason: 'missing_key' });
  }
  
  db.get(
    'SELECT * FROM lifetime_licenses WHERE license_key = ? AND status = ?',
    [license_key, 'active'],
    (err, row) => {
      if (err) {
        console.error('❌ Database error:', err);
        return res.status(500).json({ valid: false, reason: 'database_error' });
      }
      
      if (!row) {
        console.log(`❌ No matching lifetime license found for key: ${license_key.substring(0, 10)}...`);
        return res.json({ valid: false, reason: 'invalid_key' });
      }
      
      console.log(`✅ Valid lifetime license found for: ${row.customer_name || 'N/A'}`);
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

// Validate subscription license key (monthly/annual)
app.post('/validate-subscription-key', async (req, res) => {
  const { license_key } = req.body;
  
  if (!license_key) {
    return res.json({ valid: false, reason: 'missing_key' });
  }
  
  db.get(
    'SELECT * FROM subscription_licenses WHERE license_key = ? AND status = ?',
    [license_key, 'active'],
    async (err, row) => {
      if (err) {
        console.error('Database error:', err);
        return res.status(500).json({ valid: false, reason: 'database_error' });
      }
      
      if (!row) {
        return res.json({ valid: false, reason: 'invalid_key' });
      }
      
      try {
        // Check Stripe subscription status
        const subscription = await stripe.subscriptions.retrieve(row.stripe_subscription_id);
        
        const isActive = subscription.status === 'active';
        
        if (isActive) {
          res.json({
            valid: true,
            license_type: 'subscription',
            plan_type: row.plan_type,
            expires_at: new Date(subscription.current_period_end * 1000).toISOString(),
            stripe_customer_id: row.stripe_customer_id,
            subscription_status: subscription.status
          });
        } else {
          res.json({ valid: false, reason: 'subscription_inactive' });
        }
      } catch (stripeError) {
        console.error('Stripe error:', stripeError);
        res.json({ valid: false, reason: 'stripe_error' });
      }
    }
  );
});

// Get latest subscription key for auto-recovery
app.post('/get-latest-subscription-key', (req, res) => {
  const { stripe_customer_id } = req.body;
  
  if (!stripe_customer_id) {
    return res.json({ found: false });
  }
  
  db.get(
    'SELECT license_key, plan_type, expires_at FROM subscription_licenses WHERE stripe_customer_id = ? AND status = ? ORDER BY created_at DESC LIMIT 1',
    [stripe_customer_id, 'active'],
    (err, row) => {
      if (err) {
        console.error('Database error:', err);
        return res.json({ found: false });
      }
      
      if (!row) {
        return res.json({ found: false });
      }
      
      res.json({
        found: true,
        license_key: row.license_key,
        plan_type: row.plan_type,
        expires_at: row.expires_at
      });
    }
  );
});

// Create Stripe checkout session
app.post('/create-checkout-session', async (req, res) => {
  try {
    const { plan_type } = req.body;
    
    // Define price IDs for each plan
    const priceIds = {
      monthly: 'price_1QJWxQBxQUfu73U6NbJbfcRz',
      annual: 'price_1QJWxcBxQUfu73U6q4rNf9r1',
      lifetime: 'price_1QJWy6BxQUfu73U6KWoGfKKd'
    };

    if (!priceIds[plan_type]) {
      return res.status(400).json({ error: 'Invalid plan type' });
    }

    const isLifetime = plan_type === 'lifetime';
    const successUrl = `https://islajournalbackend-production.up.railway.app/success?session_id={CHECKOUT_SESSION_ID}`;
    const cancelUrl = `${process.env.FRONTEND_URL || 'https://islajournal.app'}/pricing`;

    const sessionConfig = {
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceIds[plan_type],
          quantity: 1,
        },
      ],
      mode: isLifetime ? 'payment' : 'subscription',
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: {
        plan_type: plan_type,
      },
    };

    const session = await stripe.checkout.sessions.create(sessionConfig);

    res.json({
      checkout_url: session.url,
      session_id: session.id
    });

  } catch (error) {
    console.error('Error creating checkout session:', error);
    res.status(400).json({ error: error.message });
  }
});

// Get license key by session ID (for success page)
app.get('/get-license-key/:sessionId', async (req, res) => {
  try {
    const { sessionId } = req.params;
    
    // Get session from Stripe to get customer info
    const session = await stripe.checkout.sessions.retrieve(sessionId);
    
    if (!session || session.payment_status !== 'paid') {
      return res.status(404).json({ error: 'Session not found or payment not completed' });
    }

    let licenseKey = null;
    let licenseType = session.metadata.plan_type;

    // Check if it's a lifetime purchase
    if (session.mode === 'payment' && session.metadata.plan_type === 'lifetime') {
      // Look up lifetime license by customer email
      const customer = await stripe.customers.retrieve(session.customer);
      
      const row = await new Promise((resolve, reject) => {
        db.get(
          'SELECT license_key FROM lifetime_licenses WHERE customer_email = ? ORDER BY granted_at DESC LIMIT 1',
          [customer.email],
          (err, row) => {
            if (err) reject(err);
            else resolve(row);
          }
        );
      });
      
      if (row) {
        licenseKey = row.license_key;
      }
    } else if (session.mode === 'subscription') {
      // Look up subscription license by customer ID
      const row = await new Promise((resolve, reject) => {
        db.get(
          'SELECT license_key FROM subscription_licenses WHERE stripe_customer_id = ? ORDER BY created_at DESC LIMIT 1',
          [session.customer],
          (err, row) => {
            if (err) reject(err);
            else resolve(row);
          }
        );
      });
      
      if (row) {
        licenseKey = row.license_key;
      }
    }

    if (licenseKey) {
      res.json({
        license_key: licenseKey,
        license_type: licenseType,
        customer_email: session.customer_details?.email
      });
    } else {
      res.status(404).json({ error: 'License key not found. Please check your customer portal.' });
    }

  } catch (error) {
    console.error('Error retrieving license key:', error);
    res.status(500).json({ error: 'Failed to retrieve license key' });
  }
});

// Stripe webhook
app.post('/stripe/webhook', async (req, res) => {
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
    
    // Create subscription license key for monthly/annual subscriptions
    if (session.mode === 'subscription') {
      const subscriptionKey = `ij_sub_${crypto.randomBytes(16).toString('hex')}`;
      const expiryDate = session.metadata.plan_type === 'annual' 
        ? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
        : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      
      // Get customer email
      const customer = await stripe.customers.retrieve(session.customer);
      
      db.run(
        `INSERT OR REPLACE INTO subscription_licenses (id, license_key, stripe_customer_id, stripe_subscription_id, customer_email, plan_type, expires_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          uuidv4(),
          subscriptionKey,
          session.customer,
          session.subscription,
          customer.email,
          session.metadata.plan_type,
          expiryDate.toISOString()
        ],
        async function(err) {
          if (err) {
            console.error('Error creating subscription license:', err);
          } else {
            console.log('✅ Created subscription license key:', subscriptionKey);
            
            // Add license key to subscription description so it appears in customer portal and future invoices
            try {
              await stripe.subscriptions.update(session.subscription, {
                description: `🔑 ISLA JOURNAL ${session.metadata.plan_type.toUpperCase()} LICENSE KEY: ${subscriptionKey}`,
                metadata: {
                  license_key: subscriptionKey,
                  app_name: 'Isla Journal',
                  instructions: 'Enter this key in the Isla Journal app to activate your subscription'
                }
              });
              console.log('✅ Added license key to subscription');
              
              // Also update the customer record with the subscription key for easy access
              await stripe.customers.update(session.customer, {
                metadata: {
                  latest_license_key: subscriptionKey,
                  license_type: session.metadata.plan_type,
                  app_name: 'Isla Journal',
                  instructions: 'Find your license key in your subscription details'
                }
              });
              console.log('✅ Added subscription key to customer metadata');
              
            } catch (subscriptionError) {
              console.error('❌ Error updating subscription:', subscriptionError);
            }
          }
        }
      );
    }
    
    // Handle lifetime payments - generate lifetime key
    if (session.mode === 'payment' && session.metadata.plan_type === 'lifetime') {
      const lifetimeKey = `ij_life_${crypto.randomBytes(16).toString('hex')}`;
      
      // Get customer info from Stripe
      const customer = await stripe.customers.retrieve(session.customer);
      
      db.run(
        `INSERT OR REPLACE INTO lifetime_licenses (id, license_key, customer_email, customer_name)
         VALUES (?, ?, ?, ?)`,
        [
          uuidv4(),
          lifetimeKey,
          customer.email,
          customer.name || 'Customer'
        ],
        async function(err) {
          if (err) {
            console.error('Error creating lifetime license:', err);
          } else {
            console.log('✅ Created lifetime license key:', lifetimeKey, 'for', customer.email);
            
            // Add license key to customer description for easy access
            try {
              await stripe.customers.update(session.customer, {
                description: `🔑 ISLA JOURNAL LIFETIME LICENSE KEY: ${lifetimeKey}`,
                metadata: {
                  license_key: lifetimeKey,
                  license_type: 'lifetime',
                  app_name: 'Isla Journal',
                  instructions: 'Enter this key in the Isla Journal app to activate your lifetime license',
                  never_expires: 'true'
                }
              });
              console.log('✅ Added lifetime key to customer record');
            } catch (customerError) {
              console.error('❌ Error updating customer:', customerError);
            }
          }
        }
      );
    }
  }
  
  // Handle subscription updates
  if (event.type === 'customer.subscription.updated' || event.type === 'customer.subscription.deleted') {
    const subscription = event.data.object;
    
    const newStatus = subscription.status === 'active' ? 'active' : 'inactive';
    
    db.run(
      'UPDATE subscription_licenses SET status = ? WHERE stripe_subscription_id = ?',
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
  const { license_key } = req.body;
  
  if (!license_key) {
    return res.status(400).json({ error: 'Missing license_key' });
  }
  
  db.get(
    'SELECT stripe_customer_id FROM subscription_licenses WHERE license_key = ?',
    [license_key],
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

// TEMPORARY: Admin endpoint to add lifetime license
app.post('/admin/add-lifetime-key', (req, res) => {
  const { license_key, email, name } = req.body;
  
  if (!license_key || !email) {
    return res.status(400).json({ error: 'License key and email are required' });
  }
  
  const id = uuidv4();
  
  db.run(
    'INSERT INTO lifetime_licenses (id, license_key, customer_email, customer_name) VALUES (?, ?, ?, ?)',
    [id, license_key, email, name || 'Test User'],
    function(err) {
      if (err) {
        console.error('Error adding lifetime license:', err);
        return res.status(500).json({ error: 'Failed to add license' });
      }
      
      console.log(`✅ Added lifetime license: ${license_key} for ${email}`);
      res.json({ 
        success: true, 
        message: 'Lifetime license added successfully',
        license_key: license_key,
        email: email
      });
    }
  );
});

// COMPREHENSIVE KEY GENERATOR - Generate any plan type
app.post('/admin/generate-key', (req, res) => {
  const { plan_type, email, name, custom_license_key, custom_expiry } = req.body;
  
  if (!plan_type || !email) {
    return res.status(400).json({ error: 'Plan type and email are required' });
  }
  
  if (!['lifetime', 'annual', 'monthly'].includes(plan_type)) {
    return res.status(400).json({ error: 'Invalid plan type. Must be: lifetime, annual, or monthly' });
  }
  
  // Use custom license key if provided, otherwise generate one
  let licenseKey;
  if (custom_license_key && custom_license_key.trim()) {
    licenseKey = custom_license_key.trim();
  } else {
    // Generate appropriate license key based on plan type
    if (plan_type === 'lifetime') {
      licenseKey = `ij_life_${crypto.randomBytes(16).toString('hex')}`;
    } else {
      licenseKey = `ij_sub_${crypto.randomBytes(16).toString('hex')}`;
    }
  }
  
  const id = uuidv4();
  
  if (plan_type === 'lifetime') {
    // Add to lifetime_licenses table
    db.run(
      'INSERT INTO lifetime_licenses (id, license_key, customer_email, customer_name) VALUES (?, ?, ?, ?)',
      [id, licenseKey, email, name || 'Admin Generated'],
      function(err) {
        if (err) {
          console.error('Error generating lifetime license:', err);
          return res.status(500).json({ error: 'Failed to generate license' });
        }
        
        console.log(`✅ Generated lifetime license: ${licenseKey} for ${email}`);
        res.json({ 
          success: true, 
          message: 'Lifetime license generated successfully',
          license_key: licenseKey,
          plan_type: plan_type,
          email: email
        });
      }
    );
  } else {
    // Add to subscription_licenses table (annual/monthly)
    let expiryDate;
    if (custom_expiry) {
      expiryDate = new Date(custom_expiry);
    } else {
      // Default expiry: 1 year for annual, 1 month for monthly
      const months = plan_type === 'annual' ? 12 : 1;
      expiryDate = new Date(Date.now() + months * 30 * 24 * 60 * 60 * 1000);
    }
    
    db.run(
      `INSERT INTO subscription_licenses (id, license_key, stripe_customer_id, stripe_subscription_id, plan_type, expires_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        id,
        licenseKey,
        'admin_generated', // Placeholder since no Stripe customer
        'admin_generated', // Placeholder since no Stripe subscription
        plan_type,
        expiryDate.toISOString()
      ],
      function(err) {
        if (err) {
          console.error('Error generating subscription license:', err);
          return res.status(500).json({ error: 'Failed to generate license' });
        }
        
        console.log(`✅ Generated ${plan_type} license: ${licenseKey} for ${email} (expires: ${expiryDate.toDateString()})`);
        res.json({ 
          success: true, 
          message: `${plan_type.charAt(0).toUpperCase() + plan_type.slice(1)} license generated successfully`,
          license_key: licenseKey,
          plan_type: plan_type,
          email: email,
          expires_at: expiryDate.toISOString()
        });
      }
    );
  }
});

// WEB ADMIN DASHBOARD - Main admin interface with app theme
app.get('/admin', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Isla Journal - Admin Dashboard</title>
      <style>
        @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;600;700&display=swap');
        
        body { 
          font-family: 'JetBrains Mono', 'Courier New', monospace; 
          margin: 0; 
          padding: 20px; 
          background: #F5F2E8;
          color: #1A1A1A;
          min-height: 100vh;
        }
        .container { 
          max-width: 1200px; 
          margin: 0 auto; 
          background: #EBE7D9;
          border-radius: 4px;
          border: 1px solid rgba(139, 90, 60, 0.3);
          overflow: hidden;
        }
        .header {
          background: #8B5A3C;
          color: #F5F2E8;
          padding: 30px;
          text-align: center;
        }
        .header h1 { 
          margin: 0; 
          font-size: 32px; 
          font-weight: 600;
        }
        .header p { 
          margin: 10px 0 0 0; 
          opacity: 0.9;
          font-size: 16px;
        }
        .nav {
          display: flex;
          flex-wrap: wrap;
          gap: 15px;
          padding: 30px;
          justify-content: center;
          background: #F5F2E8;
        }
        .nav-item {
          background: #8B5A3C;
          color: #F5F2E8;
          padding: 15px 25px;
          text-decoration: none;
          border-radius: 4px;
          font-weight: 500;
          transition: all 0.2s ease;
          border: 1px solid rgba(139, 90, 60, 0.3);
        }
        .nav-item:hover {
          background: #A0664B;
          transform: translateY(-1px);
        }
        .generate-section {
          padding: 30px;
          background: #F5F2E8;
        }
        .generate-section h2 {
          color: #1A1A1A;
          margin-bottom: 20px;
          font-size: 24px;
          font-weight: 600;
        }
        .key-generator {
          background: #EBE7D9;
          border: 1px solid rgba(139, 90, 60, 0.3);
          border-radius: 4px;
          padding: 25px;
          margin-bottom: 20px;
        }
        .form-row {
          display: flex;
          gap: 15px;
          margin-bottom: 15px;
          flex-wrap: wrap;
        }
        .form-group {
          flex: 1;
          min-width: 200px;
        }
        label {
          display: block;
          margin-bottom: 5px;
          font-weight: 500;
          color: #1A1A1A;
          font-family: 'JetBrains Mono', monospace;
        }
        input, select {
          width: 100%;
          padding: 12px;
          border: 1px solid rgba(139, 90, 60, 0.3);
          border-radius: 4px;
          font-size: 14px;
          font-family: 'JetBrains Mono', monospace;
          background: #F5F2E8;
          color: #1A1A1A;
          box-sizing: border-box;
        }
        input:focus, select:focus {
          outline: none;
          border-color: #8B5A3C;
          box-shadow: 0 0 0 2px rgba(139, 90, 60, 0.2);
        }
        .generate-btn {
          background: #8B5A3C;
          color: #F5F2E8;
          border: none;
          padding: 12px 30px;
          border-radius: 4px;
          cursor: pointer;
          font-size: 16px;
          font-weight: 500;
          font-family: 'JetBrains Mono', monospace;
          transition: all 0.2s ease;
          border: 1px solid rgba(139, 90, 60, 0.3);
        }
        .generate-btn:hover {
          background: #A0664B;
          transform: translateY(-1px);
        }
        .result {
          margin-top: 20px;
          padding: 15px;
          border-radius: 4px;
          display: none;
          font-family: 'JetBrains Mono', monospace;
        }
        .success {
          background: #d4edda;
          border: 1px solid #c3e6cb;
          color: #155724;
        }
        .error {
          background: #f8d7da;
          border: 1px solid #f5c6cb;
          color: #721c24;
        }
        .license-key {
          font-family: 'JetBrains Mono', monospace;
          font-size: 14px;
          font-weight: bold;
          background: #F5F2E8;
          padding: 12px;
          border-radius: 4px;
          margin: 10px 0;
          word-break: break-all;
          border: 1px solid rgba(139, 90, 60, 0.3);
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🔑 Isla Journal Admin</h1>
          <p>License Key Management Dashboard</p>
        </div>
        
        <div class="nav">
          <a href="/admin/customers" class="nav-item">👥 Manage Customers</a>
          <a href="/admin/stats" class="nav-item">📊 Statistics</a>
        </div>
        
        <div class="generate-section">
          <h2>🚀 Generate New License Key</h2>
          
          <div class="key-generator">
            <form id="generateForm">
              <div class="form-row">
                <div class="form-group">
                  <label for="planType">Plan Type *</label>
                  <select id="planType" required>
                    <option value="">Select Plan Type</option>
                    <option value="lifetime">💎 Lifetime ($99)</option>
                    <option value="annual">📅 Annual ($50/year)</option>
                    <option value="monthly">📊 Monthly ($5/month)</option>
                  </select>
                </div>
                <div class="form-group">
                  <label for="email">Customer Email *</label>
                  <input type="email" id="email" required placeholder="customer@example.com">
                </div>
              </div>
              
              <div class="form-row">
                <div class="form-group">
                  <label for="name">Customer Name</label>
                  <input type="text" id="name" placeholder="Customer Name (optional)">
                </div>
                <div class="form-group">
                  <label for="customLicense">Custom License Key (optional)</label>
                  <input type="text" id="customLicense" placeholder="Leave blank to auto-generate">
                </div>
              </div>
              
              <div class="form-row">
                <div class="form-group" id="expiryGroup" style="display: none;">
                  <label for="customExpiry">Custom Expiry Date</label>
                  <input type="date" id="customExpiry" placeholder="Leave blank for default">
                </div>
              </div>
              
              <button type="submit" class="generate-btn">✨ Generate License Key</button>
            </form>
            
            <div id="result" class="result"></div>
          </div>
        </div>
      </div>
      
      <script>
        // Show/hide expiry date field based on plan type
        document.getElementById('planType').addEventListener('change', function() {
          const expiryGroup = document.getElementById('expiryGroup');
          if (this.value === 'annual' || this.value === 'monthly') {
            expiryGroup.style.display = 'block';
          } else {
            expiryGroup.style.display = 'none';
          }
        });
        
        // Handle form submission
        document.getElementById('generateForm').addEventListener('submit', async function(e) {
          e.preventDefault();
          
          const resultDiv = document.getElementById('result');
          const formData = {
            plan_type: document.getElementById('planType').value,
            email: document.getElementById('email').value,
            name: document.getElementById('name').value,
            custom_license_key: document.getElementById('customLicense').value,
            custom_expiry: document.getElementById('customExpiry').value
          };
          
          try {
            const response = await fetch('/admin/generate-key', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(formData)
            });
            
            const data = await response.json();
            
            if (data.success) {
              resultDiv.className = 'result success';
              resultDiv.innerHTML = \`
                <h3>✅ \${data.message}</h3>
                <p><strong>License Key:</strong></p>
                <div class="license-key">\${data.license_key}</div>
                <p><strong>Email:</strong> \${data.email}</p>
                <p><strong>Plan:</strong> \${data.plan_type.charAt(0).toUpperCase() + data.plan_type.slice(1)}</p>
                \${data.expires_at ? \`<p><strong>Expires:</strong> \${new Date(data.expires_at).toLocaleDateString()}</p>\` : ''}
              \`;
            } else {
              resultDiv.className = 'result error';
              resultDiv.innerHTML = \`<h3>❌ Error</h3><p>\${data.error}</p>\`;
            }
            
            resultDiv.style.display = 'block';
            
          } catch (error) {
            resultDiv.className = 'result error';
            resultDiv.innerHTML = \`<h3>❌ Network Error</h3><p>\${error.message}</p>\`;
            resultDiv.style.display = 'block';
          }
        });
      </script>
    </body>
    </html>
  `);
});

// Success page (web)
app.get('/success', async (req, res) => {
  const { session_id } = req.query;
  
  if (!session_id) {
    return res.send(`
      <html>
        <head>
          <title>Isla Journal - Error</title>
          <style>
            body { font-family: 'Courier New', monospace; padding: 40px; background: #f5f5dc; color: #333; max-width: 600px; margin: 0 auto; }
            .error { background: #ffe6e6; padding: 20px; border-radius: 8px; border: 1px solid #ff9999; }
          </style>
        </head>
        <body>
          <div class="error">
            <h2>❌ Error</h2>
            <p>No session ID provided. Please contact support.</p>
          </div>
        </body>
      </html>
    `);
  }
  
  try {
    // Get session from Stripe
    const session = await stripe.checkout.sessions.retrieve(session_id);
    
    if (!session || session.payment_status !== 'paid') {
      return res.send(`
        <html>
          <head>
            <title>Isla Journal - Payment Pending</title>
            <style>
              body { font-family: 'Courier New', monospace; padding: 40px; background: #f5f5dc; color: #333; max-width: 600px; margin: 0 auto; }
              .warning { background: #fff3cd; padding: 20px; border-radius: 8px; border: 1px solid #ffeaa7; }
            </style>
          </head>
          <body>
            <div class="warning">
              <h2>⏳ Payment Processing</h2>
              <p>Your payment is still being processed. Please check back in a few minutes.</p>
            </div>
          </body>
        </html>
      `);
    }

    let licenseKey = null;
    let licenseType = session.metadata.plan_type;

    // Get license key based on purchase type
    if (session.mode === 'payment' && session.metadata.plan_type === 'lifetime') {
      const customer = await stripe.customers.retrieve(session.customer);
      const row = await new Promise((resolve, reject) => {
        db.get(
          'SELECT license_key FROM lifetime_licenses WHERE customer_email = ? ORDER BY granted_at DESC LIMIT 1',
          [customer.email],
          (err, row) => {
            if (err) reject(err);
            else resolve(row);
          }
        );
      });
      if (row) licenseKey = row.license_key;
    } else if (session.mode === 'subscription') {
      const row = await new Promise((resolve, reject) => {
        db.get(
          'SELECT license_key FROM subscription_licenses WHERE stripe_customer_id = ? ORDER BY created_at DESC LIMIT 1',
          [session.customer],
          (err, row) => {
            if (err) reject(err);
            else resolve(row);
          }
        );
      });
      if (row) licenseKey = row.license_key;
    }

    if (!licenseKey) {
      return res.send(`
        <html>
          <head>
            <title>Isla Journal - License Not Found</title>
            <style>
              body { font-family: 'Courier New', monospace; padding: 40px; background: #f5f5dc; color: #333; max-width: 600px; margin: 0 auto; }
              .error { background: #ffe6e6; padding: 20px; border-radius: 8px; border: 1px solid #ff9999; }
              .portal-link { background: #8B4513; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 16px; }
            </style>
          </head>
          <body>
            <div class="error">
              <h2>🔍 License Key Not Found</h2>
              <p>We couldn't find your license key. Don't worry - you can find it in your customer portal:</p>
              <a href="https://billing.stripe.com/p/login/cNieVc50A7yGfkv4BQ73G00" class="portal-link">Open Customer Portal</a>
            </div>
          </body>
        </html>
      `);
    }

    // Success page with license key
    res.send(`
      <html>
        <head>
          <title>Isla Journal - Purchase Successful!</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { 
              font-family: 'Courier New', monospace; 
              padding: 20px; 
              background: #f5f5dc; 
              color: #333; 
              max-width: 600px; 
              margin: 0 auto; 
              line-height: 1.6;
            }
            .success { 
              background: #e6ffe6; 
              padding: 30px; 
              border-radius: 12px; 
              border: 2px solid #4CAF50; 
              text-align: center; 
              margin-bottom: 20px;
            }
            .key-box { 
              background: #8B4513; 
              color: white; 
              padding: 20px; 
              border-radius: 8px; 
              margin: 20px 0; 
              word-break: break-all;
            }
            .copy-btn { 
              background: #4CAF50; 
              color: white; 
              border: none; 
              padding: 12px 24px; 
              border-radius: 6px; 
              cursor: pointer; 
              font-family: 'Courier New'; 
              font-size: 14px;
              margin: 10px 5px;
            }
            .copy-btn:hover { background: #45a049; }
            .portal-link { 
              background: #8B4513; 
              color: white; 
              padding: 12px 24px; 
              text-decoration: none; 
              border-radius: 6px; 
              display: inline-block; 
              margin: 10px 5px;
            }
            .instructions { 
              background: #fff; 
              padding: 20px; 
              border-radius: 8px; 
              border: 1px solid #ddd; 
              margin-top: 20px;
            }
            .emoji { font-size: 2em; margin-bottom: 10px; }
          </style>
        </head>
        <body>
          <div class="success">
            <div class="emoji">🎉</div>
            <h1>Purchase Successful!</h1>
            <p>Welcome to <strong>${licenseType.toUpperCase()}</strong> journaling!</p>
          </div>

          <div class="key-box">
            <h3>🔑 Your License Key:</h3>
            <div id="license-key" style="font-size: 16px; font-weight: bold; margin: 15px 0;">
              ${licenseKey}
            </div>
            <button class="copy-btn" onclick="copyKey()">📋 Copy Key</button>
          </div>

          <div class="instructions">
            <h3>📱 How to Activate:</h3>
            <ol>
              <li>Open the Isla Journal app</li>
              <li>Go to <strong>Settings</strong></li>
              <li>Enter your license key above</li>
              <li>Start journaling! ✨</li>
            </ol>
          </div>

          <div style="text-align: center; margin-top: 30px;">
            <a href="https://billing.stripe.com/p/login/cNieVc50A7yGfkv4BQ73G00" class="portal-link">
              Customer Portal
            </a>
          </div>

          <script>
            function copyKey() {
              const keyText = document.getElementById('license-key').textContent.trim();
              navigator.clipboard.writeText(keyText).then(() => {
                const btn = document.querySelector('.copy-btn');
                const originalText = btn.textContent;
                btn.textContent = '✅ Copied!';
                btn.style.background = '#4CAF50';
                setTimeout(() => {
                  btn.textContent = originalText;
                  btn.style.background = '#4CAF50';
                }, 2000);
              }).catch(() => {
                // Fallback for older browsers
                const textArea = document.createElement('textarea');
                textArea.value = keyText;
                document.body.appendChild(textArea);
                textArea.select();
                document.execCommand('copy');
                document.body.removeChild(textArea);
                alert('License key copied!');
              });
            }
          </script>
        </body>
      </html>
    `);

  } catch (error) {
    console.error('Error in success page:', error);
    res.send(`
      <html>
        <head>
          <title>Isla Journal - Error</title>
          <style>
            body { font-family: 'Courier New', monospace; padding: 40px; background: #f5f5dc; color: #333; max-width: 600px; margin: 0 auto; }
            .error { background: #ffe6e6; padding: 20px; border-radius: 8px; border: 1px solid #ff9999; }
          </style>
        </head>
        <body>
          <div class="error">
            <h2>❌ Error</h2>
            <p>Something went wrong. Please contact support or check your customer portal.</p>
          </div>
        </body>
      </html>
    `);
  }
});

// UNIFIED CUSTOMERS MANAGEMENT INTERFACE
app.get('/admin/customers', (req, res) => {
  // Combine lifetime and subscription customers
  const query = `
    SELECT 
      customer_email,
      customer_name,
      license_key,
      'lifetime' as license_type,
      'lifetime' as plan_type,
      status,
      granted_at as created_at,
      NULL as expires_at
    FROM lifetime_licenses
    
    UNION ALL
    
    SELECT 
      customer_email,
      customer_name,
      license_key,
      'subscription' as license_type,
      plan_type,
      status,
      created_at,
      expires_at
    FROM subscription_licenses
    
    ORDER BY created_at DESC
  `;
  
  db.all(query, (err, rows) => {
    if (err) {
      return res.status(500).send('<h1>Database Error</h1><p>' + err.message + '</p>');
    }
    
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Customer Management - Isla Journal</title>
        <style>
          @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;600;700&display=swap');
          
          body { 
            font-family: 'JetBrains Mono', 'Courier New', monospace; 
            margin: 0; 
            padding: 20px; 
            background: #F5F2E8;
            color: #1A1A1A;
          }
          .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            background: #EBE7D9;
            border-radius: 4px;
            border: 1px solid rgba(139, 90, 60, 0.3);
          }
          .header {
            background: #8B5A3C;
            color: #F5F2E8;
            padding: 30px;
            text-align: center;
          }
          .header h1 { 
            margin: 0; 
            font-size: 32px; 
            font-weight: 600;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            background: #F5F2E8;
          }
          th, td {
            padding: 15px;
            text-align: left;
            border-bottom: 1px solid rgba(139, 90, 60, 0.2);
            font-family: 'JetBrains Mono', monospace;
          }
          th {
            background: #8B5A3C;
            color: #F5F2E8;
            font-weight: 600;
          }
          .license-key {
            font-family: 'JetBrains Mono', monospace;
            font-size: 14px;
            background: #EBE7D9;
            padding: 8px;
            border-radius: 4px;
            word-break: break-all;
          }
          .btn {
            padding: 8px 12px;
            margin: 2px;
            border: 1px solid rgba(139, 90, 60, 0.3);
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            font-family: 'JetBrains Mono', monospace;
          }
          .btn-edit {
            background: #8B5A3C;
            color: #F5F2E8;
          }
          .btn-delete {
            background: #CC4125;
            color: #F5F2E8;
          }
          .btn-toggle {
            background: #EBE7D9;
            color: #1A1A1A;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>👥 Customer Management</h1>
            <p>Total: ${rows.length} customers</p>
          </div>
          
          <table>
            <thead>
              <tr>
                <th>Customer</th>
                <th>Type</th>
                <th>License Key</th>
                <th>Status</th>
                <th>Expires</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              ${rows.map(row => `
                <tr>
                  <td>
                    <strong>${row.customer_email || 'Unknown'}</strong>
                    ${row.customer_name ? '<br><small>' + row.customer_name + '</small>' : ''}
                  </td>
                  <td>
                    <span style="padding: 4px 8px; border-radius: 6px; font-size: 12px; font-weight: 600; ${row.license_type === 'lifetime' ? 'background: #fef3c7; color: #92400e;' : 'background: #dbeafe; color: #1e40af;'}">
                      ${row.license_type === 'lifetime' ? '💎 Lifetime' : '🔄 ' + row.plan_type}
                    </span>
                  </td>
                  <td>
                    <div class="license-key">${row.license_key.substring(0, 20)}...</div>
                  </td>
                  <td>
                    <span style="color: ${row.status === 'active' ? '#2D5016' : '#8B0000'}; font-weight: 600;">
                      ${row.status === 'active' ? '✅ Active' : '❌ Inactive'}
                    </span>
                  </td>
                  <td>${row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '<span style="color: #10b981;">Never</span>'}</td>
                  <td>${new Date(row.created_at).toLocaleDateString()}</td>
                  <td>
                    <button class="btn btn-edit" onclick="editCustomer('${row.license_key}', '${row.license_type}', '${row.customer_email}', '${row.customer_name || ''}')">
                      ✏️ Edit
                    </button>
                    <button class="btn btn-toggle" onclick="toggleStatus('${row.license_key}', '${row.license_type}', '${row.customer_email}', '${row.status}')">
                      ${row.status === 'active' ? '⏸️ Deactivate' : '▶️ Activate'}
                    </button>
                    <button class="btn btn-delete" onclick="deleteCustomer('${row.license_key}', '${row.license_type}', '${row.customer_email}')">
                      🗑️ Delete
                    </button>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
        
        <script>
          function editCustomer(licenseKey, licenseType, email, name) {
            const newName = prompt('Edit customer name:', name);
            const newKey = prompt('Edit license key:', licenseKey);
            
            if (newName !== null && newKey !== null) {
              const endpoint = licenseType === 'lifetime' 
                ? '/admin/lifetime-license/' + encodeURIComponent(email)
                : '/admin/subscription-license/' + encodeURIComponent(licenseKey);
              
              fetch(endpoint, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ customer_name: newName, license_key: newKey })
              }).then(response => response.json()).then(result => {
                if (result.success) {
                  alert('✅ Updated successfully!');
                  location.reload();
                } else {
                  alert('❌ Error: ' + result.error);
                }
              });
            }
          }
          
          function toggleStatus(licenseKey, licenseType, email, currentStatus) {
            const action = currentStatus === 'active' ? 'deactivate' : 'activate';
            if (!confirm('Are you sure you want to ' + action + ' this license?')) return;
            
            const endpoint = licenseType === 'lifetime' 
              ? '/admin/lifetime-license/' + encodeURIComponent(email) + '/toggle-status'
              : '/admin/subscription-license/' + encodeURIComponent(licenseKey) + '/toggle-status';
            
            fetch(endpoint, { method: 'POST' }).then(response => response.json()).then(result => {
              if (result.success) {
                alert('✅ Status updated!');
                location.reload();
              } else {
                alert('❌ Error: ' + result.error);
              }
            });
          }
          
          function deleteCustomer(licenseKey, licenseType, email) {
            if (!confirm('⚠️ Are you sure you want to DELETE this customer? This cannot be undone!')) return;
            
            const endpoint = licenseType === 'lifetime' 
              ? '/admin/lifetime-license/' + encodeURIComponent(email)
              : '/admin/subscription-license/' + encodeURIComponent(licenseKey);
            
            fetch(endpoint, { method: 'DELETE' }).then(response => response.json()).then(result => {
              if (result.success) {
                alert('✅ Customer deleted!');
                location.reload();
              } else {
                alert('❌ Error: ' + result.error);
              }
            });
          }
        </script>
      </body>
      </html>
    `);
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Isla Journal Backend running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/`);
  console.log(`🔑 Admin endpoint: http://localhost:${PORT}/admin/lifetime-licenses`);
});

module.exports = app; // Force deployment trigger
console.log('✅ Railway deployment active');

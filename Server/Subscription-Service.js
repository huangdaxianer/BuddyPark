const express = require('express');
const admin = require('firebase-admin');
const fetch = require('node-fetch');
const jwt = require('jsonwebtoken');
const jwkToPem = require('jwk-to-pem');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const axios = require('axios');

const app = express();

// 初始化 Firebase
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
const serviceAccountParsed = JSON.parse(serviceAccount);
admin.initializeApp({
credential: admin.credential.cert(serviceAccountParsed),
databaseURL: "https://my-money-387707-default-rtdb.asia-southeast1.firebasedatabase.app"
});

const cors = require('cors');
app.use(cors());

app.use(bodyParser.json());

async function getUserSubscriptionStatus(userIdentifier) {
    const db = admin.database();
    const ref = db.ref('users/' + userIdentifier);
    const snapshot = await ref.once('value');
    return snapshot.val();
}

app.post('/verify-receipt', async (req, res) => {
    const receiptData = req.body.receiptData; // 获取收据数据
    const userIdentifier = req.body.userIdentifier; // 获取用户标识符
    
    if (!receiptData || !userIdentifier) {
        console.log('Missing receipt data or user identifier');
        res.status(400).send('Missing receipt data or user identifier');
        return;
    }
    
    try {
        // 使用收据数据发送请求到 Apple 的验证收据 API
        const response = await axios.post(`https://sandbox.itunes.apple.com/verifyReceipt`, {
            'receipt-data': receiptData,
            'password': 'c879d8cf448d41a784b73883b275a53a'  // 你的应用的共享密钥，你可以在 App Store Connect 中找到
        });
        
        console.log('Response data:', response.data);
        
        if (!response.data.receipt.in_app || response.data.receipt.in_app.length === 0) {
            // 如果没有找到对应的订阅信息，那么我们可以认为用户当前不是订阅状态
            res.status(402).send('No subscription found for user');
            return;
        }
        
        const subscription = response.data.receipt.in_app[0]; // 获取订阅信息
        const originalTransactionId = subscription.original_transaction_id; // 获取 original_transaction_id
        const latestReceiptInfo = response.data.latest_receipt_info[0];
        const isTrialPeriod = latestReceiptInfo.is_trial_period === 'true';
        
        const db = admin.database();
        const ref = db.ref('users/' + userIdentifier);
        
        const userSubscriptionStatus = await getUserSubscriptionStatus(userIdentifier);
        const hasUsedTrial = userSubscriptionStatus.hasUsedTrial;
        
        // 如果用户试用过并且收据仍然表示试用，那么订阅失败
        if (hasUsedTrial === true && isTrialPeriod) {
            console.log('User already used trial, subscription failed');
            res.status(402).send('Subscription failed: user already used trial');
            return;
        }
        
        const purchaseDateMs = parseInt(latestReceiptInfo.purchase_date_ms, 10);
        const newExpiresDate = isTrialPeriod ? purchaseDateMs + 3 * 24 * 60 * 60 * 1000 : purchaseDateMs + 7 * 24 * 60 * 60 * 1000;
        
        // 更新 Firebase 中的字段
        const updates = {
            'isSubscribed': true,
            'expiresDate': newExpiresDate,
            'isTrialPeriod': isTrialPeriod,
            'originalTransactionId': originalTransactionId // 新增 original_transaction_id
        };
        if (isTrialPeriod) {
            updates['hasUsedTrial'] = true;
        }
        await ref.update(updates);
        console.log("ccccc");
        res.json({
            success: true,
            receipt: receiptData,
            isTrialPeriod: isTrialPeriod
        });
    } catch (error) {
        console.log('Subscription verification failed:', error);
        res.status(403).send('Subscription verification failed');
    }
});


app.get('/subscription-status/:userIdentifier', async (req, res) => {
    try {
        const userIdentifier = req.params.userIdentifier;
        if (!userIdentifier) {
            res.status(400).send('Missing user identifier');
            return;
        }

        const subscriptionStatus = await getUserSubscriptionStatus(userIdentifier);
        console.log('Subscription Status:', JSON.stringify(subscriptionStatus));

        res.json({
            success: true,
            subscriptionStatus: subscriptionStatus
        });
    } catch (error) {
        console.log('Failed to get subscription status:', error);
        res.status(500).send('Failed to get subscription status');
    }
});

function checkTrialPeriod(inApp) {
    const latestReceiptInfo = inApp[inApp.length - 1];
    return latestReceiptInfo.is_trial_period === 'true';
}


app.use(function(err, req, res, next) {
    console.error(err);
    res.status(500).send('Internal Serverless Error');
});

const port = process.env.PORT || 9000;
app.listen(port, () => {
    console.log(`Server start on http://localhost:${port}`);
});


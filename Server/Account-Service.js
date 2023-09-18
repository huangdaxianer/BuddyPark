const express = require('express');
const admin = require('firebase-admin');
const fetch = require('node-fetch');
const jwt = require('jsonwebtoken');
const jwkToPem = require('jwk-to-pem');
const bodyParser = require('body-parser');
const crypto = require('crypto');

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

function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
        var r = Math.random() * 16 | 0,
            v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

function hashWithSHA256(data) {
    const hash = crypto.createHash('sha256');
    hash.update(data);
    return hash.digest('hex');
}

app.all('/auth', async (req, res) => {
    try {
        const identityToken = req.body.identityToken;
        
        // 获取 Apple 的公开公钥
        const response = await fetch('https://appleid.apple.com/auth/keys');
        const applePublicKeys = await response.json();

        const header = jwt.decode(identityToken, { complete: true }).header;

        const applePublicKey = applePublicKeys.keys.find(
            key => key.kid === header.kid
        );
        const pem = jwkToPem(applePublicKey);
        
        // 验证 JWT
        const decoded = jwt.verify(identityToken, pem);
        const userIdentifier = decoded.sub;

        const hashedUserIdentifier = hashWithSHA256(userIdentifier);

        const db = admin.database();
        const ref = db.ref('users/' + hashedUserIdentifier);
        const userSnapshot = await ref.once('value');
        const userData = userSnapshot.val();

        if (userData) {
            return res.json({
                success: true,
                uuid: hashedUserIdentifier,
                isNewUser: false,
                freeMessageLeft: userData.freeMessageLeft
            });
        } else {
            const creationTimestamp = Date.now();
            const freeMessageLeftValue = parseInt(process.env.FREE_MESSAGE_LEFT, 10) || 20;

            await ref.set({
                'sub': userIdentifier,
                'creationTime': creationTimestamp,
                'isTrialPeriod': false,
                'isSubscribed': false,
                'expiresDate': 0,
                'hasUsedTrial': false,
                'freeMessageLeft': freeMessageLeftValue
            });

            return res.json({
                success: true,
                uuid: hashedUserIdentifier,
                isNewUser: true,
                freeMessageLeft: freeMessageLeftValue
            });
        }
    } catch (error) {
        console.log('Token validation failed:', error);
        return res.status(400).send('Invalid identityToken');
    }
});


app.use(function(err, req, res, next) {
    console.error(err);
    res.status(500).send('Internal Serverless Error');
});

const port = process.env.PORT || 9000;
app.listen(port, () => {
    console.log(`Server start on http://localhost:${port}`);
});

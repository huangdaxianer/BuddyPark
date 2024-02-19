const express = require('express')
const jwt = require('jsonwebtoken');
const jwkToPem = require('jwk-to-pem');
const fetch = require('cross-fetch')
const crypto = require('crypto');


const app = express()
var multer = require('multer');
var forms = multer({limits: { fieldSize: 10*1024*1024 }});
var admin = require('firebase-admin');


admin.initializeApp({
  databaseURL: "https://my-money-387707-default-rtdb.asia-southeast1.firebasedatabase.app"
});

app.use(forms.array());
const cors = require('cors');
app.use(cors());

const bodyParser = require('body-parser')
app.use(bodyParser.json({limit : '50mb' }));
app.use(bodyParser.urlencoded({ extended: true }));

const controller = new AbortController();
const apn = require('apn');
const apnsOptions = {
token: {
key: "AuthKey_FYMB5T6F5B.p8",  // 替换为你的 .p8 文件路径
keyId: "FYMB5T6F5B",  // 这是你的 Key ID
teamId: "4R46BG4QL5" // 替换为你的 Team ID
},
production: process.env.NODE_ENV === 'production' // 根据实际情况设置为 true 或者 false
};

let provider = new apn.Provider(apnsOptions);

const { v4: uuidv4 } = require('uuid');

app.all('/sendMessage', async (req, res) => {
    
   const openai_key = process.env.OPENAI_KEY;
    const messageUUID = uuidv4();
    let isClientDisconnected = false;
    let url = `https://api.openai.com/v1/chat/completions`;
    const requestType = req.headers["x-request-type"];
    const dialogueID = req.headers['x-dialogueid'];
    const characterID = req.headers['x-characterid'];
    const userID = req.headers['x-userid'];
    const deviceToken = req.headers['x-device-token'];

    if (process.env.PROXY_KEY && req.headers.authorization !== process.env.PROXY_KEY) {
        return res.status(403).send('Forbidden');
    }

    // 获取角色数据
    const characterData = await getCharacterData(characterID);

    const userData = await getUserData(userID);
    console.log('userid is:', userID);

    if (!userData) {
        // 如果没有找到用户数据，返回错误消息或进行其他处理
        console.error('No user data found for userID:', userID);
        return res.status(404).json({ error: "User data not found" });
    }
    // 根据用户和角色数据构造用户信息prompt
    const userPrompt = constructUserPrompt(userData);
    console.log('Constructed user prompt:', userPrompt);

    // 获取环境变量中定义的额外prompt
    const extraPrompt = process.env.EXTRA_PROMPT || '这是一个额外的提示。';


    // 根据请求类型构造完整的prompt
        var fullPrompt;

    if (requestType === "new-message") {
        // 对于new-message类型，prompt由三部分组成
        let messages = req.body.messages || [];
        fullPrompt = `${characterData.prompt} ${userPrompt} ${extraPrompt}`;
        await saveTemporaryResultToStorage(dialogueID, deviceToken, characterID, messages, fullPrompt, requestType, messageUUID);
    } else if (requestType === "remote-push") {
        // 对于remote-push类型，保留现有逻辑
        let messages = req.body.messages || [];
        fullPrompt = messages[0].content + prompt;
        await saveTemporaryResultToStorage(dialogueID, deviceToken, characterID, messages, fullPrompt, requestType, messageUUID);
    } else if (requestType === "app-restart") {
        // 对于app-restart类型，保留现有逻辑
        try {
            const lastUserReply = await getLastUserReplyFromFirebase(dialogueID);
            await sendLastAssistantReply(dialogueID, res);
            return; // 退出函数，因为已经发送了响应
        } catch (error) {
            console.error('Error occurred:', error);
            return res.status(500).json({ error: "Internal Server Error" });
        }
    }

    var systemMessage, prompt, characterName;

    if (characterData && characterData.prompt) {
        prompt = characterData.prompt;
        characterName = characterData.characterName;
        systemMessage = {
            role: "system",
            content: fullPrompt
        };
    } else {
        return res.status(404).json({ error: "Prompt not found for character ID: " + characterID });
    }



    //options 是一个请求体的样子
    const options = {
    method: req.method,
    timeout: process.env.TIMEOUT||30000,
    signal: controller.signal,
    headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer '+ openai_key,
    }
    };
    
    var usersReply;//用于定义用户发的最后一条消息
    if (req.method.toLocaleLowerCase() === 'post' && req.body) {
        let messages = req.body.messages || [];
        const maxTotalMessages = parseInt(process.env.MAX_TOTAL_MESSAGES || 40);
        const maxAssistantMessages = parseInt(process.env.MAX_ASSISTANT_MESSAGES || 20);

        // Determine which model to use based on the length of messages
        if (messages.length < 100) {
            req.body.model = 'gpt-4';
        } else if (messages.length >= 5 && messages.length <= maxTotalMessages) {
            req.body.model = 'gpt-3.5-turbo';
        } else {
            req.body.model = 'gpt-3.5-turbo';

            let assistantMessages = messages.filter(message => message.role === 'assistant').reverse().slice(0, maxAssistantMessages).reverse();
            let otherMessages = messages.filter(message => message.role !== 'assistant');
            messages = [...otherMessages, ...assistantMessages].sort((a, b) => a.timestamp - b.timestamp);

            const firstAssistantIndex = messages.findIndex(message => message.role === 'assistant');
            messages = firstAssistantIndex > 0 ? messages.slice(firstAssistantIndex) : messages;
        }
        
        const lastUserMessage = messages.slice().reverse().find(message => message.role === 'user');
        usersReply = lastUserMessage ? lastUserMessage.content : null;
        messages = messages.map(({timestamp, ...message}) => message);
        req.body.messages = [systemMessage, ...messages];

        options.body = JSON.stringify(req.body);
        console.log('Modified messages:', req.body.messages);
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    try {
        let delayTime = process.env.DELAY_TIME || 3000; // If the environment variable is not set, default to 3000
        delayTime = parseInt(delayTime, 10); // Convert the value to a number if it's a string
        await new Promise(resolve => setTimeout(resolve, delayTime));
        const lastUserReply = await getLastUserReplyFromFirebase(dialogueID);
        const lastMessageFromReq = req.body.messages && req.body.messages.length > 0 ? req.body.messages[req.body.messages.length - 1].content : null;

        if (lastUserReply !== lastMessageFromReq ) {
            console.log('User reply mismatch. Exiting function.', lastUserReply, lastMessageFromReq);
            return;
        }
        
        //检查订阅状态，如果超过免费消息数就退出
        //        const userStatus = await getUserStatusFromFirebase(userID, requestType); // 使用合适的userID
        //        if (userStatus === 0 && requestType === "new-message") {
        //            console.log('Free message limit reached. Exiting function.');
        //            return;
        //        }

        const response = await fetch(url, options);
        let chunks = [];
        let notificationPromises = [];

        const handleData = async (chunk) => {
            chunks.push(chunk);
            let chunkString = chunk.toString();
            // 保留分隔符
            let messagesAndSeparators = chunkString.split(/(#|"content": "|\"\n      },\n      "finish_reason")/);
            let fullText = ""; // 初始化一个空的 fullText，用来存放所有拆分过的消息

            for (let i = 0; i < messagesAndSeparators.length - 1; i += 2) {

                let message = messagesAndSeparators[i];
                // 检查 message 是否包含 "role":"assistant" 或 "prompt_tokens"

                if (message.includes('"role": "assistant",') || message.includes('"prompt_tokens"') || message.includes("{") || message.includes("}")) {
                    continue;
                }
                message = message.replace(/\"\s*},\s*$/, '');
                message = message.trim();
                // 根据下一个分隔符判断是否需要添加井号
                let separator = messagesAndSeparators[i + 1];
                let addSeparator = separator === '#';
                // 更新 fullText 为包含所有拆分过的消息
                fullText += message + (addSeparator ? "#" : "");
                
                const lastUserReply = await getLastUserReplyFromFirebase(dialogueID);
                const lastMessageFromReq = req.body.messages && req.body.messages.length > 0 ? req.body.messages[req.body.messages.length - 1].content : null;
                if (lastUserReply !== lastMessageFromReq) {
                    console.log('User reply mismatch. Exiting function.', lastUserReply, lastMessageFromReq);
                    throw new Error('User reply mismatch'); //使用异常来退出函数
                }
                notificationPromises.push(pushNotification(deviceToken, message, usersReply, fullText, characterID, characterName, messageUUID));
                console.log('should have pushed notification', deviceToken, message, usersReply, fullText, characterID);
                await sleep(3000);
            }
        };

        response.body.on('data', (chunk) => {
            handleData(chunk).catch(err => {
                console.error(err);
                // 这里可以处理错误，例如关闭连接或者发送一个错误消息
            });
        });

        response.body.on('end', async () => {
            try {
                let data = Buffer.concat(chunks).toString();
                console.log("Received data: ", data);  // 打印原始响应数据
                
                data = JSON.parse(data);  // 尝试解析 JSON 数据
                if (data.choices && data.choices.length > 0 && data.choices[0].message && data.choices[0].message.content) {
                    // 现在您可以安全地使用 data.choices[0].message.content
                    await Promise.all(notificationPromises);
                    let localMessages = req.body.messages || [];
                    await saveResultToStorage(dialogueID, deviceToken, data, characterID, localMessages, fullPrompt, requestType, messageUUID);
                } else {
                    // 数据不符合预期格式，打印错误信息
                    console.error("Unexpected response structure: ", data);
                }
            } catch (error) {
                console.error("Error parsing response data: ", error);
                // 如果客户端已断开连接，不执行 res.status(500).json() 操作
                if (!isClientDisconnected) {
                    res.status(500).json({ "error": error.toString() });
                }
            }
        });


    } catch (error) {
        console.error(error);
        
        // 如果客户端已断开连接，不执行 res.status(500).json() 操作
        if(!isClientDisconnected) {
            res.status(500).json({"error":error.toString()});
        }
    }
})

function hashWithSHA256(data) {
    const hash = crypto.createHash('sha256');
    hash.update(data);
    return hash.digest('hex');
}


// 根据角色ID获取角色数据的函数
async function getCharacterData(characterID) {
    const db = admin.database();
    const ref = db.ref('Character/' + characterID);
    const snapshot = await ref.once('value');
    return snapshot.val();
}

// 获取用户数据的函数
async function getUserData(userID) {
    const db = admin.database();
    const ref = db.ref('users/' + userID);
    const snapshot = await ref.once('value');
    return snapshot.val();
}

// 构造用户信息prompt的函数
function constructUserPrompt({userName, userBio, userGender, roleGender}) {
    const genderPronoun = userGender === "male" ? "他" : "她";
    const rolePreference = roleGender === "male" ? "男生" : "女生";
    return `正在和你聊天的人叫${userName}，${genderPronoun}的自我介绍是${userBio}，${genderPronoun}喜欢${rolePreference}。`;
}


function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function getLastUserReplyFromFirebase(dialogueID) {
    try {
        const ref = admin.database().ref('results/' + dialogueID);
        let lastUserMessage = null;
        
        await ref.once('value', (snapshot) => {
            const data = snapshot.val();
            if (data && data.localMessages && data.localMessages.length > 0) {
                for (let i = data.localMessages.length - 1; i >= 0; i--) {
                    if (data.localMessages[i].role === 'user') {
                        lastUserMessage = data.localMessages[i].content;
                        break;
                    }
                }
            }
        });
        
        return lastUserMessage;
    } catch (error) {
        console.error("Error fetching last user reply from Firebase Database:", error);
        throw error;
    }
}





async function getUserStatusFromFirebase(userID, requestType) {
    try {
        const ref = admin.database().ref('users/' + userID);
        let userMessageStatus;
        const snapshot = await ref.once('value');
        const userData = snapshot.val();
        if (userData) {
            if (userData.isSubscribed) {
                userData.paidMessageCount = (userData.paidMessageCount || 0) + 1;
                userMessageStatus = -1;
            } else {
                if (userData.freeMessageLeft > 0 && requestType === "new-message") {
                    userData.freeMessageLeft -= 1;
                    userMessageStatus = userData.freeMessageLeft;
                } else {
                    console.error('Free message limit reached and user is not subscribed:', userData);
                    throw new Error("Free message limit reached and user is not subscribed.");
                }
            }
            await ref.set(userData);
        } else {
            console.warn('No userData found for userID:', userID);
        }
        return userMessageStatus;
    } catch (error) {
        console.error("Error fetching last user reply from Firebase Database:", error);
        throw error;
    }
}

async function sendLastAssistantReply(dialogueID, res) {
    try {
        const ref = admin.database().ref('results/' + dialogueID);
        
        await ref.once('value', (snapshot) => {
            const data = snapshot.val();
            if (data && data.content) {
                const content = data.content;
                
                if (content) {
                    res.status(200).json({
                    role: "assistant",
                    content: content
                    });
                    console.log("Content sent", content);
                } else {
                    res.status(404).json({ error: "Content not found" });
                }
            } else {
                res.status(404).json({ error: "Content not found" });
            }
        });
    } catch (error) {
        console.error("Error sending assistant reply from Firebase Database:", error);
        res.status(500).json({ error: "Internal Server Error" });
    }
}

async function myFetch(url, options) {
    const {timeout, ...fetchOptions} = options;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout||30000)
    const res = await fetch(url, {...fetchOptions,signal:controller.signal});
    clearTimeout(timeoutId);
    return res;
}

// Error handler
app.use(function(err, req, res, next) {
    console.error(err)
    res.status(500).send('Internal Serverless Error')
})


async function saveResultToStorage(dialogueID, deviceToken, result, characterID, localMessages, fullPrompt, requestType, messageUUID) {
    // 确保 result.choices 是存在的
    if (result && result.choices && result.choices.length > 0) {
        const content = result.choices[0].message.content;
        const time = Date.now();
        
        let simplifiedResult = {
            fullPrompt,
            content,
            time,
            localMessages,
            deviceToken,
            characterID,
            messageUUID
        };

        const db = admin.database();
        const ref = db.ref(`results/${dialogueID}`);
        ref.set(simplifiedResult, (error) => {
            if (error) {
                console.error("Error saving data to Firebase Database:", error);
            } else {
                console.log("Data saved to Firebase Database successfully.");
            }
        });
    } else {
        console.error("saveResultToStorage: No choices found in the result.");
    }
}

async function saveTemporaryResultToStorage(dialogueID, deviceToken, character, localMessages, fullPrompt, requestType, messageUUID) {
    const db = admin.database();
    const ref = db.ref(`results/${dialogueID}`);
    
    // 解构获取到的结果，只保存需要的部分
    const time = Date.now(); // 获取当前时间（以毫秒为单位）
    
    // 创建一个新的对象来保存到数据库
    let simplifiedResult = {
        fullPrompt,
        time,
        localMessages,
        deviceToken,
        character,
        messageUUID
    };
    
    ref.set(simplifiedResult, (error) => {
        if (error) {
            console.error("Error saving data to Firebase Database:", error);
        } else {
            console.log("Temp Data saved to Firebase Database successfully");
        }
    });
}

async function pushNotification(deviceToken, message, usersReply, fullText, characterID, characterName, messageUUID) {
    if (deviceToken) {
        console.log("Start to push notifications.");
        let messageParts = message.split('#');
        
        for (let part of messageParts) {
            let note = new apn.Notification();
            note.rawPayload = {
                "aps": {
                    "alert": {
                        "title": characterName,
                        "body": part
                    },
                    "sound": "default",
                    "mutable-content": 1,
                    "category": "normal",
                    "raw-text": message,
                    "users-reply": usersReply,
                    "full-text": fullText,
                    "characterid": characterID,
                    "message-uuid": messageUUID
                },
                "target-content-id": characterID,
                "person": {
                    "id": characterID,
                    "name": characterName,
                    "handle": characterID
                }
            };
            note.topic = "com.penghaohuang.BuddyPark";
            
            // 打印将要发送的通知详情
            console.log(`Sending notification to device token: ${deviceToken}`);
            console.log(`Notification payload: ${JSON.stringify(note.rawPayload)}`);
            
            // 发送通知
            provider.send(note, deviceToken).then((response) => {
                // 打印成功发送的结果
                console.log("Notification sent successfully:", response);
                if (response.failed && response.failed.length > 0) {
                    // 打印失败的结果
                    response.failed.forEach((failure) => {
                        console.error("Notification failed:", failure);
                    });
                }
            }).catch((error) => {
                // 打印发送过程中捕获到的异常
                console.error("Error sending notification:", error);
            });
        }
    } else {
        console.log(`Device token not provided.`);
    }
}



function endResponse(res) {
    res.end();
}


const useMockData = false;  // 设置为true使用模拟数据，设置为false从Firebase获取数据

app.get('/getCharacters', async (req, res) => {
    const characterid = req.query.characterid;

    if (!characterid) {
        return res.status(400).send("characterid is required");
    }

    if (useMockData) {
        res.json(getMockCharacters(characterid));
    } else {
        try {
            const characters = await getCharactersFromFirebase(characterid);
            res.json(characters);
        } catch (error) {
            console.error('Server error: ', error);
            res.status(500).send("Server error");
        }
    }
});

function getMockCharacters(characterid) {
    const characters = [];
    for (let i = 0; i < 10; i++) {
        const currentId = (parseInt(characterid) + i).toString();
        characters.push({
            age: "12",
            characterName: `俊熙服务${currentId}号`,
            profileImage: "https://gpt-1251732024.cos.ap-shanghai.myqcloud.com/BuddyParkAvatar/03.png?q-sign-algorithm=sha1&q-ak=AKIDXY4sQ3N-Uhiug-Qe3AQO86_q6UKzkzlhFgDLDala_bGNEBZd6NdoqJBX1ILdySmh&q-sign-time=1702288380;1702291980&q-key-time=1702288380;1702291980&q-header-list=host&q-url-param-list=ci-process&q-signature=bbde2b018b317477bd35b2b119ebb99431e98454&x-cos-security-token=m8oaC9CQcvPItD5JmQ0RF0FCa1Whm6Za36ebbf8c11c3ca012c7c76729ddd3d19tIX303R_Mzs3aoZI1_BU0_PoxfRurOwPOn320lHHJlzTp88rCBK7VchNt7oIvY2saD3sSYrznaKDZ9zyhF7JtPusfAVmQJ_IB2gY9Zyu9s59ZtdaxmmaJux2qP26BIACOVjwnjqKox8d3yobj4AXunA9gtEXw7oiup2E4DUd5NtMumT4G2wCU9G9cKso2Kmk&ci-process=originImage",
            intro: "你是一个体育生",
            characterid: currentId
        });
    }
    return characters;
}


async function getCharactersFromFirebase(characterid) {
    try {
        const ref = admin.database().ref('Character');
        const characters = [];
        
        console.log('Starting loop to fetch 10 characters');  // 输出开始循环的日志
        
        // 获取10个连续的characterid
        for (let i = 0; i < 10; i++) {
            const currentId = (parseInt(characterid) + i).toString();  // 直接转换成字符串，不再进行前导零的填充
            console.log(`Fetching character with id: ${currentId}`);  // 输出当前获取的ID
            const snapshot = await ref.child(currentId).once('value');
            
            const characterData = snapshot.val();
            if (characterData) {
                characters.push({
                    age: characterData.age,
                    characterName: characterData.characterName,
                    profileImage: characterData.profileImage,
                    intro: characterData.intro,
                    characterid: currentId
                });
            } else {
                console.warn('No character found for characterid:', currentId);  // 输出警告日志
            }
        }

        console.log('Completed fetching characters'); // 输出完成循环的日志
        return characters;
    } catch (error) {
        console.error("Error fetching characters from Firebase Database:", error); // 输出错误日志
        throw error;
    }
}

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
        // 解析请求体中的参数
        const {
            identityToken,
            userName,
            userBio,
            userGender,
            roleGender
        } = req.body;

        // 其他验证逻辑保持不变
        const response = await fetch('https://appleid.apple.com/auth/keys');
        const applePublicKeys = await response.json();
        const header = jwt.decode(identityToken, { complete: true }).header;
        const applePublicKey = applePublicKeys.keys.find(
            key => key.kid === header.kid
        );
        const pem = jwkToPem(applePublicKey);
        const decoded = jwt.verify(identityToken, pem);
        const userIdentifier = decoded.sub;
        const hashedUserIdentifier = hashWithSHA256(userIdentifier);
        const db = admin.database();
        const ref = db.ref('users/' + hashedUserIdentifier);
        const userSnapshot = await ref.once('value');
        const userData = userSnapshot.val();

        if (userData) {
            // 用户已存在，返回已有信息
            return res.json({
                success: true,
                uuid: hashedUserIdentifier,
                isNewUser: false,
                freeMessageLeft: userData.freeMessageLeft
            });
        } else {
            // 用户不存在，创建新用户并保存新参数
            const creationTimestamp = Date.now();
            const freeMessageLeftValue = parseInt(process.env.FREE_MESSAGE_LEFT, 10) || 20;

            await ref.set({
                'sub': userIdentifier,
                'creationTime': creationTimestamp,
                'isTrialPeriod': false,
                'isSubscribed': false,
                'expiresDate': 0,
                'hasUsedTrial': false,
                'freeMessageLeft': freeMessageLeftValue,
                'userName': userName,
                'userBio': userBio,
                'userGender': userGender,
                'roleGender': roleGender
            });

            return res.json({
                success: true,
                uuid: hashedUserIdentifier,
                isNewUser: true,
                freeMessageLeft: freeMessageLeftValue
            });
        }
    } catch (error) {
        console.error('Error in /auth route:', error);
        return res.status(400).send('Invalid identityToken');
    }
});



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


exports.messageService = (req, res) => {
  // 如果你有跨域需求，你可能需要设置 CORS 头部
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');

  // 将请求转发给 Express 应用实例
  app(req, res);
};

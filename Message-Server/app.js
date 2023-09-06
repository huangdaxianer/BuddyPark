const express = require('express')
const fetch = require('cross-fetch')
const app = express()
var multer = require('multer');
var forms = multer({limits: { fieldSize: 10*1024*1024 }});
var admin = require('firebase-admin');
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
const serviceAccountParsed = JSON.parse(serviceAccount);
admin.initializeApp({
credential: admin.credential.cert(serviceAccountParsed),
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

app.all(`*`, async (req, res) => {
    //初始化常量
    const openai_key = process.env.OPENAI_KEY
    let isClientDisconnected = false;
    let url = `https://api.openai.com/v1/chat/completions`;
    //判断请求类型
    const requestType = req.headers["x-request-type"];
    const proxy_key = req.headers.authorization || "";
    if (process.env.PROXY_KEY && proxy_key !== process.env.PROXY_KEY)
        return res.status(403).send('Forbidden');
    //获取请求变量
    const dialogueID = req.headers['x-dialogueid'];
    const characterID = req.headers['x-characterid'];
    const userID = req.headers['x-userid'];
    const deviceToken = req.headers['x-device-token'];
    console.log('All request headers:', req.headers, 'Request body:', req.body);
        
    req.on('close', () => {
        isClientDisconnected = true;
    });
    
    var systemMessage;
    var prompt;
    var characterName;
    
    try {
        const databaseCharacterRef = admin.database().ref('Character/' + characterID);
        const snapshot = await databaseCharacterRef.once('value');
        const data = snapshot.val();
        if (data && data.prompt) {
            prompt = data.prompt;
            characterName = data.characterName;
            systemMessage = {
                role: "system",
                content: data.prompt
            };
        } else {
            res.status(404).json({ error: "Prompt not found" });
        }
    } catch (error) {
        throw error;
    }

    //定义 fullPrompt 变量，对于服务端类型为 remote push 的请求，缝合新的 prompt 到消息里；然后这里有一些历史上处理从服务端拿 Prompt 的逻辑
    var fullPrompt;
    var savedPrompt;
    if (requestType === "remote-push") {
        // 这种情况下 fullPrompt 的参数是从请求体中拿到的内容缝合请求头的内容
        let messages = req.body.messages || [];
        fullPrompt = messages[0].content + clientPrompt;
        savedPrompt = messages[0].content;
        await saveTemporaryResultToStorage(dialogueID, deviceToken, characterID, messages, prompt, requestType);
    }else if (requestType === "new-message"){
        // 这种情况下 fullPrompt 的参数直接套用 clientPrompt
        let messages = req.body.messages || [];
        await saveTemporaryResultToStorage(dialogueID, deviceToken, characterID, messages, prompt, requestType);
    }else if (requestType === "app-restart") {
        try {
            const lastUserReply = await getLastUserReplyFromFirebase(dialogueID);
            console.log('Last user reply:', lastUserReply);
            await sendLastAssistantReply(dialogueID, res);
        } catch (error) {
            console.error('Error occurred:', error);
            res.status(500).json({ error: "Internal Server Error" });
        }
        return;
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
        if (messages.length < 5) {
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
            console.log('testest');

            for (let i = 0; i < messagesAndSeparators.length - 1; i += 2) {
                console.log('1212121212');

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
                notificationPromises.push(pushNotification(deviceToken, message, usersReply, fullText, characterID, characterName));
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
            let data = JSON.parse(Buffer.concat(chunks).toString());
            // Await all pushNotification promises before saving the result to storage
            await Promise.all(notificationPromises);
            let localMessages = req.body.messages || [];
            await saveResultToStorage(dialogueID, deviceToken, data, characterID, localMessages, prompt, requestType);
        });
    } catch (error) {
        console.error(error);
        
        // 如果客户端已断开连接，不执行 res.status(500).json() 操作
        if(!isClientDisconnected) {
            res.status(500).json({"error":error.toString()});
        }
    }
})

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

const port = process.env.PORT||9000;
app.listen(port, () => {
    console.log(`Server start on http://localhost:${port}`);
})

async function saveResultToStorage(dialogueID, deviceToken, result, characterID, localMessages, prompt, requestType) {
    const db = admin.database();
    const ref = db.ref(`results/${dialogueID}`);
    
    // 解构获取到的结果，只保存需要的部分
    const content = result.choices[0].message.content;
    const time = Date.now(); // 获取当前时间（以毫秒为单位）
    
    // 创建一个新的对象来保存到数据库
    let simplifiedResult = {
        prompt,
        content,
        time,
        localMessages,
        deviceToken,
        characterID
    };
    
    ref.set(simplifiedResult, (error) => {
        if (error) {
            console.error("Error saving data to Firebase Database:", error);
        } else {
            console.log("Data saved to Firebase Database successfully.");
        }
    });
}

    
async function saveTemporaryResultToStorage(dialogueID, deviceToken, character, localMessages, prompt, requestType) {
    const db = admin.database();
    const ref = db.ref(`results/${dialogueID}`);
    
    // 解构获取到的结果，只保存需要的部分
    const time = Date.now(); // 获取当前时间（以毫秒为单位）
    
    // 创建一个新的对象来保存到数据库
    let simplifiedResult = {
        prompt,
        time,
        localMessages,
        deviceToken,
        character
    };
    
    ref.set(simplifiedResult, (error) => {
        if (error) {
            console.error("Error saving data to Firebase Database:", error);
        } else {
            console.log("Temp Data saved to Firebase Database successfully");
        }
    });
}

async function pushNotification(deviceToken, message, usersReply, fullText, characterID, characterName) {
    if (deviceToken) {
        console.log("start to push");
        let messageParts = message.split('#');
        
        for (let part of messageParts) {
            // 创建一个通知对象
            console.log(deviceToken, part, characterID, "finish");
            
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
//                    "free-message-left": freeMessageLeft,
                    "characterid": characterID
                },
                "target-content-id": characterID,
                "person": {
                    "id": characterID,
                    "name": characterName,
                    "handle": characterID  // 这个 handle 字段可以根据实际情况设置
                }
            };
            note.topic = "com.penghaohuang.BuddyPark";
            
            // 发送通知
            provider.send(note, deviceToken).then((result) => {
                console.log("Successfully sent message:", result);
            });
        }
    } else {
        console.log(`Device token not provided`);
    }
}

function endResponse(res) {
    res.end();
}

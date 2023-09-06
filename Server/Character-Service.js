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

let provider = new apn.Provider(apnsOptions);

app.get('/getCharacters', async (req, res) => {
    const characterid = req.query.characterid;  // 从请求中获取characterid
    console.log(`Received request for characterid: ${characterid}`); // 输出获取到的characterid

    if (!characterid) {
        console.error('Error: characterid is missing in the request');  // 输出错误日志
        return res.status(400).send("characterid is required");
    }

    try {
        console.log('Fetching characters from Firebase...'); // 输出开始获取数据的日志
        const characters = await getCharactersFromFirebase(characterid);
        console.log(`Retrieved ${characters.length} characters`); // 输出获取到的数据数量
        res.json(characters);
    } catch (error) {
        console.error('Server error: ', error);  // 输出服务器错误
        res.status(500).send("Server error");
    }
});

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
                    avatarImage: characterData.avatarImage,
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



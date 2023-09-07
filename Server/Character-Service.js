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

const useMockData = true;  // 设置为true使用模拟数据，设置为false从Firebase获取数据

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
            avatarImage: "https://gpt-1251732024.cos.ap-shanghai.myqcloud.com/IMG_6411.jpg",
            characterName: `俊熙服务${currentId}号`,
            profileImage: "https://gpt-1251732024.cos.ap-shanghai.myqcloud.com/IMG_6411.jpg",
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



const mongoose = require('mongoose');

const connectDB = async () => {
    try {
        // Use a local database by default for development. 
        // Ensure you have MongoDB running locally, or replace with a cloud URI via process.env.MONGO_URI
        const uri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/curenet_ocr';
        
        // await mongoose.connect(uri);
        // console.log(`[Database] MongoDB Connected to ${uri}`);
        console.log(`[Database] MongoDB connection bypassed. Using In-Memory mock DB.`);
    } catch (err) {
        // console.error(`[Database Error] ${err.message}`);
        // process.exit(1);
    }
};

module.exports = connectDB;

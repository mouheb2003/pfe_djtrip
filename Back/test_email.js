require("dotenv").config();
const nodemailer = require("nodemailer");

console.log("Testing email config:");
console.log("- Host:", process.env.EMAIL_HOST);
console.log("- Port:", process.env.EMAIL_PORT);
console.log("- User:", process.env.EMAIL_USER);

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST || "smtp.gmail.com",
  port: Number(process.env.EMAIL_PORT) || 465,
  secure: process.env.EMAIL_SECURE === "true",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD,
  },
});

transporter.verify()
  .then(() => {
    console.log("✅ Connexion SMTP réussie !");
  })
  .catch((err) => {
    console.error("❌ Erreur de connexion SMTP :", err.message);
  });

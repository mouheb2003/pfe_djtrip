const mongoose = require("mongoose");
const User = require("./user");

// Creating the Tourist schema that inherits from User via discriminator
const touristeSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
  },
  centres_interet: {
    type: [String],
    default: [],
  },
  langue_preferee: {
    type: String,
    default: "English",
  },
});

// Using the discriminator to inherit from User
const Touriste = User.discriminator("Touriste", touristeSchema);

module.exports = Touriste;

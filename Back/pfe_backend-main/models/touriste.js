const mongoose = require('mongoose');
const User = require('./user');

// Création du schéma Touriste qui hérite de User via discriminator
const touristeSchema = new mongoose.Schema({
    centres_interet: {
        type: [String],
        default: []
    },
    langue_preferee: {
        type: String,
        default: 'Français'
    }
});

// Utilisation du discriminator pour hériter de User
const Touriste = User.discriminator('Touriste', touristeSchema);

module.exports = Touriste;

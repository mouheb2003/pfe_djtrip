const express = require('express');
const router = express.Router();
const User = require('../models/user');
const { verifyToken } = require('../middleware/auth');

// Disconnect all users - Admin only endpoint
router.post('/disconnect-all', verifyToken, async (req, res) => {
  try {
    // Check if user is admin
    if (req.user.userType !== 'Admin') {
      return res.status(403).json({
        message: "Forbidden: Admin access required",
        error: "Unauthorized access"
      });
    }

    console.log('🔌 [DISCONNECT_ALL] Admin requested to disconnect all users');
    
    // Update all users to offline status
    const result = await User.updateMany(
      {}, // All users
      { 
        $set: { 
          lastActiveAt: new Date(Date.now() - 60000), // Set to 60 seconds ago to ensure offline status
          isOnline: false 
        }
      }
    );

    console.log(`🔌 [DISCONNECT_ALL] Updated ${result.modifiedCount} users to offline status`);
    
    res.json({
      success: true,
      message: `Successfully disconnected ${result.modifiedCount} users`,
      modifiedCount: result.modifiedCount
    });
  } catch (err) {
    console.error('❌ [DISCONNECT_ALL] Error disconnecting users:', err);
    res.status(500).json({
      message: "Error disconnecting users",
      error: err.message
    });
  }
});

module.exports = router;

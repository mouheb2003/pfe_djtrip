const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const User = require('../models/user');
const logger = require('../utils/logger');

/**
 * Socket.IO Handler
 * Real-time communication for live updates
 * - New bookings
 * - Booking status changes
 * - Check-in notifications
 * - Dashboard updates
 */

class SocketHandler {
  constructor(server) {
    this.io = new Server(server, {
      cors: {
        origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
        methods: ['GET', 'POST'],
        credentials: true
      },
      transports: ['websocket', 'polling'],
      pingTimeout: 60000,
      pingInterval: 25000
    });
    
    this.setupMiddleware();
    this.setupEvents();
  }
  
  /**
   * Setup authentication middleware
   */
  setupMiddleware() {
    this.io.use(async (socket, next) => {
      try {
        const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
        
        if (!token) {
          return next(new Error('Authentication token required'));
        }
        
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await User.findById(decoded.userId).select('email fullname accountStatus');
        
        if (!user) {
          return next(new Error('User not found'));
        }
        
        if (user.accountStatus !== 'active') {
          return next(new Error('Account is not active'));
        }
        
        socket.user = user;
        socket.userId = user._id.toString();
        socket.userType = decoded.userType;
        
        next();
      } catch (error) {
        logger.error('Socket authentication failed', { error: error.message });
        next(new Error('Authentication failed'));
      }
    });
  }
  
  /**
   * Setup socket events
   */
  setupEvents() {
    this.io.on('connection', (socket) => {
      logger.info('User connected', { 
        userId: socket.userId, 
        userType: socket.userType,
        socketId: socket.id 
      });
      
      // Join user-specific room
      socket.join(`user:${socket.userId}`);
      
      // Join role-specific rooms
      if (socket.userType === 'organisateur') {
        socket.join(`organizer:${socket.userId}`);
        socket.join('organizers');
      } else if (socket.userType === 'touriste') {
        socket.join('tourists');
      }
      
      // Booking events
      socket.on('booking:created', (data) => {
        this.handleBookingCreated(socket, data);
      });
      
      socket.on('booking:approved', (data) => {
        this.handleBookingApproved(socket, data);
      });
      
      socket.on('booking:rejected', (data) => {
        this.handleBookingRejected(socket, data);
      });
      
      socket.on('booking:cancelled', (data) => {
        this.handleBookingCancelled(socket, data);
      });
      
      // Check-in events
      socket.on('checkin:scanned', (data) => {
        this.handleCheckinScanned(socket, data);
      });
      
      socket.on('checkin:confirmed', (data) => {
        this.handleCheckinConfirmed(socket, data);
      });
      
      // Activity events
      socket.on('activity:updated', (data) => {
        this.handleActivityUpdated(socket, data);
      });
      
      // Comment events
      socket.on('comment:subscribe', (data) => {
        this.handleCommentSubscribe(socket, data);
      });
      
      socket.on('comment:unsubscribe', (data) => {
        this.handleCommentUnsubscribe(socket, data);
      });
      
      // Dashboard events
      socket.on('dashboard:subscribe', (data) => {
        this.handleDashboardSubscribe(socket, data);
      });
      
      socket.on('disconnect', (reason) => {
        logger.info('User disconnected', { 
          userId: socket.userId, 
          socketId: socket.id,
          reason 
        });
      });
    });
  }
  
  /**
   * Handle new booking event
   */
  handleBookingCreated(socket, data) {
    // Notify organizer
    this.io.to(`organizer:${data.organizerId}`).emit('booking:new', {
      bookingId: data.bookingId,
      touristName: data.touristName,
      activityTitle: data.activityTitle,
      participants: data.participants,
      timestamp: new Date()
    });
    
    logger.info('Booking created event emitted', { bookingId: data.bookingId });
  }
  
  /**
   * Handle booking approved event
   */
  handleBookingApproved(socket, data) {
    // Notify tourist
    this.io.to(`user:${data.touristId}`).emit('booking:approved', {
      bookingId: data.bookingId,
      activityTitle: data.activityTitle,
      qrToken: data.qrToken,
      timestamp: new Date()
    });
    
    logger.info('Booking approved event emitted', { bookingId: data.bookingId });
  }
  
  /**
   * Handle booking rejected event
   */
  handleBookingRejected(socket, data) {
    // Notify tourist
    this.io.to(`user:${data.touristId}`).emit('booking:rejected', {
      bookingId: data.bookingId,
      activityTitle: data.activityTitle,
      reason: data.reason,
      timestamp: new Date()
    });
    
    logger.info('Booking rejected event emitted', { bookingId: data.bookingId });
  }
  
  /**
   * Handle booking cancelled event
   */
  handleBookingCancelled(socket, data) {
    // Notify organizer
    this.io.to(`organizer:${data.organizerId}`).emit('booking:cancelled', {
      bookingId: data.bookingId,
      touristName: data.touristName,
      activityTitle: data.activityTitle,
      reason: data.reason,
      timestamp: new Date()
    });
    
    logger.info('Booking cancelled event emitted', { bookingId: data.bookingId });
  }
  
  /**
   * Handle check-in scanned event
   */
  handleCheckinScanned(socket, data) {
    // Notify organizer dashboard
    this.io.to(`organizer:${data.organizerId}`).emit('checkin:scanned', {
      bookingId: data.bookingId,
      touristName: data.touristName,
      activityTitle: data.activityTitle,
      timestamp: new Date()
    });
    
    logger.info('Check-in scanned event emitted', { bookingId: data.bookingId });
  }
  
  /**
   * Handle check-in confirmed event
   */
  handleCheckinConfirmed(socket, data) {
    // Notify tourist
    this.io.to(`user:${data.touristId}`).emit('checkin:confirmed', {
      bookingId: data.bookingId,
      activityTitle: data.activityTitle,
      checkinTime: data.checkinTime,
      timestamp: new Date()
    });
    
    logger.info('Check-in confirmed event emitted', { bookingId: data.bookingId });
  }
  
  /**
   * Handle activity updated event
   */
  handleActivityUpdated(socket, data) {
    // Notify all users interested in this activity
    this.io.emit('activity:updated', {
      activityId: data.activityId,
      title: data.title,
      changes: data.changes,
      timestamp: new Date()
    });
    
    logger.info('Activity updated event emitted', { activityId: data.activityId });
  }
  
  /**
   * Handle comment subscription (join post room)
   */
  handleCommentSubscribe(socket, data) {
    const { postId } = data;
    
    if (postId) {
      socket.join(`post:${postId}`);
      
      socket.emit('comment:subscribed', {
        postId,
        timestamp: new Date()
      });
      
      logger.info('Comment subscription', { 
        userId: socket.userId, 
        postId 
      });
    }
  }
  
  /**
   * Handle comment unsubscription (leave post room)
   */
  handleCommentUnsubscribe(socket, data) {
    const { postId } = data;
    
    if (postId) {
      socket.leave(`post:${postId}`);
      
      socket.emit('comment:unsubscribed', {
        postId,
        timestamp: new Date()
      });
      
      logger.info('Comment unsubscription', { 
        userId: socket.userId, 
        postId 
      });
    }
  }
  
  /**
   * Emit comment created event to post room
   */
  emitCommentCreated(postId, comment) {
    this.io.to(`post:${postId}`).emit('comment:created', comment);
    logger.info('Comment created event emitted', { postId, commentId: comment._id });
  }
  
  /**
   * Emit comment deleted event to post room
   */
  emitCommentDeleted(postId, commentId) {
    this.io.to(`post:${postId}`).emit('comment:deleted', { commentId });
    logger.info('Comment deleted event emitted', { postId, commentId });
  }
  
  /**
   * Emit comment updated event to post room
   */
  emitCommentUpdated(postId, comment) {
    this.io.to(`post:${postId}`).emit('comment:updated', comment);
    logger.info('Comment updated event emitted', { postId, commentId: comment._id });
  }
  
  /**
   * Handle dashboard subscription
   */
  handleDashboardSubscribe(socket, data) {
    const { dashboardType } = data;
    
    // Join dashboard-specific room
    socket.join(`dashboard:${dashboardType}:${socket.userId}`);
    
    socket.emit('dashboard:subscribed', {
      dashboardType,
      timestamp: new Date()
    });
    
    logger.info('Dashboard subscription', { 
      userId: socket.userId, 
      dashboardType 
    });
  }
  
  /**
   * Emit event to specific user
   */
  emitToUser(userId, event, data) {
    this.io.to(`user:${userId}`).emit(event, data);
  }
  
  /**
   * Emit event to specific organizer
   */
  emitToOrganizer(organizerId, event, data) {
    this.io.to(`organizer:${organizerId}`).emit(event, data);
  }
  
  /**
   * Emit event to all organizers
   */
  emitToAllOrganizers(event, data) {
    this.io.to('organizers').emit(event, data);
  }
  
  /**
   * Emit event to all tourists
   */
  emitToAllTourists(event, data) {
    this.io.to('tourists').emit(event, data);
  }
  
  /**
   * Emit event to all connected users
   */
  emitToAll(event, data) {
    this.io.emit(event, data);
  }
  
  /**
   * Get connected users count
   */
  getConnectedCount() {
    return this.io.sockets.sockets.size;
  }
  
  /**
   * Get connected users by type
   */
  async getConnectedUsersByType() {
    const sockets = await this.io.fetchSockets();
    const counts = { organisateur: 0, touriste: 0, admin: 0 };
    
    sockets.forEach(socket => {
      if (socket.userType) {
        counts[socket.userType] = (counts[socket.userType] || 0) + 1;
      }
    });
    
    return counts;
  }
  
  /**
   * Graceful shutdown
   */
  async close() {
    await this.io.close();
    logger.info('Socket.IO server closed');
  }
}

module.exports = SocketHandler;

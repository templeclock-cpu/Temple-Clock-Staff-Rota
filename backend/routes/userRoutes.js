const express = require('express');
const { getUsers, getUserById, createUser, updateUser, updateMyProfile, deleteUser } = require('../controllers/userController');
const { protect, authorize, validateObjectId } = require('../middleware/auth');

const router = express.Router();

// All routes below require authentication
router.use(protect);

// GET /api/users - Get all users (admin only)
router.get('/', authorize('admin'), getUsers);

// POST /api/users - Create new user (admin only)
router.post('/', authorize('admin'), createUser);

// PUT /api/users/me - Update own profile (any authenticated user)
router.put('/me', updateMyProfile);

// GET /api/users/:id - Get single user
router.get('/:id', validateObjectId, getUserById);

// PUT /api/users/:id - Update user (admin only)
router.put('/:id', validateObjectId, authorize('admin'), updateUser);

// DELETE /api/users/:id - Deactivate user (admin only)
router.delete('/:id', validateObjectId, authorize('admin'), deleteUser);

module.exports = router;

const User = require('../models/User');

// @desc    Get all users (staff list)
// @route   GET /api/users
// @access  Private/Admin
const getUsers = async (req, res) => {
  try {
    const users = await User.find({ isActive: true }).select('-password').sort({ name: 1 });
    res.json(users);
  } catch (error) {
    console.error('GetUsers error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get single user by ID
// @route   GET /api/users/:id
// @access  Private
const getUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password');

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Staff can only view their own profile
    if (req.user.role === 'staff' && req.user._id.toString() !== req.params.id) {
      return res.status(403).json({ message: 'Not authorized to view this profile' });
    }

    res.json(user);
  } catch (error) {
    console.error('GetUserById error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Create a new user (employee)
// @route   POST /api/users
// @access  Private/Admin
const createUser = async (req, res) => {
  try {
    const { name, email, password, role, hourlyRate, phone, department, profileImage } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Name, email and password are required' });
    }

    // Check if user already exists
    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(409).json({ message: 'A user with this email already exists' });
    }

    const user = await User.create({
      name,
      email: email.toLowerCase(),
      password,
      role: role || 'staff',
      hourlyRate: hourlyRate || 0,
      phone: phone || '',
      department: department || '',
      profileImage: profileImage || null,
    });

    // Return user without password
    const userObj = user.toObject();
    delete userObj.password;

    res.status(201).json(userObj);
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({ message: 'A user with this email already exists' });
    }
    console.error('CreateUser error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update user
// @route   PUT /api/users/:id
// @access  Private/Admin
const updateUser = async (req, res) => {
  try {
    const { name, email, role, hourlyRate, annualLeaveBalance, phone, department, isActive, profileImage } =
      req.body;

    const user = await User.findById(req.params.id);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // ── SAFEGUARD: Admin cannot change their OWN role ──
    const isSelf = req.user._id.toString() === req.params.id;
    if (isSelf && role && role !== user.role) {
      return res.status(403).json({
        message: 'You cannot change your own role. Ask another admin to do this.',
      });
    }

    // ── SAFEGUARD: Admin cannot deactivate themselves ──
    if (isSelf && isActive === false) {
      return res.status(403).json({
        message: 'You cannot deactivate your own account.',
      });
    }

    // Update fields if provided
    if (name) user.name = name;
    if (email) user.email = email;
    if (role) user.role = role;
    if (hourlyRate !== undefined) user.hourlyRate = hourlyRate;
    if (annualLeaveBalance !== undefined) user.annualLeaveBalance = annualLeaveBalance;
    if (phone) user.phone = phone;
    if (department) user.department = department;
    if (isActive !== undefined) user.isActive = isActive;
    if (profileImage !== undefined) user.profileImage = profileImage;

    const updatedUser = await user.save();
    const userObj = updatedUser.toObject();
    delete userObj.password;
    res.json(userObj);
  } catch (error) {
    console.error('UpdateUser error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Update own profile (staff self-edit)
// @route   PUT /api/users/me
// @access  Private (any authenticated user)
const updateMyProfile = async (req, res) => {
  try {
    const { phone, profileImage } = req.body;
    const user = await User.findById(req.user._id);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Staff can update their own phone and profile image
    if (phone !== undefined) user.phone = phone;
    if (profileImage !== undefined) user.profileImage = profileImage;

    const updatedUser = await user.save();
    const userObj = updatedUser.toObject();
    delete userObj.password;
    res.json(userObj);
  } catch (error) {
    console.error('UpdateMyProfile error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Delete user (soft delete - sets isActive to false)
// @route   DELETE /api/users/:id
// @access  Private/Admin
const deleteUser = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // ── SAFEGUARD: Admin cannot delete themselves ──
    if (req.user._id.toString() === req.params.id) {
      return res.status(403).json({
        message: 'You cannot deactivate your own account.',
      });
    }

    // Soft delete: mark as inactive instead of removing
    user.isActive = false;
    await user.save();

    res.json({ message: 'User deactivated successfully' });
  } catch (error) {
    console.error('DeleteUser error:', error.message);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { getUsers, getUserById, createUser, updateUser, updateMyProfile, deleteUser };

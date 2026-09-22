const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { createAutoRequest, getMyAutoGroups, getAutoGroup, confirmAutoGroup, leaveAutoGroup } = require('../controllers/autoGroupController');

router.post('/requests', protect, createAutoRequest);
router.get('/my-groups', protect, getMyAutoGroups);
router.get('/:id', protect, getAutoGroup);
router.patch('/:id/confirm', protect, confirmAutoGroup);
router.patch('/:id/leave', protect, leaveAutoGroup);

module.exports = router;

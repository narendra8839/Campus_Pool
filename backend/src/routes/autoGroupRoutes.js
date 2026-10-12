const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { getMyAutoGroups, getAutoGroup, confirmAutoGroup, leaveAutoGroup } = require('../controllers/autoGroupController');
const {
  browseAutoGroups,
  createAutoGroupListing,
  decideAutoGroupJoinRequest,
  requestToJoinAutoGroup,
} = require('../controllers/autoGroupListingController');

router.get('/browse', protect, browseAutoGroups);
router.post('/groups', protect, createAutoGroupListing);
router.post('/requests', protect, createAutoGroupListing);
router.get('/my-groups', protect, getMyAutoGroups);
router.post('/:id/join-requests', protect, requestToJoinAutoGroup);
router.patch('/:id/join-requests/:requestId', protect, decideAutoGroupJoinRequest);
router.get('/:id', protect, getAutoGroup);
router.patch('/:id/confirm', protect, confirmAutoGroup);
router.patch('/:id/leave', protect, leaveAutoGroup);

module.exports = router;

const express = require('express');
const { route } = require('../controllers/routingController');

const router = express.Router();
router.get('/route', route);

module.exports = router;
